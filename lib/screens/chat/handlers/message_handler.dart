import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/models/chat_folder.dart';
import 'package:gwid/services/notification_service.dart';
import 'package:gwid/services/message_queue_service.dart';
import 'package:gwid/services/chat_cache_service.dart';
import 'package:gwid/app_sizes.dart';

class MessageHandler {
  final void Function(VoidCallback) setState;
  final BuildContext Function() getContext;
  final bool Function() getMounted;
  final List<Chat> allChats;
  final Map<int, Contact> contacts;
  final List<ChatFolder> folders;
  final Set<int> onlineChats;
  final Set<int> typingChats;
  final Map<int, Timer> typingDecayTimers;
  final Function(int) setTypingForChat;
  final Function() filterChats;
  final Function() refreshChats;
  final Function(List<dynamic>?) sortFoldersByOrder;
  final Function() updateFolderTabController;
  final TabController folderTabController;
  final Function(Profile) setMyProfile;
  final Function(String) showTokenExpiredDialog;
  final bool Function(Chat) isSavedMessages;

  // Дедупликация сообщений - храним ID последних обработанных сообщений
  static final Set<String> _processedMessageIds = {};
  static const int _maxProcessedMessages = 100;

  MessageHandler({
    required this.setState,
    required this.getContext,
    required this.getMounted,
    required this.allChats,
    required this.contacts,
    required this.folders,
    required this.onlineChats,
    required this.typingChats,
    required this.typingDecayTimers,
    required this.setTypingForChat,
    required this.filterChats,
    required this.refreshChats,
    required this.sortFoldersByOrder,
    required this.updateFolderTabController,
    required this.folderTabController,
    required this.setMyProfile,
    required this.showTokenExpiredDialog,
    required this.isSavedMessages,
  });

  /// Получить текстовое представление вложения для уведомления
  String _getAttachmentPreviewText(Message message) {
    if (message.attaches.isEmpty) {
      return message.text;
    }

    // Если есть текст - возвращаем его
    if (message.text.isNotEmpty) {
      return message.text;
    }

    // Анализируем вложения
    for (final attach in message.attaches) {
      final type = attach['_type'] ?? attach['type'];

      switch (type) {
        case 'STICKER':
          return '🎭 Стикер';
        case 'PHOTO':
        case 'IMAGE':
          final count = message.attaches
              .where(
                (a) =>
                    (a['_type'] ?? a['type']) == 'PHOTO' ||
                    (a['_type'] ?? a['type']) == 'IMAGE',
              )
              .length;
          return count > 1 ? '🖼 Фото ($count)' : '🖼 Фото';
        case 'VIDEO':
          final videoType = attach['videoType'] as int?;
          if (videoType == 1) {
            // Кружочек (видеосообщение)
            return '📹 Видеосообщение';
          }
          final count = message.attaches
              .where((a) => (a['_type'] ?? a['type']) == 'VIDEO')
              .length;
          return count > 1 ? '🎬 Видео ($count)' : '🎬 Видео';
        case 'VOICE':
          return '🎤 Голосовое сообщение';
        case 'AUDIO':
          final title = attach['title'] as String? ?? attach['name'] as String?;
          if (title != null && title.isNotEmpty) {
            return '🎵 $title';
          }
          return '🎵 Аудио';
        case 'FILE':
          final fileName = attach['name'] as String?;
          if (fileName != null && fileName.isNotEmpty) {
            return '📎 $fileName';
          }
          return '📎 Файл';
        case 'DOCUMENT':
          final docName = attach['name'] as String?;
          if (docName != null && docName.isNotEmpty) {
            return '📄 $docName';
          }
          return '📄 Документ';
        case 'GIF':
          return '🎞 GIF';
        case 'LOCATION':
        case 'GEO':
          return '📍 Местоположение';
        case 'CONTACT':
          final contactName =
              attach['name'] as String? ?? attach['firstName'] as String?;
          if (contactName != null && contactName.isNotEmpty) {
            return '👤 Контакт: $contactName';
          }
          return '👤 Контакт';
        case 'POLL':
          final question = attach['question'] as String?;
          if (question != null && question.isNotEmpty) {
            return '📊 $question';
          }
          return '📊 Опрос';
        case 'CALL':
        case 'call':
          final callType = attach['callType'] as String? ?? 'AUDIO';
          final hangupType = attach['hangupType'] as String? ?? '';
          if (hangupType == 'MISSED') {
            return callType == 'VIDEO'
                ? '📵 Пропущенный видеозвонок'
                : '📵 Пропущенный звонок';
          } else if (hangupType == 'CANCELED') {
            return callType == 'VIDEO'
                ? '📵 Видеозвонок отменён'
                : '📵 Звонок отменён';
          } else if (hangupType == 'REJECTED') {
            return callType == 'VIDEO'
                ? '📵 Видеозвонок отклонён'
                : '📵 Звонок отклонён';
          }
          return callType == 'VIDEO' ? '📹 Видеозвонок' : '📞 Звонок';
        case 'FORWARD':
          return 'Пересланное сообщение';
        case 'REPLY':
          return message.text.isNotEmpty ? message.text : 'Ответ';
      }
    }

    // Если тип не распознан - возвращаем generic
    return '📎 Вложение';
  }

