import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';

const int _me = 4242;
const int _chatId = -1000000000001;

CachedChat _cached({int? favIndex}) => CachedChat(
  id: _chatId,
  accountId: _me,
  type: 'CHAT',
  title: 'pinned chat',
  unreadCount: 0,
  lastEventTime: 1700000000000,
  cachedAt: 0,
  favIndex: favIndex,
  dontDisturbUntil: 0,
  isOnline: false,
  seenTime: 0,
  participants: {_me: 1700000000000},
);

CachedChat _parse({
  Map<dynamic, dynamic> chatsConfig = const {},
  CachedChat? existing,
}) => parseChatRow(
  {
    'id': _chatId,
    'type': 'CHAT',
    'title': 'pinned chat',
    'lastEventTime': 1700000000000,
    'participants': {'$_me': 1700000000000},
  },
  _me,
  _me,
  const {},
  chatsConfig,
  const {},
  existing == null ? const {} : {_chatId: existing},
  0,
)!;

void main() {
  group('login sync keeps pins', () {
    test('a zero favIndex in the config does not unpin a cached chat', () {
      final parsed = _parse(
        chatsConfig: {
          '$_chatId': {'favIndex': 0, 'dontDisturbUntil': 0},
        },
        existing: _cached(favIndex: 3),
      );
      expect(parsed.favIndex, 3);
    });

    test('a real favIndex from the config wins', () {
      final parsed = _parse(
        chatsConfig: {
          '$_chatId': {'favIndex': 2, 'dontDisturbUntil': 0},
        },
        existing: _cached(favIndex: 3),
      );
      expect(parsed.favIndex, 2);
    });

    test('mute settings still come from the config', () {
      final parsed = _parse(
        chatsConfig: {
          '$_chatId': {'favIndex': 0, 'dontDisturbUntil': -1},
        },
        existing: _cached(favIndex: 3),
      );
      expect(parsed.dontDisturbUntil, -1);
      expect(parsed.isMuted, isTrue);
    });

    test('a chat with no cached pin stays unpinned', () {
      final parsed = _parse(
        chatsConfig: {
          '$_chatId': {'favIndex': 0, 'dontDisturbUntil': 0},
        },
      );
      expect(parsed.favIndex, isNull);
    });

    test('without a config entry the cached pin survives', () {
      expect(_parse(existing: _cached(favIndex: 5)).favIndex, 5);
    });
  });
}
