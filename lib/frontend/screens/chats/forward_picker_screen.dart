import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/messages.dart' show ContactCache;

class ForwardTarget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  const ForwardTarget({
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });
}

Future<ForwardTarget?> showForwardPicker({
  required BuildContext context,
  required int accountId,
  int messageCount = 1,
}) {
  return showModalBottomSheet<ForwardTarget>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ForwardPickerSheet(accountId: accountId, messageCount: messageCount),
  );
}

class _ForwardPickerSheet extends StatefulWidget {
  final int accountId;
  final int messageCount;

  const _ForwardPickerSheet({
    required this.accountId,
    required this.messageCount,
  });

  @override
  State<_ForwardPickerSheet> createState() => _ForwardPickerSheetState();
}

class _ForwardPickerSheetState extends State<_ForwardPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ForwardTarget> _all = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final chats = await ChatsModule.getChats(widget.accountId);
    final targets = <ForwardTarget>[];
    for (final chat in chats) {
      if (chat.type == 'CHANNEL' && chat.owner != widget.accountId) continue;
      targets.add(_targetFor(chat));
    }
    targets.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _all = targets;
      _loading = false;
    });
  }

  ForwardTarget _targetFor(CachedChat chat) {
    if (chat.id == 0) {
      return ForwardTarget(
        chatId: 0,
        name: 'Избранное',
        imageUrl: '',
        chatType: chat.type,
      );
    }
    if (chat.type == 'DIALOG') {
      int otherId = widget.accountId;
      for (final entry in chat.participants.entries) {
        if (entry.key != widget.accountId) {
          otherId = entry.key;
          break;
        }
      }
      return ForwardTarget(
        chatId: chat.id,
        name: ContactCache.get(otherId) ?? chat.title ?? 'Пользователь',
        imageUrl: ContactCache.getAvatar(otherId) ?? chat.iconUrl ?? '',
        chatType: chat.type,
      );
    }
    return ForwardTarget(
      chatId: chat.id,
      name: chat.title ?? 'Чат',
      imageUrl: chat.iconUrl ?? '',
      chatType: chat.type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _query.isEmpty
        ? _all
        : _all.where((t) => t.name.toLowerCase().contains(_query)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        widget.messageCount > 1
                            ? 'Переслать (${widget.messageCount})'
                            : 'Переслать',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск чата',
                      prefixIcon: const Icon(Symbols.search),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Ничего не найдено',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final t = filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: cs.surfaceContainerHighest,
                                backgroundImage: t.imageUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(
                                        t.imageUrl,
                                        maxWidth: 132,
                                        maxHeight: 132,
                                      )
                                    : null,
                                child: t.imageUrl.isEmpty
                                    ? Icon(
                                        t.chatId == 0
                                            ? Symbols.bookmark
                                            : Symbols.person,
                                        color: cs.onSurfaceVariant,
                                      )
                                    : null,
                              ),
                              title: Text(
                                t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).pop(t),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
