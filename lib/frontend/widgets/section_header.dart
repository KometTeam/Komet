import 'package:flutter/material.dart';

/// Small primary-colored section title used across settings/profile screens.
class SectionHeader extends StatelessWidget {
  static const double _opacity = 0.72;

  final String title;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: cs.primary.withValues(alpha: _opacity),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
