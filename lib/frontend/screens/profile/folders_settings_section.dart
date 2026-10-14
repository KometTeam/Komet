import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/models/chat_folder.dart';
import '../../../backend/modules/folders.dart';
import '../../../core/config/app_shape.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import '../chats/folder_action_sheet.dart';
import '../chats/folder_edit_sheet.dart';

enum _Preset { unread, personal, channels }

class FoldersSettingsSection extends StatefulWidget {
  const FoldersSettingsSection({super.key});

  @override
  State<FoldersSettingsSection> createState() => _FoldersSettingsSectionState();
}

class _FoldersSettingsSectionState extends State<FoldersSettingsSection> {
  int? _accountId;
  ChatFolder? _allChats;
  List<ChatFolder> _folders = const [];
  bool _channelsSuggested = false;
  bool _filtersEnabled = false;
  final Set<_Preset> _adding = {};

  @override
  void initState() {
    super.initState();
    FoldersModule.revision.addListener(_reload);
    unawaited(_reload());
  }

  @override
  void dispose() {
    FoldersModule.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final folders = await FoldersModule.loadFolders(accountId);
    final flags = await FoldersModule.loadSuggestionFlags(accountId);
    if (!mounted) return;
    setState(() {
      _accountId = accountId;
      _allChats = folders.where(FoldersModule.isAllChatsFolder).firstOrNull;
      _folders = [
        for (final folder in folders)
          if (!FoldersModule.isAllChatsFolder(folder)) folder,
      ];
      _channelsSuggested = flags.channelsSuggested;
      _filtersEnabled = flags.filtersEnabled;
    });
  }

  List<_Preset> get _suggestions => [
    if (!_folders.any(
      (f) => FoldersModule.isUnreadFolder(f, filtersEnabled: _filtersEnabled),
    ))
      _Preset.unread,
    if (!_folders.any(
      (f) => FoldersModule.isPersonalFolder(f, filtersEnabled: _filtersEnabled),
    ))
      _Preset.personal,
    if (_channelsSuggested && !_folders.any(FoldersModule.isChannelsFolder))
      _Preset.channels,
  ];

  String _presetTitle(AppLocalizations l10n, _Preset preset) =>
      switch (preset) {
        _Preset.unread => l10n.foldersSettingsPresetUnread,
        _Preset.personal => l10n.foldersSettingsPresetPersonal,
        _Preset.channels => l10n.foldersSettingsPresetChannels,
      };

  static List<int> _presetFilters(_Preset preset) => switch (preset) {
    _Preset.unread => const [FolderFilter.unread],
    _Preset.personal => const [FolderFilter.contact, FolderFilter.notContact],
    _Preset.channels => const [FolderFilter.channel],
  };

  Future<void> _addPreset(_Preset preset) async {
    final accountId = _accountId;
    if (accountId == null || !_adding.add(preset)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {});
    try {
      await FoldersModule.createFolder(
        api,
        accountId,
        title: _presetTitle(l10n, preset),
        filters: _presetFilters(preset),
      );
      Haptics.success();
    } catch (e) {
      Haptics.error();
      if (mounted) {
        showCustomNotification(
          context,
          e is PacketError ? e.message : l10n.foldersSettingsAddFailed,
        );
      }
    } finally {
      _adding.remove(preset);
      if (mounted) setState(() {});
    }
  }

  Future<void> _reorder(int oldIndex, int target) async {
    final accountId = _accountId;
    if (accountId == null || target == oldIndex) return;
    final previous = _folders;
    final reordered = [...previous];
    reordered.insert(target, reordered.removeAt(oldIndex));
    setState(() => _folders = reordered);

    final stored = await FoldersModule.loadFoldersOrder(accountId);
    final allChatsId = _allChats?.id;
    final order = FoldersModule.spliceOrder(
      stored.isEmpty && allChatsId != null ? [allChatsId] : stored,
      [for (final folder in reordered) folder.id],
    );
    try {
      await FoldersModule.reorderFolders(api, accountId, order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _folders = previous);
      showCustomNotification(
        context,
        e is PacketError
            ? e.message
            : AppLocalizations.of(context)!.foldersSettingsReorderFailed,
      );
    }
  }

  void _openFolder(ChatFolder folder) {
    if (!folder.canEditTitle && !folder.canEditFilters) return;
    unawaited(showFolderEditSheet(context, folder: folder));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final suggestions = _suggestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FolderRow(
                  leading: Icon(Symbols.sms, color: cs.onSurface, size: 24),
                  title: _allChats?.title ?? l10n.chatListAllChatsFolder,
                ),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _folders.length,
                  onReorderStart: (_) => Haptics.selection(),
                  onReorderItem: (oldIndex, newIndex) =>
                      unawaited(_reorder(oldIndex, newIndex)),
                  proxyDecorator: _liftedRow,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return _FolderRow(
                      key: ValueKey(folder.id),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Tooltip(
                          message: l10n.foldersSettingsReorder,
                          child: Icon(
                            Symbols.menu,
                            color: cs.onSurfaceVariant,
                            size: 24,
                          ),
                        ),
                      ),
                      emoji: folder.emoji,
                      title: folder.title,
                      onTap: () => _openFolder(folder),
                      trailing: folder.canDelete
                          ? _FolderMenu(
                              onDelete: () => unawaited(
                                confirmDeleteFolder(context, folder),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ],
            ),
            _FolderRow(
              leading: Icon(Symbols.add, color: cs.primary, size: 24),
              title: l10n.foldersSettingsCreate,
              titleColor: cs.primary,
              onTap: () => unawaited(showFolderEditSheet(context)),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          SectionHeader(l10n.foldersSettingsRecommended),
          SettingsCard(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final preset in suggestions)
                    _PresetRow(
                      key: ValueKey(preset),
                      title: _presetTitle(l10n, preset),
                      busy: _adding.contains(preset),
                      tooltip: l10n.foldersSettingsAdd,
                      onAdd: () => unawaited(_addPreset(preset)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _liftedRow(Widget child, int index, Animation<double> animation) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Material(
          color: cs.surfaceContainerHighest,
          elevation: lerpDouble(0, 6, t)!,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    super.key,
    required this.leading,
    required this.title,
    this.emoji,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? emoji;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emoji = this.emoji;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: trailing == null ? 20 : 6,
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 18),
                if (emoji != null && emoji.isNotEmpty) ...[
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor ?? cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderMenu extends StatelessWidget {
  const _FolderMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<VoidCallback>(
      icon: Icon(Symbols.more_vert, color: cs.onSurfaceVariant),
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: onDelete,
          child: Row(
            children: [
              Icon(Symbols.delete, size: 20, color: cs.error),
              const SizedBox(width: 12),
              Text(l10n.msgActionsDelete, style: TextStyle(color: cs.error)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    super.key,
    required this.title,
    required this.busy,
    required this.tooltip,
    required this.onAdd,
  });

  final String title;
  final bool busy;
  final String tooltip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox.square(
            dimension: 40,
            child: IconButton.filled(
              onPressed: busy ? null : onAdd,
              tooltip: tooltip,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: AppShape.buttonRadius,
                ),
              ),
              icon: busy
                  ? SmallSpinner(size: 18, color: cs.onPrimary)
                  : const Icon(Symbols.add, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
