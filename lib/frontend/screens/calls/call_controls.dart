import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../widgets/animated_slash_icon.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/small_spinner.dart';

class CallControlBar extends StatelessWidget {
  final List<Widget> children;

  const CallControlBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final child in children) Expanded(child: child)],
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  static const double maxDiameter = 62;
  static const double _minGap = 6;

  final IconData icon;
  final IconData? slashedIcon;
  final bool slashed;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool busy;

  const CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.onLongPress,
    this.slashedIcon,
    this.slashed = false,
    this.busy = false,
  });

  Widget _buildIcon() {
    final crossed = slashedIcon;
    if (crossed == null) {
      return Icon(icon, color: foreground, size: 26, fill: 1);
    }
    return AnimatedSlashIcon(
      icon: icon,
      slashedIcon: crossed,
      slashed: slashed,
      color: foreground,
      size: 26,
      fill: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = min(maxDiameter, constraints.maxWidth - _minGap);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: diameter,
              height: diameter,
              child: GlossyPill(
                color: background,
                borderRadius: BorderRadius.circular(diameter / 2),
                onTap: busy ? null : onTap,
                onLongPress: busy ? null : onLongPress,
                depth: 9,
                child: Center(
                  child: busy
                      ? SmallSpinner(size: 22, color: foreground)
                      : _buildIcon(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
