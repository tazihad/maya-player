// -----------------------------------------------------------------------------
// File Name:      lib/screens/more/history_screen.dart
// Description:    Playback history list with watch progress and resume options.
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
import '../../theme/app_theme.dart';
import '../player_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surfaceDark,
                  title: const Text('Clear History?'),
                  content: const Text('Are you sure you want to clear your playback history?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        storage.clearHistory();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: storage,
        builder: (context, _) {
          final history = storage.history;

          if (history.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text('No playback history', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              final isFile = File(item.path).existsSync();

              return ListTile(
                leading: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLightDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_circle_outline, color: AppTheme.primaryOrange),
                    ),
                  ],
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${item.folderName.isNotEmpty ? "${item.folderName} • " : ""}${item.lastPlayed.toLocal().toString().split('.').first}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 3,
                        color: AppTheme.primaryOrange,
                        backgroundColor: AppTheme.surfaceLightDark,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                  onPressed: () => storage.removeHistoryItem(item.path),
                ),
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
              );
            },
          );
        },
      ),
    );
  }
}
