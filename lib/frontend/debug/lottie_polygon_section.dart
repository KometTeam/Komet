import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../screens/profile/lottie_polygon_screen.dart';

class DebugLottiePolygonSection extends StatelessWidget {
  const DebugLottiePolygonSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LottiePolygonScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                Icon(
                  Symbols.animation,
                  color: cs.onSurfaceVariant,
                  size: 22,
                  weight: 400,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lottie полигон',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Анимированные иконки — тапни, чтобы проиграть',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  color: cs.onSurfaceVariant,
                  size: 22,
                  weight: 400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
