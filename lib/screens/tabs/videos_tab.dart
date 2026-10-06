// -----------------------------------------------------------------------------
// File Name:      lib/screens/tabs/videos_tab.dart
// Description:    All videos tab with Grid and List views, sorting, and search.
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
import '../../models/video_model.dart';
import '../../services/video_discovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video_list_item.dart';
import '../../widgets/video_thumbnail_widget.dart';
import '../player_screen.dart';

class VideosTab extends StatefulWidget {
  final VideoDiscoveryService discoveryService;
  final VoidCallback onRefresh;

  const VideosTab({
    super.key,
    required this.discoveryService,
    required this.onRefresh,
  });

  @override
  State<VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<VideosTab> {
  bool _isGridView = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  VideoSortOption _sortOption = VideoSortOption.dateDesc;

  List<VideoModel> get _filteredVideos {
    if (_searchQuery.trim().isEmpty) {
      return widget.discoveryService.allVideos;
    }
    return widget.discoveryService.allVideos
        .where((v) =>
            v.title.toLowerCase().contains(_searchQuery.trim().toLowerCase()) ||
            v.folderName.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
        .toList();
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Sort Videos By',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppTheme.surfaceLightDark),
              _sortTile('Date Modified (Newest first)', VideoSortOption.dateDesc),
              _sortTile('Date Modified (Oldest first)', VideoSortOption.dateAsc),
              _sortTile('Name (A - Z)', VideoSortOption.nameAsc),
              _sortTile('Name (Z - A)', VideoSortOption.nameDesc),
              _sortTile('File Size (Largest first)', VideoSortOption.sizeDesc),
              _sortTile('Duration (Longest first)', VideoSortOption.durationDesc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(String title, VideoSortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryOrange : AppTheme.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryOrange) : null,
      onTap: () {
        setState(() {
          _sortOption = option;
          widget.discoveryService.sortVideos(_sortOption);
        });
        Navigator.of(context).pop();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filteredVideos;

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search videos...',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isSearching = false;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      )
                    : Text(
                        '${videos.length} ${videos.length == 1 ? 'Video' : 'Videos'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ),
              if (!_isSearching) ...[
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'Search',
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort',
                  onPressed: _showSortModal,
                ),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ],
            ],
          ),
        ),

        // Videos Content
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primaryOrange,
            onRefresh: () async => widget.onRefresh(),
            child: videos.isEmpty
                ? const Center(
                    child: Text(
                      'No videos found',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.95,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          return Card(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => PlayerScreen(
                                      initialVideo: video,
                                      playlist: widget.discoveryService.allVideos,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: VideoThumbnailWidget(
                                      video: video,
                                      width: double.infinity,
                                      height: double.infinity,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          video.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${video.folderName} • ${video.formattedSize}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          return VideoListItem(
                            video: videos[index],
                            playlist: widget.discoveryService.allVideos,
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
