import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../theme/app_theme.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final VideoModel video;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const VideoThumbnailWidget({
    super.key,
    required this.video,
    this.width = 110,
    this.height = 70,
    this.borderRadius,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _loaded = false;
      _bytes = null;
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    try {
      final bytes = await widget.video.getThumbnail(
        width: widget.width.toInt() * 2,
        height: widget.height.toInt() * 2,
      );
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: AppTheme.surfaceLightColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_bytes != null)
              Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              )
            else if (_loaded)
              _placeholder()
            else
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              ),

            // Duration badge in bottom-right corner
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.video.formattedDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Resolution badge in top-right corner
            if (widget.video.resolutionBadge.isNotEmpty)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    widget.video.resolutionBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceLightColor,
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: AppTheme.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
