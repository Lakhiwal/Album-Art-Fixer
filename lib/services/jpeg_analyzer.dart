import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/audio_item.dart';

class JpegInspectionResult {
  final ArtworkCompliance compliance;
  final String description;
  final int? width;
  final int? height;
  final int? components;

  const JpegInspectionResult({
    required this.compliance,
    required this.description,
    this.width,
    this.height,
    this.components,
  });
}

class JpegAnalyzer {
  /// Inspects raw image bytes to detect Baseline, Progressive, Extended, CMYK, PNG, etc.
  static JpegInspectionResult inspectImage(Uint8List data) {
    if (data.isEmpty) {
      return const JpegInspectionResult(
        compliance: ArtworkCompliance.noArtwork,
        description: 'No artwork data',
      );
    }

    // Check PNG signature: 89 50 4E 47 0D 0A 1A 0A
    if (data.length >= 8 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      int? width;
      int? height;
      if (data.length >= 24) {
        width =
            (data[16] << 24) | (data[17] << 16) | (data[18] << 8) | data[19];
        height =
            (data[20] << 24) | (data[21] << 16) | (data[22] << 8) | data[23];
      }
      return JpegInspectionResult(
        compliance: ArtworkCompliance.png,
        description: 'PNG Cover (${width ?? '?'}x${height ?? '?'}) - Needs JPG',
        width: width,
        height: height,
      );
    }

    // Check WebP signature: RIFF .... WEBP
    if (data.length >= 12 &&
        data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x45 &&
        data[10] == 0x42 &&
        data[11] == 0x50) {
      return const JpegInspectionResult(
        compliance: ArtworkCompliance.otherFormat,
        description: 'WebP Cover - Needs Baseline JPG',
      );
    }

    // Check JPEG signature: FF D8
    if (data.length < 4 || data[0] != 0xFF || data[1] != 0xD8) {
      return const JpegInspectionResult(
        compliance: ArtworkCompliance.otherFormat,
        description: 'Non-JPEG/PNG Artwork',
      );
    }

    int pos = 2;
    while (pos + 3 < data.length) {
      if (data[pos] != 0xFF) {
        pos++;
        continue;
      }

      while (pos < data.length && data[pos] == 0xFF) {
        pos++;
      }
      if (pos >= data.length) break;

      final marker = data[pos++];

      // Markers without length field
      if (marker == 0xD9 || marker == 0xDA) break; // EOI or SOS
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) continue;

      if (pos + 1 >= data.length) break;
      final length = (data[pos] << 8) | data[pos + 1];
      if (length < 2 || pos + length > data.length) break;

      // Start of Frame markers
      if ((marker >= 0xC0 && marker <= 0xCF) &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        if (pos + 7 > data.length) break;
        final height = (data[pos + 3] << 8) | data[pos + 4];
        final width = (data[pos + 5] << 8) | data[pos + 6];
        final components = data[pos + 7];

        final dimStr = ' (${width}x$height)';

        // 4 components = CMYK or YCCK (Causes inverted colors/crash on DAP)
        if (components == 4) {
          return JpegInspectionResult(
            compliance: ArtworkCompliance.cmykJpeg,
            description: 'CMYK JPEG$dimStr (Inverted Colors on DAP)',
            width: width,
            height: height,
            components: components,
          );
        }

        if (marker == 0xC0) {
          final isOversized = width > 1000 || height > 1000;
          return JpegInspectionResult(
            compliance: ArtworkCompliance.baselineJpeg,
            description: isOversized
                ? 'Baseline JPEG$dimStr - Oversized for DAP'
                : 'Baseline JPEG$dimStr - HiBy Compliant',
            width: width,
            height: height,
            components: components,
          );
        } else if (marker == 0xC2) {
          return JpegInspectionResult(
            compliance: ArtworkCompliance.progressiveJpeg,
            description: 'Progressive JPEG$dimStr (HiBy Incompatible)',
            width: width,
            height: height,
            components: components,
          );
        } else {
          return JpegInspectionResult(
            compliance: ArtworkCompliance.extendedJpeg,
            description:
                'Extended JPEG (0x${marker.toRadixString(16).toUpperCase()})$dimStr',
            width: width,
            height: height,
            components: components,
          );
        }
      }

      pos += length;
    }

    return const JpegInspectionResult(
      compliance: ArtworkCompliance.otherFormat,
      description: 'Unknown JPEG Encoding',
    );
  }

  /// Converts any image bytes to strict Baseline JPEG (sRGB) in a background isolate
  static Future<Uint8List> convertToBaselineAsync({
    required Uint8List rawBytes,
    int maxDimension = 800,
    int quality = 90,
  }) {
    return Isolate.run(() => _convertToBaselineSync(
      rawBytes: rawBytes,
      maxDimension: maxDimension,
      quality: quality,
    ));
  }

  static Uint8List _convertToBaselineSync({
    required Uint8List rawBytes,
    int maxDimension = 800,
    int quality = 90,
  }) {
    img.Image? image;
    try {
      image = img.decodeImage(rawBytes);
    } catch (_) {
      throw Exception('Corrupted or unreadable image stream');
    }

    if (image == null) {
      throw Exception('Unable to decode image data');
    }

    img.Image processed = image;

    // Handle alpha channels / PNG transparency: blend onto clean black/dark background
    if (processed.hasAlpha) {
      final solidBg = img.Image(
        width: processed.width,
        height: processed.height,
        backgroundColor: img.ColorRgb8(15, 17, 23),
      );
      img.compositeImage(solidBg, processed);
      processed = solidBg;
    }

    // Ensure 3-channel RGB (converts CMYK or Grayscale to standard sRGB)
    if (processed.numChannels != 3) {
      processed = processed.convert(numChannels: 3);
    }

    // Resize if oversized while strictly preserving aspect ratio
    if (maxDimension > 0 &&
        (processed.width > maxDimension || processed.height > maxDimension)) {
      if (processed.width >= processed.height) {
        processed = img.copyResize(
          processed,
          width: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        processed = img.copyResize(
          processed,
          height: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // encodeJpg always writes baseline sequential DCT JPEG
    final encoded = img.encodeJpg(processed, quality: quality);
    final uint8Result = Uint8List.fromList(encoded);

    return uint8Result;
  }

  /// Generates a lightweight 96x96 thumbnail in background to prevent OutOfMemory
  static Future<Uint8List?> createThumbnailAsync(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return Future.value(null);
    if (rawBytes.length <= 48 * 1024) return Future.value(rawBytes);

    return Isolate.run(() {
      try {
        final decoded = img.decodeImage(rawBytes);
        if (decoded == null) return null;
        final resized = img.copyResize(
          decoded,
          width: 96,
          height: 96,
          interpolation: img.Interpolation.nearest,
        );
        return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
      } catch (_) {
        return null;
      }
    });
  }
}
