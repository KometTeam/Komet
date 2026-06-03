import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../core/utils/media_cache.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String cacheName;
  final String? url;

  const VideoPlayerScreen({
    super.key,
    required this.cacheName,
    this.url,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _error = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    File? file = await MediaCache.existing(widget.cacheName);
    if (file == null && widget.url != null) {
      file = await MediaCache.getOrDownload(
        widget.cacheName,
        widget.url!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
    }
    if (!mounted) return;
    if (file == null) {
      setState(() => _error = true);
      return;
    }

    final controller = VideoPlayerController.file(file);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
      controller.play();
      controller.addListener(_onTick);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _error
                ? const Icon(Symbols.error, color: Colors.white54, size: 64)
                : ready
                    ? AspectRatio(
                        aspectRatio: c.value.aspectRatio,
                        child: VideoPlayer(c),
                      )
                    : _buildLoading(),
          ),
          if (ready)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlay,
                child: AnimatedOpacity(
                  opacity: c.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.play_arrow,
                          color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                colors: const VideoProgressColors(playedColor: Colors.white),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Symbols.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          color: Colors.white,
          value: _progress > 0 && _progress < 1 ? _progress : null,
        ),
        if (_progress > 0 && _progress < 1) ...[
          const SizedBox(height: 12),
          Text(
            '${(_progress * 100).round()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
