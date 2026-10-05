import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/video_model.dart';
import '../theme/app_theme.dart';
import '../widgets/video_list_item.dart';
import 'player_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderDetailScreen({
    super.key,
    required this.folder,
  });

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  List<VideoModel> get _filteredVideos {
    if (_searchQuery.trim().isEmpty) {
      return widget.folder.videos;
    }
    return widget.folder.videos
        .where((v) =>
            v.title.toLowerCase().contains(_searchQuery.trim().toLowerCase()))
        .toList();
  }

  void _playAll({bool shuffle = false}) {
    if (widget.folder.videos.isEmpty) return;
    List<VideoModel> list = List.from(widget.folder.videos);
    if (shuffle) {
      list.shuffle();
    }
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filteredVideos;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search videos...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.folder.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${widget.folder.videoCount} videos • ${widget.folder.totalSizeFormatted}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
        ],
      ),
      body: Column(
        children: [
          // Play All & Shuffle Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.surfaceLightColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text(
                      'Play All',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _playAll(shuffle: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.surfaceLightColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.shuffle, size: 20, color: AppTheme.accentOrange),
                    label: const Text('Shuffle'),
                    onPressed: () => _playAll(shuffle: true),
                  ),
                ),
              ],
            ),
          ),

          // Video List
          Expanded(
            child: videos.isEmpty
                ? const Center(
                    child: Text(
                      'No videos found',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];
                      return VideoListItem(
                        video: video,
                        playlist: widget.folder.videos,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
