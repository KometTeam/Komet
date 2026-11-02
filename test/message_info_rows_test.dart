import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/message_info.dart';
import 'package:komet/backend/modules/messages.dart';

const int _accountId = 1001;
const int _chatId = -2002;
const int _peerId = 3003;

CachedMessage _fromServer(Map<String, dynamic> payload) =>
    CachedMessage.fromPushPayload(_accountId, _chatId, payload);

Map<String, String> _map(CachedMessage message) => {
  for (final row in buildMessageInfoRows(message)) row.label: row.value,
};

List<String> _labels(CachedMessage message) => [
  for (final row in buildMessageInfoRows(message)) row.label,
];

void main() {
  group('технические поля сообщения', () {
    test('простое сообщение отдаёт id, cid и отправителя', () {
      final rows = _map(
        _fromServer({
          'id': '900000000000000001',
          'time': 1700000001000,
          'type': 'USER',
          'sender': _accountId,
          'cid': -1700000000901,
          'text': '1',
          'attaches': <dynamic>[],
          'reactionInfo': <String, dynamic>{},
        }),
      );

      expect(rows['id'], '900000000000000001');
      expect(rows['cid'], '-1700000000901');
      expect(rows['chatId'], '$_chatId');
      expect(rows['sender'], '$_accountId');
      expect(rows['type'], 'USER');
      expect(rows['time'], startsWith('1700000001000 · '));
      expect(rows['text.length'], '1');
      expect(rows.containsKey('attaches'), isFalse);
      expect(rows.containsKey('reactionInfo'), isFalse);
      expect(rows.containsKey('updateTime'), isFalse);
    });

    test('правленое сообщение со ссылкой описывает вложения и разметку', () {
      final rows = _map(
        _fromServer({
          'id': '900000000000000002',
          'time': 1700000002000,
          'type': 'USER',
          'updateTime': 1700000002050,
          'sender': _accountId,
          'cid': -1700000001901,
          'text': 'https://example.test/joincall/abc',
          'attaches': [
            {
              '_type': 'SHARE',
              'shareId': 4004,
              'title': 'Synthetic call',
            },
          ],
          'elements': [
            {'type': 'LINK', 'length': 33},
          ],
          'reactionInfo': <String, dynamic>{},
        }),
      );

      expect(rows['updateTime'], startsWith('1700000002050 · '));
      expect(rows['attaches'], 'SHARE');
      expect(rows['elements'], 'LINK');
    });

    test('пересылка разворачивается в источник', () {
      final rows = _map(
        _fromServer({
          'id': '900000000000000003',
          'time': 1700000003000,
          'type': 'USER',
          'sender': _peerId,
          'text': '',
          'attaches': <dynamic>[],
          'link': {
            'type': 'FORWARD',
            'message': {'id': '900000000000000004', 'text': 'synthetic'},
            'chatId': _chatId,
            'chatName': 'synthetic chat',
            'chatAccessType': 'PRIVATE',
          },
          'reactionInfo': <String, dynamic>{},
        }),
      );

      expect(
        rows['link'],
        'FORWARD · synthetic chat ($_chatId) · 900000000000000004',
      );
    });

    test('повторяющиеся типы вложений схлопываются в счётчик', () {
      final rows = _map(
        _fromServer({
          'id': '1',
          'time': 1700000003000,
          'sender': _peerId,
          'attaches': [
            {'_type': 'PHOTO'},
            {'_type': 'PHOTO'},
            {'_type': 'PHOTO'},
          ],
        }),
      );

      expect(rows['attaches'], 'PHOTO ×3');
    });

    test('реакции показывают разбивку и свою', () {
      final rows = _map(
        _fromServer({
          'id': '1',
          'time': 1700000003000,
          'sender': _peerId,
          'attaches': <dynamic>[],
          'reactionInfo': {
            'counters': [
              {'reaction': '👍', 'count': 2},
              {'reaction': '🔥', 'count': 1},
            ],
            'totalCount': 3,
            'yourReaction': '👍',
          },
        }),
      );

      expect(rows['reactionInfo'], '👍 2, 🔥 1 · total 3 · your 👍');
    });

    test('незнакомые скалярные поля payload попадают в конец списка', () {
      final labels = _labels(
        _fromServer({
          'id': '1',
          'time': 1700000003000,
          'sender': _peerId,
          'attaches': <dynamic>[],
          'views': 512,
          'options': 2,
        }),
      );

      expect(labels, containsAllInOrder(['id', 'views', 'options']));
    });

    test('своё ещё не отправленное сообщение обходится без payload', () {
      final rows = _map(
        const CachedMessage(
          id: 'temp_1_1700000000000000',
          accountId: _accountId,
          chatId: _chatId,
          senderId: _accountId,
          text: 'привет',
          time: 1700000000000,
          status: 'sending',
        ),
      );

      expect(rows['id'], 'temp_1_1700000000000000');
      expect(rows['status'], 'sending');
      expect(rows['text.length'], '6');
      expect(rows.containsKey('cid'), isFalse);
      expect(rows.containsKey('type'), isFalse);
    });
  });
}
