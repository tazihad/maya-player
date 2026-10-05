import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_model.dart';
import '../models/folder_model.dart';

enum VideoSortOption {
  nameAsc,
  nameDesc,
  dateDesc,
  dateAsc,
  sizeDesc,
  sizeAsc,
  durationDesc,
  durationAsc,
}

enum FolderSortOption {
  nameAsc,
  nameDesc,
  countDesc,
  countAsc,
  sizeDesc,
}

class VideoDiscoveryService {
  static final VideoDiscoveryService _instance =
      VideoDiscoveryService._internal();
  factory VideoDiscoveryService() => _instance;
  VideoDiscoveryService._internal();

  List<VideoModel> _allVideos = [];
  List<FolderModel> _folders = [];
  bool _isLoading = false;

  List<VideoModel> get allVideos => List.unmodifiable(_allVideos);
  List<FolderModel> get folders => List.unmodifiable(_folders);
  bool get isLoading => _isLoading;

  /// Check and request required permissions for media access
  Future<bool> requestPermissions() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        return true;
      }

      // Secondary check with permission_handler for Android 13+ and legacy
      if (Platform.isAndroid) {
        final videoStatus = await Permission.videos.request();
        if (videoStatus.isGranted) return true;

        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error requesting media permissions: $e');
      return false;
    }
  }

  /// Scan device and discover all videos, grouping them by folder (VLC style)
  Future<void> scanVideos() async {
    _isLoading = true;
    _allVideos = [];
    _folders = [];

    try {
      final bool hasPerm = await requestPermissions();
      if (!hasPerm) {
        _isLoading = false;
        return;
      }

      // Fetch all video albums/paths
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        hasAll: true,
        onlyAll: false,
      );

      final Map<String, List<VideoModel>> folderMap = {};
      final List<VideoModel> flatVideosList = [];

      for (final album in albums) {
        // Skip the virtual "Recent" / "All" album for folder grouping, but read from it if it's the only one
        final int totalAssets = await album.assetCountAsync;
        if (totalAssets == 0) continue;

        final List<AssetEntity> entities =
            await album.getAssetListRange(start: 0, end: totalAssets);

        for (final entity in entities) {
          // Resolve file info
          final File? file = await entity.file;
          final String filePath = file?.path ?? '';
          if (filePath.isEmpty && entity.relativePath == null) continue;

          // Determine folder name & path
          String folderName = album.name;
          String folderPath = '';

          if (filePath.isNotEmpty) {
            final fileDir = Directory(filePath).parent;
            folderName = fileDir.path.split(Platform.pathSeparator).last;
            folderPath = fileDir.path;
          } else {
            folderName = album.name;
            folderPath = album.id;
          }

          if (folderName.trim().isEmpty) {
            folderName = 'Internal Storage';
          }

          final video = VideoModel(
            id: entity.id,
            title: entity.title ?? (filePath.isNotEmpty ? filePath.split(Platform.pathSeparator).last : 'Video_${entity.id}'),
            path: filePath,
            duration: Duration(seconds: entity.duration),
            size: (await file?.length()) ?? 0,
            dateModified: entity.createDateTime,
            folderName: folderName,
            folderPath: folderPath,
            width: entity.width,
            height: entity.height,
            assetEntity: entity,
          );

          // Avoid duplicate entries in allVideos
          if (!flatVideosList.any((v) => v.id == video.id || (v.path.isNotEmpty && v.path == video.path))) {
            flatVideosList.add(video);
          }

          // Add to folder group
          final groupKey = folderName;
          if (!folderMap.containsKey(groupKey)) {
            folderMap[groupKey] = [];
          }

          if (!folderMap[groupKey]!.any((v) => v.id == video.id || (v.path.isNotEmpty && v.path == video.path))) {
            folderMap[groupKey]!.add(video);
          }
        }
      }

      _allVideos = flatVideosList;

      // Build folder models
      final List<FolderModel> generatedFolders = [];
      folderMap.forEach((name, videos) {
        if (videos.isNotEmpty) {
          final firstPath = videos.first.folderPath;
          generatedFolders.add(FolderModel(
            id: name,
            name: name,
            path: firstPath,
            videos: videos,
          ));
        }
      });

      _folders = generatedFolders;

      // Default sort
      sortVideos(VideoSortOption.dateDesc);
      sortFolders(FolderSortOption.nameAsc);
    } catch (e, stack) {
      debugPrint('Error discovering videos: $e\n$stack');
    } finally {
      _isLoading = false;
    }
  }

  void sortVideos(VideoSortOption option) {
    switch (option) {
      case VideoSortOption.nameAsc:
        _allVideos.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case VideoSortOption.nameDesc:
        _allVideos.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case VideoSortOption.dateDesc:
        _allVideos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
        break;
      case VideoSortOption.dateAsc:
        _allVideos.sort((a, b) => a.dateModified.compareTo(b.dateModified));
        break;
      case VideoSortOption.sizeDesc:
        _allVideos.sort((a, b) => b.size.compareTo(a.size));
        break;
      case VideoSortOption.sizeAsc:
        _allVideos.sort((a, b) => a.size.compareTo(b.size));
        break;
      case VideoSortOption.durationDesc:
        _allVideos.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      case VideoSortOption.durationAsc:
        _allVideos.sort((a, b) => a.duration.compareTo(b.duration));
        break;
    }

    // Sort videos inside each folder as well
    for (final folder in _folders) {
      switch (option) {
        case VideoSortOption.nameAsc:
          folder.videos.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          break;
        case VideoSortOption.nameDesc:
          folder.videos.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
          break;
        case VideoSortOption.dateDesc:
          folder.videos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
          break;
        case VideoSortOption.dateAsc:
          folder.videos.sort((a, b) => a.dateModified.compareTo(b.dateModified));
          break;
        case VideoSortOption.sizeDesc:
          folder.videos.sort((a, b) => b.size.compareTo(a.size));
          break;
        case VideoSortOption.sizeAsc:
          folder.videos.sort((a, b) => a.size.compareTo(b.size));
          break;
        case VideoSortOption.durationDesc:
          folder.videos.sort((a, b) => b.duration.compareTo(a.duration));
          break;
        case VideoSortOption.durationAsc:
          folder.videos.sort((a, b) => a.duration.compareTo(b.duration));
          break;
      }
    }
  }

  void sortFolders(FolderSortOption option) {
    switch (option) {
      case FolderSortOption.nameAsc:
        _folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FolderSortOption.nameDesc:
        _folders.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case FolderSortOption.countDesc:
        _folders.sort((a, b) => b.videoCount.compareTo(a.videoCount));
        break;
      case FolderSortOption.countAsc:
        _folders.sort((a, b) => a.videoCount.compareTo(b.videoCount));
        break;
      case FolderSortOption.sizeDesc:
        _folders.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
        break;
    }
  }
}
