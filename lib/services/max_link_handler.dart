import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/screens/chat_screen.dart';
import 'package:gwid/services/chat_cache_service.dart';

enum MaxLinkOpenResult { notHandled, opened, failed }

class MaxLinkHandler {
  MaxLinkHandler._();

  static bool isSupportedUri(Uri uri) {
    if (uri.host != 'max.ru') return false;
    return uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'max';
  }

  static Uri normalize(Uri uri) {
    if (uri.scheme == 'max' || uri.scheme == 'http') {
      return uri.replace(scheme: 'https');
    }
    return uri;
  }

  static bool isDirectChatOrChannelLink(Uri uri) {
    if (!isSupportedUri(uri)) return false;
    if (uri.pathSegments.isEmpty) return false;
    // join-ссылки обрабатываются отдельным флоу (вступление в группу)
    if (uri.path.startsWith('/join/')) return false;
    if (uri.pathSegments.first == 'join') return false;
    return true;
  }

  static Future<MaxLinkOpenResult> tryOpenChatFromUri(
    BuildContext context,
    Uri uri, {
    bool showErrors = true,
  }) async {
    if (!isDirectChatOrChannelLink(uri)) return MaxLinkOpenResult.notHandled;

    final normalized = normalize(uri);
    final link = normalized.toString();

    try {
      await ApiService.instance.waitUntilOnline();
      final chatInfo = await ApiService.instance.getChatInfoByLink(link);

      final chatId = _parseChatId(chatInfo['id']);
      if (chatId == null) {
        throw Exception('Не удалось определить chatId');
      }

      await ApiService.instance.subscribeToChat(chatId, true);

      final myId = _myIdFromLastPayload();
      final isGroupChat = _isGroupChat(chatInfo, chatId);
      final isChannel = _isChannel(chatInfo);
      final participantCount = chatInfo['participantCount'] as int?;

      final contact =
          _buildContactFromChatInfo(chatInfo, chatId, isGroupChat, isChannel) ??
          await _buildContactFallbackFromCache(chatId, isGroupChat);

      if (!context.mounted) return MaxLinkOpenResult.opened;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            contact: contact,
            myId: myId,
            pinnedMessage: null,
            isGroupChat: isGroupChat,
            isChannel: isChannel,
            participantCount: participantCount,
          ),
        ),
      );

      return MaxLinkOpenResult.opened;
    } catch (e) {
      print('Ошибка открытия max-ссылки ($link): $e');
      if (showErrors && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть: $link'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
          ),
        );
      }
      return MaxLinkOpenResult.failed;
    }
  }

  static int? _parseChatId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  static int _myIdFromLastPayload() {
    try {
      final lastPayload = ApiService.instance.lastChatsPayload;
      final profileData = lastPayload?['profile'] as Map<String, dynamic>?;
      final contactProfile = profileData?['contact'] as Map<String, dynamic>?;
      return contactProfile?['id'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static bool _isGroupChat(Map<String, dynamic> chatInfo, int chatId) {
    final chatType = chatInfo['type'] as String?;
    return chatType == 'CHAT' || chatInfo['isGroup'] == true || chatId < 0;
  }

  static bool _isChannel(Map<String, dynamic> chatInfo) {
    final chatType = chatInfo['type'] as String?;
    return chatInfo['isChannel'] == true || chatType == 'CHANNEL';
  }

  static Contact? _buildContactFromChatInfo(
    Map<String, dynamic> chatInfo,
    int chatId,
    bool isGroupChat,
    bool isChannel,
  ) {
    if (isGroupChat || isChannel) {
      final title =
          chatInfo['title'] as String? ??
          chatInfo['displayTitle'] as String? ??
          'Чат';
      final photo =
          chatInfo['baseIconUrl'] as String? ??
          chatInfo['baseUrl'] as String? ??
          chatInfo['iconUrl'] as String?;

      return Contact(
        id: chatId,
        name: title,
        firstName: title,
        lastName: '',
        photoBaseUrl: photo,
      );
    }

    final contactData = chatInfo['contact'];
    if (contactData is Map<String, dynamic>) {
      return Contact.fromJson(contactData);
    }

    final displayTitle = chatInfo['displayTitle'] as String? ?? 'Контакт';
    final photo =
        chatInfo['baseIconUrl'] as String? ??
        chatInfo['baseUrl'] as String? ??
        chatInfo['iconUrl'] as String?;
    return Contact(
      id: chatId,
      name: displayTitle,
      firstName: displayTitle.split(' ').first,
      lastName: displayTitle.split(' ').length > 1
          ? displayTitle.split(' ').sublist(1).join(' ')
          : '',
      photoBaseUrl: photo,
    );
  }

  static Future<Contact> _buildContactFallbackFromCache(
    int chatId,
    bool isGroupChat,
  ) async {
    final cachedChat = await ChatCacheService().getChatById(chatId);
    if (cachedChat == null) {
      return Contact(
        id: chatId,
        name: 'Чат $chatId',
        firstName: 'Чат',
        lastName: '$chatId',
      );
    }

    if (isGroupChat) {
      final title =
          cachedChat['title'] as String? ??
          cachedChat['displayTitle'] as String? ??
          'Группа';
      final baseIconUrl = cachedChat['baseIconUrl'] as String?;
      return Contact(
        id: chatId,
        name: title,
        firstName: title,
        lastName: '',
        photoBaseUrl: baseIconUrl,
      );
    }

    final contactData = cachedChat['contact'] as Map<String, dynamic>?;
    if (contactData != null) {
      return Contact.fromJson(contactData);
    }

    final displayTitle = cachedChat['displayTitle'] as String? ?? 'Контакт';
    final baseIconUrl = cachedChat['baseIconUrl'] as String?;
    return Contact(
      id: chatId,
      name: displayTitle,
      firstName: displayTitle.split(' ').first,
      lastName: displayTitle.split(' ').length > 1
          ? displayTitle.split(' ').sublist(1).join(' ')
          : '',
      photoBaseUrl: baseIconUrl,
    );
  }
}

