import 'dart:async';

import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../api.dart';

// #***! что оказалось по ссылке, чат юзер или ошибка
sealed class ResolvedLink {
  const ResolvedLink();
}

class ResolvedChat extends ResolvedLink {
  final Map<dynamic, dynamic> chat;
  final Map<dynamic, dynamic>? message;

  const ResolvedChat(this.chat, this.message);
}

class ResolvedUser extends ResolvedLink {
  final Map<dynamic, dynamic> contact;

  const ResolvedUser(this.contact);
}

class ResolvedLinkError extends ResolvedLink {
  final String message;

  const ResolvedLinkError(this.message);
}

// #***! разбор ссылок приглашений и вступление
abstract class LinkModule {
  // #***! silent, ошибку покажем сами в диалоге
  static Future<ResolvedLink?> resolve(Api api, String url) async {
    final Packet response;
    try {
      response = await api.sendRequest(Opcode.linkInfo, {
        'link': url,
      }, silent: true);
    } on TimeoutException {
      return const ResolvedLinkError('Превышено время ожидания');
    } on PacketError catch (e) {
      return ResolvedLinkError(e.message);
    }

    final payload = response.payload;
    if (payload is! Map) return null;
    if (!response.isOk) {
      return ResolvedLinkError(messageFromErrorPayload(payload));
    }

    // #***! в ответе или чат или контакт
    final chat = payload['chat'];
    if (chat is Map) {
      final message = payload['message'];
      return ResolvedChat(chat, message is Map ? message : null);
    }

    final user = payload['user'];
    if (user is Map && user['contact'] is Map) {
      return ResolvedUser(user['contact'] as Map);
    }

    return null;
  }

  // #***! вступление по ссылке, вернёт текст ошибки или null
  static Future<String?> join(Api api, String url) async {
    try {
      final response = await api.sendRequest(Opcode.chatJoin, {'link': url});
      if (response.isOk) return null;
      return messageFromErrorPayload(response.payload);
    } on TimeoutException {
      return 'Превышено время ожидания';
    } on PacketError catch (e) {
      return e.message;
    }
  }
}
