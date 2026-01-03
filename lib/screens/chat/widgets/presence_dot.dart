import 'package:flutter/material.dart';
import 'package:gwid/app_sizes.dart';

class PresenceDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  const PresenceDot({super.key, required this.isOnline, this.size = 10});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? colors.primary : colors.onSurfaceVariant,
      ),
    );
  }
}
