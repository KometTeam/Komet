import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeGlassDock extends StatefulWidget {
  final int count;
  final double inactiveWidth;
  final double activeWidth;
  final double progress;
  final Duration animationDuration;
  final bool pressed;
  final double insetX;
  final double insetY;
  final double radius;
  final Color tint;
  final Color selectorTint;

  const NativeGlassDock({
    super.key,
    required this.count,
    required this.inactiveWidth,
    required this.activeWidth,
    required this.progress,
    this.animationDuration = Duration.zero,
    this.pressed = false,
    this.insetX = 4,
    this.insetY = 8,
    this.radius = 34,
    this.tint = Colors.transparent,
    required this.selectorTint,
  });

  @override
  State<NativeGlassDock> createState() => _NativeGlassDockState();
}

class _NativeGlassDockState extends State<NativeGlassDock> {
  static const String _viewType = 'ru.komet.app/liquid_glass_dock';

  MethodChannel? _channel;
  String? _materialKey;

  @override
  void didUpdateWidget(covariant NativeGlassDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _channel;
    if (channel == null) return;
    if (widget.progress != oldWidget.progress) {
      if (widget.animationDuration > Duration.zero) {
        unawaited(channel.invokeMethod('animateTo', widget.progress));
      } else {
        unawaited(channel.invokeMethod('setProgress', widget.progress));
      }
    }
    if (widget.pressed != oldWidget.pressed) {
      unawaited(channel.invokeMethod('setPressed', widget.pressed));
    }
    if (widget.count != oldWidget.count ||
        widget.inactiveWidth != oldWidget.inactiveWidth ||
        widget.activeWidth != oldWidget.activeWidth) {
      unawaited(
        channel.invokeMethod('setGeometry', {
          'count': widget.count,
          'inactiveWidth': widget.inactiveWidth,
          'activeWidth': widget.activeWidth,
        }),
      );
    }
  }

  Map<String, Object> _params(bool dark) => {
    'radiusTL': widget.radius,
    'radiusTR': widget.radius,
    'radiusBL': widget.radius,
    'radiusBR': widget.radius,
    'dark': dark,
    'tintA': widget.tint.a,
    'tintR': widget.tint.r,
    'tintG': widget.tint.g,
    'tintB': widget.tint.b,
    'selectorA': widget.selectorTint.a,
    'selectorR': widget.selectorTint.r,
    'selectorG': widget.selectorTint.g,
    'selectorB': widget.selectorTint.b,
    'count': widget.count,
    'inactiveWidth': widget.inactiveWidth,
    'activeWidth': widget.activeWidth,
    'insetX': widget.insetX,
    'insetY': widget.insetY,
    'progress': widget.progress,
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final materialKey =
        'dock-${widget.radius}-$dark-${widget.tint}-${widget.selectorTint}';
    if (_materialKey != materialKey) {
      _materialKey = materialKey;
      _channel = null;
    }
    return UiKitView(
      key: ValueKey(materialKey),
      viewType: _viewType,
      onPlatformViewCreated: _onCreated,
      creationParams: _params(dark),
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  void _onCreated(int viewId) {
    final channel = MethodChannel('${_viewType}_$viewId');
    _channel = channel;
    unawaited(channel.invokeMethod('setProgress', widget.progress));
  }
}
