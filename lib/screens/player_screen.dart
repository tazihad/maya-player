// -----------------------------------------------------------------------------
// File Name:      lib/screens/player_screen.dart
// Description:    Advanced MPV player with mpvKt and Aniyomi inspired UI and gestures.
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final VideoModel? initialVideo;
  final String? directUrl;
  final List<VideoModel> playlist;

  const PlayerScreen({
    super.key,
    this.initialVideo,
    this.directUrl,
    this.playlist = const [],
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  late int _currentIndex;
  late VideoModel? _currentVideo;

  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;

  // Aspect Ratio & HW/SW
  BoxFit _videoFit = BoxFit.contain;
  int _fitIndex = 0;
  final List<Map<String, dynamic>> _fitOptions = [
    {'label': 'Fit (Original)', 'fit': BoxFit.contain},
    {'label': 'Crop (Zoom)', 'fit': BoxFit.cover},
    {'label': 'Stretch', 'fit': BoxFit.fill},
  ];

  bool _isHardwareDecoded = true;
  double _playbackSpeed = 1.0;
  bool _isFastForwarding2x = false;

  // Orientation
  bool _isLandscapeLocked = true;

  // VLC/mpvKt Gestures HUD
  double _brightnessLevel = 0.5;
  double _volumeLevel = 100.0;
  String? _gestureIndicatorText;
  IconData? _gestureIndicatorIcon;
  double? _gestureProgress;
  Timer? _gestureIndicatorTimer;

  // Double-tap Seek Animation
  String? _doubleTapFeedback;
  bool _doubleTapIsForward = true;
  Timer? _doubleTapTimer;

  // Horizontal Seek Scrubbing
  bool _isScrubbing = false;
  Duration _scrubTargetPosition = Duration.zero;

  StreamSubscription? _completedSubscription;
  StreamSubscription? _posSubscription;

  @override
  void initState() {
    super.initState();
    final storage = StorageService();

    // Lock to landscape or auto according to settings
    if (storage.screenOrientation == 'portrait') {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      _isLandscapeLocked = false;
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _isLandscapeLocked = true;
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _isHardwareDecoded = storage.hardwareDecoding;
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: _isHardwareDecoded,
      ),
    );

    _currentVideo = widget.initialVideo;
    if (_currentVideo != null && widget.playlist.isNotEmpty) {
      _currentIndex = widget.playlist.indexWhere((v) => v.id == _currentVideo!.id);
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      _currentIndex = 0;
    }

    _startPlayback();
    _startHideControlsTimer();

    // Auto advance
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        _playNext();
      }
    });

    // Record position periodically
    _posSubscription = _player.stream.position.listen((pos) {
      if (_currentVideo != null && pos.inSeconds > 0 && pos.inSeconds % 5 == 0) {
        StorageService().recordPlayback(
          path: _currentVideo!.path,
          title: _currentVideo!.title,
          folderName: _currentVideo!.folderName,
          positionMs: pos.inMilliseconds,
          durationMs: _player.state.duration.inMilliseconds,
        );
      }
    });
  }

  void _startPlayback() {
    final storage = StorageService();
    String? mediaPath;
    String videoTitle = 'Maya Player';
    String folderName = '';

    if (_currentVideo != null && _currentVideo!.path.isNotEmpty) {
      mediaPath = _currentVideo!.path;
      videoTitle = _currentVideo!.title;
      folderName = _currentVideo!.folderName;
    } else if (widget.directUrl != null && widget.directUrl!.isNotEmpty) {
      mediaPath = widget.directUrl!;
      videoTitle = widget.directUrl!;
      folderName = 'Stream';
    }

    if (mediaPath != null) {
      _player.open(Media(mediaPath));
      final savedPos = storage.getSavedPosition(mediaPath);
      if (savedPos > 3000) {
        // Resume playback if watched for more than 3s
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _player.seek(Duration(milliseconds: savedPos));
            _showHUD('Resumed at ${_formatDuration(Duration(milliseconds: savedPos))}',
                icon: Icons.history);
          }
        });
      }

      storage.recordPlayback(
        path: mediaPath,
        title: videoTitle,
        folderName: folderName,
        positionMs: savedPos,
        durationMs: 0,
      );
    }
  }

  void _playNext() {
    if (widget.playlist.isNotEmpty && _currentIndex < widget.playlist.length - 1) {
      setState(() {
        _currentIndex++;
        _currentVideo = widget.playlist[_currentIndex];
      });
      _startPlayback();
    }
  }

  void _playPrevious() {
    if (widget.playlist.isNotEmpty && _currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentVideo = widget.playlist[_currentIndex];
      });
      _startPlayback();
    }
  }

  void _startHideControlsTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls && !_isLocked) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _cycleAspectRatio() {
    setState(() {
      _fitIndex = (_fitIndex + 1) % _fitOptions.length;
      _videoFit = _fitOptions[_fitIndex]['fit'] as BoxFit;
    });
    _showHUD('Aspect: ${_fitOptions[_fitIndex]['label']}',
        icon: Icons.aspect_ratio);
  }

  void _toggleOrientation() {
    setState(() {
      _isLandscapeLocked = !_isLandscapeLocked;
    });
    if (_isLandscapeLocked) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _showHUD('Locked Landscape', icon: Icons.screen_lock_landscape);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _showHUD('Auto Rotate', icon: Icons.screen_rotation);
    }
  }

  void _showHUD(String message, {IconData? icon, double? progress}) {
    _gestureIndicatorTimer?.cancel();
    setState(() {
      _gestureIndicatorText = message;
      _gestureIndicatorIcon = icon;
      _gestureProgress = progress;
    });
    _gestureIndicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _gestureIndicatorText = null;
          _gestureIndicatorIcon = null;
          _gestureProgress = null;
        });
      }
    });
  }

  void _handleDoubleTapSeek(bool isForward) {
    if (_isLocked) return;
    final seekSeconds = StorageService().doubleTapSeekSeconds;
    final currentPos = _player.state.position;
    final duration = _player.state.duration;
    final delta = Duration(seconds: isForward ? seekSeconds : -seekSeconds);
    final target = currentPos + delta;
    final boundedTarget = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);

    _player.seek(boundedTarget);

    _doubleTapTimer?.cancel();
    setState(() {
      _doubleTapIsForward = isForward;
      _doubleTapFeedback = isForward ? '+$seekSeconds s' : '-$seekSeconds s';
    });
    _doubleTapTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _doubleTapFeedback = null;
        });
      }
    });
  }

  void _showTrackPicker({required bool isSubtitle}) {
    final tracks = isSubtitle
        ? _player.state.tracks.subtitle
        : _player.state.tracks.audio;
    final currentTrack = isSubtitle
        ? _player.state.track.subtitle
        : _player.state.track.audio;

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      isSubtitle ? Icons.subtitles_outlined : Icons.audiotrack_outlined,
                      color: AppTheme.primaryOrange,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isSubtitle ? 'Select Subtitle Track' : 'Select Audio Track',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.surfaceLightDark),
              if (tracks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No tracks available',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                ...tracks.map((track) {
                  final isSelected = track.id == currentTrack.id;
                  final title = track.title ?? track.language ?? 'Track ${track.id}';
                  return ListTile(
                    title: Text(title,
                        style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryOrange
                                : AppTheme.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: track.language != null ? Text(track.language!) : null,
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppTheme.primaryOrange)
                        : null,
                    onTap: () {
                      if (isSubtitle) {
                        _player.setSubtitleTrack(track);
                      } else {
                        _player.setAudioTrack(track);
                      }
                      Navigator.of(context).pop();
                      _showHUD('Selected: $title',
                          icon: isSubtitle ? Icons.subtitles : Icons.audiotrack);
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedPicker() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 3.0];
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
                child: Row(
                  children: [
                    Icon(Icons.speed, color: AppTheme.primaryOrange),
                    SizedBox(width: 10),
                    Text(
                      'Playback Speed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppTheme.surfaceLightDark),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: speeds.map((speed) {
                  final isSelected = (_playbackSpeed == speed);
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryOrange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _playbackSpeed = speed;
                        });
                        _player.setRate(speed);
                        Navigator.of(context).pop();
                        _showHUD('Speed: ${speed}x', icon: Icons.speed);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _gestureIndicatorTimer?.cancel();
    _doubleTapTimer?.cancel();
    _completedSubscription?.cancel();
    _posSubscription?.cancel();

    // Save final playback progress
    if (_currentVideo != null) {
      StorageService().recordPlayback(
        path: _currentVideo!.path,
        title: _currentVideo!.title,
        folderName: _currentVideo!.folderName,
        positionMs: _player.state.position.inMilliseconds,
        durationMs: _player.state.duration.inMilliseconds,
      );
    }

    _player.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentVideo?.title ?? widget.directUrl ?? 'Maya Player';
    final subtitle = _currentVideo != null
        ? '${_currentVideo!.folderName} • ${_currentVideo!.formattedSize}'
        : 'Network Stream';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MPV Video Display Core
          Center(
            child: Video(
              controller: _controller,
              fit: _videoFit,
              controls: NoVideoControls,
            ),
          ),

          // Aniyomi/mpvKt Touch Gestures Area
          Positioned.fill(
            child: Row(
              children: [
                // Left half: Double tap seek backwards, Vertical drag brightness
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () => _handleDoubleTapSeek(false),
                    onLongPressStart: (_) {
                      if (_isLocked) return;
                      _player.setRate(2.0);
                      setState(() => _isFastForwarding2x = true);
                    },
                    onLongPressEnd: (_) {
                      if (_isLocked) return;
                      _player.setRate(_playbackSpeed);
                      setState(() => _isFastForwarding2x = false);
                    },
                    onVerticalDragUpdate: (details) {
                      if (_isLocked || !StorageService().gestureControlsEnabled) return;
                      _brightnessLevel = (_brightnessLevel - (details.primaryDelta ?? 0) / 250)
                          .clamp(0.0, 1.0);
                      _showHUD(
                        '${(_brightnessLevel * 100).toInt()}%',
                        icon: Icons.brightness_6,
                        progress: _brightnessLevel,
                      );
                    },
                    onHorizontalDragStart: (details) {
                      if (_isLocked || !StorageService().gestureControlsEnabled) return;
                      _isScrubbing = true;
                      _scrubTargetPosition = _player.state.position;
                    },
                    onHorizontalDragUpdate: (details) {
                      if (!_isScrubbing || _isLocked) return;
                      final duration = _player.state.duration;
                      final deltaSeconds = (details.primaryDelta ?? 0) * 0.5;
                      final targetMs = _scrubTargetPosition.inMilliseconds +
                          (deltaSeconds * 1000).toInt();
                      _scrubTargetPosition = Duration(
                        milliseconds: targetMs.clamp(0, duration.inMilliseconds),
                      );
                      _showHUD(
                        '${_formatDuration(_scrubTargetPosition)} / ${_formatDuration(duration)}',
                        icon: Icons.fast_forward,
                      );
                    },
                    onHorizontalDragEnd: (details) {
                      if (_isScrubbing) {
                        _isScrubbing = false;
                        _player.seek(_scrubTargetPosition);
                      }
                    },
                  ),
                ),

                // Right half: Double tap seek forward, Vertical drag volume
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () => _handleDoubleTapSeek(true),
                    onLongPressStart: (_) {
                      if (_isLocked) return;
                      _player.setRate(2.0);
                      setState(() => _isFastForwarding2x = true);
                    },
                    onLongPressEnd: (_) {
                      if (_isLocked) return;
                      _player.setRate(_playbackSpeed);
                      setState(() => _isFastForwarding2x = false);
                    },
                    onVerticalDragUpdate: (details) {
                      if (_isLocked || !StorageService().gestureControlsEnabled) return;
                      final maxVolume = StorageService().audioBoost ? 150.0 : 100.0;
                      _volumeLevel = (_volumeLevel - (details.primaryDelta ?? 0) / 2.5)
                          .clamp(0.0, maxVolume);
                      _player.setVolume(_volumeLevel);
                      _showHUD(
                        '${_volumeLevel.toInt()}%',
                        icon: _volumeLevel > 100 ? Icons.volume_up : Icons.volume_down,
                        progress: _volumeLevel / maxVolume,
                      );
                    },
                    onHorizontalDragStart: (details) {
                      if (_isLocked || !StorageService().gestureControlsEnabled) return;
                      _isScrubbing = true;
                      _scrubTargetPosition = _player.state.position;
                    },
                    onHorizontalDragUpdate: (details) {
                      if (!_isScrubbing || _isLocked) return;
                      final duration = _player.state.duration;
                      final deltaSeconds = (details.primaryDelta ?? 0) * 0.5;
                      final targetMs = _scrubTargetPosition.inMilliseconds +
                          (deltaSeconds * 1000).toInt();
                      _scrubTargetPosition = Duration(
                        milliseconds: targetMs.clamp(0, duration.inMilliseconds),
                      );
                      _showHUD(
                        '${_formatDuration(_scrubTargetPosition)} / ${_formatDuration(duration)}',
                        icon: Icons.fast_forward,
                      );
                    },
                    onHorizontalDragEnd: (details) {
                      if (_isScrubbing) {
                        _isScrubbing = false;
                        _player.seek(_scrubTargetPosition);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Double Tap Ripple Indicator (mpvKt style)
          if (_doubleTapFeedback != null)
            Align(
              alignment: _doubleTapIsForward ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 130,
                height: 130,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _doubleTapIsForward ? Icons.fast_forward : Icons.fast_rewind,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _doubleTapFeedback!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2X Speed Press HUD Badge (Aniyomi style)
          if (_isFastForwarding2x)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryOrange, width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fast_forward, color: AppTheme.primaryOrange, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '2X SPEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Center Vertical / Pill HUD Gesture Overlay
          if (_gestureIndicatorText != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_gestureIndicatorIcon != null)
                      Icon(_gestureIndicatorIcon, color: AppTheme.primaryOrange, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      _gestureIndicatorText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_gestureProgress != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: _gestureProgress,
                          color: AppTheme.primaryOrange,
                          backgroundColor: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Floating Unlock Screen Button
          if (_isLocked)
            Positioned(
              left: 24,
              top: 24,
              child: SafeArea(
                child: FloatingActionButton(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _isLocked = false;
                      _showControls = true;
                    });
                    _startHideControlsTimer();
                    _showHUD('Controls Unlocked', icon: Icons.lock_open);
                  },
                  child: const Icon(Icons.lock),
                ),
              ),
            ),

          // mpvKt / Aniyomi Modern Player Overlay Controls
          if (_showControls && !_isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.88),
                    ],
                    stops: const [0.0, 0.25, 0.70, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar (Aniyomi / mpvKt header)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Decoder indicator chip (HW / SW)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isHardwareDecoded
                                    ? AppTheme.primaryOrange.withOpacity(0.3)
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _isHardwareDecoded
                                      ? AppTheme.primaryOrange
                                      : Colors.white24,
                                ),
                              ),
                              child: Text(
                                _isHardwareDecoded ? 'HW' : 'SW',
                                style: TextStyle(
                                  color: _isHardwareDecoded
                                      ? AppTheme.primaryOrange
                                      : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Aspect Ratio
                            IconButton(
                              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                              tooltip: 'Aspect Ratio',
                              onPressed: _cycleAspectRatio,
                            ),

                            // Subtitle selector
                            IconButton(
                              icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                              tooltip: 'Subtitles',
                              onPressed: () => _showTrackPicker(isSubtitle: true),
                            ),

                            // Audio selector
                            IconButton(
                              icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
                              tooltip: 'Audio Tracks',
                              onPressed: () => _showTrackPicker(isSubtitle: false),
                            ),

                            // Speed button
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                              ),
                              onPressed: _showSpeedPicker,
                              child: Text(
                                '${_playbackSpeed}x',
                                style: const TextStyle(
                                  color: AppTheme.primaryOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Middle Controls (Rewind 10, Play/Pause, Forward 10, Next/Prev)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous video
                        if (widget.playlist.isNotEmpty)
                          IconButton(
                            iconSize: 38,
                            color: _currentIndex > 0 ? Colors.white : Colors.white24,
                            icon: const Icon(Icons.skip_previous),
                            onPressed: _currentIndex > 0 ? _playPrevious : null,
                          ),
                        const SizedBox(width: 14),

                        // Rewind 10s
                        IconButton(
                          iconSize: 46,
                          color: Colors.white,
                          icon: const Icon(Icons.replay_10),
                          onPressed: () => _handleDoubleTapSeek(false),
                        ),
                        const SizedBox(width: 24),

                        // Main Play / Pause Button
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? true;
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryOrange.withOpacity(0.95),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                iconSize: 52,
                                color: Colors.white,
                                icon: Icon(isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                                onPressed: () {
                                  _player.playOrPause();
                                  _startHideControlsTimer();
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 24),

                        // Forward 10s
                        IconButton(
                          iconSize: 46,
                          color: Colors.white,
                          icon: const Icon(Icons.forward_10),
                          onPressed: () => _handleDoubleTapSeek(true),
                        ),
                        const SizedBox(width: 14),

                        // Next video
                        if (widget.playlist.isNotEmpty)
                          IconButton(
                            iconSize: 38,
                            color: _currentIndex < widget.playlist.length - 1
                                ? Colors.white
                                : Colors.white24,
                            icon: const Icon(Icons.skip_next),
                            onPressed: _currentIndex < widget.playlist.length - 1
                                ? _playNext
                                : null,
                          ),
                      ],
                    ),

                    // Bottom Bar (Material 3 Scrubber, Timestamp, Lock, Orientation)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: StreamBuilder<Duration>(
                          stream: _player.stream.position,
                          builder: (context, posSnapshot) {
                            final position = posSnapshot.data ?? Duration.zero;
                            final duration = _player.state.duration;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Scrubber Slider
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppTheme.primaryOrange,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: AppTheme.primaryOrange,
                                    overlayColor: AppTheme.primaryOrange.withOpacity(0.2),
                                    trackHeight: 3.5,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7,
                                    ),
                                  ),
                                  child: Slider(
                                    min: 0.0,
                                    max: duration.inMilliseconds > 0
                                        ? duration.inMilliseconds.toDouble()
                                        : 1.0,
                                    value: position.inMilliseconds
                                        .toDouble()
                                        .clamp(0.0, duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0),
                                    onChanged: (val) {
                                      _startHideControlsTimer();
                                      _player.seek(Duration(milliseconds: val.toInt()));
                                    },
                                  ),
                                ),

                                // Bottom row: Timestamps, Lock, Fullscreen/Rotate
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
                                          tooltip: 'Lock Screen',
                                          onPressed: () {
                                            setState(() {
                                              _isLocked = true;
                                              _showControls = false;
                                            });
                                            _showHUD('Controls Locked', icon: Icons.lock);
                                          },
                                        ),
                                        Text(
                                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            _isLandscapeLocked
                                                ? Icons.screen_lock_landscape
                                                : Icons.screen_rotation,
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                          tooltip: 'Orientation',
                                          onPressed: _toggleOrientation,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
