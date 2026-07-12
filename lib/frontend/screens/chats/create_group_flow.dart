import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/chats.dart';
import '../../../backend/modules/contacts.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/names.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/swipe_route.dart';
import 'chat_screen.dart';

Future<void> showCreateGroupFlow(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => const _CreateGroupFlow(),
  );
}

enum _Step { pickParticipants, groupDetails }

class _CreateGroupFlow extends StatefulWidget {
  const _CreateGroupFlow();

  @override
  State<_CreateGroupFlow> createState() => _CreateGroupFlowState();
}

class _CreateGroupFlowState extends State<_CreateGroupFlow> {
  _Step _step = _Step.pickParticipants;
  List<CachedContact> _all = [];
  final List<CachedContact> _selected = [];
  bool _loading = true;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _title = TextEditingController();
  File? _avatar;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final myId = await TokenStorage.getActiveAccountId();
      if (myId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final list = await ContactsModule.getContacts(myId);
      list.removeWhere((c) => c.id == myId);
      list.sort(
        (a, b) => displayName(a.firstName, a.lastName).toLowerCase().compareTo(
          displayName(b.firstName, b.lastName).toLowerCase(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(CachedContact c) {
    setState(() {
      final idx = _selected.indexWhere((x) => x.id == c.id);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(c);
      }
    });
  }

  bool _isSelected(int id) => _selected.any((c) => c.id == id);

  Future<void> _pickAvatar() async {
    if (_creating) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final file = File(path);
    final size = await file.length();
    if (size > kMaxAvatarBytes) {
      if (!mounted) return;
      showCustomNotification(context, 'Картинка слишком большая (макс 8 МБ)');
      return;
    }
    if (!mounted) return;
    setState(() => _avatar = file);
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final chat = await chats.createGroupChat(
        api,
        title: title,
        userIds: _selected.map((c) => c.id).toList(),
      );
      if (!mounted) return;
      if (chat == null) {
        showCustomNotification(context, 'Не удалось создать группу');
        setState(() => _creating = false);
        return;
      }

      if (_avatar != null) {
        final url = await chats.requestChatPhotoUploadUrl(api);
        if (url != null) {
          final bytes = await compressAvatar(await _avatar!.readAsBytes());
          if (bytes == null) {
            if (mounted) {
              showCustomNotification(context, 'Не удалось обработать аватарку');
            }
          } else {
            final token = await fileUploader.uploadImage(
              Uri.parse(url),
              bytes,
              filename: 'avatar.jpg',
            );
            if (token != null) {
              await chats.setChatPhoto(api, chatId: chat.id, photoToken: token);
            } else if (mounted) {
              showCustomNotification(context, 'Не удалось загрузить аватарку');
            }
          }
        }
      }

      if (!mounted) return;
      navigator.pop();
      navigator.push(
        SwipeRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            name: chat.title ?? title,
            imageUrl: chat.iconUrl ?? '',
            chatType: chat.type,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, 'Ошибка: $e');
        setState(() => _creating = false);
      }
    }
  }

  String _statusText(CachedContact c) => c.isBot ? 'Бот' : 'Был(-а) недавно';

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              final offset = child.key == const ValueKey(_Step.pickParticipants)
                  ? Offset(-0.05, 0)
                  : Offset(0.05, 0);
              return SlideTransition(
                position: Tween<Offset>(
                  begin: offset,
                  end: Offset.zero,
                ).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: _step == _Step.pickParticipants
                ? KeyedSubtree(
                    key: const ValueKey(_Step.pickParticipants),
                    child: _buildPickerStep(),
                  )
                : KeyedSubtree(
                    key: const ValueKey(_Step.groupDetails),
                    child: _buildDetailsStep(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerStep() {
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _all
        : _all
              .where(
                (c) => displayName(
                  c.firstName,
                  c.lastName,
                ).toLowerCase().contains(query),
              )
              .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Выберите участников',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _selected)
                  _SelectedChip(
                    contact: c,
                    label: displayName(c.firstName, c.lastName),
                    onRemove: () => _toggle(c),
                    cs: cs,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
        Flexible(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final picked = _isSelected(c.id);
                    final dim = c.isBot;
                    return InkWell(
                      onTap: () => _toggle(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            KometAvatar(
                              name: c.firstName,
                              size: 40,
                              imageUrl: c.baseUrl,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName(c.firstName, c.lastName),
                                    style: TextStyle(
                                      color: dim
                                          ? cs.onSurface.withValues(alpha: 0.5)
                                          : cs.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _statusText(c),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (picked)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Symbols.check,
                                  color: cs.onPrimary,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: 'Отменить',
                  filled: false,
                  onTap: () => Navigator.pop(context),
                  cs: cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetButton(
                  label: 'Далее',
                  filled: true,
                  onTap: () => setState(() => _step = _Step.groupDetails),
                  cs: cs,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    final cs = Theme.of(context).colorScheme;
    final canCreate = _title.text.trim().isNotEmpty && !_creating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: _creating
                    ? null
                    : () => setState(() => _step = _Step.pickParticipants),
                icon: Icon(Symbols.arrow_back, color: cs.onSurfaceVariant),
              ),
              Expanded(
                child: Text(
                  'Создать группу',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _creating ? null : () => Navigator.pop(context),
                icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _avatar != null
                      ? Image.file(_avatar!, fit: BoxFit.cover)
                      : Icon(
                          Symbols.add_a_photo,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _title,
                  onChanged: (_) => setState(() {}),
                  enabled: !_creating,
                  style: TextStyle(color: cs.onSurface, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Название группы',
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _SheetButton(
                  label: 'Отменить',
                  filled: false,
                  onTap: _creating ? null : () => Navigator.pop(context),
                  cs: cs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SheetButton(
                  label: _creating ? 'Создаю...' : 'Создать',
                  filled: true,
                  onTap: canCreate ? _create : null,
                  cs: cs,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final CachedContact contact;
  final String label;
  final VoidCallback onRemove;
  final ColorScheme cs;
  const _SelectedChip({
    required this.contact,
    required this.label,
    required this.onRemove,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KometAvatar(
              name: contact.firstName,
              size: 24,
              imageUrl: contact.baseUrl,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                style: TextStyle(color: cs.onSurface, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final ColorScheme cs;
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (disabled ? cs.primary.withValues(alpha: 0.4) : cs.primary)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled
                ? cs.onPrimary
                : (disabled
                      ? cs.onSurface.withValues(alpha: 0.4)
                      : cs.onSurface),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
