// -----------------------------------------------------------------------------
// File Name:      lib/screens/tabs/home_tab.dart
// Description:    Home dashboard with Continue Watching, Quick Actions and stats.
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

import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/video_model.dart';
import '../../services/storage_service.dart';
import '../../services/video_discovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video_list_item.dart';
import '../player_screen.dart';

class HomeTab extends StatelessWidget {
  final VideoDiscoveryService discoveryService;
  final VoidCallback onRefresh;
  final Function(int) onNavigateToTab;

  const HomeTab({
    super.key,
    required this.discoveryService,
    required this.onRefresh,
    required this.onNavigateToTab,
  });

  void _openStreamDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.primaryOrange),
            SizedBox(width: 8),
            Text('Open Network Stream'),
          ],
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter URL (http://, rtsp://, etc.)',
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
                StorageService().saveStream(url);
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PlayerScreen(directUrl: url),
                  ),
                );
              }
            },
            child: const Text('Play'),
          ),
        ],
      ),
    );
  }

  void _playRandomVideo(BuildContext context) {
    if (discoveryService.allVideos.isEmpty) return;
    final list = List<VideoModel>.from(discoveryService.allVideos)..shuffle();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          initialVideo: list.first,
          playlist: list,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return RefreshIndicator(
      color: AppTheme.primaryOrange,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Quick Stats Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryOrange.withOpacity(0.2),
                    AppTheme.surfaceLightDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Maya Player',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${discoveryService.allVideos.length} videos discovered in ${discoveryService.folders.length} folders',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Quick Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.link,
                    label: 'Stream URL',
                    onTap: () => _openStreamDialog(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.shuffle,
                    label: 'Shuffle Play',
                    onTap: () => _playRandomVideo(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.folder_open,
                    label: 'Browser',
                    onTap: () => onNavigateToTab(2), // Navigate to Browser tab
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Continue Watching Section
          ListenableBuilder(
            listenable: storage,
            builder: (context, _) {
              final history = storage.history;
              if (history.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Continue Watching',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => onNavigateToTab(4), // Navigate to More -> History
                          child: const Text('View All', style: TextStyle(color: AppTheme.primaryOrange)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: history.length > 8 ? 8 : history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final isFile = File(item.path).existsSync();

                        return Container(
                          width: 180,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              final video = VideoModel(
                                id: item.path,
                                title: item.title,
                                path: item.path,
                                duration: Duration(milliseconds: item.durationMs),
                                size: 0,
                                dateModified: item.lastPlayed,
                                folderName: item.folderName,
                                folderPath: '',
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PlayerScreen(
                                    initialVideo: isFile ? video : null,
                                    directUrl: isFile ? null : item.path,
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: AppTheme.surfaceLightDark,
                                      child: const Center(
                                        child: Icon(Icons.play_circle_fill,
                                            size: 38, color: AppTheme.primaryOrange),
                                      ),
                                    ),
                                  ),
                                  LinearProgressIndicator(
                                    value: item.progress,
                                    minHeight: 3,
                                    color: AppTheme.primaryOrange,
                                    backgroundColor: Colors.white12,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // Recently Discovered Videos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Videos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(1), // Navigate to Videos tab
                  child: const Text('See All', style: TextStyle(color: AppTheme.primaryOrange)),
                ),
              ],
            ),
          ),
          ...discoveryService.allVideos.take(6).map((video) {
            return VideoListItem(
              video: video,
              playlist: discoveryService.allVideos,
            );
          }),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLightDark),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryOrange, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
