import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/config/komet_settings.dart';
import '../../../core/security/archive_lock.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show accountModule, animojiModule;
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/reaction_picker.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/underline_tab_bar.dart';
import '../lock/archive_gate.dart';
import 'archive_lock_settings_screen.dart';
import 'folders_settings_section.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});

  Widget _tab(Widget section) => ListView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
    children: [section],
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    UnderlineTabBar(
                      labels: [
                        l10n.chatSettingsTabChats,
                        l10n.chatSettingsTabFolders,
                      ],
                      alignment: TabAlignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 56),
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
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: ConnectionSpinner(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _tab(const _ChatsSettingsSection()),
                    _tab(const FoldersSettingsSection()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatsSettingsSection extends StatelessWidget {
  const _ChatsSettingsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l10n.chatListArchive,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        ),
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
            const _ArchiveLockTile(),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(
          l10n.chatSettingsReactionsTitle,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        ),
        const SettingsCard(children: [_DoubleTapReactionTile()]),
        const SizedBox(height: 20),
        SectionHeader(
          l10n.chatSettingsAutoDownloadTitle,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        ),
        SettingsCard(
          children: [
            _toggle(
              KometSettings.autoDownloadPhoto,
              KometSettings.setAutoDownloadPhoto,
              Symbols.image,
              l10n.chatSettingsAutoDownloadPhoto,
            ),
            _toggle(
              KometSettings.autoDownloadVideo,
              KometSettings.setAutoDownloadVideo,
              Symbols.videocam,
              l10n.chatSettingsAutoDownloadVideo,
            ),
            _toggle(
              KometSettings.autoDownloadVoice,
              KometSettings.setAutoDownloadVoice,
              Symbols.mic,
              l10n.chatSettingsAutoDownloadVoice,
            ),
            _toggle(
              KometSettings.autoDownloadVideoNote,
              KometSettings.setAutoDownloadVideoNote,
              Symbols.radio_button_checked,
              l10n.chatSettingsAutoDownloadVideoNote,
            ),
          ],
        ),
        const SizedBox(height: 20),
        SectionHeader(
          l10n.chatSettingsAutoplayTitle,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        ),
        SettingsCard(
          children: [
            _toggle(
              KometSettings.autoplayVideo,
              KometSettings.setAutoplayVideo,
              Symbols.movie,
              l10n.chatSettingsAutoplayVideo,
              subtitle: l10n.chatSettingsAutoplayVideoHint,
            ),
            _toggle(
              KometSettings.autoplayGif,
              KometSettings.setAutoplayGif,
              Symbols.gif_box,
              l10n.chatSettingsAutoplayGif,
            ),
            _toggle(
              KometSettings.autoplayAnimoji,
              KometSettings.setAutoplayAnimoji,
              Symbols.emoji_emotions,
              l10n.chatSettingsAutoplayAnimoji,
            ),
            _toggle(
              KometSettings.autoplayVideoNote,
              KometSettings.setAutoplayVideoNote,
              Symbols.radio_button_checked,
              l10n.chatSettingsAutoplayVideoNote,
            ),
          ],
        ),
      ],
    );
  }

  Widget _toggle(
    ValueNotifier<bool> notifier,
    Future<void> Function(bool value) onChanged,
    IconData icon,
    String label, {
    String? subtitle,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) => SettingsToggleTile(
        icon: icon,
        label: label,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ArchiveLockTile extends StatefulWidget {
  const _ArchiveLockTile();

  @override
  State<_ArchiveLockTile> createState() => _ArchiveLockTileState();
}

class _ArchiveLockTileState extends State<_ArchiveLockTile> {
  Offset? _tapPosition;

  void _open() {
    final tapPosition = _tapPosition;
    _tapPosition = null;
    pushPastArchiveLock(
      context,
      tapPosition: tapPosition,
      destination: () => MaterialPageRoute<void>(
        builder: (_) => const ArchiveLockSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Listener(
      onPointerDown: (event) => _tapPosition = event.position,
      child: ValueListenableBuilder<bool>(
        valueListenable: ArchiveLock.instance.enabled,
        builder: (context, enabled, _) => SettingsNavTile(
          icon: Symbols.lock,
          label: l10n.archiveLockTitle,
          value: enabled ? l10n.securityEnabledMasc : l10n.securityDisabledMasc,
          onTap: _open,
        ),
      ),
    );
  }
}

class _DoubleTapReactionTile extends StatefulWidget {
  const _DoubleTapReactionTile();

  @override
  State<_DoubleTapReactionTile> createState() => _DoubleTapReactionTileState();
}

class _DoubleTapReactionTileState extends State<_DoubleTapReactionTile> {
  static const double _glyphSize = 26;

  late final Future<void> _catalog = animojiModule.ensureLoaded().catchError(
    (Object e) => logger.w('Каталог реакций не загрузился: $e'),
  );

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final current = accountModule.doubleTapReaction.value;
    final picked = await showModalBottomSheet<({String? emoji})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) => _DoubleTapReactionSheet(current: current),
    );
    if (picked == null || picked.emoji == current || !context.mounted) return;
    Haptics.selection();
    try {
      await accountModule.setDoubleTapReaction(picked.emoji);
    } catch (e) {
      logger.w('Реакция на двойной тап не сохранилась: $e');
      if (context.mounted) {
        showCustomNotification(
          context,
          l10n.chatSettingsDoubleTapReactionFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<String?>(
      valueListenable: accountModule.doubleTapReaction,
      builder: (context, emoji, _) => SettingsNavTile(
        icon: Symbols.add_reaction,
        label: l10n.chatSettingsDoubleTapReaction,
        value: l10n.chatSettingsDoubleTapReactionOff,
        trailing: emoji == null
            ? null
            : FutureBuilder<void>(
                future: _catalog,
                builder: (context, _) => ReactionGlyph(
                  key: ValueKey(emoji),
                  reaction: _reactionFor(emoji),
                  size: _glyphSize,
                ),
              ),
        onTap: () => _pick(context),
      ),
    );
  }

  static ReactionEmoji _reactionFor(String emoji) {
    final animoji = animojiModule.findByEmoji(emoji);
    return animoji == null
        ? ReactionEmoji(emoji: emoji)
        : ReactionEmoji.fromAnimoji(animoji);
  }
}

class _DoubleTapReactionSheet extends StatelessWidget {
  final String? current;

  const _DoubleTapReactionSheet({required this.current});

  static Future<List<ReactionEmoji>> _loadReactions() async {
    try {
      await animojiModule.ensureLoaded();
    } catch (e) {
      logger.w('Каталог реакций не загрузился: $e');
    }
    return availableReactions();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.62),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text(
                l10n.chatSettingsDoubleTapReaction,
                style: TextStyle(
                  fontFamily: displayFontOf(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                l10n.chatSettingsDoubleTapReactionHint,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Icon(Symbols.block, color: cs.onSurfaceVariant),
                title: Text(l10n.chatSettingsDoubleTapReactionNone),
                trailing: current == null
                    ? Icon(Symbols.check, color: cs.primary)
                    : null,
                onTap: () => Navigator.pop(context, (emoji: null)),
              ),
            ),
            Expanded(
              child: ReactionEmojiPicker(
                selected: current,
                loadEmojis: _loadReactions,
                onPick: (emoji) => Navigator.pop(context, (emoji: emoji)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
