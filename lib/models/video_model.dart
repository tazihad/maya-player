import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';

class VideoModel {
  final String id;
  final String title;
  final String path;
  final Duration duration;
  final int size; // in bytes
  final DateTime dateModified;
  final String folderName;
  final String folderPath;
  final int width;
  final int height;
  final AssetEntity? assetEntity;

  VideoModel({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.size,
    required this.dateModified,
    required this.folderName,
    required this.folderPath,
    this.width = 0,
    this.height = 0,
    this.assetEntity,
  });

  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get formattedSize {
    if (size <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double bytes = size.toDouble();
    while (bytes >= 1024 && i < suffixes.length - 1) {
      bytes /= 1024;
      i++;
    }
    return '${bytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String get resolutionBadge {
    if (width <= 0 || height <= 0) return '';
    if (width >= 3840 || height >= 2160) return '4K';
    if (width >= 1920 || height >= 1080) return '1080p';
    if (width >= 1280 || height >= 720) return '720p';
    if (width >= 854 || height >= 480) return '480p';
    return '${height}p';
  }

  Future<Uint8List?> getThumbnail({int width = 300, int height = 200}) async {
    if (assetEntity != null) {
      return await assetEntity!.thumbnailDataWithSize(
        ThumbnailSize(width, height),
        format: ThumbnailFormat.jpeg,
      );
    }
    return null;
  }
}
