import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/widgets/chat_message_bubble.dart';
import 'package:gwid/chat_screen.dart';

class ControlMessageChip extends StatelessWidget {
  final Message message;
  final Map<int, Contact> contacts;
  final int myId;

  const ControlMessageChip({
    super.key,
    required this.message,
    required this.contacts,
    required this.myId,
  });

  String _formatControlMessage() {
    final controlAttach = message.attaches.firstWhere(
      (a) => a['_type'] == 'CONTROL',
    );

    final eventType = controlAttach['event'];
    final senderName = contacts[message.senderId]?.name ?? 'Неизвестный';
    final isMe = message.senderId == myId;
    final senderDisplayName = isMe ? 'Вы' : senderName;

    String _formatUserList(List<int> userIds) {
      if (userIds.isEmpty) {
        return '';
      }
      final userNames = userIds
          .map((id) {
            if (id == myId) {
              return 'Вы';
            }
            return contacts[id]?.name ?? 'участник с ID $id';
          })
          .where((name) => name.isNotEmpty)
          .join(', ');
      return userNames;
    }

    switch (eventType) {
      case 'new':
        final title = controlAttach['title'] ?? 'Новая группа';
        return '$senderDisplayName создал(а) группу "$title"';

      case 'add':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return 'К чату присоединились новые участники';
        }
        final userNames = _formatUserList(userIds);
        if (userNames.isEmpty) {
          return 'К чату присоединились новые участники';
        }
        return '$senderDisplayName добавил(а) в чат: $userNames';

      case 'remove':
      case 'kick':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName удалил(а) участников из чата';
        }
        final userNames = _formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName удалил(а) участников из чата';
        }

        if (userIds.contains(myId)) {
          return 'Вы были удалены из чата';
        }
        return '$senderDisplayName удалил(а) из чата: $userNames';

      case 'leave':
        if (isMe) {
          return 'Вы покинули группу';
        }
        return '$senderName покинул(а) группу';

      case 'title':
        final newTitle = controlAttach['title'] ?? '';
        if (newTitle.isEmpty) {
          return '$senderDisplayName изменил(а) название группы';
        }
        return '$senderDisplayName изменил(а) название группы на "$newTitle"';

      case 'avatar':
      case 'photo':
        return '$senderDisplayName изменил(а) фото группы';

      case 'description':
        return '$senderDisplayName изменил(а) описание группы';

      case 'admin':
      case 'promote':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName назначил(а) администраторов';
        }
        final userNames = _formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName назначил(а) администраторов';
        }

        if (userIds.contains(myId) && userIds.length == 1) {
          return 'Вас назначили администратором';
        }
        return '$senderDisplayName назначил(а) администраторов: $userNames';

      case 'demote':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName снял(а) администраторов';
        }
        final userNames = _formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName снял(а) администраторов';
        }

        if (userIds.contains(myId) && userIds.length == 1) {
          return 'С вас сняли права администратора';
        }
        return '$senderDisplayName снял(а) права администратора с: $userNames';

      case 'ban':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName заблокировал(а) участников';
        }
        final userNames = _formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName заблокировал(а) участников';
        }

        if (userIds.contains(myId)) {
          return 'Вы были заблокированы в чате';
        }
        return '$senderDisplayName заблокировал(а): $userNames';

      case 'unban':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName разблокировал(а) участников';
        }
        final userNames = _formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName разблокировал(а) участников';
        }
        return '$senderDisplayName разблокировал(а): $userNames';

      case 'join':
        if (isMe) {
          return 'Вы присоединились к группе';
        }
        return '$senderName присоединился(ась) к группе';

      case 'pin':
        final pinnedMessage = controlAttach['pinnedMessage'];
        if (pinnedMessage != null && pinnedMessage is Map<String, dynamic>) {
          final pinnedText = pinnedMessage['text'] as String?;
          if (pinnedText != null && pinnedText.isNotEmpty) {
            return '$senderDisplayName закрепил(а) сообщение: "$pinnedText"';
          }
        }
        return '$senderDisplayName закрепил(а) сообщение';

      default:
        final eventTypeStr = eventType?.toString() ?? 'неизвестное';
        return 'Событие: $eventTypeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _formatControlMessage(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class MessagePreviewDialog {
  static String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (now.day == dt.day && now.month == dt.month && now.year == dt.year) {
      return DateFormat('HH:mm', 'ru').format(dt);
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.day == yesterday.day &&
          dt.month == yesterday.month &&
          dt.year == yesterday.year) {
        return 'Вчера';
      } else {
        return DateFormat('d MMM', 'ru').format(dt);
      }
    }
  }

  static bool _isSavedMessages(Chat chat) {
    return chat.id == 0;
  }

  static bool _isGroupChat(Chat chat) {
    return chat.type == 'CHAT' || chat.participantIds.length > 2;
  }

  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static bool _isMessageGrouped(
    Message currentMessage,
    Message? previousMessage,
  ) {
    if (previousMessage == null) return false;

    final currentTime = DateTime.fromMillisecondsSinceEpoch(
      currentMessage.time,
    );
    final previousTime = DateTime.fromMillisecondsSinceEpoch(
      previousMessage.time,
    );

    final timeDifference = currentTime.difference(previousTime).inMinutes;

    return currentMessage.senderId == previousMessage.senderId &&
        timeDifference <= 5;
  }

  static String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Сегодня';
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      if (_isSameDay(date, yesterday)) {
        return 'Вчера';
      } else {
        return DateFormat('d MMM yyyy', 'ru').format(date);
      }
    }
  }

  static String _getChatTitle(Chat chat, Map<int, Contact> contacts) {
    final bool isSavedMessages = _isSavedMessages(chat);
    final bool isGroupChat = _isGroupChat(chat);
    final bool isChannel = chat.type == 'CHANNEL';

    if (isSavedMessages) {
      return "Избранное";
    } else if (isChannel) {
      return chat.title ?? "Канал";
    } else if (isGroupChat) {
      return chat.title?.isNotEmpty == true ? chat.title! : "Группа";
    } else {
      final myId = chat.ownerId;
      final otherParticipantId = chat.participantIds.firstWhere(
        (id) => id != myId,
        orElse: () => myId,
      );
      final contact = contacts[otherParticipantId];
      return contact?.name ?? "Неизвестный чат";
    }
  }

  static Future<void> show(
    BuildContext context,
    Chat chat,
    Map<int, Contact> contacts,
    Profile? myProfile,
    VoidCallback? onClose,
    Widget Function(BuildContext)? menuBuilder,
  ) async {
    final colors = Theme.of(context).colorScheme;

    List<Message> messages = [];
    bool isLoading = true;

    try {
      messages = await ApiService.instance.getMessageHistory(
        chat.id,
        force: false,
      );
      if (messages.length > 10) {
        messages = messages.sublist(messages.length - 10);
      }
    } catch (e) {
      print('Ошибка загрузки сообщений для предпросмотра: $e');
    } finally {
      isLoading = false;
    }

    final Set<int> senderIds = messages.map((m) => m.senderId).toSet();
    senderIds.remove(0);

    final Set<int> forwardedSenderIds = {};
    for (final message in messages) {
      if (message.isForwarded && message.link != null) {
        final link = message.link;
        if (link is Map<String, dynamic>) {
          final chatName = link['chatName'] as String?;
          if (chatName == null) {
            final forwardedMessage = link['message'] as Map<String, dynamic>?;
            final originalSenderId = forwardedMessage?['sender'] as int?;
            if (originalSenderId != null) {
              forwardedSenderIds.add(originalSenderId);
            }
          }
        }
      }
    }

    final allIdsToFetch = {
      ...senderIds,
      ...forwardedSenderIds,
    }.where((id) => !contacts.containsKey(id)).toList();

    if (allIdsToFetch.isNotEmpty) {
      try {
        final newContacts = await ApiService.instance.fetchContactsByIds(
          allIdsToFetch,
        );
        for (final contact in newContacts) {
          contacts[contact.id] = contact;
        }
      } catch (e) {
        print('Ошибка загрузки контактов для предпросмотра: $e');
      }
    }

    final chatTitle = _getChatTitle(chat, contacts);
    final bool isGroupChat = _isGroupChat(chat);
    final bool isChannel = chat.type == 'CHANNEL';
    final myId = myProfile?.id ?? chat.ownerId;

    if (!context.mounted) return;

    List<ChatItem> chatItems = [];
    for (int i = 0; i < messages.length; i++) {
      final currentMessage = messages[i];
      final previousMessage = (i > 0) ? messages[i - 1] : null;

      final currentDate = DateTime.fromMillisecondsSinceEpoch(
        currentMessage.time,
      ).toLocal();
      final previousDate = previousMessage != null
          ? DateTime.fromMillisecondsSinceEpoch(previousMessage.time).toLocal()
          : null;

      if (previousMessage == null || !_isSameDay(currentDate, previousDate!)) {
        chatItems.add(DateSeparatorItem(currentDate));
      }

      final isGrouped = _isMessageGrouped(currentMessage, previousMessage);
      final isFirstInGroup = previousMessage == null || !isGrouped;
      final isLastInGroup =
          i == messages.length - 1 ||
          !_isMessageGrouped(messages[i + 1], currentMessage);

      chatItems.add(
        MessageItem(
          currentMessage,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          isGrouped: isGrouped,
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
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
                        Expanded(
                          child: Text(
                            chatTitle,
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
                            onClose?.call();
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : messages.isEmpty
                        ? Center(
                            child: Text(
                              'Нет сообщений',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            itemCount: chatItems.length,
                            itemBuilder: (context, index) {
                              final mappedIndex = chatItems.length - 1 - index;
                              final item = chatItems[mappedIndex];

                              if (item is DateSeparatorItem) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 16,
                                  ),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDateSeparator(item.date),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              if (item is MessageItem) {
                                final message = item.message;
                                final isControlMessage = message.attaches.any(
                                  (a) => a['_type'] == 'CONTROL',
                                );
                                if (isControlMessage) {
                                  return ControlMessageChip(
                                    message: message,
                                    contacts: contacts,
                                    myId: myId,
                                  );
                                }
                                final isMe = message.senderId == myId;
                                final senderContact =
                                    contacts[message.senderId];
                                final senderName = isMe
                                    ? 'Вы'
                                    : (senderContact?.name ?? 'Неизвестный');

                                String? forwardedFrom;
                                String? forwardedFromAvatarUrl;
                                if (message.isForwarded) {
                                  final link = message.link;
                                  if (link is Map<String, dynamic>) {
                                    final chatName =
                                        link['chatName'] as String?;
                                    final chatIconUrl =
                                        link['chatIconUrl'] as String?;

                                    if (chatName != null) {
                                      forwardedFrom = chatName;
                                      forwardedFromAvatarUrl = chatIconUrl;
                                    } else {
                                      final forwardedMessage =
                                          link['message']
                                              as Map<String, dynamic>?;
                                      final originalSenderId =
                                          forwardedMessage?['sender'] as int?;
                                      if (originalSenderId != null) {
                                        final originalSenderContact =
                                            contacts[originalSenderId];
                                        forwardedFrom =
                                            originalSenderContact?.name ??
                                            'Участник $originalSenderId';
                                        forwardedFromAvatarUrl =
                                            originalSenderContact?.photoBaseUrl;
                                      }
                                    }
                                  }
                                }

                                return ChatMessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  readStatus: null,
                                  deferImageLoading: true,
                                  myUserId: myId,
                                  chatId: chat.id,
                                  onReply: null,
                                  onEdit: null,
                                  canEditMessage: null,
                                  onDeleteForMe: null,
                                  onDeleteForAll: null,
                                  onReaction: null,
                                  onRemoveReaction: null,
                                  isGroupChat: isGroupChat,
                                  isChannel: isChannel,
                                  senderName: senderName,
                                  forwardedFrom: forwardedFrom,
                                  forwardedFromAvatarUrl:
                                      forwardedFromAvatarUrl,
                                  contactDetailsCache: contacts,
                                  onReplyTap: null,
                                  useAutoReplyColor: false,
                                  customReplyColor: null,
                                  isFirstInGroup: item.isFirstInGroup,
                                  isLastInGroup: item.isLastInGroup,
                                  isGrouped: item.isGrouped,
                                  avatarVerticalOffset: -8.0,
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                  ),
                  if (menuBuilder != null) ...[
                    Divider(height: 1, color: colors.outline.withOpacity(0.2)),
                    menuBuilder(context),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
