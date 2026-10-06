// -----------------------------------------------------------------------------
// File Name:      lib/services/storage_service.dart
// Description:    Local persistence service for history, playlists, streams and settings.
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

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class HistoryItem {
  final String path;
  final String title;
  final String folderName;
  final int positionMs;
  final int durationMs;
  final DateTime lastPlayed;

  HistoryItem({
    required this.path,
    required this.title,
    required this.folderName,
    required this.positionMs,
    required this.durationMs,
    required this.lastPlayed,
  });

  double get progress =>
      durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'folderName': folderName,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'lastPlayed': lastPlayed.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        path: json['path'] as String? ?? '',
        title: json['title'] as String? ?? '',
        folderName: json['folderName'] as String? ?? '',
        positionMs: json['positionMs'] as int? ?? 0,
        durationMs: json['durationMs'] as int? ?? 0,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.tryParse(json['lastPlayed'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class SavedStream {
  final String url;
  final String title;
  final DateTime addedAt;

  SavedStream({
    required this.url,
    required this.title,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SavedStream.fromJson(Map<String, dynamic> json) => SavedStream(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  bool _initialized = false;
  File? _storageFile;

  List<HistoryItem> _history = [];
  Map<String, List<String>> _playlists = {
    'Favorites': [],
    'Watch Later': [],
  };
  List<SavedStream> _streams = [];

  // Settings
  bool hardwareDecoding = true;
  String screenOrientation = 'auto'; // 'auto', 'sensor_landscape', 'portrait'
  String defaultAspectRatio = 'contain'; // 'contain', 'cover', 'fill'
  int doubleTapSeekSeconds = 10; // 5, 10, 15, 30
  bool audioBoost = false;
  bool gestureControlsEnabled = true;
  String themeMode = 'dark'; // 'dark', 'light', 'system'
  bool backgroundPlayback = false;

  List<HistoryItem> get history => List.unmodifiable(_history);
  Map<String, List<String>> get playlists => Map.unmodifiable(_playlists);
  List<SavedStream> get streams => List.unmodifiable(_streams);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _storageFile = File('${dir.path}/maya_player_storage.json');
      if (await _storageFile!.exists()) {
        final content = await _storageFile!.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        if (json['history'] is List) {
          _history = (json['history'] as List)
              .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        if (json['playlists'] is Map) {
          final loadedPlaylists = <String, List<String>>{};
          (json['playlists'] as Map<String, dynamic>).forEach((k, v) {
            if (v is List) {
              loadedPlaylists[k] = v.cast<String>();
            }
          });
          _playlists = loadedPlaylists;
          _playlists.putIfAbsent('Favorites', () => []);
          _playlists.putIfAbsent('Watch Later', () => []);
        }

        if (json['streams'] is List) {
          _streams = (json['streams'] as List)
              .map((e) => SavedStream.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        if (json['settings'] is Map) {
          final s = json['settings'] as Map<String, dynamic>;
          hardwareDecoding = s['hardwareDecoding'] as bool? ?? true;
          screenOrientation = s['screenOrientation'] as String? ?? 'auto';
          defaultAspectRatio = s['defaultAspectRatio'] as String? ?? 'contain';
          doubleTapSeekSeconds = s['doubleTapSeekSeconds'] as int? ?? 10;
          audioBoost = s['audioBoost'] as bool? ?? false;
          gestureControlsEnabled =
              s['gestureControlsEnabled'] as bool? ?? true;
          themeMode = s['themeMode'] as String? ?? 'dark';
          backgroundPlayback = s['backgroundPlayback'] as bool? ?? false;
        }
      }
    } catch (e) {
      debugPrint('Error loading storage: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    if (_storageFile == null) return;
    try {
      final data = {
        'history': _history.map((e) => e.toJson()).toList(),
        'playlists': _playlists,
        'streams': _streams.map((e) => e.toJson()).toList(),
        'settings': {
          'hardwareDecoding': hardwareDecoding,
          'screenOrientation': screenOrientation,
          'defaultAspectRatio': defaultAspectRatio,
          'doubleTapSeekSeconds': doubleTapSeekSeconds,
          'audioBoost': audioBoost,
          'gestureControlsEnabled': gestureControlsEnabled,
          'themeMode': themeMode,
          'backgroundPlayback': backgroundPlayback,
        },
      };
      await _storageFile!.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving storage: $e');
    }
  }

  // History operations
  Future<void> recordPlayback({
    required String path,
    required String title,
    required String folderName,
    required int positionMs,
    required int durationMs,
  }) async {
    _history.removeWhere((item) => item.path == path);
    _history.insert(
      0,
      HistoryItem(
        path: path,
        title: title,
        folderName: folderName,
        positionMs: positionMs,
        durationMs: durationMs,
        lastPlayed: DateTime.now(),
      ),
    );
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    notifyListeners();
    await _save();
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _save();
  }

  Future<void> removeHistoryItem(String path) async {
    _history.removeWhere((item) => item.path == path);
    notifyListeners();
    await _save();
  }

  int getSavedPosition(String path) {
    final item = _history.where((i) => i.path == path).firstOrNull;
    return item?.positionMs ?? 0;
  }

  // Playlists operations
  Future<void> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _playlists.containsKey(trimmed)) return;
    _playlists[trimmed] = [];
    notifyListeners();
    await _save();
  }

  Future<void> deletePlaylist(String name) async {
    if (name == 'Favorites' || name == 'Watch Later') return;
    _playlists.remove(name);
    notifyListeners();
    await _save();
  }

  Future<void> addToPlaylist(String playlistName, String videoPath) async {
    if (!_playlists.containsKey(playlistName)) {
      _playlists[playlistName] = [];
    }
    if (!_playlists[playlistName]!.contains(videoPath)) {
      _playlists[playlistName]!.add(videoPath);
      notifyListeners();
      await _save();
    }
  }

  Future<void> removeFromPlaylist(String playlistName, String videoPath) async {
    if (_playlists.containsKey(playlistName)) {
      _playlists[playlistName]!.remove(videoPath);
      notifyListeners();
      await _save();
    }
  }

  bool isFavorite(String videoPath) {
    return _playlists['Favorites']?.contains(videoPath) ?? false;
  }

  Future<void> toggleFavorite(String videoPath) async {
    if (isFavorite(videoPath)) {
      await removeFromPlaylist('Favorites', videoPath);
    } else {
      await addToPlaylist('Favorites', videoPath);
    }
  }

  // Streams operations
  Future<void> saveStream(String url, {String? title}) async {
    _streams.removeWhere((s) => s.url == url);
    _streams.insert(
      0,
      SavedStream(
        url: url,
        title: title ?? url,
        addedAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> deleteStream(String url) async {
    _streams.removeWhere((s) => s.url == url);
    notifyListeners();
    await _save();
  }

  // Settings updates
  Future<void> updateSettings({
    bool? hardwareDecoding,
    String? screenOrientation,
    String? defaultAspectRatio,
    int? doubleTapSeekSeconds,
    bool? audioBoost,
    bool? gestureControlsEnabled,
    String? themeMode,
    bool? backgroundPlayback,
  }) async {
    if (hardwareDecoding != null) this.hardwareDecoding = hardwareDecoding;
    if (screenOrientation != null) this.screenOrientation = screenOrientation;
    if (defaultAspectRatio != null) this.defaultAspectRatio = defaultAspectRatio;
    if (doubleTapSeekSeconds != null) this.doubleTapSeekSeconds = doubleTapSeekSeconds;
    if (audioBoost != null) this.audioBoost = audioBoost;
    if (gestureControlsEnabled != null) this.gestureControlsEnabled = gestureControlsEnabled;
    if (themeMode != null) this.themeMode = themeMode;
    if (backgroundPlayback != null) this.backgroundPlayback = backgroundPlayback;
    notifyListeners();
    await _save();
  }
}
