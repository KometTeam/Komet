import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/chats.dart';
import '../../../backend/modules/contacts.dart';
import '../../../core/storage/token_storage.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import 'chat_screen.dart';

Future<void> showCreateGroupFlow(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final selected = await showModalBottomSheet<List<CachedContact>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ParticipantsPickerSheet(),
  );
  if (selected == null) return;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _GroupDetailsSheet(participants: selected),
  );
}

class _ParticipantsPickerSheet extends StatefulWidget {
  const _ParticipantsPickerSheet();

  @override
  State<_ParticipantsPickerSheet> createState() => _ParticipantsPickerSheetState();
}

class _ParticipantsPickerSheetState extends State<_ParticipantsPickerSheet> {
  final TextEditingController _search = TextEditingController();
  List<CachedContact> _all = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final myId = await TokenStorage.getActiveAccountId();
      if (myId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final list = await ContactsModule.getContacts(myId);
      list.removeWhere((c) => c.id == myId);
      list.sort((a, b) => _displayName(a).toLowerCase().compareTo(_displayName(b).toLowerCase()));
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayName(CachedContact c) {
    final last = c.lastName ?? '';
    return last.isEmpty ? c.firstName : '${c.firstName} $last';
  }

  String _statusText(CachedContact c) {
    if (c.isBot) return 'Бот';
    return 'Был(-а) недавно';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _all
        : _all.where((c) => _displayName(c).toLowerCase().contains(query)).toList();
    final selected = _all.where((c) => _selectedIds.contains(c.id)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
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
              if (selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in selected)
                        _SelectedChip(
                          contact: c,
                          label: _displayName(c),
                          onRemove: () => setState(() => _selectedIds.remove(c.id)),
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
                    prefixIcon: Icon(Symbols.search, color: cs.onSurfaceVariant, size: 20),
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
                          final picked = _selectedIds.contains(c.id);
                          final dim = c.isBot;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (picked) {
                                  _selectedIds.remove(c.id);
                                } else {
                                  _selectedIds.add(c.id);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  _Avatar(contact: c, size: 40, cs: cs),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _displayName(c),
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
                                            color: cs.onSurfaceVariant.withValues(alpha: 0.8),
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
                                      child: Icon(Symbols.check, color: cs.onPrimary, size: 16),
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
                        onTap: () {
                          final picked = _all
                              .where((c) => _selectedIds.contains(c.id))
                              .toList();
                          Navigator.pop(context, picked);
                        },
                        cs: cs,
                      ),
                    ),
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

class _GroupDetailsSheet extends StatefulWidget {
  final List<CachedContact> participants;
  const _GroupDetailsSheet({required this.participants});

  @override
  State<_GroupDetailsSheet> createState() => _GroupDetailsSheetState();
}

class _GroupDetailsSheetState extends State<_GroupDetailsSheet> {
  final TextEditingController _title = TextEditingController();
  File? _avatar;
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_creating) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    setState(() => _avatar = File(path));
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final chat = await ChatsModule.createGroupChat(
        api,
        title: title,
        userIds: widget.participants.map((c) => c.id).toList(),
      );
      if (!mounted) return;
      if (chat == null) {
        showCustomNotification(context, 'Не удалось создать группу');
        setState(() => _creating = false);
        return;
      }

      if (_avatar != null) {
        final url = await ChatsModule.requestChatPhotoUploadUrl(api);
        if (url != null) {
          final bytes = await _avatar!.readAsBytes();
          final token = await fileUploader.uploadImage(Uri.parse(url), bytes);
          if (token != null) {
            await ChatsModule.setChatPhoto(api, chatId: chat.id, photoToken: token);
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final canCreate = _title.text.trim().isNotEmpty && !_creating;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _creating ? null : () => Navigator.pop(context),
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
                    onPressed: _creating
                        ? null
                        : () {
                            Navigator.pop(context);
                            Navigator.maybePop(context);
                          },
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
                          : Icon(Symbols.add_a_photo, color: cs.onSurfaceVariant, size: 20),
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
                        hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
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
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final CachedContact contact;
  final double size;
  final ColorScheme cs;
  const _Avatar({required this.contact, required this.size, required this.cs});

  @override
  Widget build(BuildContext context) {
    final url = contact.baseUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _initials(cs, size),
          errorWidget: (_, _, _) => _initials(cs, size),
        ),
      );
    }
    return _initials(cs, size);
  }

  Widget _initials(ColorScheme cs, double size) {
    final initial = contact.firstName.isNotEmpty
        ? contact.firstName[0].toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
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
            _Avatar(contact: contact, size: 24, cs: cs),
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
              ? (disabled
                  ? cs.primary.withValues(alpha: 0.4)
                  : cs.primary)
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
