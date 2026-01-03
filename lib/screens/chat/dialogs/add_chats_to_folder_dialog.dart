import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/chat_folder.dart';
import 'package:gwid/widgets/contact_name_widget.dart';

class AddChatsToFolderDialog extends StatefulWidget {
  final ChatFolder folder;
  final List<Chat> availableChats;
  final Map<int, Contact> contacts;
  final Function(List<Chat>) onAddChats;

  const AddChatsToFolderDialog({
    super.key,
    required this.folder,
    required this.availableChats,
    required this.contacts,
    required this.onAddChats,
  });

  @override
  State<AddChatsToFolderDialog> createState() => _AddChatsToFolderDialogState();
}

class _AddChatsToFolderDialogState extends State<AddChatsToFolderDialog> {
  late final Set<int> _selectedChatIds;

  @override
  void initState() {
    super.initState();
    final currentInclude = widget.folder.include ?? [];
    _selectedChatIds = currentInclude.toSet();
  }

  bool _isGroupChat(Chat chat) {
    return chat.type == 'CHAT' || chat.participantIds.length > 2;
  }

  bool _isSavedMessages(Chat chat) {
    return chat.id == 0;
  }

  void _toggleChatSelection(Chat chat) {
    setState(() {
      if (_selectedChatIds.contains(chat.id)) {
        _selectedChatIds.remove(chat.id);
      } else {
        _selectedChatIds.add(chat.id);
      }
    });
  }

  void _addSelectedChats() {
    final selectedChats = widget.availableChats
        .where((chat) => _selectedChatIds.contains(chat.id))
        .toList();

    Navigator.of(context).pop();
    widget.onAddChats(selectedChats);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colors.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.folder.emoji != null) ...[
                      Text(
                        widget.folder.emoji!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        'Выбрать чаты для "${widget.folder.title}"',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: colors.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.availableChats.length,
                  itemBuilder: (context, index) {
                    final chat = widget.availableChats[index];
                    final isGroupChat = _isGroupChat(chat);
                    final isChannel = chat.type == 'CHANNEL';
                    final isSavedMessages = _isSavedMessages(chat);

                    Contact? contact;
                    String title;
                    String? avatarUrl;
                    IconData leadingIcon;

                    if (isSavedMessages) {
                      contact = widget.contacts[chat.ownerId];
                      title = "Избранное";
                      leadingIcon = Icons.bookmark;
                      avatarUrl = null;
                    } else if (isChannel) {
                      contact = null;
                      title = chat.title ?? "Канал";
                      leadingIcon = Icons.campaign;
                      avatarUrl = chat.baseIconUrl;
                    } else if (isGroupChat) {
                      contact = null;
                      title = chat.title?.isNotEmpty == true
                          ? chat.title!
                          : "Группа";
                      leadingIcon = Icons.group;
                      avatarUrl = chat.baseIconUrl;
                    } else {
                      final myId = chat.ownerId;
                      final otherParticipantId = chat.participantIds.firstWhere(
                        (id) => id != myId,
                        orElse: () => myId,
                      );
                      contact = widget.contacts[otherParticipantId];

                      if (contact != null) {
                        title = getContactDisplayName(
                          contactId: contact.id,
                          originalName: contact.name,
                          originalFirstName: contact.firstName,
                          originalLastName: contact.lastName,
                        );
                      } else if (chat.title?.isNotEmpty == true) {
                        title = chat.title!;
                      } else {
                        title = "ID $otherParticipantId";
                      }
                      avatarUrl = contact?.photoBaseUrl;
                      leadingIcon = Icons.person;
                    }

                    final isSelected = _selectedChatIds.contains(chat.id);

                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: colors.primaryContainer,
                            backgroundImage: avatarUrl != null
                                ? CachedNetworkImageProvider(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? (isSavedMessages || isGroupChat || isChannel)
                                      ? Icon(
                                          leadingIcon,
                                          color: colors.onPrimaryContainer,
                                        )
                                      : Text(
                                          title.isNotEmpty
                                              ? title[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: colors.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                : null,
                          ),
                        ],
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: title == 'Данные загружаются...'
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: isGroupChat && chat.participantIds.length > 2
                          ? Text(
                              '${chat.participantIds.length} участников',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleChatSelection(chat),
                      ),
                      onTap: () => _toggleChatSelection(chat),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedChatIds.isEmpty
                            ? 'Выберите чаты'
                            : 'Выбрано: ${_selectedChatIds.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _addSelectedChats,
                      child: const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