  StreamSubscription? listen() {
    return ApiService.instance.messages.listen((message) {
      if (!getMounted()) return;

      if (message['type'] == 'invalid_token') {
        print(
          'Получено событие недействительного токена, перенаправляем на вход',
        );
        showTokenExpiredDialog(
          message['message'] ?? 'Токен авторизации недействителен',
        );
        return;
      }

      final opcode = message['opcode'];
      final cmd = message['cmd'];
      final payload = message['payload'];

      if (opcode == 19 && (cmd == 0x100 || cmd == 256) && payload != null) {
        _handleProfileUpdate(payload);
        return;
      }

      if (payload == null) return;
      final chatIdValue = payload['chatId'];
      final int? chatId = chatIdValue != null ? chatIdValue as int? : null;

      if (opcode == 272 ||
          opcode == 274 ||
          opcode == 48 ||
          opcode == 55 ||
          opcode == 135) {
      } else if (chatId == null) {
        return;
      }

      if (opcode == 129 && chatId != null) {
        setTypingForChat(chatId);
      } else if (opcode == 64 && (cmd == 0x100 || cmd == 256)) {
        // Успешная отправка сообщения с сервера - обновляем чат
        final messageData = payload['message'] as Map<String, dynamic>?;
        if (messageData != null) {
          final cid = messageData['cid'] as int?;

          // Удаляем из очереди по id или cid
          final queueService = MessageQueueService();
          if (cid != null) {
            final queueItem = queueService.findByCid(cid);
            if (queueItem != null) {
              queueService.removeFromQueue(queueItem.id);
            }
          }
        }

        // Обновляем чат с новым сообщением
        _handleNewChat(payload);
      } else if (opcode == 64) {
        // Локальное обновление чата (без cmd, это локальное сообщение)
        _handleNewChat(payload);
      } else if (opcode == 128 && chatId != null) {
        _handleNewMessage(chatId, payload);
      } else if (opcode == 67 && chatId != null) {
        _handleEditedMessage(chatId, payload);
      } else if (opcode == 66 && chatId != null) {
        _handleDeletedMessages(chatId, payload);
      } else if (opcode == 132) {
        _handlePresenceUpdate(payload);
      } else if (opcode == 36) {
        _handleBlockedContacts(payload);
      } else if (opcode == 48) {
        _handleGroupCreatedOrUpdated(payload);
      } else if (opcode == 89) {
        _handleJoinGroup(payload, cmd);
      } else if (opcode == 55) {
        _handleChatUpdate(payload, cmd);
      } else if (opcode == 135) {
        _handleChatRemoved(payload);
      } else if (opcode == 272) {
        _handleFoldersUpdate(payload);
      } else if (opcode == 274) {
        _handleFolderCreatedOrUpdated(payload, cmd);
      } else if (opcode == 276) {
        _handleFolderDeleted(payload, cmd);
      }
    });
  }

