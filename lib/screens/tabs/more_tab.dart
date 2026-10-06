// -----------------------------------------------------------------------------
// File Name:      lib/screens/tabs/more_tab.dart
// Description:    VLC-style More menu leading to Streams, History, Settings and About.
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
import '../more/about_screen.dart';
import '../more/history_screen.dart';
import '../more/settings_screen.dart';
import '../more/streams_screen.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // STREAMS
            _moreCard(
              context,
              icon: Icons.link_rounded,
              title: 'Streams',
              subtitle: '${storage.streams.length} saved streams • Open network stream',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const StreamsScreen()),
                );
              },
            ),

            // HISTORY
            _moreCard(
              context,
              icon: Icons.history_rounded,
              title: 'History',
              subtitle: '${storage.history.length} watched videos • Resume playback',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
            ),

            // SETTINGS
            _moreCard(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Video decoding, screen orientation, audio boost & gestures',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),

            // ABOUT
            _moreCard(
              context,
              icon: Icons.info_outline_rounded,
              title: 'About Maya Player',
              subtitle: 'Version 0.0.1-alpha.2 • mpv engine • MIT License',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AboutScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _moreCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryOrange, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
