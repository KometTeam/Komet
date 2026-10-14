import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_message_actions_style.dart';
import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'settings_card.dart';
import 'settings_radio_tile.dart';

class MessageActionsStyleCard extends StatelessWidget {
  const MessageActionsStyleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (
        style: MessageActionsStyle.radial,
        icon: Symbols.bubble_chart,
        label: l10n.appearanceMessageActionsRadial,
        description: l10n.appearanceMessageActionsRadialDescription,
      ),
      (
        style: MessageActionsStyle.list,
        icon: Symbols.menu,
        label: l10n.appearanceMessageActionsList,
        description: l10n.appearanceMessageActionsListDescription,
      ),
    ];
    return SettingsPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceMessageActionsTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appearanceMessageActionsSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<MessageActionsStyle>(
            valueListenable: AppMessageActionsStyle.current,
            builder: (context, current, _) => Column(
              children: [
                for (final item in items)
                  SettingsRadioTile(
                    leading: Icon(
                      item.icon,
                      color: cs.onSurface,
                      size: 22,
                      weight: 500,
                    ),
                    label: item.label,
                    description: item.description,
                    selected: current == item.style,
                    onTap: () {
                      if (current == item.style) return;
                      Haptics.selection();
                      AppMessageActionsStyle.save(item.style);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
