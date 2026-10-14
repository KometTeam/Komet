import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_fonts.dart';
import 'sheet_helpers.dart';

Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? hint,
  required List<T> options,
  required T selected,
  required String Function(T option) labelOf,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: displayFontOf(sheetContext),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    hint,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              for (final option in options)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(labelOf(option)),
                  trailing: option == selected
                      ? Icon(Symbols.check, color: cs.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      );
    },
  );
}
