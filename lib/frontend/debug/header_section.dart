import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DebugHeaderSection extends StatelessWidget {
  const DebugHeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Symbols.arrow_back,
            color: cs.onSurface,
            size: 24,
            weight: 400,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Для разработчиков',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }
}
