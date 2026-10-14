import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/haptics.dart';

class PasscodeDots extends StatefulWidget {
  final int length;
  final int filled;
  final int errorTick;
  final Color color;

  const PasscodeDots({
    super.key,
    required this.length,
    required this.filled,
    required this.errorTick,
    required this.color,
  });

  @override
  State<PasscodeDots> createState() => _PasscodeDotsState();
}

class _PasscodeDotsState extends State<PasscodeDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(PasscodeDots old) {
    super.didUpdateWidget(old);
    if (widget.errorTick != old.errorTick) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 14 * (1 - t);
        final failing = _shake.isAnimating;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.length; i++)
                _Dot(
                  filled: i < widget.filled,
                  color: failing ? error : widget.color,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final bool filled;
  final Color color;

  const _Dot({required this.filled, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutBack,
        width: filled ? 16 : 14,
        height: filled ? 16 : 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
  }
}

class PasscodeKeypad extends StatelessWidget {
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;
  final bool enabled;
  final bool canErase;
  final double keySize;

  const PasscodeKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.biometricIcon = Symbols.fingerprint,
    this.enabled = true,
    this.canErase = true,
    this.keySize = maxKeySize,
  });

  static const double maxKeySize = 76;
  static const double minKeySize = 52;
  static const double _gapX = 26;
  static const double _gapY = 14;

  static double keySizeFor(double availableHeight) =>
      (availableHeight / 4 - _gapY).clamp(minKeySize, maxKeySize);

  static int? digitOf(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
    final label = event.character;
    if (label != null && label.length == 1) {
      final code = label.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) return code - 0x30;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scale = keySize / maxKeySize;
    final cell = Size(keySize + _gapX, keySize + _gapY);
    Widget digit(int value) => _PadKey(
      size: keySize,
      cell: cell,
      enabled: enabled,
      onTap: () => onDigit(value),
      background: cs.surfaceContainerHigh,
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: 30 * scale,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
          height: 1,
        ),
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.35,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [for (final v in row) digit(v)],
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              onBiometric == null
                  ? SizedBox.fromSize(size: cell)
                  : _PadKey(
                      size: keySize,
                      cell: cell,
                      enabled: true,
                      onTap: onBiometric!,
                      child: Icon(
                        biometricIcon,
                        size: 32 * scale,
                        color: cs.primary,
                      ),
                    ),
              digit(0),
              _PadKey(
                size: keySize,
                cell: cell,
                enabled: enabled && canErase,
                onTap: onBackspace,
                semanticLabel: MaterialLocalizations.of(
                  context,
                ).deleteButtonTooltip,
                child: Icon(
                  Symbols.backspace,
                  size: 28 * scale,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatefulWidget {
  final double size;
  final Size cell;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;
  final bool enabled;
  final String? semanticLabel;

  const _PadKey({
    required this.size,
    required this.cell,
    required this.onTap,
    required this.child,
    required this.enabled,
    this.background,
    this.semanticLabel,
  });

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> with SingleTickerProviderStateMixin {
  static const double _pressDepth = 0.16;

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 60),
    reverseDuration: const Duration(milliseconds: 280),
  );
  late final CurvedAnimation _depth = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeInBack,
  );
  int? _pointer;
  Offset _downAt = Offset.zero;
  bool _confirmOnRelease = false;

  @override
  void dispose() {
    _depth.dispose();
    _press.dispose();
    super.dispose();
  }

  bool get _inScrolledLayout {
    final position = context
        .findAncestorStateOfType<ScrollableState>()
        ?.position;
    return position != null &&
        position.hasContentDimensions &&
        position.maxScrollExtent > position.minScrollExtent;
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    if (event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _downAt = event.position;
    _confirmOnRelease = _inScrolledLayout;
    unawaited(Haptics.tap());
    _pressIn();
    if (!_confirmOnRelease) widget.onTap();
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downAt).distance > kTouchSlop) _letGo();
  }

  void _onUp(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    final confirm = _confirmOnRelease;
    _letGo();
    if (confirm && widget.enabled) widget.onTap();
  }

  void _onCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _letGo();
  }

  void _pressIn() {
    _press.forward().whenCompleteOrCancel(() {
      if (_pointer == null && mounted) _press.reverse();
    });
  }

  void _letGo() {
    _pointer = null;
    _confirmOnRelease = false;
    if (!_press.isAnimating || _press.status != AnimationStatus.forward) {
      _press.reverse();
    }
  }

  void _activateFromSemantics() {
    if (!widget.enabled) return;
    unawaited(Haptics.tap());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = widget.background;
    final rest = background ?? cs.primary.withValues(alpha: 0);
    final pressed = background == null
        ? cs.primary.withValues(alpha: 0.16)
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.34), background);

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      onTap: widget.enabled ? _activateFromSemantics : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: SizedBox.fromSize(
          size: widget.cell,
          child: Center(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _depth,
                child: Center(child: widget.child),
                builder: (context, child) {
                  final depth = _depth.value;
                  return Transform.scale(
                    scale: 1 - depth * _pressDepth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(rest, pressed, depth.clamp(0, 1)),
                      ),
                      child: SizedBox.square(
                        dimension: widget.size,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
