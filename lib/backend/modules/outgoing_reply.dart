import 'messages.dart';

class OutgoingReply {
  const OutgoingReply._(this.message, this.messageId, this.sourceChatId);

  static OutgoingReply? of(CachedMessage? message, {int? sourceChatId}) {
    if (message == null) return null;
    final id = int.tryParse(message.id);
    if (id == null) return null;
    return OutgoingReply._(message, id, sourceChatId);
  }

  static OutgoingReply? fromPayload(
    Map<String, dynamic>? payload, {
    required int accountId,
    required int chatId,
  }) {
    final link = payload?['link'];
    if (link is! Map || (link['type'] as String?)?.toUpperCase() != 'REPLY') {
      return null;
    }
    final quoted = link['message'];
    if (quoted is! Map) return null;
    final id = int.tryParse('${quoted['id']}');
    if (id == null) return null;
    final sender = quoted['sender'];
    final time = quoted['time'];
    final forward = quoted['link'];
    final source = link['chatId'];
    return OutgoingReply._(
      CachedMessage(
        id: '$id',
        accountId: accountId,
        chatId: chatId,
        senderId: sender is int ? sender : 0,
        text: quoted['text'] as String?,
        time: time is int ? time : 0,
        payload: {
          'attaches': quoted['attaches'] ?? const [],
          if (forward is Map) 'link': forward,
        },
      ),
      id,
      source is int && source != chatId ? source : null,
    );
  }

  final CachedMessage message;
  final int messageId;
  final int? sourceChatId;

  Map<String, dynamic> linkIn(int chatId) {
    final sourceLink = message.payload?['link'];
    return {
      'type': 'REPLY',
      'chatId': sourceChatId ?? chatId,
      'message': {
        'id': messageId,
        'sender': message.senderId,
        'text': message.text,
        'time': message.time,
        'attaches': message.payload?['attaches'] ?? const [],
        if (sourceLink is Map && sourceLink['type'] == 'FORWARD')
          'link': sourceLink,
      },
    };
  }

  CachedMessage quotedIn(CachedMessage outgoing) => outgoing.copyWith(
    payload: {...?outgoing.payload, 'link': linkIn(outgoing.chatId)},
  );

  static CachedMessage keepQuote(CachedMessage sent, CachedMessage? local) {
    if (_quotesMessage(sent.payload)) return sent;
    final localPayload = local?.payload;
    if (!_quotesMessage(localPayload)) return sent;
    return sent.copyWith(
      payload: {...?sent.payload, 'link': localPayload!['link']},
    );
  }

  static bool _quotesMessage(Map<String, dynamic>? payload) {
    final link = payload?['link'];
    return link is Map &&
        (link['type'] as String?)?.toUpperCase() == 'REPLY' &&
        link['message'] is Map;
  }
}
