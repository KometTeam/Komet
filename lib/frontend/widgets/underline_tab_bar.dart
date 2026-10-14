import 'package:flutter/material.dart';

class UnderlineTabBar extends StatelessWidget {
  final List<String> labels;
  final TabAlignment alignment;
  final EdgeInsetsGeometry padding;

  const UnderlineTabBar({
    super.key,
    required this.labels,
    this.alignment = TabAlignment.start,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TabBar(
      isScrollable: true,
      tabAlignment: alignment,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: cs.primary, width: 3),
        borderRadius: BorderRadius.circular(3),
      ),
      labelColor: cs.primary,
      unselectedLabelColor: cs.onSurfaceVariant,
      labelStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      padding: padding,
      tabs: [for (final label in labels) Tab(text: label)],
    );
  }
}
