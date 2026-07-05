import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:komet/main.dart';

import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/media_cache.dart';
import '../../../../models/attachment.dart';

class VideoNoteBubble extends StatefulWidget {
  final VideoAttachment attachment;
  final String messageId;
  final int chatId;
  final ColorScheme cs;

  const VideoNoteBubble({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.chatId,
    required this.cs,
  });

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble> {
  static const double _size = 210;
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _error = false;

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  static Uint8List? _previewBytes(String? data) {
    if (data == null) return null;
    const marker = 'base64,';
    final idx = data.indexOf(marker);
    if (idx < 0) return null;
    try {
      return base64Decode(data.substring(idx + marker.length));
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggle() async {
    final existing = _controller;
    if (existing != null) {
      setState(
        () => existing.value.isPlaying ? existing.pause() : existing.play(),
      );
      return;
    }
    if (_loading) return;

    final a = widget.attachment;
    final videoId = a.videoId;
    final token = a.videoToken;
    if (videoId == null || token == null) {
      setState(() => _error = true);
      return;
    }

    setState(() => _loading = true);
    Haptics.tap();
    try {
      final cacheName = 'videonote_$videoId.mp4';
      var file = await MediaCache.existing(cacheName);
      if (file == null) {
        final url = await messagesModule.getVideoUrl(
          messageId: widget.messageId,
          chatId: widget.chatId,
          token: token,
          videoId: videoId,
        );
        if (url == null) throw Exception('no_url');
        file = await MediaCache.getOrDownload(cacheName, url);
        if (file == null) throw Exception('download');
      }
      if (!mounted) return;
      final c = VideoPlayerController.file(file);
      _controller = c;
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      c.addListener(_onTick);
      c.play();
      setState(() => _loading = false);
    } catch (e) {
      logger.w('VideoNoteBubble._toggle: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final playing = ready && c.value.isPlaying;
    final preview = _previewBytes(a.previewData);

    double progress = 0;
    if (ready && c.value.duration.inMilliseconds > 0) {
      progress =
          c.value.position.inMilliseconds / c.value.duration.inMilliseconds;
    }

    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: _size,
                height: _size,
                child: ready
                    ? FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: c.value.size.width,
                          height: c.value.size.height,
                          child: VideoPlayer(c),
                        ),
                      )
                    : preview != null
                    ? Image.memory(
                        preview,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Container(color: widget.cs.surfaceContainerHighest),
              ),
            ),
            if (ready)
              SizedBox(
                width: _size - 2,
                height: _size - 2,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 3,
                  color: widget.cs.primary,
                  backgroundColor: Colors.white24,
                ),
              ),
            if (!playing)
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _error ? Symbols.error : Symbols.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
