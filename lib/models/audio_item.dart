import 'dart:convert';
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
  final int? fileModifiedMs;
  final int? fileSize;
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
    this.fileModifiedMs,
    this.fileSize,
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

  Map<String, dynamic> toJson() => {
    'path': path,
    'fileName': fileName,
    'parentDirectory': parentDirectory,
    'extension': extension,
    'title': title,
    'artist': artist,
    'album': album,
    'compliance': compliance.name,
    'statusDescription': statusDescription,
    'artworkWidth': artworkWidth,
    'artworkHeight': artworkHeight,
    'artworkBytesLength': artworkBytesLength,
    'fileModifiedMs': fileModifiedMs,
    'fileSize': fileSize,
    'hasBackup': hasBackup,
    'thumbnailBase64': thumbnailBytes != null ? base64Encode(thumbnailBytes!) : null,
  };

  factory AudioItem.fromJson(Map<String, dynamic> json) {
    ArtworkCompliance comp;
    try {
      comp = ArtworkCompliance.values.firstWhere((e) => e.name == json['compliance']);
    } catch (_) {
      comp = ArtworkCompliance.error;
    }

    Uint8List? thumb;
    if (json['thumbnailBase64'] != null) {
      try {
        thumb = base64Decode(json['thumbnailBase64'] as String);
      } catch (_) {}
    }

    final item = AudioItem(
      path: json['path'] as String,
      fileName: json['fileName'] as String,
      parentDirectory: json['parentDirectory'] as String,
      extension: json['extension'] as String,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      compliance: comp,
      statusDescription: json['statusDescription'] as String? ?? '',
      artworkWidth: json['artworkWidth'] as int?,
      artworkHeight: json['artworkHeight'] as int?,
      artworkBytesLength: json['artworkBytesLength'] as int?,
      thumbnailBytes: thumb,
      fileModifiedMs: json['fileModifiedMs'] as int?,
      fileSize: json['fileSize'] as int?,
      hasBackup: json['hasBackup'] as bool? ?? false,
    );
    item.isSelected = item.needsFix;
    return item;
  }
}
