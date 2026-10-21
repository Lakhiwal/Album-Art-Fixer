import 'dart:typed_data';

enum ArtworkCompliance {
  baselineJpeg,
  progressiveJpeg,
  extendedJpeg,
  png,
  cmykJpeg,
  noArtwork,
  otherFormat,
  corruptArtwork,
  error,
}

class AudioItem {
  final String path;
  final String fileName;
  final String parentDirectory;
  final String extension;
  final String? title;
  final String? artist;
  final String? album;
  final ArtworkCompliance compliance;
  final String statusDescription;
  final int? artworkWidth;
  final int? artworkHeight;
  final int? artworkBytesLength;
  final Uint8List? thumbnailBytes;
  String? conversionResult;
  bool isConverted;
  bool isSelected;
  bool hasBackup;

  AudioItem({
    required this.path,
    required this.fileName,
    required this.parentDirectory,
    required this.extension,
    this.title,
    this.artist,
    this.album,
    required this.compliance,
    required this.statusDescription,
    this.artworkWidth,
    this.artworkHeight,
    this.artworkBytesLength,
    this.thumbnailBytes,
    this.conversionResult,
    this.isConverted = false,
    bool? isSelected,
    this.hasBackup = false,
  }) : isSelected = isSelected ?? false;

  bool get needsFix =>
      compliance == ArtworkCompliance.progressiveJpeg ||
      compliance == ArtworkCompliance.extendedJpeg ||
      compliance == ArtworkCompliance.cmykJpeg ||
      compliance == ArtworkCompliance.png ||
      compliance == ArtworkCompliance.otherFormat ||
      (artworkWidth != null && artworkWidth! > 1000) ||
      (artworkHeight != null && artworkHeight! > 1000);
}
