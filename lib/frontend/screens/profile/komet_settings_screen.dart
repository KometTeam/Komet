import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/build_profile.dart';
import '../../../core/config/komet_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import 'plugins_screen.dart';

class KometSettingsScreen extends StatelessWidget {
  const KometSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Komet',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            SectionHeader(
              l10n.authLimitsSignupMessagesTitle,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                if (BuildProfile.plugins)
                  SettingsNavTile(
                    icon: Symbols.extension,
                    label: l10n.pluginsScreenTitle,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PluginsScreen()),
                    ),
                  ),
                if (BuildProfile.hiddenContentViewers) ...[
                  ValueListenableBuilder<bool>(
                    valueListenable: KometSettings.viewDeleted,
                    builder: (context, value, _) => SettingsToggleTile(
                      icon: Symbols.delete_history,
                      label: 'View deleted message',
                      subtitle: l10n.kometSettingsViewDeletedSubtitle,
                      value: value,
                      onChanged: KometSettings.setViewDeleted,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: KometSettings.viewRedacted,
                    builder: (context, value, _) => SettingsToggleTile(
                      icon: Symbols.history_edu,
                      label: 'View redacted message history',
                      subtitle: l10n.kometSettingsViewRedactedSubtitle,
                      value: value,
                      onChanged: KometSettings.setViewRedacted,
                    ),
                  ),
                ],
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.fullTimestamp,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.schedule,
                    label: 'View full timestamp',
                    subtitle: l10n.kometSettingsFullTimestampSubtitle,
                    value: value,
                    onChanged: KometSettings.setFullTimestamp,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.showForward,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.forward,
                    label: 'Show Forward',
                    subtitle: l10n.kometSettingsShowForwardSubtitle,
                    value: value,
                    onChanged: KometSettings.setShowForward,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.showTypingTime,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.timer,
                    label: 'Show typing time',
                    subtitle: l10n.kometSettingsTypingTimeSubtitle,
                    value: value,
                    onChanged: KometSettings.setShowTypingTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(
              l10n.kometSettingsFoldersHeader,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.hideAllChatsFolder,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.folder_off,
                    label: 'Hide "All" folder',
                    subtitle: l10n.kometSettingsHideAllFolderSubtitle,
                    value: value,
                    onChanged: KometSettings.setHideAllChatsFolder,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.showHiddenChats,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.visibility_lock,
                    label: 'Show hidden chats',
                    subtitle: l10n.kometSettingsShowHiddenChatsSubtitle,
                    value: value,
                    onChanged: KometSettings.setShowHiddenChats,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.archiveOnPull,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.archive,
                    label: 'Pull-down archive',
                    subtitle: l10n.kometSettingsArchiveOnPullSubtitle,
                    value: value,
                    onChanged: KometSettings.setArchiveOnPull,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              'Ghost Mode',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.ghostMode,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.visibility_off,
                    label: 'Ghost Mode',
                    subtitle: l10n.kometSettingsGhostModeSubtitle,
                    value: value,
                    onChanged: _setGhostMode,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.antiRead,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.mark_chat_read,
                    label: 'Anti read',
                    subtitle: l10n.kometSettingsAntiReadSubtitle,
                    value: value,
                    onChanged: KometSettings.setAntiRead,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.selfOnlineCheck,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.radar,
                    label: 'Self Online Check',
                    subtitle: l10n.kometSettingsSelfOnlineCheckSubtitle,
                    value: value,
                    onChanged: KometSettings.setSelfOnlineCheck,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(
              l10n.kometSettingsDebugHeader,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.recordDebugLogs,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.bug_report,
                    label: l10n.kometSettingsDebugLogsLabel,
                    subtitle: l10n.kometSettingsDebugLogsSubtitle,
                    value: value,
                    onChanged: KometSettings.setRecordDebugLogs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setGhostMode(bool value) async {
    await KometSettings.setGhostMode(value);
    api.sendPing(interactive: !value);
  }
}
