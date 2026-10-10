import 'package:flutter/material.dart';

import '../../core/config/app_bottom_navigation_style.dart';
import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'settings_card.dart';

class BottomNavigationStyleCard extends StatelessWidget {
  const BottomNavigationStyleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SettingsPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceBottomNavigationTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appearanceBottomNavigationSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<BottomNavigationStyle>(
            valueListenable: AppBottomNavigationStyle.current,
            builder: (context, current, _) =>
                SegmentedButton<BottomNavigationStyle>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: BottomNavigationStyle.floating,
                      label: Text(l10n.appearanceBottomNavigationFloating),
                    ),
                    ButtonSegment(
                      value: BottomNavigationStyle.compact,
                      label: Text(l10n.appearanceBottomNavigationCompact),
                    ),
                  ],
                  selected: {current},
                  onSelectionChanged: (selection) {
                    Haptics.selection();
                    AppBottomNavigationStyle.save(selection.first);
                  },
                ),
          ),
        ],
      ),
    );
  }
}
