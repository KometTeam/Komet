import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/models/chat_folder.dart';
import '../../../backend/modules/folders.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import 'folder_edit_sheet.dart';

Future<void> showChatFoldersSheet(
  BuildContext context, {
  required List<int> chatIds,
}) async {
  if (chatIds.isEmpty) return;
  final cs = Theme.of(context).colorScheme;
  final createNew = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _ChatFoldersSheet(chatIds: chatIds),
  );
  if (createNew != true || !context.mounted) return;
  await showFolderEditSheet(context, initialChatIds: chatIds);
}

enum _Membership { none, some, all }

class _ChatFoldersSheet extends StatefulWidget {
  final List<int> chatIds;

  const _ChatFoldersSheet({required this.chatIds});

  @override
  State<_ChatFoldersSheet> createState() => _ChatFoldersSheetState();
}

class _ChatFoldersSheetState extends State<_ChatFoldersSheet> {
  int? _accountId;
  List<ChatFolder> _folders = const [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    FoldersModule.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    FoldersModule.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final accountId = _accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final folders = await FoldersModule.loadFolders(accountId);
    if (!mounted) return;
    setState(() {
      _accountId = accountId;
      _folders = [
        for (final folder in folders)
          if (!FoldersModule.isAllChatsFolder(folder) && folder.canEditFilters)
            folder,
      ];
      _loading = false;
    });
  }

  _Membership _membershipIn(ChatFolder folder) {
    final included = widget.chatIds.where(folder.include.contains).length;
    if (included == 0) return _Membership.none;
    return included == widget.chatIds.length
        ? _Membership.all
        : _Membership.some;
  }

  Future<void> _toggle(ChatFolder folder) async {
    final accountId = _accountId;
    if (accountId == null || _busy.contains(folder.id)) return;
    final add = _membershipIn(folder) != _Membership.all;
    final include = add
        ? [
            ...folder.include,
            for (final id in widget.chatIds)
              if (!folder.include.contains(id)) id,
          ]
        : [
            for (final id in folder.include)
              if (!widget.chatIds.contains(id)) id,
          ];
    setState(() => _busy.add(folder.id));
    Haptics.selection();
    try {
      await FoldersModule.updateFolder(
        api,
        accountId,
        folder,
        include: include,
      );
    } catch (e) {
      Haptics.error();
      if (mounted) {
        showCustomNotification(
          context,
          e is PacketError
              ? e.message
              : AppLocalizations.of(
                  context,
                )!.chatFoldersUpdateFailed(folder.title),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(folder.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
              child: Text(
                l10n.chatFoldersAddTo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SmallSpinner(),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final folder in _folders)
                      _FolderRow(
                        key: ValueKey(folder.id),
                        title: _folderLabel(folder),
                        membership: _membershipIn(folder),
                        busy: _busy.contains(folder.id),
                        onTap: () => _toggle(folder),
                      ),
                    _NewFolderRow(
                      label: l10n.folderActionNewFolder,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _folderLabel(ChatFolder folder) {
    final emoji = folder.emoji;
    if (emoji == null || emoji.isEmpty) return folder.title;
    return '$emoji ${folder.title}';
  }
}

class _FolderRow extends StatelessWidget {
  final String title;
  final _Membership membership;
  final bool busy;
  final VoidCallback onTap;

  const _FolderRow({
    super.key,
    required this.title,
    required this.membership,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          children: [
            Icon(Symbols.folder, color: cs.onSurface, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: busy
                    ? const SmallSpinner(size: 20)
                    : Checkbox(
                        tristate: true,
                        value: switch (membership) {
                          _Membership.none => false,
                          _Membership.some => null,
                          _Membership.all => true,
                        },
                        onChanged: (_) => onTap(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewFolderRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NewFolderRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(Symbols.create_new_folder, color: cs.primary, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: cs.primary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
