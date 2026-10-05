import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/video_model.dart';
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

  BoxFit _videoFit = BoxFit.contain;
  int _fitIndex = 0;
  final List<Map<String, dynamic>> _fitOptions = [
    {'label': 'Fit', 'fit': BoxFit.contain},
    {'label': 'Crop', 'fit': BoxFit.cover},
    {'label': 'Stretch', 'fit': BoxFit.fill},
  ];

  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  double _brightnessLevel = 0.5;
  double _volumeLevel = 100.0;
  String? _gestureIndicatorText;
  IconData? _gestureIndicatorIcon;
  Timer? _gestureIndicatorTimer;

  // Double-tap seek feedback
  String? _seekFeedback;
  Timer? _seekFeedbackTimer;

  StreamSubscription? _completedSubscription;

  @override
  void initState() {
    super.initState();
    // Enable full immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
    _controller = VideoController(_player);

    _currentVideo = widget.initialVideo;
    if (_currentVideo != null && widget.playlist.isNotEmpty) {
      _currentIndex = widget.playlist.indexWhere((v) => v.id == _currentVideo!.id);
      if (_currentIndex == -1) _currentIndex = 0;
    } else {
      _currentIndex = 0;
    }

    _startPlayback();
    _startHideControlsTimer();

    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        _playNext();
      }
    });
  }

  void _startPlayback() {
    if (_currentVideo != null && _currentVideo!.path.isNotEmpty) {
      _player.open(Media(_currentVideo!.path));
    } else if (widget.directUrl != null && widget.directUrl!.isNotEmpty) {
      _player.open(Media(widget.directUrl!));
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
    _showToast('Aspect: ${_fitOptions[_fitIndex]['label']}');
  }

  void _showToast(String message, {IconData? icon}) {
    _gestureIndicatorTimer?.cancel();
    setState(() {
      _gestureIndicatorText = message;
      _gestureIndicatorIcon = icon;
    });
    _gestureIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _gestureIndicatorText = null;
          _gestureIndicatorIcon = null;
        });
      }
    });
  }

  void _handleDoubleTapSeek(bool isForward) {
    if (_isLocked) return;
    final currentPos = _player.state.position;
    final duration = _player.state.duration;
    final delta = isForward ? const Duration(seconds: 10) : const Duration(seconds: -10);
    final target = currentPos + delta;
    final boundedTarget = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);

    _player.seek(boundedTarget);

    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekFeedback = isForward ? '+10s' : '-10s';
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _seekFeedback = null;
        });
      }
    });
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
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
                child: Text(
                  'Playback Speed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Divider(color: AppTheme.surfaceLightColor),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: _speedOptions.map((speed) {
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
                        _showToast('Speed: ${speed}x', icon: Icons.speed);
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
    _seekFeedbackTimer?.cancel();
    _completedSubscription?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentVideo?.title ?? widget.directUrl ?? 'Maya Player';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MPV Video Layer
          Center(
            child: Video(
              controller: _controller,
              fit: _videoFit,
              controls: NoVideoControls,
            ),
          ),

          // Double Tap & Gesture Detectors (VLC gesture zones)
          Row(
            children: [
              // Left half for double tap seek backward & vertical drag brightness
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTap: () => _handleDoubleTapSeek(false),
                  onVerticalDragUpdate: (details) {
                    if (_isLocked) return;
                    _brightnessLevel = (_brightnessLevel - (details.primaryDelta ?? 0) / 300)
                        .clamp(0.0, 1.0);
                    _showToast(
                      'Brightness: ${(_brightnessLevel * 100).toInt()}%',
                      icon: Icons.brightness_6,
                    );
                  },
                ),
              ),

              // Right half for double tap seek forward & vertical drag volume
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTap: () => _handleDoubleTapSeek(true),
                  onVerticalDragUpdate: (details) {
                    if (_isLocked) return;
                    _volumeLevel = (_volumeLevel - (details.primaryDelta ?? 0) / 2)
                        .clamp(0.0, 100.0);
                    _player.setVolume(_volumeLevel);
                    _showToast(
                      'Volume: ${_volumeLevel.toInt()}%',
                      icon: Icons.volume_up,
                    );
                  },
                ),
              ),
            ],
          ),

          // Quick double-tap seek animation indicator
          if (_seekFeedback != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _seekFeedback!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // On-screen Gesture Toast Indicator (Volume, Brightness, Speed)
          if (_gestureIndicatorText != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryOrange, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_gestureIndicatorIcon != null) ...[
                      Icon(_gestureIndicatorIcon, color: AppTheme.primaryOrange, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _gestureIndicatorText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lock Screen Floating Button
          if (_showControls || _isLocked)
            Positioned(
              left: 20,
              top: MediaQuery.of(context).padding.top + 60,
              child: FloatingActionButton.small(
                heroTag: 'lockBtn',
                backgroundColor: _isLocked ? AppTheme.primaryOrange : Colors.black.withOpacity(0.6),
                foregroundColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _isLocked = !_isLocked;
                    if (_isLocked) _showControls = false;
                  });
                  _showToast(_isLocked ? 'Controls Locked' : 'Controls Unlocked',
                      icon: _isLocked ? Icons.lock : Icons.lock_open);
                },
                child: Icon(_isLocked ? Icons.lock : Icons.lock_open, size: 20),
              ),
            ),

          // Controls Overlay
          if (_showControls && !_isLocked)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: Column(
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
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                              tooltip: 'Aspect Ratio',
                              onPressed: _cycleAspectRatio,
                            ),
                            IconButton(
                              icon: const Icon(Icons.speed, color: Colors.white),
                              tooltip: 'Playback Speed',
                              onPressed: _showSpeedMenu,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Center playback controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Previous button
                        if (widget.playlist.isNotEmpty)
                          IconButton(
                            iconSize: 42,
                            color: _currentIndex > 0 ? Colors.white : Colors.white38,
                            icon: const Icon(Icons.skip_previous),
                            onPressed: _currentIndex > 0 ? _playPrevious : null,
                          ),
                        const SizedBox(width: 20),
                        // Play/Pause button
                        StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? true;
                            return IconButton(
                              iconSize: 64,
                              color: AppTheme.primaryOrange,
                              icon: Icon(isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled),
                              onPressed: () {
                                _player.playOrPause();
                                _startHideControlsTimer();
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        // Next button
                        if (widget.playlist.isNotEmpty)
                          IconButton(
                            iconSize: 42,
                            color: _currentIndex < widget.playlist.length - 1
                                ? Colors.white
                                : Colors.white38,
                            icon: const Icon(Icons.skip_next),
                            onPressed: _currentIndex < widget.playlist.length - 1
                                ? _playNext
                                : null,
                          ),
                      ],
                    ),

                    // Bottom Seek & Time Bar
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
                                // Scrubber
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: AppTheme.primaryOrange,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: AppTheme.primaryOrange,
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
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
                                // Time timestamps
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
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
