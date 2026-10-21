import 'dart:io';

import 'package:haudiotagger/haudiotagger.dart';

import '../models/audio_item.dart';
import 'jpeg_analyzer.dart';

class AudioService {
  static const Set<String> supportedExtensions = {
    'flac',
    'm4a',
    'mp4',
    'alac',
    'mp3',
    'ogg',
    'opus',
    'wav',
    'aac',
    'aiff',
  };

  /// Discovers audio files recursively while safely skipping hidden system folders and macOS resource forks
  static List<File> listAudioFiles(String directoryPath) {
    final dir = Directory(directoryPath);
    if (!dir.existsSync()) return [];

    final audioFiles = <File>[];
    try {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;

          // Skip hidden files, system files, and backup files
          if (fileName.startsWith('.') ||
              fileName.startsWith('._') ||
              fileName.endsWith('.albumartfixer-backup') ||
              fileName.endsWith('.tmp')) {
            continue;
          }

          // Check if parent folder is hidden
          final pathParts = entity.path.split(Platform.pathSeparator);
          if (pathParts.any(
            (part) => part.startsWith('.') && part != '.' && part != '..',
          )) {
            continue;
          }

          final ext = fileName.contains('.')
              ? fileName.split('.').last.toLowerCase()
              : '';
          if (supportedExtensions.contains(ext)) {
            audioFiles.add(entity);
          }
        }
      }
    } catch (_) {
      // Graceful error handling for permission issues on subdirectories
    }
    return audioFiles;
  }

  /// Inspects a single audio file and parses its metadata and artwork
  static Future<AudioItem> inspectAudioFile(File file) async {
    final path = file.path;
    final fileName = file.path.split(Platform.pathSeparator).last;
    final parentDir = file.parent.path;
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    final backupFile = File('$path.albumartfixer-backup');
    final hasBackup = backupFile.existsSync();

    try {
      final tag = await Haudiotagger.read(path);

      if (tag == null || tag.pictures.isEmpty) {
        return AudioItem(
          path: path,
          fileName: fileName,
          parentDirectory: parentDir,
          extension: ext,
          title: tag?.title,
          artist: tag?.trackArtist ?? tag?.albumArtist,
          album: tag?.album,
          compliance: ArtworkCompliance.noArtwork,
          statusDescription: 'No embedded artwork found',
          hasBackup: hasBackup,
          isSelected: false,
        );
      }

      // Find the front cover or the first available picture
      final cover = tag.pictures.firstWhere(
        (p) => p.pictureType == PictureType.coverFront,
        orElse: () => tag.pictures.first,
      );

      final inspection = JpegAnalyzer.inspectImage(cover.bytes);
      final thumb = JpegAnalyzer.createThumbnail(cover.bytes);

      final needsFix =
          inspection.compliance != ArtworkCompliance.baselineJpeg ||
          (inspection.width != null && inspection.width! > 1000) ||
          (inspection.height != null && inspection.height! > 1000);

      return AudioItem(
        path: path,
        fileName: fileName,
        parentDirectory: parentDir,
        extension: ext,
        title: tag.title,
        artist: tag.trackArtist ?? tag.albumArtist,
        album: tag.album,
        compliance: inspection.compliance,
        statusDescription: inspection.description,
        artworkWidth: inspection.width,
        artworkHeight: inspection.height,
        artworkBytesLength: cover.bytes.length,
        thumbnailBytes: thumb,
        isSelected: needsFix,
        hasBackup: hasBackup,
      );
    } catch (e) {
      return AudioItem(
        path: path,
        fileName: fileName,
        parentDirectory: parentDir,
        extension: ext,
        compliance: ArtworkCompliance.error,
        statusDescription: 'Read Error: ${e.toString()}',
        hasBackup: hasBackup,
        isSelected: false,
      );
    }
  }

  /// Fixes the artwork for an AudioItem: converts to Baseline JPEG and updates the file tags
  static Future<void> fixAudioItem(
    AudioItem item, {
    int maxDimension = 800,
    bool createBackup = false,
    bool exportFolderCover = false,
  }) async {
    final file = File(item.path);
    if (!file.existsSync()) {
      item.conversionResult = 'Error: File does not exist';
      return;
    }

    try {
      final tag = await Haudiotagger.read(item.path);
      if (tag == null || tag.pictures.isEmpty) {
        item.conversionResult = 'Skipped: No artwork to convert';
        return;
      }

      // Create backup if requested and not already existing
      if (createBackup) {
        final backupPath = '${item.path}.albumartfixer-backup';
        final backupFile = File(backupPath);
        if (!backupFile.existsSync()) {
          await file.copy(backupPath);
          item.hasBackup = true;
        }
      }

      final updatedPictures = <Picture>[];

      for (final pic in tag.pictures) {
        final inspection = JpegAnalyzer.inspectImage(pic.bytes);

        final isOversized =
            (inspection.width != null && inspection.width! > maxDimension) ||
            (inspection.height != null && inspection.height! > maxDimension);

        if (inspection.compliance == ArtworkCompliance.baselineJpeg &&
            !isOversized) {
          // Already baseline and within dimensions
          updatedPictures.add(pic);
        } else {
          // Convert progressive / PNG / CMYK / oversized to clean baseline JPEG
          final baselineBytes = JpegAnalyzer.convertToBaseline(
            rawBytes: pic.bytes,
            maxDimension: maxDimension,
            quality: 90,
          );

          updatedPictures.add(
            Picture(
              pictureType: pic.pictureType,
              mimeType: MimeType.jpeg,
              bytes: baselineBytes,
            ),
          );

          // Also export cover.jpg in album folder if requested
          if (exportFolderCover && pic.pictureType == PictureType.coverFront) {
            try {
              final folderCoverFile = File(
                '${file.parent.path}${Platform.pathSeparator}cover.jpg',
              );
              if (!folderCoverFile.existsSync()) {
                await folderCoverFile.writeAsBytes(baselineBytes);
              }
            } catch (_) {}
          }
        }
      }

      // Write updated tag with new pictures back to the file using direct path writer
      final updatedTag = tag.copyWith(pictures: updatedPictures);
      await Haudiotagger.write(item.path, updatedTag);

      // Verify the write
      final verifyTag = await Haudiotagger.read(item.path);
      if (verifyTag != null && verifyTag.pictures.isNotEmpty) {
        final verifyCover = verifyTag.pictures.firstWhere(
          (p) => p.pictureType == PictureType.coverFront,
          orElse: () => verifyTag.pictures.first,
        );
        final verifyInspection = JpegAnalyzer.inspectImage(verifyCover.bytes);

        if (verifyInspection.compliance == ArtworkCompliance.baselineJpeg) {
          item.isConverted = true;
          item.conversionResult =
              'Fixed: Converted to Baseline JPEG (${verifyInspection.width}x${verifyInspection.height})';
        } else {
          item.conversionResult =
              'Warning: Saved (${verifyInspection.description})';
        }
      } else {
        item.conversionResult = 'Error: Artwork missing after update';
      }
    } catch (e) {
      item.conversionResult = 'Error: ${e.toString()}';
    }
  }

  /// Restores original audio file from its sibling .albumartfixer-backup file
  static Future<bool> restoreBackup(AudioItem item) async {
    final backupPath = '${item.path}.albumartfixer-backup';
    final backupFile = File(backupPath);
    if (!backupFile.existsSync()) {
      item.conversionResult = 'No backup file found';
      return false;
    }

    try {
      final targetFile = File(item.path);
      await backupFile.copy(targetFile.path);
      await backupFile.delete();

      item.isConverted = false;
      item.hasBackup = false;
      item.conversionResult = 'Restored to original artwork';
      return true;
    } catch (e) {
      item.conversionResult = 'Restore Error: ${e.toString()}';
      return false;
    }
  }
}
