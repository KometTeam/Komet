import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/models/chat_folder.dart';
import '../../../backend/modules/chats.dart';
import '../../../backend/modules/cloud_storage.dart';
import '../../../backend/modules/folders.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../main.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';

typedef _ChatType = ({int filter, IconData icon, String label});

const List<_ChatType> _chatTypes = [
  (filter: FolderFilter.contact, icon: Symbols.person, label: 'Контакты'),
  (
    filter: FolderFilter.notContact,
    icon: Symbols.person_off,
    label: 'Не в контактах',
  ),
  (filter: FolderFilter.chat, icon: Symbols.group, label: 'Группы'),
  (filter: FolderFilter.channel, icon: Symbols.campaign, label: 'Каналы'),
  (filter: FolderFilter.bot, icon: Symbols.smart_toy, label: 'Боты'),
];

const Set<int> _editableFilters = {
  FolderFilter.contact,
  FolderFilter.notContact,
  FolderFilter.chat,
  FolderFilter.channel,
  FolderFilter.bot,
  FolderFilter.unread,
  FolderFilter.notMuted,
};

Future<void> showFolderEditSheet(
  BuildContext context, {
  ChatFolder? folder,
}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _FolderEditSheet(folder: folder),
  );
}

class _FolderEditSheet extends StatefulWidget {
  final ChatFolder? folder;

  const _FolderEditSheet({this.folder});

  @override
  State<_FolderEditSheet> createState() => _FolderEditSheetState();
}

