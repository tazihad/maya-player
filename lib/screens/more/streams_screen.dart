// -----------------------------------------------------------------------------
// File Name:      lib/screens/more/streams_screen.dart
// Description:    Network stream manager, stream URL player and saved streams.
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
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../player_screen.dart';

class StreamsScreen extends StatefulWidget {
  const StreamsScreen({super.key});

  @override
  State<StreamsScreen> createState() => _StreamsScreenState();
}

class _StreamsScreenState extends State<StreamsScreen> {
  final StorageService _storage = StorageService();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  void _showAddStreamDialog() {
    _urlController.clear();
    _titleController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.primaryOrange),
            SizedBox(width: 10),
            Text('Open Network Stream'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Stream URL',
                hintText: 'http://, rtsp://, https://...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                hintText: 'e.g. Live Stream',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
              final url = _urlController.text.trim();
              if (url.isNotEmpty) {
                final title = _titleController.text.trim();
                _storage.saveStream(url, title: title.isNotEmpty ? title : null);
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

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Stream URL',
            onPressed: _showAddStreamDialog,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _storage,
        builder: (context, _) {
          final streams = _storage.streams;

          if (streams.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_outlined, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No network streams yet',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_link),
                    label: const Text('Open Stream URL'),
                    onPressed: _showAddStreamDialog,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: streams.length,
            itemBuilder: (context, index) {
              final stream = streams[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.surfaceLightDark,
                  child: Icon(Icons.play_arrow, color: AppTheme.primaryOrange),
                ),
                title: Text(
                  stream.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  stream.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                  onPressed: () => _storage.deleteStream(stream.url),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PlayerScreen(directUrl: stream.url),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
        onPressed: _showAddStreamDialog,
        child: const Icon(Icons.add_link),
      ),
    );
  }
}
