import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// #***! замок с галочкой когда код безопасности сверен лично
class EncryptionLockBadge extends StatelessWidget {
  final double size;
  final Color? borderColor;
  final bool verified;

  const EncryptionLockBadge({
    super.key,
    this.size = 16,
    this.borderColor,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: verified ? cs.tertiary : cs.primary,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? cs.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Icon(
        verified ? Symbols.verified_user : Symbols.lock,
        size: size * 0.62,
        weight: 700,
        fill: 1,
        color: verified ? cs.onTertiary : cs.onPrimary,
      ),
    );
  }
}
