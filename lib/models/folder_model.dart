import 'video_model.dart';

class FolderModel {
  final String id;
  final String name;
  final String path;
  final List<VideoModel> videos;

  FolderModel({
    required this.id,
    required this.name,
    required this.path,
    required this.videos,
  });

  int get videoCount => videos.length;

  int get totalSizeBytes =>
      videos.fold(0, (previousValue, element) => previousValue + element.size);

  String get totalSizeFormatted {
    final size = totalSizeBytes;
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

  VideoModel? get thumbnailVideo => videos.isNotEmpty ? videos.first : null;
}