  void _handleProfileUpdate(Map<String, dynamic> payload) {
    final profileData = payload['profile'];
    if (profileData != null) {
      print('🔄 ChatsScreen: Получен профиль из opcode 19, обновляем UI');
      Future.microtask(() {
        final context = getContext();
        if (context.mounted) {
          setMyProfile(Profile.fromJson(profileData));
        }
      });
    }
  }

  void _handleNewChat(Map<String, dynamic> payload) {
    final chatId = payload['chatId'] as int?;
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    final messageJson = payload['message'] as Map<String, dynamic>?;

    // Если есть полный объект чата - используем его
    if (chatJson != null) {
      final newChat = Chat.fromJson(chatJson);
      ApiService.instance.updateChatInCacheFromJson(chatJson);

      final context = getContext();
      if (context.mounted) {
        setState(() {
          final existingIndex = allChats.indexWhere(
            (chat) => chat.id == newChat.id,
          );
          if (existingIndex != -1) {
            allChats[existingIndex] = newChat;
          } else {
            final savedIndex = allChats.indexWhere(isSavedMessages);
            final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
            allChats.insert(insertIndex, newChat);
          }
          filterChats();
        });
      }
    }
    // Если есть только сообщение и chatId - обновляем существующий чат
    else if (chatId != null && messageJson != null) {
      final newMessage = Message.fromJson(messageJson);
      final context = getContext();
      if (context.mounted) {
        setState(() {
          final chatIndex = allChats.indexWhere((chat) => chat.id == chatId);
          if (chatIndex != -1) {
            final oldChat = allChats[chatIndex];
            final updatedChat = oldChat.copyWith(lastMessage: newMessage);
            allChats.removeAt(chatIndex);
            _insertChatAtCorrectPosition(updatedChat);
            filterChats();
          }
        });
      }
    }
  }

