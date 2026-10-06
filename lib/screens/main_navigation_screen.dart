// -----------------------------------------------------------------------------
// File Name:      lib/screens/main_navigation_screen.dart
// Description:    Main navigation shell with VLC-style bottom navigation bar.
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
import '../services/storage_service.dart';
import '../services/video_discovery_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';
import 'tabs/browser_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/more_tab.dart';
import 'tabs/playlists_tab.dart';
import 'tabs/videos_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final VideoDiscoveryService _discoveryService = VideoDiscoveryService();

  bool _isLoading = true;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    StorageService().init();
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

  void _openStreamDialog() {
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
            Text('Open Stream URL'),
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

  String get _appBarTitle {
    switch (_currentIndex) {
      case 1:
        return 'Videos';
      case 2:
        return 'Browser';
      case 3:
        return 'Playlists';
      case 4:
        return 'More';
      default:
        return 'Maya Player';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maya Player')),
        body: _buildPermissionDeniedView(),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maya Player')),
        body: const Center(
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_currentIndex == 0) ...[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: AppTheme.primaryOrange, size: 20),
              ),
              const SizedBox(width: 8),
            ],
            Text(_appBarTitle),
            if (_currentIndex == 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLightDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'mpv',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentOrange),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Open Stream URL',
            onPressed: _openStreamDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan Videos',
            onPressed: _loadVideos,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0: HOME
          HomeTab(
            discoveryService: _discoveryService,
            onRefresh: _loadVideos,
            onNavigateToTab: (index) {
              setState(() => _currentIndex = index);
            },
          ),
          // 1: VIDEOS
          VideosTab(
            discoveryService: _discoveryService,
            onRefresh: _loadVideos,
          ),
          // 2: BROWSER (Folder browse)
          BrowserTab(
            discoveryService: _discoveryService,
            onRefresh: _loadVideos,
          ),
          // 3: PLAYLISTS
          PlaylistsTab(
            discoveryService: _discoveryService,
          ),
          // 4: MORE
          const MoreTab(),
        ],
      ),
      // VLC-Style Material 3 Bottom Navigation Bar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_outlined),
            selectedIcon: Icon(Icons.movie),
            label: 'Videos',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Browser',
          ),
          NavigationDestination(
            icon: Icon(Icons.playlist_play_outlined),
            selectedIcon: Icon(Icons.playlist_play),
            label: 'Playlists',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
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
