import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/message_info.dart';
import 'package:komet/backend/modules/messages.dart';

const int _accountId = 270546051;
const int _chatId = -78807406861784;

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
          'id': '117241017304569410',
          'time': 1788955952523,
          'type': 'USER',
          'sender': _accountId,
          'cid': -1788955952374,
          'text': '1',
          'attaches': <dynamic>[],
          'reactionInfo': <String, dynamic>{},
        }),
      );

      expect(rows['id'], '117241017304569410');
      expect(rows['cid'], '-1788955952374');
      expect(rows['chatId'], '$_chatId');
      expect(rows['sender'], '$_accountId');
      expect(rows['type'], 'USER');
      expect(rows['time'], startsWith('1788955952523 · '));
      expect(rows['text.length'], '1');
      expect(rows.containsKey('attaches'), isFalse);
      expect(rows.containsKey('reactionInfo'), isFalse);
      expect(rows.containsKey('updateTime'), isFalse);
    });

    test('правленое сообщение со ссылкой описывает вложения и разметку', () {
      final rows = _map(
        _fromServer({
          'id': '117241017682102228',
          'time': 1788955958284,
          'type': 'USER',
          'updateTime': 1788955958318,
          'sender': _accountId,
          'cid': -1788955958052,
          'text': 'https://example.test/joincall/abc',
          'attaches': [
            {
              '_type': 'SHARE',
              'shareId': 6421452419,
              'title': 'Групповой звонок',
            },
          ],
          'elements': [
            {'type': 'LINK', 'length': 33},
          ],
          'reactionInfo': <String, dynamic>{},
        }),
      );

      expect(rows['updateTime'], startsWith('1788955958318 · '));
      expect(rows['attaches'], 'SHARE');
      expect(rows['elements'], 'LINK');
    });

    test('пересылка разворачивается в источник', () {
      final rows = _map(
        _fromServer({
          'id': '117251783665282870',
          'time': 1789120234150,
          'type': 'USER',
          'sender': 67779544,
          'text': '',
          'attaches': <dynamic>[],
          'link': {
            'type': 'FORWARD',
            'message': {'id': '117251783278678900', 'text': 'jkj'},
            'chatId': -78807406861784,
            'chatName': 'test',
            'chatAccessType': 'PRIVATE',
          },
          'reactionInfo': <String, dynamic>{},
        }),
      );

      expect(
        rows['link'],
        'FORWARD · test (-78807406861784) · 117251783278678900',
      );
    });

    test('повторяющиеся типы вложений схлопываются в счётчик', () {
      final rows = _map(
        _fromServer({
          'id': '1',
          'time': 1789120234150,
          'sender': 67779544,
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
          'time': 1789120234150,
          'sender': 67779544,
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
          'time': 1789120234150,
          'sender': 67779544,
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
