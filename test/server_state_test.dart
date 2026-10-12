import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/cache/message_session_cache.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_admin_state.dart';
import 'package:komet/models/chat_info.dart';
import 'package:komet/models/chat_restriction.dart';

CachedMessage _message(String id, int time) => CachedMessage(
  id: id,
  accountId: 1,
  chatId: 10,
  senderId: 1,
  text: 'Synthetic $id',
  time: time,
  status: 'sent',
);

ChatInfo _group(Map<String, bool> options, {int adminPermissions = 118}) =>
    ChatInfo.fromMap({
      'id': -1000,
      'type': 'CHAT',
      'owner': 11,
      'adminParticipants': {
        '11': {'id': 11, 'permissions': 4095},
        '22': {'id': 22, 'permissions': adminPermissions},
      },
      'options': options,
    });

ChatAdminState _state(int myId, ChatInfo info) => ChatAdminState(
  chatId: -1000,
  myId: myId,
  name: 'Synthetic group',
  imageUrl: '',
  info: info,
);

void main() {
  group('MessageSessionCache.append', () {
    tearDown(MessageSessionCache.clearAll);

    test('adds delivered messages to a chat opened before', () {
      MessageSessionCache.save(1, 10, [
        _message('1', 100),
        _message('2', 200),
      ], reachedStart: true);

      MessageSessionCache.append(1, 10, [
        _message('2', 200),
        _message('3', 300),
      ]);

      final cached = MessageSessionCache.get(1, 10)!;
      expect(cached.messages.map((m) => m.id), ['1', '2', '3']);
      expect(cached.reachedStart, isTrue);
    });

    test('leaves chats that were never opened alone', () {
      MessageSessionCache.append(1, 20, [_message('9', 900)]);

      expect(MessageSessionCache.get(1, 20), isNull);
    });
  });

  group('ChatRestriction', () {
    test('reads the chat options', () {
      final info = _group({
        'DISABLE_FORWARD': true,
        'MESSAGE_COPY_NOT_ALLOWED': false,
        'CONFIRM_BEFORE_SEND': true,
      });

      expect(ChatRestriction.forwardDisabled.enabledIn(info), isTrue);
      expect(ChatRestriction.copyDisabled.enabledIn(info), isFalse);
      expect(ChatRestriction.confirmBeforeSend.enabledIn(info), isTrue);
    });

    test('writes a single option', () {
      expect(ChatRestriction.confirmBeforeSend.optionFor(true), {
        'CONFIRM_BEFORE_SEND': true,
      });
    });
  });

  group('adding members', () {
    test('anyone adds when the group allows it', () {
      final info = _group({'ONLY_ADMIN_CAN_ADD_MEMBER': false});

      expect(_state(33, info).canAddMembers, isTrue);
    });

    test('only admins with the right add when the group restricts it', () {
      final info = _group({'ONLY_ADMIN_CAN_ADD_MEMBER': true});

      expect(_state(33, info).canAddMembers, isFalse);
      expect(_state(11, info).canAddMembers, isTrue);
      expect(_state(22, info).canAddMembers, isTrue);
      expect(
        _state(
          22,
          _group({'ONLY_ADMIN_CAN_ADD_MEMBER': true}, adminPermissions: 0),
        ).canAddMembers,
        isFalse,
      );
    });
  });

  group('CachedChat options', () {
    CachedChat chat(Set<String> options) => CachedChat(
      id: -1,
      accountId: 1,
      type: 'CHANNEL',
      title: 'Synthetic channel',
      unreadCount: 0,
      lastEventTime: 1700000000000,
      cachedAt: 0,
      dontDisturbUntil: 0,
      isOnline: false,
      seenTime: 0,
      participants: const {1: 1700000000000},
      options: options,
    );

    test('comments follow the server switch', () {
      expect(chat({'COMMENTS'}).commentsEnabled, isTrue);
      expect(chat(const {}).commentsEnabled, isFalse);
    });

    test('confirmation follows the server switch', () {
      expect(chat({'CONFIRM_BEFORE_SEND'}).confirmBeforeSend, isTrue);
      expect(chat(const {}).confirmBeforeSend, isFalse);
    });
  });
}