  void _handleNewMessage(int chatId, Map<String, dynamic> payload) {
    if (allChats.isEmpty) {
      return;
    }

    final newMessage = Message.fromJson(payload['message']);

    if (newMessage.status == 'REMOVED') {
      ApiService.instance.clearCacheForChat(chatId);
      unawaited(
        ChatCacheService().removeMessageFromCache(chatId, newMessage.id),
      );
      return;
    }

    // Обработка контактов в сообщении
    for (final attach in newMessage.attaches) {
      if (attach['_type'] == 'CONTACT') {
        final contactIdValue = attach['contactId'];
        final int? contactId = contactIdValue is int
            ? contactIdValue
            : (contactIdValue is String ? int.tryParse(contactIdValue) : null);
        if (contactId != null) {
          // Проверяем, есть ли контакт в кэше перед запросом
          final cachedContact = ApiService.instance.getCachedContact(contactId);
          if (cachedContact == null) {
            // Запрашиваем данные контакта по ID только если его нет в кэше
            ApiService.instance.fetchContactsByIds([contactId]);
          }
        }
      }
    }

    // Дедупликация
    final messageId = newMessage.id;
    if (_processedMessageIds.contains(messageId)) return;

    _processedMessageIds.add(messageId);
    if (_processedMessageIds.length > _maxProcessedMessages) {
      _processedMessageIds.remove(_processedMessageIds.first);
    }

    ApiService.instance.clearCacheForChat(chatId);

    // Получаем myId из профиля
    int? myId;
    final lastPayload = ApiService.instance.lastChatsPayload;
    if (lastPayload != null) {
      final profileData = lastPayload['profile'] as Map<String, dynamic>?;
      final contactProfile = profileData?['contact'] as Map<String, dynamic>?;
      myId = contactProfile?['id'] as int?;
    }

    // Если myId не найден, пробуем получить из ApiService
    if (myId == null && ApiService.instance.userId != null) {
      myId = int.tryParse(ApiService.instance.userId!);
    }

    // Не показываем уведомление для своих сообщений
    bool shouldShowNotification = (myId == null || newMessage.senderId != myId);

    // Если мы в приложении и в этом чате - не показываем уведомление
    if (shouldShowNotification &&
        ApiService.instance.isAppInForeground &&
        ApiService.instance.currentActiveChatId == chatId) {
      shouldShowNotification = false;
    }

    final int chatIndex = allChats.indexWhere((chat) => chat.id == chatId);
    if (shouldShowNotification && chatIndex != -1) {
      final oldChat = allChats[chatIndex];
      // Проверяем как по myId, так и по ownerId чата
      if (newMessage.senderId == oldChat.ownerId ||
          (myId != null && newMessage.senderId == myId)) {
        shouldShowNotification = false;
      }
    }

    if (shouldShowNotification) {
      final contact = contacts[newMessage.senderId];
      final chatFromPayload = payload['chat'] as Map<String, dynamic>?;

      if (contact == null) {
        _loadAndShowNotification(
          chatId,
          newMessage,
          newMessage.senderId,
          chatFromPayload,
        );
      } else {
        _showNotificationWithContact(
          chatId,
          newMessage,
          contact,
          chatFromPayload,
        );
      }
    }

    if (chatIndex != -1) {
      final oldChat = allChats[chatIndex];

      // Определяем, наше ли это сообщение
      final isMyMessage =
          (myId != null && newMessage.senderId == myId) ||
          newMessage.senderId == oldChat.ownerId;

      final updatedChat = oldChat.copyWith(
        lastMessage: newMessage,
        newMessages: !isMyMessage
            ? oldChat.newMessages + 1
            : oldChat.newMessages,
      );

      setState(() {
        allChats.removeAt(chatIndex);
        _insertChatAtCorrectPosition(updatedChat);
        filterChats();
      });
    } else if (payload['chat'] is Map<String, dynamic>) {
      final chatJson = payload['chat'] as Map<String, dynamic>;
      final newChat = Chat.fromJson(chatJson);
      ApiService.instance.updateChatInCacheFromJson(chatJson);

      setState(() {
        final savedIndex = allChats.indexWhere(isSavedMessages);
        final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
        allChats.insert(insertIndex, newChat);
        filterChats();
      });
    } else {
      final lastPayload = ApiService.instance.lastChatsPayload;
      if (lastPayload != null) {
        final chats = lastPayload['chats'] as List<dynamic>?;
        if (chats != null) {
          Map<String, dynamic>? chatJson;
          for (final c in chats) {
            if (c is Map<String, dynamic> && c['id'] == chatId) {
              chatJson = c;
              break;
            }
          }
          if (chatJson != null) {
            final newChat = Chat.fromJson(chatJson);
            final updatedChat = newChat.copyWith(
              lastMessage: Message.fromJson(payload['message']),
              newMessages: newChat.newMessages + 1,
            );
            setState(() {
              allChats.add(updatedChat);
              _insertChatAtCorrectPosition(updatedChat);
              filterChats();
            });
          }
        }
      }
    }
  }

