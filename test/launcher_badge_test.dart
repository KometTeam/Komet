import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/core/push/launcher_badge.dart';

CachedChat _chat(int id, {int unread = 0, bool muted = false}) => CachedChat(
  id: id,
  accountId: 1,
  type: 'DIALOG',
  title: 'Synthetic chat $id',
  unreadCount: unread,
  lastEventTime: 1700000000000,
  cachedAt: 0,
  dontDisturbUntil: muted ? -1 : ChatsModule.muteOff,
  isOnline: false,
  seenTime: 0,
  participants: const {1: 1700000000000},
);

BadgeCount _count(
  List<CachedChat> chats, {
  bool enabled = true,
  bool includeMuted = false,
  bool countMessages = true,
  Set<int> archived = const {},
}) => BadgeCount.of(
  chats,
  enabled: enabled,
  includeMuted: includeMuted,
  countMessages: countMessages,
  isArchived: (chat) => archived.contains(chat.id),
);

void main() {
  final chats = [
    _chat(1, unread: 3),
    _chat(2, unread: 5, muted: true),
    _chat(3),
    _chat(4, unread: 2),
  ];

  test('sums unread messages of chats with sound', () {
    final badge = _count(chats);

    expect(badge.count, 5);
    expect(badge.chatIds, {1, 4});
  });

  test('muted chats count when asked to', () {
    expect(_count(chats, includeMuted: true).count, 10);
  });

  test('counts chats instead of messages', () {
    final badge = _count(chats, countMessages: false, includeMuted: true);

    expect(badge.count, 3);
    expect(badge.byChats, isTrue);
  });

  test('archived chats stay out of the badge', () {
    expect(_count(chats, archived: {1}).count, 2);
  });

  test('a disabled badge is empty', () {
    final badge = _count(chats, enabled: false);

    expect(badge.count, 0);
    expect(badge.chatIds, isEmpty);
    expect(badge.toArgs()['enabled'], isFalse);
  });

  test('equal counts compare equal regardless of order', () {
    final a = _count(chats);
    final b = _count(chats.reversed.toList());

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == _count(chats, includeMuted: true), isFalse);
  });
}
