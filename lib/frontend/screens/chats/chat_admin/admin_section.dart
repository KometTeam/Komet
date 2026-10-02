import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/hint_bubble.dart';
import '../../../widgets/settings_card.dart';
import '../../../widgets/swipe_route.dart';
import 'admins_screen.dart';
import 'channel_followers_screen.dart';
import 'chat_admin_state.dart';
import 'group_settings_screen.dart';

class AdminSection extends StatelessWidget {
  final ChatAdminState state;
  final VoidCallback onLeave;

  const AdminSection({super.key, required this.state, required this.onLeave});

  static bool visibleFor(ChatAdminState state) =>
      state.isAdmin || state.hasSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminsTile = SettingsNavTile(
      icon: Symbols.shield_person,
      label: l10n.adminsTitle,
      value: '${state.adminIds.length}',
      onTap: () => pushSwipeable(context, (_) => AdminsScreen(state: state)),
    );
    if (!state.isChannel) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SettingsCard(
          children: [
            if (state.isAdmin) adminsTile,
            if (state.hasSettings)
              SettingsNavTile(
                icon: Symbols.settings,
                label: l10n.groupSettingsTitle,
                onTap: () => pushSwipeable(
                  context,
                  (_) => GroupSettingsScreen(state: state, onLeave: onLeave),
                ),
              ),
          ],
        ),
      );
    }
    final followers = state.followersCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          children: [
            adminsTile,
            SettingsNavTile(
              icon: Symbols.group,
              label: l10n.channelFollowersTitle,
              value: followers == null ? null : '$followers',
              onTap: () => pushSwipeable(
                context,
                (_) => ChannelFollowersScreen(state: state),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            Builder(
              builder: (tileContext) => SettingsNavTile(
                icon: Symbols.monitoring,
                label: l10n.channelStatsTitle,
                onTap: () =>
                    showHintBubble(tileContext, l10n.channelStatsUnavailable),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
