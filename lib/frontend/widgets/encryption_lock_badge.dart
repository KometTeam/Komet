import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class EncryptionLockBadge extends StatelessWidget {
  final double size;
  final Color? borderColor;

  const EncryptionLockBadge({super.key, this.size = 16, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? cs.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(
        Symbols.lock,
        size: size * 0.62,
        weight: 700,
        fill: 1,
        color: cs.onPrimary,
      ),
    );
  }
}
