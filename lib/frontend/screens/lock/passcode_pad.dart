import 'dart:math' as math;

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
        duration: const Duration(milliseconds: 160),
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

  static double keySizeFor(double availableHeight) =>
      (availableHeight / 4 - 14).clamp(minKeySize, maxKeySize);

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
    Widget digit(int value) => _PadKey(
      size: keySize,
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
            _PadRow(children: [for (final v in row) digit(v)]),
          _PadRow(
            children: [
              onBiometric == null
                  ? SizedBox.square(dimension: keySize)
                  : _PadKey(
                      size: keySize,
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
                enabled: enabled && canErase,
                onTap: onBackspace,
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

class _PadRow extends StatelessWidget {
  final List<Widget> children;

  const _PadRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 26),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PadKey extends StatefulWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;
  final Color? background;
  final bool enabled;

  const _PadKey({
    required this.size,
    required this.onTap,
    required this.child,
    required this.enabled,
    this.background,
  });

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.enabled
          ? () {
              Haptics.selection();
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed && widget.background != null
                ? Color.alphaBlend(
                    cs.primary.withValues(alpha: 0.18),
                    widget.background!,
                  )
                : widget.background,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
