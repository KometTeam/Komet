import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/glossy_pill.dart';

class DebugToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String Function(bool value)? subtitle;
  final ValueListenable<bool> valueListenable;
  final ValueChanged<bool> onChanged;

  const DebugToggleTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.valueListenable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: valueListenable,
      builder: (context, value, _) {
        final resolvedSubtitle = subtitle?.call(value);
        return GlossyPill(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          depth: 6,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (resolvedSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        resolvedSubtitle,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        );
      },
    );
  }
}
