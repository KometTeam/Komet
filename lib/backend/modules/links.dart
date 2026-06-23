import 'dart:async';

import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../api.dart';

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

abstract class LinkModule {
  static Future<ResolvedLink?> resolve(Api api, String url) async {
    final Packet response;
    try {
      response = await api.sendRequest(Opcode.linkInfo, {'link': url});
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
