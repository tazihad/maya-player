// -----------------------------------------------------------------------------
// File Name:      lib/screens/home_screen.dart
// Description:    Main discovery screen with Folders and All Videos tabs.
// Author:         @tazihad
// Website:        https://zihad.com.bd
// License:        MIT License
// -----------------------------------------------------------------------------

// MIT License
//
// Copyright (c) 2024 @tazihad
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/folder_model.dart';
import '../models/video_model.dart';
import '../services/video_discovery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/folder_grid_item.dart';
import '../widgets/video_list_item.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final VideoDiscoveryService _discoveryService = VideoDiscoveryService();

  bool _isLoading = true;
  bool _hasPermission = true;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  VideoSortOption _videoSortOption = VideoSortOption.dateDesc;
  FolderSortOption _folderSortOption = FolderSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    final hasPerm = await _discoveryService.requestPermissions();
    if (!hasPerm) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
      return;
    }

    await _discoveryService.scanVideos();
    if (mounted) {
      setState(() {
        _hasPermission = true;
        _isLoading = false;
      });
    }
  }

  void _openUrlDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.primaryOrange),
            SizedBox(width: 8),
            Text('Open Network Stream', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter URL (http://, rtsp://, etc.)',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PlayerScreen(
                      directUrl: url,
                    ),
                  ),
                );
              }
            },
            child: const Text('Play Stream'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isFoldersTab = _tabController.index == 0;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    isFoldersTab ? 'Sort Folders By' : 'Sort Videos By',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(color: AppTheme.surfaceLightColor),
                if (isFoldersTab) ...[
                  _sortTile(
                    title: 'Folder Name (A - Z)',
                    selected: _folderSortOption == FolderSortOption.nameAsc,
                    onTap: () {
                      setState(() {
                        _folderSortOption = FolderSortOption.nameAsc;
                        _discoveryService.sortFolders(_folderSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'Folder Name (Z - A)',
                    selected: _folderSortOption == FolderSortOption.nameDesc,
                    onTap: () {
                      setState(() {
                        _folderSortOption = FolderSortOption.nameDesc;
                        _discoveryService.sortFolders(_folderSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'Most Videos',
                    selected: _folderSortOption == FolderSortOption.countDesc,
                    onTap: () {
                      setState(() {
                        _folderSortOption = FolderSortOption.countDesc;
                        _discoveryService.sortFolders(_folderSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'Total Size',
                    selected: _folderSortOption == FolderSortOption.sizeDesc,
                    onTap: () {
                      setState(() {
                        _folderSortOption = FolderSortOption.sizeDesc;
                        _discoveryService.sortFolders(_folderSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ] else ...[
                  _sortTile(
                    title: 'Date Modified (Newest first)',
                    selected: _videoSortOption == VideoSortOption.dateDesc,
                    onTap: () {
                      setState(() {
                        _videoSortOption = VideoSortOption.dateDesc;
                        _discoveryService.sortVideos(_videoSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'Date Modified (Oldest first)',
                    selected: _videoSortOption == VideoSortOption.dateAsc,
                    onTap: () {
                      setState(() {
                        _videoSortOption = VideoSortOption.dateAsc;
                        _discoveryService.sortVideos(_videoSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'Name (A - Z)',
                    selected: _videoSortOption == VideoSortOption.nameAsc,
                    onTap: () {
                      setState(() {
                        _videoSortOption = VideoSortOption.nameAsc;
                        _discoveryService.sortVideos(_videoSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'File Size (Largest first)',
                    selected: _videoSortOption == VideoSortOption.sizeDesc,
                    onTap: () {
                      setState(() {
                        _videoSortOption = VideoSortOption.sizeDesc;
                        _discoveryService.sortVideos(_videoSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                  _sortTile(
                    title: 'Duration (Longest first)',
                    selected: _videoSortOption == VideoSortOption.durationDesc,
                    onTap: () {
                      setState(() {
                        _videoSortOption = VideoSortOption.durationDesc;
                        _discoveryService.sortVideos(_videoSortOption);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: selected ? AppTheme.primaryOrange : AppTheme.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check, color: AppTheme.primaryOrange)
          : null,
      onTap: onTap,
    );
  }

  List<FolderModel> get _filteredFolders {
    if (_searchQuery.trim().isEmpty) {
      return _discoveryService.folders;
    }
    return _discoveryService.folders
        .where((f) =>
            f.name.toLowerCase().contains(_searchQuery.trim().toLowerCase()) ||
            f.videos.any((v) =>
                v.title.toLowerCase().contains(_searchQuery.trim().toLowerCase())))
        .toList();
  }

  List<VideoModel> get _filteredVideos {
    if (_searchQuery.trim().isEmpty) {
      return _discoveryService.allVideos;
    }
    return _discoveryService.allVideos
        .where((v) =>
            v.title.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search videos and folders...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppTheme.primaryOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Maya Player'),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'mpv',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Open Stream URL',
            onPressed: _openUrlDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan Videos',
            onPressed: _loadVideos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Folders (${_discoveryService.folders.length})',
              icon: const Icon(Icons.folder_outlined, size: 20),
            ),
            Tab(
              text: 'All Videos (${_discoveryService.allVideos.length})',
              icon: const Icon(Icons.video_library_outlined, size: 20),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return _buildPermissionDeniedView();
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryOrange),
            SizedBox(height: 16),
            Text(
              'Discovering videos on device...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // Folders Tab
        RefreshIndicator(
          color: AppTheme.primaryOrange,
          onRefresh: _loadVideos,
          child: _buildFoldersView(),
        ),

        // All Videos Tab
        RefreshIndicator(
          color: AppTheme.primaryOrange,
          onRefresh: _loadVideos,
          child: _buildAllVideosView(),
        ),
      ],
    );
  }

  Widget _buildFoldersView() {
    final folders = _filteredFolders;

    if (folders.isEmpty) {
      return _buildEmptyView('No video folders found');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        return FolderGridItem(folder: folders[index]);
      },
    );
  }

  Widget _buildAllVideosView() {
    final videos = _filteredVideos;

    if (videos.isEmpty) {
      return _buildEmptyView('No videos found');
    }

    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return VideoListItem(
          video: videos[index],
          playlist: _discoveryService.allVideos,
        );
      },
    );
  }

  Widget _buildEmptyView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_collection_outlined,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Rescan'),
            onPressed: _loadVideos,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_special_outlined,
              size: 72,
              color: AppTheme.primaryOrange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Maya Player needs storage and media permissions to discover and group video files stored on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _loadVideos,
              child: const Text(
                'Grant Permissions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text(
                'Open App Settings',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