class _FolderEditSheetState extends State<_FolderEditSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _search = TextEditingController();

  final Set<int> _types = {};
  final Set<int> _chatIds = {};
  List<int> _preservedFilters = const [];
  bool _onlyUnread = false;
  bool _onlyNotMuted = false;

  List<CachedChat> _chats = [];
  int _myId = 0;
  bool _loading = true;
  bool _busy = false;

  bool get _isNew => widget.folder == null;

  @override
  void initState() {
    super.initState();
    final folder = widget.folder;
    if (folder != null) {
      _title.text = folder.title;
      _types.addAll(
        folder.filters.where((f) => _chatTypes.any((t) => t.filter == f)),
      );
      _chatIds.addAll(folder.include);
      _onlyUnread = folder.filters.contains(FolderFilter.unread);
      _onlyNotMuted = folder.filters.contains(FolderFilter.notMuted);
      _preservedFilters = folder.filters
          .where((f) => !_editableFilters.contains(f))
          .toList();
    }
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final list = await chats.getChats(accountId);
      list.removeWhere(CloudStorageModule.isCloudStorageGroup);
      if (!mounted) return;
      setState(() {
        _myId = accountId;
        _chats = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _peerId(CachedChat chat) {
    for (final entry in chat.participants.entries) {
      if (entry.key != _myId) return entry.key;
    }
    return _myId;
  }

  String _chatTitle(CachedChat chat) {
    if (chat.id == 0) return 'Избранное';
    if (chat.type == 'DIALOG') {
      return ContactCache.get(_peerId(chat)) ?? chat.title ?? 'Пользователь';
    }
    return chat.title ?? 'Чат';
  }

  String? _chatAvatar(CachedChat chat) {
    if (chat.type == 'DIALOG' && chat.id != 0) {
      return ContactCache.getAvatar(_peerId(chat)) ?? chat.iconUrl;
    }
    return chat.iconUrl;
  }

  List<int> _buildFilters() => [
    ..._types,
    if (_onlyUnread) FolderFilter.unread,
    if (_onlyNotMuted) FolderFilter.notMuted,
    ..._preservedFilters,
  ];

  bool get _canSubmit =>
      !_busy &&
      _title.text.trim().isNotEmpty &&
      (_types.isNotEmpty || _chatIds.isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    if (_myId == 0) {
      showCustomNotification(context, 'Нет активного аккаунта');
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      final title = _title.text.trim();
      final folder = widget.folder;
      if (folder == null) {
        await FoldersModule.createFolder(
          api,
          _myId,
          title: title,
          include: _chatIds.toList(),
          filters: _buildFilters(),
        );
      } else {
        await FoldersModule.updateFolder(
          api,
          _myId,
          folder,
          title: title,
          include: _chatIds.toList(),
          filters: _buildFilters(),
        );
      }
      Haptics.success();
      if (mounted) navigator.pop();
    } catch (e) {
      Haptics.error();
      if (!mounted) return;
      setState(() => _busy = false);
      showCustomNotification(
        context,
        e is PacketError ? e.message : 'Не удалось сохранить папку',
      );
    }
  }

  Future<void> _delete() async {
    final folder = widget.folder;
    if (folder == null || _busy) return;
    if (_myId == 0) {
      showCustomNotification(context, 'Нет активного аккаунта');
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      message: 'Удалить папку «${folder.title}»? Чаты останутся на месте.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await FoldersModule.deleteFolders(api, _myId, [folder.id]);
      Haptics.success();
      if (mounted) navigator.pop();
    } catch (e) {
      Haptics.error();
      if (!mounted) return;
      setState(() => _busy = false);
      showCustomNotification(
        context,
        e is PacketError ? e.message : 'Не удалось удалить папку',
      );
    }
  }

  void _clearSelection() {
    setState(() {
      _types.clear();
      _chatIds.clear();
      _onlyUnread = false;
      _onlyNotMuted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final query = _search.text.trim().toLowerCase();
    final types = query.isEmpty
        ? _chatTypes
        : _chatTypes
              .where((t) => t.label.toLowerCase().contains(query))
              .toList();
    final visibleChats = query.isEmpty
        ? _chats
        : _chats
              .where((c) => _chatTitle(c).toLowerCase().contains(query))
              .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(cs),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildTitleCard(cs),
                    const SizedBox(height: 12),
                    _buildPickerCard(cs, types, visibleChats),
                    if (widget.folder?.canEditFilters ?? true) ...[
                      const SizedBox(height: 12),
                      _buildShowOnlyCard(cs),
                    ],
                  ],
                ),
              ),
              _buildActions(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _isNew ? 'Новая папка' : 'Изменение папки',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
        ),
      ],
    ),
  );

  Widget _buildCard(ColorScheme cs, Widget child) => Container(
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  Widget _buildTitleCard(ColorScheme cs) {
    final canEditTitle = widget.folder?.canEditTitle ?? true;
    return _buildCard(
      cs,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _title,
                enabled: canEditTitle && !_busy,
                onChanged: (_) => setState(() {}),
                maxLength: FoldersModule.titleMaxLength,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    FoldersModule.titleMaxLength,
                  ),
                ],
                style: TextStyle(color: cs.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Название папки',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_title.text.characters.length}/${FoldersModule.titleMaxLength}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerCard(
    ColorScheme cs,
    List<_ChatType> types,
    List<CachedChat> visibleChats,
  ) {
    final canEditFilters = widget.folder?.canEditFilters ?? true;
    return _buildCard(
      cs,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Найти по имени',
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                prefixIcon: Icon(
                  Symbols.search,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          if (types.isNotEmpty && canEditFilters) ...[
            _buildSectionLabel(cs, 'ТИПЫ ЧАТОВ'),
            for (final type in types)
              _buildRow(
                cs,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(type.icon, color: cs.onSurface, size: 20),
                ),
                title: type.label,
                selected: _types.contains(type.filter),
                onTap: () => setState(() {
                  if (!_types.remove(type.filter)) _types.add(type.filter);
                  Haptics.selection();
                }),
              ),
          ],
          if (_loading) ...[
            _buildSectionLabel(cs, 'ЧАТЫ И КАНАЛЫ'),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Center(child: SmallSpinner(size: 28)),
            ),
          ] else if (visibleChats.isNotEmpty) ...[
            _buildSectionLabel(cs, 'ЧАТЫ И КАНАЛЫ'),
            for (final chat in visibleChats)
              _buildRow(
                cs,
                leading: KometAvatar(
                  name: _chatTitle(chat),
                  size: 40,
                  imageUrl: _chatAvatar(chat),
                ),
                title: _chatTitle(chat),
                subtitle: chat.id == 0 ? 'Сообщения себе' : null,
                selected: _chatIds.contains(chat.id),
                onTap: () => setState(() {
                  if (!_chatIds.remove(chat.id)) _chatIds.add(chat.id);
                  Haptics.selection();
                }),
              ),
          ],
          if (!_loading && types.isEmpty && visibleChats.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Text(
                'Ничего не найдено',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(
      text,
      style: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _buildRow(
    ColorScheme cs, {
    required Widget leading,
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: _busy ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          AnimatedScale(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            scale: selected ? 1 : 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Symbols.check, color: cs.onPrimary, size: 16),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildShowOnlyCard(ColorScheme cs) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildSectionLabel(cs, 'ПОКАЗЫВАТЬ ТОЛЬКО'),
      _buildCard(
        cs,
        Column(
          children: [
            _buildToggle(
              cs,
              icon: Symbols.notifications,
              title: 'Чаты с уведомлениями',
              value: _onlyNotMuted,
              onChanged: (v) => setState(() => _onlyNotMuted = v),
            ),
            _buildToggle(
              cs,
              icon: Symbols.mark_chat_unread,
              title: 'Непрочитанные чаты',
              value: _onlyUnread,
              onChanged: (v) => setState(() => _onlyUnread = v),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildToggle(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
    child: Row(
      children: [
        Icon(icon, color: cs.onSurfaceVariant, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            title,
            style: TextStyle(color: cs.onSurface, fontSize: 15),
          ),
        ),
        Switch(
          value: value,
          onChanged: _busy
              ? null
              : (v) {
                  Haptics.selection();
                  onChanged(v);
                },
        ),
      ],
    ),
  );

  Widget _buildActions(ColorScheme cs) {
    final folder = widget.folder;
    final hasSelection =
        _types.isNotEmpty ||
        _chatIds.isNotEmpty ||
        _onlyUnread ||
        _onlyNotMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: folder == null
                ? SheetButton(
                    label: 'Очистить выбор',
                    filled: false,
                    onTap: hasSelection && !_busy ? _clearSelection : null,
                  )
                : SheetButton(
                    label: 'Удалить папку',
                    filled: false,
                    color: cs.error,
                    onTap: folder.canDelete && !_busy ? _delete : null,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SheetButton(
              label: _isNew ? 'Создать папку' : 'Сохранить',
              filled: true,
              onTap: _canSubmit ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
