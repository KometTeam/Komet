import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show RTCVideoRenderer, RTCVideoView, RTCVideoViewObjectFit;

class CallVideoView extends StatefulWidget {
  const CallVideoView({
    super.key,
    required this.renderer,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.mirror = false,
    this.placeholder,
  });

  final RTCVideoRenderer renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool mirror;
  final Widget? placeholder;

  @override
  State<CallVideoView> createState() => _CallVideoViewState();
}

class _CallVideoViewState extends State<CallVideoView> {
  static const Duration _switchCooldown = Duration(milliseconds: 200);

  bool _armed = false;
  String? _sourceId;
  Timer? _cooldown;

  @override
  void initState() {
    super.initState();
    _bind(widget.renderer);
  }

  @override
  void didUpdateWidget(CallVideoView old) {
    super.didUpdateWidget(old);
    if (identical(old.renderer, widget.renderer)) return;
    old.renderer.removeListener(_onRenderer);
    _cooldown?.cancel();
    _cooldown = null;
    _bind(widget.renderer);
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    widget.renderer.removeListener(_onRenderer);
    super.dispose();
  }

  void _bind(RTCVideoRenderer renderer) {
    _sourceId = renderer.srcObject?.id;
    _armed = _hasFrames;
    renderer.addListener(_onRenderer);
  }

  bool get _hasFrames {
    final renderer = widget.renderer;
    return renderer.textureId != null &&
        renderer.srcObject != null &&
        renderer.value.width > 0;
  }

  void _onRenderer() {
    final id = widget.renderer.srcObject?.id;
    if (id != _sourceId) {
      _sourceId = id;
      _cooldown?.cancel();
      _cooldown = Timer(_switchCooldown, () {
        _cooldown = null;
        _sync();
      });
      if (_armed && mounted) setState(() => _armed = false);
      return;
    }
    if (_cooldown != null) return;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final next = _hasFrames;
    if (next != _armed) setState(() => _armed = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_armed) return widget.placeholder ?? const SizedBox.expand();
    return RTCVideoView(
      widget.renderer,
      objectFit: widget.objectFit,
      mirror: widget.mirror,
    );
  }
}
