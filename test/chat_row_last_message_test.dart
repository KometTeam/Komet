import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';

const int _me = 501;
const int _peer = 777;
const int _chatId = 4242;
const int _lastMsgId = 9000000;

CachedChat _cached({int? senderId, String? status, int? lastMsgId}) =>
    CachedChat(
      id: _chatId,
      accountId: _me,
      type: 'DIALOG',
      title: 'Диалог',
      lastMsgId: lastMsgId ?? _lastMsgId,
      lastMsgTime: 1700000000000,
      lastMsgText: 'привет',
      lastMsgSenderId: senderId,
      lastMsgStatus: status,
      unreadCount: 0,
      lastEventTime: 1700000000000,
      cachedAt: 0,
      dontDisturbUntil: ChatsModule.muteOff,
      isOnline: false,
      seenTime: 0,
      participants: {_me: 1700000000000, _peer: 0},
    );

Map<String, dynamic> _serverChat({Object? sender}) => {
  'id': _chatId,
  'type': 'DIALOG',
  'participants': {'$_me': 1700000000000, '$_peer': 0},
  'lastMessage': {
    'id': _lastMsgId,
    'time': 1700000000000,
    'text': 'привет',
    if (sender != null) 'sender': sender,
  },
};

CachedChat _parse(
  Map<String, dynamic> chat, {
  Map<int, CachedChat> existing = const {},
}) {
  final parsed = parseChatRow(
    chat,
    _me,
    _me,
    const {},
    const {},
    const {},
    existing,
    0,
  );
  expect(parsed, isNotNull);
  return parsed!;
}

void main() {
  group('разбор чата из ответа сервера', () {
    test('отправитель последнего сообщения берётся из payload', () {
      final parsed = _parse(_serverChat(sender: _me));
      expect(parsed.lastMsgSenderId, _me);
    });

    test('отправитель читается и когда сервер прислал его строкой', () {
      final parsed = _parse(_serverChat(sender: '$_me'));
      expect(parsed.lastMsgSenderId, _me);
      expect(parsed.lastMsgId, _lastMsgId);
    });

    test('без sender в payload отправитель берётся из кэша', () {
      final parsed = _parse(
        _serverChat(),
        existing: {_chatId: _cached(senderId: _me, status: 'read')},
      );
      expect(parsed.lastMsgSenderId, _me);
      expect(parsed.lastMsgStatus, 'read');
    });

    test('на новом последнем сообщении кэш не подмешивается', () {
      final parsed = _parse(
        _serverChat(sender: _peer),
        existing: {
          _chatId: _cached(
            senderId: _me,
            status: 'read',
            lastMsgId: _lastMsgId - 100,
          ),
        },
      );
      expect(parsed.lastMsgSenderId, _peer);
      expect(parsed.lastMsgStatus, isNull);
    });
  });
}
