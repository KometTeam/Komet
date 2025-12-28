import 'dart:async';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/services/cache_service.dart';

class ChatCacheService {
  static final ChatCacheService _instance = ChatCacheService._internal();
  factory ChatCacheService() => _instance;
  ChatCacheService._internal();

  final CacheService _cacheService = CacheService();

  Future<void> initialize() async {
    await _cacheService.initialize();
    print('ChatCacheService инициализирован');
  }

  static const String _chatsKey = 'cached_chats';
  static const String _contactsKey = 'cached_contacts';
  static const String _messagesKey = 'cached_messages';
  static const String _chatMessagesKey = 'cached_chat_messages';

  static const Duration _chatsTTL = Duration(hours: 1);
  static const Duration _contactsTTL = Duration(hours: 24);
  static const Duration _messagesTTL = Duration(hours: 2);

  Future<void> cacheChats(List<Map<String, dynamic>> chats) async {
    try {
      await _cacheService.set(_chatsKey, chats, ttl: _chatsTTL);
      print('Кэшировано ${chats.length} чатов');
    } catch (e) {
      print('Ошибка кэширования чатов: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getCachedChats() async {
    try {
      final cached = await _cacheService.get<List<dynamic>>(
        _chatsKey,
        ttl: _chatsTTL,
      );
      if (cached != null) {
        return cached.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Ошибка получения кэшированных чатов: $e');
    }
    return null;
  }

  /// Получить чат из кэша по ID
  Future<Map<String, dynamic>?> getChatById(int chatId) async {
    try {
      final chats = await getCachedChats();
      if (chats != null) {
        for (final chat in chats) {
          if (chat['id'] == chatId) {
            return chat;
          }
        }
      }
    } catch (e) {
      print('Ошибка поиска чата в кэше: $e');
    }
    return null;
  }

  Future<void> cacheContacts(List<Contact> contacts) async {
    try {
      final contactsData = contacts
          .map(
            (contact) => {
              'id': contact.id,
              'names': [
                {
                  'name': contact.name,
                  'firstName': contact.firstName,
                  'lastName': contact.lastName,
                  'type': 'ONEME',
                },
              ],
              'photoBaseUrl': contact.photoBaseUrl,
              'baseUrl': contact.photoBaseUrl,
              'isBlocked': contact.isBlocked,
              'isBlockedByMe': contact.isBlockedByMe,
              'accountStatus': contact.accountStatus,
              'status': contact.status,
              'options': contact.options,
              'description': contact.description,
            },
          )
          .toList();

      await _cacheService.set(_contactsKey, contactsData, ttl: _contactsTTL);
      print(
        '✅ Кэшировано ${contacts.length} контактов (глобально) с описаниями',
      );
    } catch (e) {
      print('❌ Ошибка кэширования контактов: $e');
    }
  }

  Future<List<Contact>?> getCachedContacts() async {
    try {
      final cached = await _cacheService.get<List<dynamic>>(
        _contactsKey,
        ttl: _contactsTTL,
      );
      if (cached != null) {
        final contacts = cached.map((data) => Contact.fromJson(data)).toList();
        print('✅ Загружено ${contacts.length} контактов из глобального кэша');
        return contacts;
      }
    } catch (e) {
      print('❌ Ошибка получения кэшированных контактов: $e');
    }
    return null;
  }

  
  Future<void> cacheChatContacts(int chatId, List<Contact> contacts) async {
    try {
      final key = 'chat_contacts_$chatId';
      final contactsData = contacts
          .map(
            (contact) => {
              'id': contact.id,
              'names': [
                {
                  'name': contact.name,
                  'firstName': contact.firstName,
                  'lastName': contact.lastName,
                  'type': 'ONEME',
                },
              ],
              'photoBaseUrl': contact.photoBaseUrl,
              'baseUrl': contact.photoBaseUrl,
              'isBlocked': contact.isBlocked,
              'isBlockedByMe': contact.isBlockedByMe,
              'accountStatus': contact.accountStatus,
              'status': contact.status,
              'options': contact.options,
              'description': contact.description,
            },
          )
          .toList();

      await _cacheService.set(key, contactsData, ttl: _contactsTTL);
      print('✅ Кэшировано ${contacts.length} контактов для чата $chatId');
    } catch (e) {
      print('❌ Ошибка кэширования контактов для чата $chatId: $e');
    }
  }

  Future<List<Contact>?> getCachedChatContacts(int chatId) async {
    try {
      final key = 'chat_contacts_$chatId';
      final cached = await _cacheService.get<List<dynamic>>(
        key,
        ttl: _contactsTTL,
      );
      if (cached != null) {
        final contacts = cached.map((data) => Contact.fromJson(data)).toList();
        print('✅ Загружено ${contacts.length} контактов из кэша чата $chatId');
        return contacts;
      }
    } catch (e) {
      print('❌ Ошибка получения кэшированных контактов для чата $chatId: $e');
    }
    return null;
  }

  Future<void> cacheChatMessages(int chatId, List<Message> messages) async {
    try {
      final key = '$_chatMessagesKey$chatId';
      final messagesData = messages
          .map(
            (message) => {
              'id': message.id,
              'sender': message.senderId,
              'text': message.text,
              'time': message.time,
              'status': message.status,
              'updateTime': message.updateTime,
              'attaches': message.attaches,
              'cid': message.cid,
              'reactionInfo': message.reactionInfo,
              'link': message.link,
            },
          )
          .toList();

      await _cacheService.set(key, messagesData, ttl: _messagesTTL);
      print('Кэшировано ${messages.length} сообщений для чата $chatId');
    } catch (e) {
      print('Ошибка кэширования сообщений для чата $chatId: $e');
    }
  }

  Future<List<Message>?> getCachedChatMessages(int chatId) async {
    try {
      final key = '$_chatMessagesKey$chatId';
      final cached = await _cacheService.get<List<dynamic>>(
        key,
        ttl: _messagesTTL,
      );
      if (cached != null) {
        return cached.map((data) => Message.fromJson(data)).toList();
      }
    } catch (e) {
      print('Ошибка получения кэшированных сообщений для чата $chatId: $e');
    }
    return null;
  }

  Future<void> addMessageToCache(int chatId, Message message) async {
    try {
      final cached = await getCachedChatMessages(chatId);

      if (cached != null) {
        final updatedMessages = [message, ...cached];
        await cacheChatMessages(chatId, updatedMessages);
      } else {
        await cacheChatMessages(chatId, [message]);
      }
    } catch (e) {
      print('Ошибка добавления сообщения в кэш: $e');
    }
  }

  Future<void> updateMessageInCache(int chatId, Message updatedMessage) async {
    try {
      final cached = await getCachedChatMessages(chatId);

      if (cached != null) {
        final updatedMessages = cached.map((message) {
          if (message.id == updatedMessage.id) {
            return updatedMessage;
          }
          return message;
        }).toList();

        await cacheChatMessages(chatId, updatedMessages);
      }
    } catch (e) {
      print('Ошибка обновления сообщения в кэше: $e');
    }
  }

  Future<void> removeMessageFromCache(int chatId, String messageId) async {
    try {
      final cached = await getCachedChatMessages(chatId);

      if (cached != null) {
        final updatedMessages = cached
            .where((message) => message.id != messageId)
            .toList();
        await cacheChatMessages(chatId, updatedMessages);
      }
    } catch (e) {
      print('Ошибка удаления сообщения из кэша: $e');
    }
  }

  Future<void> cacheChatInfo(int chatId, Map<String, dynamic> chatInfo) async {
    try {
      final key = 'chat_info_$chatId';
      await _cacheService.set(key, chatInfo, ttl: _chatsTTL);
    } catch (e) {
      print('Ошибка кэширования информации о чате $chatId: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedChatInfo(int chatId) async {
    try {
      final key = 'chat_info_$chatId';
      return await _cacheService.get<Map<String, dynamic>>(key, ttl: _chatsTTL);
    } catch (e) {
      print('Ошибка получения кэшированной информации о чате $chatId: $e');
      return null;
    }
  }

  Future<void> cacheLastMessage(int chatId, Message? lastMessage) async {
    try {
      final key = 'last_message_$chatId';
      if (lastMessage != null) {
        final messageData = {
          'id': lastMessage.id,
          'sender': lastMessage.senderId,
          'text': lastMessage.text,
          'time': lastMessage.time,
          'status': lastMessage.status,
          'updateTime': lastMessage.updateTime,
          'attaches': lastMessage.attaches,
          'cid': lastMessage.cid,
          'reactionInfo': lastMessage.reactionInfo,
          'link': lastMessage.link,
        };
        await _cacheService.set(key, messageData, ttl: _chatsTTL);
      } else {
        await _cacheService.remove(key);
      }
    } catch (e) {
      print('Ошибка кэширования последнего сообщения для чата $chatId: $e');
    }
  }

  Future<Message?> getCachedLastMessage(int chatId) async {
    try {
      final key = 'last_message_$chatId';
      final cached = await _cacheService.get<Map<String, dynamic>>(
        key,
        ttl: _chatsTTL,
      );
      if (cached != null) {
        return Message.fromJson(cached);
      }
    } catch (e) {
      print(
        'Ошибка получения кэшированного последнего сообщения для чата $chatId: $e',
      );
    }
    return null;
  }

  Future<void> clearChatCache(int chatId) async {
    try {
      final keys = [
        '$_chatMessagesKey$chatId',
        'chat_info_$chatId',
        'last_message_$chatId',
        'chat_contacts_$chatId',
      ];

      for (final key in keys) {
        await _cacheService.remove(key);
      }

      print('Кэш для чата $chatId очищен (включая контакты)');
    } catch (e) {
      print('Ошибка очистки кэша для чата $chatId: $e');
    }
  }

  Future<void> clearAllChatCache() async {
    try {
      await _cacheService.remove(_chatsKey);
      await _cacheService.remove(_contactsKey);
      await _cacheService.remove(_messagesKey);

      print('Весь кэш чатов очищен');
    } catch (e) {
      print('Ошибка очистки всего кэша чатов: $e');
    }
  }

  Future<Map<String, dynamic>> getChatCacheStats() async {
    try {
      final cacheStats = await _cacheService.getCacheStats();
      final chats = await getCachedChats();
      final contacts = await getCachedContacts();

      return {
        'cachedChats': chats?.length ?? 0,
        'cachedContacts': contacts?.length ?? 0,
        'cacheStats': cacheStats,
      };
    } catch (e) {
      print('Ошибка получения статистики кэша чатов: $e');
      return {};
    }
  }

  Future<bool> isCacheValid(String cacheType) async {
    try {
      switch (cacheType) {
        case 'chats':
          return await _cacheService.get(_chatsKey, ttl: _chatsTTL) != null;
        case 'contacts':
          return await _cacheService.get(_contactsKey, ttl: _contactsTTL) !=
              null;
        default:
          return false;
      }
    } catch (e) {
      print('Ошибка проверки актуальности кэша: $e');
      return false;
    }
  }
}
