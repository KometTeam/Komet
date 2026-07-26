import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';

const int _me = 4242;
const int _peer = 7331;
const int _chatId = -1000000000001;

const int _readMark = 1700000000000;
const int _mentionTime = 1700000005000;
const int _lastMsgTime = 1700000010000;

const int _mentionId = 111411200327680777;
const int _lastMsgId = 111411200655360012;
const int _oldMentionId = 111411196067840005;

CachedChat _chat({
  int? mentionId,
  int readMark = _readMark,
  int unread = 2,
}) => CachedChat(
  id: _chatId,
  accountId: _me,
  type: 'CHAT',
  unreadCount: unread,
  lastEventTime: _lastMsgTime,
  cachedAt: 0,
  dontDisturbUntil: 0,
  isOnline: false,
  seenTime: 0,
  participants: {_me: readMark, _peer: _lastMsgTime},
  lastMentionMsgId: mentionId,
);

void main() {
  group('message id', () {
    test('carries the timestamp in its high bits', () {
      expect(messageIdToTime(_mentionId), _mentionTime);
      expect(messageIdToTime(_lastMsgId), _lastMsgTime);
      expect(messageIdToTime(_oldMentionId), _readMark - 60000);
    });
  });

  group('hasUnreadMention', () {
    test('is set when the mention is newer than my read mark', () {
      expect(_chat(mentionId: _mentionId).hasUnreadMention, isTrue);
    });

    test('stays off for a mention I have already read', () {
      expect(_chat(mentionId: _oldMentionId).hasUnreadMention, isFalse);
    });

    test('clears once the read mark passes the mention', () {
      final read = _chat(
        mentionId: _mentionId,
        readMark: _lastMsgTime,
        unread: 0,
      );
      expect(read.hasUnreadMention, isFalse);
    });

    test('is false without a mention id', () {
      expect(_chat().hasUnreadMention, isFalse);
    });
  });

  group('parseChatRow', () {
    CachedChat parse(Map<String, dynamic> chat) => parseChatRow(
      chat,
      _me,
      _me,
      const {},
      const {},
      const {},
      const {},
      0,
    )!;

    test('reads lastMentionMessageId from the server chat', () {
      final chat = parse({
        'id': _chatId,
        'type': 'CHAT',
        'title': 'test mention',
        'newMessages': 2,
        'lastEventTime': _lastMsgTime,
        'participants': {'$_me': _readMark},
        'lastMentionMessageId': '$_mentionId',
      });

      expect(chat.lastMentionMsgId, _mentionId);
      expect(chat.hasUnreadMention, isTrue);
    });

    test('a chat without mentions keeps the badge off', () {
      final chat = parse({
        'id': _chatId,
        'type': 'CHAT',
        'title': 'test',
        'lastEventTime': _lastMsgTime,
        'participants': {'$_me': _readMark},
      });

      expect(chat.lastMentionMsgId, isNull);
      expect(chat.hasUnreadMention, isFalse);
    });
  });

  group('messageMentionsUser', () {
    test('matches a USER_MENTION addressed to me', () {
      expect(
        messageMentionsUser(const {
          'elements': [
            {'type': 'USER_MENTION', 'entityId': _me, 'length': 15},
          ],
        }, _me),
        isTrue,
      );
    });

    test('ignores a mention of somebody else', () {
      expect(
        messageMentionsUser(const {
          'elements': [
            {'type': 'USER_MENTION', 'entityId': _peer, 'length': 15},
          ],
        }, _me),
        isFalse,
      );
    });

    test('ignores messages without elements', () {
      expect(messageMentionsUser(const {'text': 'privet'}, _me), isFalse);
    });
  });
}
