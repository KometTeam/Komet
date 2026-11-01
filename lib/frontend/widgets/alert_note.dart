import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_shape.dart';

class AlertNote extends StatelessWidget {
  AlertNote(String message, {super.key, this.icon = Symbols.error, this.margin})
    : messages = [message];

  const AlertNote.all(
    this.messages, {
    super.key,
    this.icon = Symbols.error,
    this.margin,
  });

  final List<String> messages;
  final IconData icon;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = TextStyle(color: cs.onSurface, fontSize: 13.5, height: 1.35);
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: AppShape.buttonRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < messages.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 18, color: cs.error),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(messages[i], style: style)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
