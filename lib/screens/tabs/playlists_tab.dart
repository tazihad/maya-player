// -----------------------------------------------------------------------------
// File Name:      lib/screens/tabs/playlists_tab.dart
// Description:    VLC-style playlists tab for Favorites, Watch Later and custom lists.
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
import '../../services/storage_service.dart';
import '../../services/video_discovery_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video_list_item.dart';
import '../player_screen.dart';

class PlaylistsTab extends StatefulWidget {
  final VideoDiscoveryService discoveryService;

  const PlaylistsTab({
    super.key,
    required this.discoveryService,
  });

  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  final StorageService _storage = StorageService();

  void _showCreatePlaylistDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create New Playlist'),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist Name',
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
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                _storage.createPlaylist(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openPlaylist(String name, List<String> paths) {
    final videos = widget.discoveryService.allVideos
        .where((v) => paths.contains(v.path))
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (name != 'Favorites' && name != 'Watch Later')
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete Playlist',
                  onPressed: () {
                    _storage.deletePlaylist(name);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              if (videos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppTheme.surfaceDark,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryOrange,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play All'),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PlayerScreen(
                                  initialVideo: videos.first,
                                  playlist: videos,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.shuffle, color: AppTheme.accentOrange),
                          label: const Text('Shuffle'),
                          onPressed: () {
                            final shuffled = List<VideoModel>.from(videos)..shuffle();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PlayerScreen(
                                  initialVideo: shuffled.first,
                                  playlist: shuffled,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: videos.isEmpty
                    ? const Center(
                        child: Text(
                          'No videos in this playlist yet',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          return VideoListItem(
                            video: videos[index],
                            playlist: videos,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _storage,
        builder: (context, _) {
          final playlists = _storage.playlists;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${playlists.length} Playlists',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceDark,
                        foregroundColor: AppTheme.primaryOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Playlist'),
                      onPressed: _showCreatePlaylistDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              ...playlists.entries.map((entry) {
                final name = entry.key;
                final paths = entry.value;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLightDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        name == 'Favorites'
                            ? Icons.favorite
                            : name == 'Watch Later'
                                ? Icons.watch_later
                                : Icons.playlist_play,
                        color: AppTheme.primaryOrange,
                        size: 26,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      '${paths.length} ${paths.length == 1 ? "video" : "videos"}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    onTap: () => _openPlaylist(name, paths),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
