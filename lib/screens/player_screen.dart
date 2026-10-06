// -----------------------------------------------------------------------------
// File Name:      lib/screens/player_screen.dart
// Description:    Advanced Video Player with Master Android Compose-styled UI,
//                 Material 3 design, gestures, and MPV playback engine.
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
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import '../models/video_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

enum AspectMode {
  bestFit('Best Fit'),
  fill('Fill / Crop'),
  ratio16_9('16:9'),
  ratio4_3('4:3'),
  original('Original 100%');

  final String label;
  const AspectMode(this.label);
}

enum ScreenOrientation {
  sensor('Auto Rotate'),
  landscape('Landscape Locked'),
  portrait('Portrait Locked');

  final String label;
  const ScreenOrientation(this.label);
}

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

  // Playback state
  bool _isPlaying = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _showControls = true;
  bool _isLocked = false;
  Timer? _hideTimer;

  // Media Options
  double _playbackSpeed = 1.0;
  AspectMode _currentAspect = AspectMode.bestFit;
  ScreenOrientation _currentOrientation = ScreenOrientation.sensor;
  bool _extendOverNotch = false;
  bool _isHardwareDecoded = true;
  bool _isFastForwarding2x = false;

  // Swipe HUD state (Volume & Brightness)
  double _volumeLevel = 1.0; // 0.0 to 1.0 (or boost up to 1.5)
  double _brightnessLevel = 0.6; // 0.02 to 1.0
  String? _activeGestureHud; // "volume" | "brightness"
  Timer? _gestureHudTimer;

  // Double-tap Seek Animation
  String? _doubleTapFeedback;
  bool _doubleTapIsForward = true;
  Timer? _doubleTapTimer;

  // Horizontal Seek Scrubbing
  bool _isScrubbing = false;
  Duration _scrubTargetPosition = Duration.zero;

  // Toast Banner Message
  String? _activeToastMessage;
  Timer? _toastTimer;

  StreamSubscription? _completedSubscription;
  StreamSubscription? _posSubscription;
  StreamSubscription? _durSubscription;
  StreamSubscription? _playingSubscription;

  @override
  void initState() {
    super.initState();
    final storage = StorageService();

    // Orientation setup
    if (storage.screenOrientation == 'portrait') {
      _currentOrientation = ScreenOrientation.portrait;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else if (storage.screenOrientation == 'landscape') {
      _currentOrientation = ScreenOrientation.landscape;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _currentOrientation = ScreenOrientation.sensor;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
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

    // Initialize current brightness if available
    _initBrightness();

    _startPlayback();
    _startHideControlsTimer();

    // Stream subscriptions
    _playingSubscription = _player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _isPlaying = playing);
      }
    });

    _posSubscription = _player.stream.position.listen((pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
      }
      if (_currentVideo != null && pos.inSeconds > 0 && pos.inSeconds % 5 == 0) {
        StorageService().recordPlayback(
          path: _currentVideo!.path,
          title: _currentVideo!.title,
          folderName: _currentVideo!.folderName,
          positionMs: pos.inMilliseconds,
          durationMs: _totalDuration.inMilliseconds,
        );
      }
    });

    _durSubscription = _player.stream.duration.listen((dur) {
      if (mounted) {
        setState(() => _totalDuration = dur);
      }
    });

    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        _playNext();
      }
    });
  }

  Future<void> _initBrightness() async {
    try {
      final current = await ScreenBrightnessPlatform.instance.application;
      if (current > 0 && mounted) {
        setState(() {
          _brightnessLevel = current.clamp(0.02, 1.0);
        });
      }
    } catch (_) {}
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
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _player.seek(Duration(milliseconds: savedPos));
            _showToast('Resumed at ${_formatDuration(Duration(milliseconds: savedPos))}');
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
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showControls && _isPlaying && !_isLocked) {
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
    if (_showControls && !_isLocked) {
      _startHideControlsTimer();
    }
  }

  void _cycleOrientation() {
    HapticFeedback.heavyImpact();
    setState(() {
      switch (_currentOrientation) {
        case ScreenOrientation.sensor:
          _currentOrientation = ScreenOrientation.landscape;
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          break;
        case ScreenOrientation.landscape:
          _currentOrientation = ScreenOrientation.portrait;
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
          ]);
          break;
        case ScreenOrientation.portrait:
          _currentOrientation = ScreenOrientation.sensor;
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          break;
      }
    });
    _showToast(_currentOrientation.label);
  }

  IconData get _orientationIcon {
    switch (_currentOrientation) {
      case ScreenOrientation.sensor:
        return Icons.screen_rotation_outlined;
      case ScreenOrientation.landscape:
        return Icons.screen_lock_landscape_outlined;
      case ScreenOrientation.portrait:
        return Icons.screen_lock_portrait_outlined;
    }
  }

  void _cycleAspectRatio() {
    const modes = AspectMode.values;
    final nextIndex = (modes.indexOf(_currentAspect) + 1) % modes.length;
    setState(() {
      _currentAspect = modes[nextIndex];
    });
    _showToast('Aspect: ${_currentAspect.label}');
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _activeToastMessage = message;
    });
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _activeToastMessage = null;
        });
      }
    });
  }

  void _triggerGestureHud(String type) {
    _gestureHudTimer?.cancel();
    setState(() {
      _activeGestureHud = type;
    });
    _gestureHudTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _activeGestureHud = null;
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

  void _showAspectSheet() {
    _startHideControlsTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF22232B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHeader('Aspect Ratio & Screen Cutout'),
                SwitchListTile(
                  secondary: const Icon(Icons.fit_screen_outlined, color: AppTheme.primaryOrange),
                  title: const Text('Extend over cutout / Hide notch',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    _extendOverNotch
                        ? 'Render edge-to-edge behind camera cutout'
                        : 'Safe bounds padding',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  value: _extendOverNotch,
                  activeThumbColor: AppTheme.primaryOrange,
                  onChanged: (val) {
                    setState(() {
                      _extendOverNotch = val;
                    });
                    setSheetState(() {});
                  },
                ),
                const Divider(color: Colors.white12),
                ...AspectMode.values.map((mode) {
                  final isSelected = _currentAspect == mode;
                  return RadioListTile<AspectMode>(
                    value: mode,
                    groupValue: _currentAspect,
                    activeColor: AppTheme.primaryOrange,
                    title: Text(
                      mode.label,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryOrange : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _currentAspect = val;
                        });
                        Navigator.of(sheetContext).pop();
                        _showToast('Aspect: ${val.label}');
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedSheet() {
    _startHideControlsTimer();
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF22232B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader('Playback Speed'),
              ...speeds.map((speed) {
                final isSelected = (_playbackSpeed == speed);
                return RadioListTile<double>(
                  value: speed,
                  groupValue: _playbackSpeed,
                  activeColor: AppTheme.primaryOrange,
                  title: Text(
                    '${speed}x ${speed == 1.0 ? "(Normal)" : ""}',
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryOrange : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _playbackSpeed = val;
                      });
                      _player.setRate(val);
                      Navigator.of(sheetContext).pop();
                      _showToast('Speed: ${val}x');
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackPicker({required bool isSubtitle}) {
    _startHideControlsTimer();
    final tracks = isSubtitle
        ? _player.state.tracks.subtitle
        : _player.state.tracks.audio;
    final currentTrack = isSubtitle
        ? _player.state.track.subtitle
        : _player.state.track.audio;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF22232B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(isSubtitle ? 'Subtitles & Captions' : 'Select Audio Stream'),
              if (isSubtitle)
                RadioListTile<String>(
                  value: 'no',
                  groupValue: currentTrack.id,
                  activeColor: AppTheme.primaryOrange,
                  title: Text(
                    'Off',
                    style: TextStyle(
                      color: currentTrack.id == 'no' ? AppTheme.primaryOrange : Colors.white,
                      fontWeight: currentTrack.id == 'no' ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onChanged: (_) {
                    _player.setSubtitleTrack(SubtitleTrack.no());
                    Navigator.of(sheetContext).pop();
                    _showToast('Subtitles: Off');
                  },
                ),
              if (tracks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text('No tracks available', style: TextStyle(color: Colors.white60)),
                )
              else
                ...tracks.map((track) {
                  final isSelected = track.id == currentTrack.id;
                  final title = track.title ?? track.language ?? 'Track ${track.id}';
                  return RadioListTile<String>(
                    value: track.id,
                    groupValue: currentTrack.id,
                    activeColor: AppTheme.primaryOrange,
                    title: Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryOrange : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: track.language != null
                        ? Text(track.language!, style: const TextStyle(color: Colors.white54, fontSize: 12))
                        : null,
                    onChanged: (_) {
                      if (isSubtitle) {
                        _player.setSubtitleTrack(track as SubtitleTrack);
                      } else {
                        _player.setAudioTrack(track as AudioTrack);
                      }
                      Navigator.of(sheetContext).pop();
                      _showToast('Selected: $title');
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
      ],
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
    _gestureHudTimer?.cancel();
    _doubleTapTimer?.cancel();
    _toastTimer?.cancel();
    _completedSubscription?.cancel();
    _posSubscription?.cancel();
    _durSubscription?.cancel();
    _playingSubscription?.cancel();

    // Reset brightness
    try {
      ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
    } catch (_) {}

    // Save final playback position
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
    final videoTitle = _currentVideo?.title ?? widget.directUrl ?? 'Maya Player';

    // Video fitting configuration according to AspectMode
    BoxFit fit;
    double? aspectRatio;
    switch (_currentAspect) {
      case AspectMode.bestFit:
        fit = BoxFit.contain;
        aspectRatio = null;
        break;
      case AspectMode.fill:
        fit = BoxFit.cover;
        aspectRatio = null;
        break;
      case AspectMode.ratio16_9:
        fit = BoxFit.fill;
        aspectRatio = 16.0 / 9.0;
        break;
      case AspectMode.ratio4_3:
        fit = BoxFit.fill;
        aspectRatio = 4.0 / 3.0;
        break;
      case AspectMode.original:
        fit = BoxFit.scaleDown;
        aspectRatio = null;
        break;
    }

    Widget videoViewport = Video(
      controller: _controller,
      fit: fit,
      aspectRatio: aspectRatio,
      controls: NoVideoControls,
    );

    if (!_extendOverNotch) {
      videoViewport = SafeArea(
        maintainBottomViewPadding: true,
        child: Center(child: videoViewport),
      );
    } else {
      videoViewport = Center(child: videoViewport);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Surface Area
          videoViewport,

          // 2. Gesture Detection Layer (Left=Brightness, Right=Volume, Tap=Hide/Show)
          Positioned.fill(
            child: Row(
              children: [
                // Left half: Brightness, Double-tap rewind, Scrubbing, Long-press 2x
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
                    onVerticalDragStart: (_) {
                      if (_isLocked) return;
                      _triggerGestureHud('brightness');
                    },
                    onVerticalDragUpdate: (details) {
                      if (_isLocked || !StorageService().gestureControlsEnabled) return;
                      final delta = -(details.primaryDelta ?? 0) / 250;
                      _brightnessLevel = (_brightnessLevel + delta).clamp(0.02, 1.0);
                      try {
                        ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(_brightnessLevel);
                      } catch (_) {}
                      _triggerGestureHud('brightness');
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
                      _showToast('${_formatDuration(_scrubTargetPosition)} / ${_formatDuration(duration)}');
                    },
                    onHorizontalDragEnd: (details) {
                      if (_isScrubbing) {
                        _isScrubbing = false;
                        _player.seek(_scrubTargetPosition);
                      }
                    },
                  ),
                ),

                // Right half: Volume, Double-tap forward, Scrubbing, Long-press 2x
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
                    onVerticalDragStart: (_) {
                      if (_isLocked) return;
                      _triggerGestureHud('volume');
                    },
                    onVerticalDragUpdate: (details) {
                      if (_isLocked || !StorageService().gestureControlsEnabled) return;
                      final maxVolume = StorageService().audioBoost ? 1.5 : 1.0;
                      final delta = -(details.primaryDelta ?? 0) / 250;
                      _volumeLevel = (_volumeLevel + delta).clamp(0.0, maxVolume);
                      _player.setVolume((_volumeLevel * 100).clamp(0.0, 150.0));
                      _triggerGestureHud('volume');
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
                      _showToast('${_formatDuration(_scrubTargetPosition)} / ${_formatDuration(duration)}');
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

          // 3. Left / Right HUD Pill for Volume & Brightness
          if (_activeGestureHud != null && !_isLocked)
            Align(
              alignment: _activeGestureHud == 'brightness'
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _GestureHudPill(
                  isBrightness: _activeGestureHud == 'brightness',
                  level: _activeGestureHud == 'brightness' ? _brightnessLevel : _volumeLevel,
                ),
              ),
            ),

          // 4. Double Tap Seek Ripple Indicator
          if (_doubleTapFeedback != null)
            Align(
              alignment: _doubleTapIsForward ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 120,
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _doubleTapIsForward ? Icons.fast_forward : Icons.fast_rewind,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _doubleTapFeedback!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. 2X Speed Press HUD Badge
          if (_isFastForwarding2x)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
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

          // 6. Active Toast Message Banner
          if (_activeToastMessage != null)
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1F26).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    _activeToastMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          // 7. Screen Lock Indicator (When Locked, only show floating unlock token)
          if (_isLocked && _showControls)
            Positioned(
              left: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SafeArea(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(27),
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _isLocked = false;
                        _showControls = true;
                      });
                      _startHideControlsTimer();
                      _showToast('Screen Unlocked');
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8C1D18).withValues(alpha: 0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Color(0xFFFFDAD6),
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 8. Master UI Controls Layer
          if (_showControls && !_isLocked)
            Positioned.fill(
              child: Stack(
                children: [
                  // Top Gradient Scrim (130dp)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 130,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.75),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Gradient Scrim (200dp)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 200,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content Column: Top Bar, Center Controls, Bottom Bar
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    videoTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // Decoder chip (HW / SW)
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isHardwareDecoded
                                      ? AppTheme.primaryOrange.withValues(alpha: 0.3)
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

                              // Audio Track Selector
                              IconButton(
                                icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
                                tooltip: 'Audio Track',
                                onPressed: () => _showTrackPicker(isSubtitle: false),
                              ),

                              // Subtitle Track Selector
                              IconButton(
                                icon: const Icon(Icons.subtitles_outlined, color: Colors.white),
                                tooltip: 'Subtitles',
                                onPressed: () => _showTrackPicker(isSubtitle: true),
                              ),

                              // Playback Speed
                              IconButton(
                                icon: const Icon(Icons.speed_outlined, color: Colors.white),
                                tooltip: 'Playback Speed',
                                onPressed: _showSpeedSheet,
                              ),

                              // Orientation Lock
                              IconButton(
                                icon: Icon(_orientationIcon, color: Colors.white),
                                tooltip: 'Screen Rotation',
                                onPressed: _cycleOrientation,
                              ),

                              // Aspect Ratio Button (Click to cycle, Long-click for sheet)
                              InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: _cycleAspectRatio,
                                onLongPress: () {
                                  HapticFeedback.heavyImpact();
                                  _showAspectSheet();
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.aspect_ratio_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              // Lock Screen Button
                              IconButton(
                                icon: const Icon(Icons.lock_outlined, color: Colors.white),
                                tooltip: 'Lock Screen',
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  setState(() {
                                    _isLocked = true;
                                    _showControls = false;
                                  });
                                  _showToast('Screen Locked');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Center Hero Controls (-10s, Play/Pause, +10s)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.playlist.isNotEmpty)
                            IconButton(
                              iconSize: 36,
                              color: _currentIndex > 0 ? Colors.white : Colors.white24,
                              icon: const Icon(Icons.skip_previous),
                              onPressed: _currentIndex > 0 ? _playPrevious : null,
                            ),
                          const SizedBox(width: 14),

                          // Rewind 10s
                          InkWell(
                            borderRadius: BorderRadius.circular(27),
                            onTap: () {
                              _startHideControlsTimer();
                              _handleDoubleTapSeek(false);
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              child: const Icon(
                                Icons.replay_10,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 36),

                          // Play / Pause (76dp)
                          InkWell(
                            borderRadius: BorderRadius.circular(38),
                            onTap: () {
                              _player.playOrPause();
                              _startHideControlsTimer();
                            },
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryOrange,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryOrange.withValues(alpha: 0.45),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(width: 36),

                          // Forward 10s
                          InkWell(
                            borderRadius: BorderRadius.circular(27),
                            onTap: () {
                              _startHideControlsTimer();
                              _handleDoubleTapSeek(true);
                            },
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                              child: const Icon(
                                Icons.forward_10,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          if (widget.playlist.isNotEmpty)
                            IconButton(
                              iconSize: 36,
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

                      // Bottom Timeline and Status
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppTheme.primaryOrange,
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                  thumbColor: AppTheme.primaryOrange,
                                  overlayColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
                                  trackHeight: 3.5,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6.5,
                                  ),
                                ),
                                child: Slider(
                                  value: _currentPosition.inMilliseconds
                                      .toDouble()
                                      .clamp(0.0, _totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0),
                                  max: _totalDuration.inMilliseconds > 0
                                      ? _totalDuration.inMilliseconds.toDouble()
                                      : 1.0,
                                  onChanged: (val) {
                                    _startHideControlsTimer();
                                    _player.seek(Duration(milliseconds: val.toInt()));
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Speed chip
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _showSpeedSheet,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_playbackSpeed}x',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Aspect chip
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _cycleAspectRatio,
                                        onLongPress: () {
                                          HapticFeedback.heavyImpact();
                                          _showAspectSheet();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _currentAspect.label,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GestureHudPill extends StatelessWidget {
  final bool isBrightness;
  final double level;

  const _GestureHudPill({
    required this.isBrightness,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0.0, 1.0);
    final percentage = (level * 100).toInt();

    IconData icon;
    if (isBrightness) {
      icon = Icons.brightness_medium;
    } else {
      icon = level <= 0.001 ? Icons.volume_off : Icons.volume_up;
    }

    return Container(
      width: 48,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF282930).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
          Container(
            width: 8,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: clampedLevel,
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          Text(
            '$percentage%',
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