  void _handleEditedMessage(int chatId, Map<String, dynamic> payload) {
    final editedMessage = Message.fromJson(payload['message']);
    ApiService.instance.clearCacheForChat(chatId);

    final int chatIndex = allChats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      final oldChat = allChats[chatIndex];
      if (oldChat.lastMessage.id == editedMessage.id) {
        final updatedChat = oldChat.copyWith(lastMessage: editedMessage);
        setState(() {
          allChats.removeAt(chatIndex);
          _insertChatAtCorrectPosition(updatedChat);
          filterChats();
        });
      }
    }
  }

  void _handleDeletedMessages(int chatId, Map<String, dynamic> payload) {
    final deletedMessageIds = List<String>.from(payload['messageIds'] ?? []);
    ApiService.instance.clearCacheForChat(chatId);

    final int chatIndex = allChats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      final oldChat = allChats[chatIndex];
      if (deletedMessageIds.contains(oldChat.lastMessage.id)) {
        ApiService.instance.getChatsOnly(force: true).then((data) {
          final context = getContext();
          if (context.mounted) {
            final chats = data['chats'] as List<dynamic>;
            final filtered = chats
                .cast<Map<String, dynamic>>()
                .where((chat) => chat['id'] == chatId)
                .toList();
            final Map<String, dynamic>? updatedChatData = filtered.isNotEmpty
                ? filtered.first
                : null;
            if (updatedChatData != null) {
              final updatedChat = Chat.fromJson(updatedChatData);
              setState(() {
                allChats.removeAt(chatIndex);
                allChats.insert(0, updatedChat);
                filterChats();
              });
            }
          }
        });
      }
    }
  }

  void _handlePresenceUpdate(Map<String, dynamic> payload) {
    final bool isOnline = payload['online'] == true;
    final dynamic contactIdAny = payload['contactId'] ?? payload['userId'];

    if (contactIdAny != null) {
      final int? cid = contactIdAny is int
          ? contactIdAny
          : int.tryParse(contactIdAny.toString());
      if (cid != null) {
        final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final userPresence = {
          'seen': currentTime,
          'on': isOnline ? 'ON' : 'OFF',
        };
        ApiService.instance.updatePresenceData({cid.toString(): userPresence});

        for (final chat in allChats) {
          final otherId = chat.participantIds.firstWhere(
            (id) => id != chat.ownerId,
            orElse: () => chat.ownerId,
          );
          if (otherId == cid) {
            if (isOnline) {
              onlineChats.add(chat.id);
            } else {
              onlineChats.remove(chat.id);
            }
          }
        }
        final context = getContext();
        if (context.mounted) setState(() {});
        return;
      }
    }

    final dynamic cidAny = payload['chatId'];
    final int? chatIdFromPayload = cidAny is int
        ? cidAny
        : int.tryParse(cidAny?.toString() ?? '');
    if (chatIdFromPayload != null) {
      if (isOnline) {
        onlineChats.add(chatIdFromPayload);
      } else {
        onlineChats.remove(chatIdFromPayload);
      }
      final context = getContext();
      if (context.mounted) setState(() {});
    }
  }

  void _handleBlockedContacts(Map<String, dynamic> payload) {
    if (payload['contacts'] == null) return;
    final List<dynamic> blockedContactsJson = payload['contacts'] as List;
    final blockedContacts = blockedContactsJson
        .map((json) => Contact.fromJson(json))
        .toList();

    for (final blockedContact in blockedContacts) {
      contacts[blockedContact.id] = blockedContact;
      ApiService.instance.notifyContactUpdate(blockedContact);
    }

    final context = getContext();
    if (context.mounted) setState(() {});
  }

  void _handleGroupCreatedOrUpdated(Map<String, dynamic> payload) {
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    final chatsJson = payload['chats'] as List<dynamic>?;

    Map<String, dynamic>? effectiveChatJson = chatJson;
    if (effectiveChatJson == null &&
        chatsJson != null &&
        chatsJson.isNotEmpty) {
      final first = chatsJson.first;
      if (first is Map<String, dynamic>) {
        effectiveChatJson = first;
      }
    }

    if (effectiveChatJson != null) {
      final newChat = Chat.fromJson(effectiveChatJson);
      ApiService.instance.updateChatInCacheFromJson(effectiveChatJson);
      final context = getContext();
      if (context.mounted) {
        setState(() {
          final existingIndex = allChats.indexWhere(
            (chat) => chat.id == newChat.id,
          );
          if (existingIndex != -1) {
            allChats[existingIndex] = newChat;
          } else {
            final savedIndex = allChats.indexWhere(isSavedMessages);
            final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
            allChats.insert(insertIndex, newChat);
          }
        });
        filterChats();
      }
    } else {
      refreshChats();
    }
  }

  void _handleJoinGroup(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    if (chatJson != null) {
      final chatType = chatJson['type'] as String?;
      if (chatType == 'CHAT') {
        final newChat = Chat.fromJson(chatJson);
        ApiService.instance.updateChatInCacheFromJson(chatJson);
        final context = getContext();
        if (context.mounted) {
          setState(() {
            final existingIndex = allChats.indexWhere(
              (chat) => chat.id == newChat.id,
            );
            if (existingIndex != -1) {
              allChats[existingIndex] = newChat;
            } else {
              final savedIndex = allChats.indexWhere(isSavedMessages);
              final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
              allChats.insert(insertIndex, newChat);
            }
            filterChats();
          });
        }
      }
    }
  }

  void _handleChatUpdate(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    final chatJson = payload['chat'] as Map<String, dynamic>?;
    if (chatJson != null) {
      final updatedChat = Chat.fromJson(chatJson);
      ApiService.instance.updateChatInCacheFromJson(chatJson);
      final context = getContext();
      if (context.mounted) {
        setState(() {
          final existingIndex = allChats.indexWhere(
            (chat) => chat.id == updatedChat.id,
          );
          if (existingIndex != -1) {
            allChats[existingIndex] = updatedChat;
          } else {
            final savedIndex = allChats.indexWhere(isSavedMessages);
            final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
            allChats.insert(insertIndex, updatedChat);
          }
          filterChats();
        });
      }
    }
  }

  void _handleChatRemoved(Map<String, dynamic> payload) {
    if (payload['chat'] is! Map<String, dynamic>) return;
    final removedChat = payload['chat'] as Map<String, dynamic>;
    final int? removedChatId = removedChat['id'] as int?;
    final String? status = removedChat['status'] as String?;

    if (removedChatId != null && status == 'REMOVED') {
      final context = getContext();
      if (context.mounted) {
        setState(() {
          allChats.removeWhere((chat) => chat.id == removedChatId);
        });
      }
    }
  }

  void _handleFoldersUpdate(Map<String, dynamic> payload) {
    if (payload['folders'] == null && payload['foldersOrder'] == null) {
      refreshChats();
      return;
    }

    try {
      final foldersJson = payload['folders'] as List<dynamic>?;
      if (foldersJson != null) {
        final newFolders = foldersJson.map((json) {
          final jsonMap = json is Map<String, dynamic>
              ? json
              : Map<String, dynamic>.from(json as Map);
          return ChatFolder.fromJson(jsonMap);
        }).toList();

        final context = getContext();
        if (context.mounted) {
          setState(() {
            folders.clear();
            folders.addAll(newFolders);
            final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
            sortFoldersByOrder(foldersOrder);
          });
          updateFolderTabController();
          filterChats();
        }
      }
    } catch (e) {
      print('Ошибка обработки папок из opcode 272: $e');
    }
  }

  void _handleFolderCreatedOrUpdated(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    try {
      final folderJson = payload['folder'] as Map<String, dynamic>?;
      if (folderJson != null) {
        final updatedFolder = ChatFolder.fromJson(folderJson);
        final folderId = updatedFolder.id;

        final context = getContext();
        if (context.mounted) {
          final existingIndex = folders.indexWhere((f) => f.id == folderId);
          final isNewFolder = existingIndex == -1;

          setState(() {
            if (existingIndex != -1) {
              folders[existingIndex] = updatedFolder;
            } else {
              folders.add(updatedFolder);
            }
            final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
            sortFoldersByOrder(foldersOrder);
          });

          updateFolderTabController();
          filterChats();

          if (isNewFolder) {
            final newFolderIndex = folders.indexWhere((f) => f.id == folderId);
            if (newFolderIndex != -1) {
              final targetIndex = newFolderIndex + 1;
              if (folderTabController.length > targetIndex) {
                folderTabController.animateTo(targetIndex);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка обработки созданной/обновленной папки из opcode 274: $e');
    }
  }

  void _handleFolderDeleted(Map<String, dynamic> payload, int cmd) {
    if (cmd != 0x100 && cmd != 256) return;
    try {
      final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
      final context = getContext();
      if (foldersOrder != null && context.mounted) {
        final currentIndex = folderTabController.index;

        setState(() {
          final orderedIds = foldersOrder.map((id) => id.toString()).toList();
          folders.removeWhere((folder) => !orderedIds.contains(folder.id));
          sortFoldersByOrder(foldersOrder);
        });

        updateFolderTabController();
        filterChats();

        if (currentIndex >= folderTabController.length) {
          folderTabController.animateTo(0);
        } else if (currentIndex > 0) {
          folderTabController.animateTo(
            currentIndex < folderTabController.length ? currentIndex : 0,
          );
        }

        ApiService.instance.requestFolderSync();
      }
    } catch (e) {
      print('Ошибка обработки удаления папки из opcode 276: $e');
    }
  }

  void _insertChatAtCorrectPosition(Chat chat) {
    if (isSavedMessages(chat)) {
      if (chat.id == 0) {
        allChats.insert(0, chat);
      } else {
        final savedIndex = allChats.indexWhere(
          (c) => isSavedMessages(c) && c.id == 0,
        );
        final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
        allChats.insert(insertIndex, chat);
      }
    } else {
      final savedIndex = allChats.indexWhere(isSavedMessages);
      final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
      allChats.insert(insertIndex, chat);
    }
  }

  /// Показать уведомление с известным контактом
  void _showNotificationWithContact(
    int chatId,
    Message message,
    Contact contact, [
    Map<String, dynamic>? chatFromPayload,
  ]) async {
    // Получаем данные чата
    final effectiveChat = await _getEffectiveChat(chatId, chatFromPayload);

    // Группы: chatId < 0 ИЛИ type='CHAT' ИЛИ isGroup
    final isGroupChat =
        chatId < 0 ||
        (effectiveChat != null &&
            (effectiveChat.isGroup || effectiveChat.type == 'CHAT'));
    final groupTitle =
        effectiveChat?.title ??
        effectiveChat?.displayTitle ??
        (isGroupChat ? 'Группа' : null);
    final avatarUrl = isGroupChat
        ? (effectiveChat?.baseIconUrl ?? contact.photoBaseUrl)
        : contact.photoBaseUrl;

    NotificationService().showMessageNotification(
      chatId: chatId,
      senderName: contact.name,
      messageText: _getAttachmentPreviewText(message),
      avatarUrl: avatarUrl,
      isGroupChat: isGroupChat,
      groupTitle: groupTitle,
    );
  }

  /// Загрузить контакт и показать уведомление
  void _loadAndShowNotification(
    int chatId,
    Message message,
    int userId, [
    Map<String, dynamic>? chatFromPayload,
  ]) {
    ApiService.instance
        .fetchContactsByIds([userId])
        .then((contactsList) {
          if (contactsList.isNotEmpty) {
            final contact = contactsList.first;
            contacts[userId] = contact;
            _showNotificationWithContact(
              chatId,
              message,
              contact,
              chatFromPayload,
            );
          } else {
            _showNotificationWithoutContact(
              chatId,
              message,
              userId,
              chatFromPayload,
            );
          }
        })
        .catchError((_) {
          _showNotificationWithoutContact(
            chatId,
            message,
            userId,
            chatFromPayload,
          );
        });
  }

  /// Показать уведомление без информации о контакте
  void _showNotificationWithoutContact(
    int chatId,
    Message message,
    int userId, [
    Map<String, dynamic>? chatFromPayload,
  ]) async {
    final effectiveChat = await _getEffectiveChat(chatId, chatFromPayload);

    final isGroupChat =
        chatId < 0 ||
        (effectiveChat != null &&
            (effectiveChat.isGroup || effectiveChat.type == 'CHAT'));
    final groupTitle =
        effectiveChat?.title ??
        effectiveChat?.displayTitle ??
        (isGroupChat ? 'Группа' : null);
    final avatarUrl = isGroupChat ? effectiveChat?.baseIconUrl : null;

    NotificationService().showMessageNotification(
      chatId: chatId,
      senderName: 'Пользователь $userId',
      messageText: _getAttachmentPreviewText(message),
      avatarUrl: avatarUrl,
      isGroupChat: isGroupChat,
      groupTitle: groupTitle,
    );
  }

  /// Получить данные чата из разных источников
  Future<Chat?> _getEffectiveChat(
    int chatId, [
    Map<String, dynamic>? chatFromPayload,
  ]) async {
    // Ищем в allChats
    try {
      return allChats.firstWhere((c) => c.id == chatId);
    } catch (_) {}

    // Из payload
    if (chatFromPayload != null) {
      return Chat.fromJson(chatFromPayload);
    }

    // Из кэша
    try {
      final cachedChatJson = await ChatCacheService().getChatById(chatId);
      if (cachedChatJson != null) {
        return Chat.fromJson(cachedChatJson);
      }
    } catch (_) {}

    return null;
  }
}
