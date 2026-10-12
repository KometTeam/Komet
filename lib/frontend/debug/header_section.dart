import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_fonts.dart';

class DebugHeaderSection extends StatelessWidget {
  final VoidCallback? onReset;

  const DebugHeaderSection({super.key, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'Dev menu',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: displayFontOf(context),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(
                Symbols.arrow_back,
                color: cs.onSurface,
                size: 24,
                weight: 400,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(foregroundColor: cs.onSurface),
              child: const Text(
                'Сброс',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
