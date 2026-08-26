import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';

enum ComposerAction { mic, videocam, send }

const Map<(ComposerAction, ComposerAction), String> _morphs = {
  (ComposerAction.mic, ComposerAction.videocam):
      'assets/lottie/ic_mic_to_videocam.json',
  (ComposerAction.videocam, ComposerAction.mic):
      'assets/lottie/ic_videocam_to_mic.json',
  (ComposerAction.mic, ComposerAction.send):
      'assets/lottie/ic_mic_to_send.json',
  (ComposerAction.videocam, ComposerAction.send):
      'assets/lottie/ic_videocam_to_send.json',
  (ComposerAction.send, ComposerAction.mic):
      'assets/lottie/ic_send_to_mic.json',
  (ComposerAction.send, ComposerAction.videocam):
      'assets/lottie/ic_send_to_videocam.json',
};

IconData composerActionIcon(ComposerAction action) => switch (action) {
  ComposerAction.mic => Symbols.mic,
  ComposerAction.videocam => Symbols.videocam,
  ComposerAction.send => Symbols.send,
};

class ComposerMorphIcon extends StatefulWidget {
  const ComposerMorphIcon({
    super.key,
    required this.action,
    required this.color,
    this.size = 24,
    this.duration = const Duration(milliseconds: 400),
  });

  final ComposerAction action;
  final Color color;
  final double size;
  final Duration duration;

  @override
  State<ComposerMorphIcon> createState() => _ComposerMorphIconState();
}

class _ComposerMorphIconState extends State<ComposerMorphIcon>
    with SingleTickerProviderStateMixin {
  static bool _warmed = false;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  String? _playing;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _warmUp();
  }

  void _warmUp() {
    if (_warmed) return;
    _warmed = true;
    for (final asset in _morphs.values.toSet()) {
      AssetLottie(asset).load();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_playing == null || !mounted) return;
    setState(() => _playing = null);
  }

  @override
  void didUpdateWidget(ComposerMorphIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.action == oldWidget.action) return;

    final asset = _morphs[(oldWidget.action, widget.action)];
    if (asset == null) {
      if (_playing != null) setState(() => _playing = null);
      return;
    }

    _controller.stop();
    _playing = null;
    _controller.value = 0;
    setState(() => _playing = asset);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _playing;
    if (asset == null) {
      return Icon(
        composerActionIcon(widget.action),
        color: widget.color,
        size: widget.size,
        weight: 400,
      );
    }
    return SizedBox.square(
      dimension: widget.size,
      child: Lottie.asset(
        asset,
        controller: _controller,
        fit: BoxFit.contain,
        delegates: LottieDelegates(
          values: [ValueDelegate.color(const ['**'], value: widget.color)],
        ),
      ),
    );
  }
}
