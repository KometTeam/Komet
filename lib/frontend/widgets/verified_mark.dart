import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class VerifiedMark extends StatelessWidget {
  final double size;
  final Color? color;

  const VerifiedMark({super.key, this.size = 15, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      Symbols.verified,
      size: size,
      color: color ?? cs.primary,
      weight: 600,
      fill: 1,
    );
  }
}
