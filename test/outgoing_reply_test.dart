import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/backend/modules/outgoing_reply.dart';

const int _me = 1;
const int _chatId = 900201;
const int _peer = 900301;

CachedMessage _message(
  String id, {
  int sender = _me,
  Map<String, dynamic>? payload,
}) => CachedMessage(
  id: id,
  accountId: _me,
  chatId: _chatId,
  senderId: sender,
  text: 'синтетика',
  time: 1700000000000,
  payload: payload,
);

void main() {
  test('a message still waiting for its server id cannot be replied to', () {
    expect(OutgoingReply.of(_message('temp_1_2', sender: _peer)), isNull);
    expect(OutgoingReply.of(null), isNull);
  });

  test('the optimistic message carries the full quote', () {
    final reply = OutgoingReply.of(_message('42', sender: _peer))!;
    final quoted = reply.quotedIn(_message('temp_9_9'));
    final link = quoted.payload!['link'] as Map;
    expect(link['type'], 'REPLY');
    expect(link['chatId'], _chatId);
    expect((link['message'] as Map)['id'], 42);
    expect((link['message'] as Map)['sender'], _peer);
  });

  test('a cross-chat reply points at the source chat', () {
    final reply = OutgoingReply.of(
      _message('42', sender: _peer),
      sourceChatId: 777,
    )!;
    expect(reply.linkIn(_chatId)['chatId'], 777);
  });

  test('the server echo keeps the local quote when it lacks the message', () {
    final reply = OutgoingReply.of(_message('42', sender: _peer))!;
    final local = reply.quotedIn(_message('temp_9_9'));
    final echo = _message(
      '100',
      payload: {
        'link': {'type': 'REPLY', 'chatId': _chatId, 'messageId': 42},
      },
    );
    final kept = OutgoingReply.keepQuote(echo, local);
    expect(((kept.payload!['link'] as Map)['message'] as Map)['id'], 42);
    expect(OutgoingReply.keepQuote(_message('101'), null).payload, isNull);
  });

  test('a full quote from the server wins over the local one', () {
    final reply = OutgoingReply.of(_message('42', sender: _peer))!;
    final local = reply.quotedIn(_message('temp_9_9'));
    final echo = _message(
      '100',
      payload: {
        'link': {
          'type': 'REPLY',
          'chatId': _chatId,
          'message': {'id': 42, 'sender': _peer, 'text': 'с сервера'},
        },
      },
    );
    final kept = OutgoingReply.keepQuote(echo, local);
    expect(
      ((kept.payload!['link'] as Map)['message'] as Map)['text'],
      'с сервера',
    );
  });

  test('a failed message gives back the reply it was sent with', () {
    final original = OutgoingReply.of(
      _message('42', sender: _peer),
      sourceChatId: 777,
    )!;
    final failed = original.quotedIn(_message('temp_9_9'));
    final restored = OutgoingReply.fromPayload(
      failed.payload,
      accountId: _me,
      chatId: _chatId,
    )!;
    expect(restored.messageId, 42);
    expect(restored.sourceChatId, 777);
    expect(restored.linkIn(_chatId), original.linkIn(_chatId));
  });

  test('a message without a reply restores none', () {
    expect(
      OutgoingReply.fromPayload(
        _message('temp_1_1').payload,
        accountId: _me,
        chatId: _chatId,
      ),
      isNull,
    );
  });
}
