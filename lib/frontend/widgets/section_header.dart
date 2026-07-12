import 'package:flutter/material.dart';

/// Small primary-colored section title used across settings/profile screens.
class SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  const SectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: TextStyle(
          color: cs.primary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
