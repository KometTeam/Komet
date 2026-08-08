import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/models/attachment.dart';
import 'package:komet/models/bot_info.dart';

void main() {
  group('botStarted control message', () {
    CachedMessage parse(Map<String, dynamic> message) =>
        CachedMessage.fromPushPayload(1001, 2002, message);

    test('is control and shows the payload the server put into text', () {
      final message = parse({
        'id': '3003',
        'time': 1700000000000,
        'type': 'USER',
        'sender': 1001,
        'text': 'abc123',
        'attaches': [
          {'_type': 'CONTROL', 'event': 'botStarted'},
        ],
      });

      expect(message.isControl, isTrue);
      expect(message.botStartPayload, 'abc123');
      expect(message.isSilentBotStart, isFalse);
    });

    test('reads the payload off the attach when it is there', () {
      final message = parse({
        'id': '3006',
        'time': 1700000000000,
        'type': 'USER',
        'sender': 1001,
        'attaches': [
          {
            '_type': 'CONTROL',
            'event': 'botStarted',
            'startPayload': 'abc123',
          },
        ],
      });

      expect(message.botStartPayload, 'abc123');
      expect(message.isSilentBotStart, isFalse);
    });

    test('a start without a payload stays hidden', () {
      final message = parse({
        'id': '3007',
        'time': 1700000000000,
        'type': 'USER',
        'sender': 1001,
        'text': '',
        'attaches': [
          {'_type': 'CONTROL', 'event': 'botStarted'},
        ],
      });

      expect(message.isControl, isTrue);
      expect(message.botStartPayload, isNull);
      expect(message.isSilentBotStart, isTrue);
    });

    test('other control events are untouched', () {
      final message = parse({
        'id': '3004',
        'time': 1700000000000,
        'type': 'USER',
        'sender': 1001,
        'attaches': [
          {'_type': 'CONTROL', 'event': 'add', 'userIds': [1002]},
        ],
      });

      expect(message.isControl, isTrue);
      expect(message.botStartPayload, isNull);
      expect(message.isSilentBotStart, isFalse);
    });

    test('a plain message is not a start at all', () {
      final message = parse({
        'id': '3005',
        'time': 1700000000000,
        'type': 'USER',
        'sender': 1001,
        'text': 'привет',
        'attaches': const [],
      });

      expect(message.isControl, isFalse);
      expect(message.botStartPayload, isNull);
      expect(message.isSilentBotStart, isFalse);
    });

    test('the event name used on the wire stays stable', () {
      expect(ControlAttachment.botStartedEvent, 'botStarted');
    });
  });

  group('BotInfo', () {
    test('parses commands and the bot contact', () {
      final info = BotInfo.fromPayload(4004, {
        'commands': [
          {'botId': 4004, 'name': 'start', 'description': 'Главное меню'},
          {'botId': 4004, 'name': 'stats', 'description': '  '},
          {'botId': 4004, 'description': 'без имени'},
        ],
        'contact': {
          'id': 4004,
          'names': [
            {'name': 'Тестовый бот', 'type': 'ONEME'},
          ],
          'options': ['BOT'],
          'description': 'Описание бота',
          'link': 'https://max.ru/id100000000001_bot',
        },
      });

      expect(info.botId, 4004);
      expect(info.commands.map((c) => c.name), ['start', 'stats']);
      expect(info.commands.first.slash, '/start');
      expect(info.commands.first.description, 'Главное меню');
      expect(info.commands.last.description, isNull);
      expect(info.contact?.isBot, isTrue);
      expect(info.contact?.displayName, 'Тестовый бот');
      expect(info.description, 'Описание бота');
      expect(info.link, 'https://max.ru/id100000000001_bot');
    });

    test('tolerates a payload without commands or contact', () {
      final info = BotInfo.fromPayload(4005, const {});

      expect(info.commands, isEmpty);
      expect(info.contact, isNull);
      expect(info.link, isNull);
    });
  });
}
