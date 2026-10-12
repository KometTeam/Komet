import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/config/komet_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.chatSettingsTitle,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: KometSettings.archiveOnPull,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.archive,
                    label: l10n.chatSettingsArchiveOnPull,
                    subtitle: l10n.kometSettingsArchiveOnPullSubtitle,
                    value: value,
                    onChanged: KometSettings.setArchiveOnPull,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(
              l10n.chatSettingsAutoDownloadTitle,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                _autoDownload(
                  KometSettings.autoDownloadPhoto,
                  KometSettings.setAutoDownloadPhoto,
                  Symbols.image,
                  l10n.chatSettingsAutoDownloadPhoto,
                ),
                _autoDownload(
                  KometSettings.autoDownloadVideo,
                  KometSettings.setAutoDownloadVideo,
                  Symbols.videocam,
                  l10n.chatSettingsAutoDownloadVideo,
                ),
                _autoDownload(
                  KometSettings.autoDownloadVoice,
                  KometSettings.setAutoDownloadVoice,
                  Symbols.mic,
                  l10n.chatSettingsAutoDownloadVoice,
                ),
                _autoDownload(
                  KometSettings.autoDownloadVideoNote,
                  KometSettings.setAutoDownloadVideoNote,
                  Symbols.radio_button_checked,
                  l10n.chatSettingsAutoDownloadVideoNote,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _autoDownload(
    ValueNotifier<bool> notifier,
    Future<void> Function(bool value) onChanged,
    IconData icon,
    String label,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) => SettingsToggleTile(
        icon: icon,
        label: label,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
