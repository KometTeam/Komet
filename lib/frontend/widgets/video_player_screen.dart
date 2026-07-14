import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../core/utils/format.dart';
import 'small_spinner.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Map<String, String> sources;
  final String? initialQuality;

  const VideoPlayerScreen({
    super.key,
    required this.sources,
    this.initialQuality,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _error = false;
  bool _controlsVisible = true;
  double? _dragValue;
  late String _quality;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _quality =
        widget.initialQuality != null &&
            widget.sources.containsKey(widget.initialQuality)
        ? widget.initialQuality!
        : widget.sources.keys.first;
    _load(_quality);
  }

  Future<void> _load(
    String quality, {
    Duration? position,
    bool wasPlaying = true,
  }) async {
    final url = widget.sources[quality];
    if (url == null) {
      setState(() => _error = true);
      return;
    }

    final generation = ++_loadGeneration;
    final old = _controller;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    setState(() {
      _quality = quality;
      _error = false;
    });

    try {
      await controller.initialize();
      old?.removeListener(_onTick);
      await old?.dispose();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (generation != _loadGeneration) {
        return;
      }
      if (position != null) await controller.seekTo(position);
      if (generation != _loadGeneration) {
        return;
      }
      controller.addListener(_onTick);
      if (wasPlaying) controller.play();
      setState(() {});
    } catch (_) {
      if (generation == _loadGeneration && mounted) {
        setState(() => _error = true);
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  Future<void> _switchQuality(String quality) async {
    if (quality == _quality) return;
    final c = _controller;
    final position = c?.value.position;
    final wasPlaying = c?.value.isPlaying ?? true;
    await _load(quality, position: position, wasPlaying: wasPlaying);
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

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized;
    final buffering = ready && c.value.isBuffering;
    final value = ready ? c.value : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: _error
                  ? const Icon(Symbols.error, color: Colors.white54, size: 64)
                  : ready
                  ? AspectRatio(
                      aspectRatio: c.value.aspectRatio,
                      child: VideoPlayer(c),
                    )
                  : const SmallSpinner(size: 36, color: Colors.white),
            ),
            if (buffering)
              const Center(
                child: SmallSpinner(size: 36, color: Colors.white),
              ),
            if (!_error)
              AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _buildControls(context, value, buffering),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    VideoPlayerValue? value,
    bool buffering,
  ) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final duration = value?.duration ?? Duration.zero;
    final position = value?.position ?? Duration.zero;
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = position.inMilliseconds.toDouble().clamp(0, maxMs);
    final sliderValue = _dragValue ?? posMs.toDouble();
    final isPlaying = value?.isPlaying ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black54],
          stops: [0, 0.5, 1],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPad + 4, left: 4, right: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Symbols.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (widget.sources.length > 1)
                  PopupMenuButton<String>(
                    color: Colors.black87,
                    initialValue: _quality,
                    onSelected: _switchQuality,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Symbols.tune,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _quality,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (_) => widget.sources.keys
                        .map(
                          (q) => PopupMenuItem<String>(
                            value: q,
                            child: Row(
                              children: [
                                Icon(
                                  q == _quality
                                      ? Symbols.check
                                      : Symbols.check_box_outline_blank,
                                  color: q == _quality
                                      ? Colors.white
                                      : Colors.transparent,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  q,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: buffering
                  ? const SizedBox.shrink()
                  : IconButton(
                      iconSize: 64,
                      icon: Icon(
                        isPlaying ? Symbols.pause : Symbols.play_arrow,
                        color: Colors.white,
                        fill: 1,
                      ),
                      onPressed: _togglePlay,
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: bottomPad + 8,
            ),
            child: Row(
              children: [
                Text(
                  formatDurationClock(position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      min: 0,
                      max: maxMs <= 0 ? 1 : maxMs,
                      value: maxMs <= 0
                          ? 0
                          : sliderValue.clamp(0, maxMs).toDouble(),
                      onChanged: maxMs <= 0
                          ? null
                          : (v) => setState(() => _dragValue = v),
                      onChangeEnd: maxMs <= 0
                          ? null
                          : (v) {
                              _controller?.seekTo(
                                Duration(milliseconds: v.round()),
                              );
                              setState(() => _dragValue = null);
                            },
                    ),
                  ),
                ),
                Text(
                  formatDurationClock(duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
