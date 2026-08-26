import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_colors.dart';

class PreviewSelectionToggle extends StatelessWidget {
  final ValueListenable<Set<String>> selectedIds;
  final String id;
  final VoidCallback onTap;

  const PreviewSelectionToggle({
    super.key,
    required this.selectedIds,
    required this.id,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selectedIds,
      builder: (context, selected, _) {
        final index = selected.toList().indexOf(id);
        final isSelected = index >= 0;
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? MediaAccent.of(context) : Colors.transparent,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: isSelected
                ? Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class PreviewCountBadge extends StatelessWidget {
  final int count;

  const PreviewCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DashedCirclePainter(color: Colors.white),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    const dashes = 22;
    const sweep = (2 * math.pi) / dashes;
    const dashRatio = 0.55;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * dashRatio, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class PreviewToolIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const PreviewToolIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class PreviewFileToggle extends StatefulWidget {
  const PreviewFileToggle({super.key});

  @override
  State<PreviewFileToggle> createState() => _FileToggleState();
}

class _FileToggleState extends State<PreviewFileToggle> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => setState(() => _active = !_active),
      icon: TweenAnimationBuilder<double>(
        tween: Tween(end: _active ? 1 : 0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          final color = Color.lerp(
            Colors.white54,
            Color.lerp(Colors.white, MediaAccent.of(context), 0.4),
            t,
          );
          return Icon(Symbols.description, color: color, size: 24);
        },
      ),
    );
  }
}

class PreviewSendButton extends StatelessWidget {
  final VoidCallback onTap;

  const PreviewSendButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MediaAccent.of(context),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Symbols.send, color: Colors.white, size: 24, fill: 1),
        ),
      ),
    );
  }
}
