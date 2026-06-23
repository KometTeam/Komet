import 'package:flutter/material.dart';

import '../../core/cache/info_cache.dart';

class OnlineDot extends StatelessWidget {
  final int userId;
  final double size;
  final Color color;
  final Color borderColor;
  final double borderWidth;

  const OnlineDot({
    super.key,
    required this.userId,
    required this.borderColor,
    this.size = 12,
    this.color = const Color(0xFF2EC36B),
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PresenceFetch.revision,
      builder: (context, _, _) {
        final online = PresenceFetch.isOnline(userId);
        return AnimatedScale(
          scale: online ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: online ? Curves.easeOutBack : Curves.easeIn,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
          ),
        );
      },
    );
  }
}
