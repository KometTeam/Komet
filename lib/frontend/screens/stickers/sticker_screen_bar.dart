import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';

PreferredSizeWidget stickerScreenBar(
  BuildContext context, {
  required Widget title,
  Widget? leading,
  List<Widget> actions = const [],
}) {
  final cs = Theme.of(context).colorScheme;
  return AppBar(
    backgroundColor: cs.surface,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    leading:
        leading ??
        IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface, size: 24),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
    title: DefaultTextStyle.merge(
      style: TextStyle(
        fontFamily: displayFontOf(context),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      child: title,
    ),
    actions: [...actions, const SizedBox(width: 4)],
  );
}
