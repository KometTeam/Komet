import 'package:flutter/material.dart';

import '../../../core/config/app_fonts.dart';
import '../../widgets/settings_card.dart';
import 'lock_glyph.dart';

class LockHero extends StatelessWidget {
  final bool enabled;
  final String title;
  final String description;

  const LockHero({
    super.key,
    required this.enabled,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsPanel(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: enabled ? 1 : 0),
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutBack,
            builder: (context, closed, _) => Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  cs.surfaceContainerHighest,
                  cs.primaryContainer,
                  closed.clamp(0.0, 1.0),
                ),
              ),
              child: LockGlyph(
                closed: closed,
                size: 52,
                color: Color.lerp(
                  cs.onSurfaceVariant,
                  cs.onPrimaryContainer,
                  closed.clamp(0.0, 1.0),
                )!,
                holeColor: Color.lerp(
                  cs.surfaceContainerHighest,
                  cs.primaryContainer,
                  closed.clamp(0.0, 1.0),
                )!,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontFamily: displayFontOf(context),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
