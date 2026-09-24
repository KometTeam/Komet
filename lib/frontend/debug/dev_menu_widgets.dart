import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/glossy_pill.dart';

const double _groupRadius = 24;

class DevGroup extends StatelessWidget {
  final List<Widget> children;

  const DevGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlossyPill(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_groupRadius),
        depth: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_groupRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class DevRow extends StatelessWidget {
  final String? caption;
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DevRow({
    super.key,
    this.caption,
    required this.title,
    this.icon,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caption = this.caption;
    final icon = this.icon;
    final trailing = this.trailing;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.fromLTRB(icon == null ? 20 : 22, 12, 16, 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: cs.onSurface, size: 26, weight: 400),
              const SizedBox(width: 22),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null)
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13.5,
                      ),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing],
          ],
        ),
      ),
    );
  }
}

class DevSwitchRow extends StatelessWidget {
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const DevSwitchRow({
    super.key,
    required this.title,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final description = this.description;
    final onChanged = this.onChanged;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class DevToggleRow extends StatelessWidget {
  final String title;
  final String Function(bool value)? description;
  final ValueListenable<bool> valueListenable;
  final ValueChanged<bool> onChanged;

  const DevToggleRow({
    super.key,
    required this.title,
    this.description,
    required this.valueListenable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: valueListenable,
      builder: (context, value, _) => DevSwitchRow(
        title: title,
        description: description?.call(value),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class DevGroupLabel extends StatelessWidget {
  final String text;

  const DevGroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
      child: Text(
        text,
        style: TextStyle(
          color: cs.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
