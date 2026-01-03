import 'package:flutter/material.dart';
import 'package:gwid/app_sizes.dart';

class TypingDots extends StatefulWidget {
  final Color color;
  final double size;
  const TypingDots({super.key, required this.color, this.size = 18});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    return SizedBox(
      width: w,
      height: w * 0.6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          double a(int i) => 0.3 + 0.7 * ((t + i / 3) % 1.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              return Opacity(
                opacity: a(i),
                child: Container(
                  width: w * 0.22,
                  height: w * 0.22,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
