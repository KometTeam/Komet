import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/chat_folder.dart';

class ChatsListPage extends StatefulWidget {
  final ChatFolder? folder;
  final List<Chat> allChats;
  final Map<int, Contact> contacts;
  final String searchQuery;
  final Widget Function(Chat, int, ChatFolder?) buildChatListItem;
  final bool Function(Chat) isSavedMessages;
  final bool Function(Chat, ChatFolder)? chatBelongsToFolder;

  const ChatsListPage({
    super.key,
    required this.folder,
    required this.allChats,
    required this.contacts,
    required this.searchQuery,
    required this.buildChatListItem,
    required this.isSavedMessages,
    this.chatBelongsToFolder,
  });

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    List<Chat> chatsForFolder = widget.allChats;

    if (widget.folder != null && widget.chatBelongsToFolder != null) {
      chatsForFolder = widget.allChats
          .where((chat) => widget.chatBelongsToFolder!(chat, widget.folder!))
          .toList();
    }

    // Сортировка по времени последнего сообщения (новые сверху)
    chatsForFolder.sort((a, b) {
      return b.lastMessage.time.compareTo(a.lastMessage.time);
    });

    if (widget.searchQuery.isNotEmpty) {
      chatsForFolder = chatsForFolder.where((chat) {
        final isSavedMessages = widget.isSavedMessages(chat);
        if (isSavedMessages) {
          return "избранное".contains(widget.searchQuery.toLowerCase());
        }
        final otherParticipantId = chat.participantIds.firstWhere(
          (id) => id != chat.ownerId,
          orElse: () => 0,
        );
        final contactName =
            widget.contacts[otherParticipantId]?.name.toLowerCase() ?? '';
        return contactName.contains(widget.searchQuery.toLowerCase());
      }).toList();
    }

    if (chatsForFolder.isEmpty) {
      return Center(
        child: Text(
          widget.folder == null ? 'Нет чатов' : 'В этой папке пока нет чатов',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: ListView.builder(
        itemCount: chatsForFolder.length,
        itemExtent: 72.0,
        cacheExtent: 500.0,
        itemBuilder: (context, index) {
          return widget.buildChatListItem(
            chatsForFolder[index],
            index,
            widget.folder,
          );
        },
      ),
    );
  }
}
