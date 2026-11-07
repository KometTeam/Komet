import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/ghost_read_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _account = 900001;
const int _chat = 900201;

GhostRead _read() => GhostReadStore.instance.of(_account, _chat)!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GhostReadStore.instance.clearAll();
    await GhostReadStore.instance.load();
  });

  test(
    'a chat read locally stays read while the server still counts it',
    () async {
      await GhostReadStore.instance.noteLocalRead(
        _account,
        _chat,
        mark: 1000,
        left: 0,
        serverUnread: 5,
        serverOwnMark: 400,
      );
      expect(_read().unreadFor(5, lastMessageTime: 1000), 0);
      expect(_read().unreadFor(5), 0);
    },
  );

  test('messages arriving after the local read are counted', () async {
    await GhostReadStore.instance.noteLocalRead(
      _account,
      _chat,
      mark: 1000,
      left: 0,
      serverUnread: 5,
      serverOwnMark: 400,
    );
    await GhostReadStore.instance.noteServer(_account, _chat, unread: 8);
    expect(_read().unreadFor(8, lastMessageTime: 1300), 3);
  });

  test('reading again rebases on the latest server count', () async {
    await GhostReadStore.instance.noteLocalRead(
      _account,
      _chat,
      mark: 1000,
      left: 0,
      serverUnread: 5,
      serverOwnMark: 400,
    );
    await GhostReadStore.instance.noteServer(_account, _chat, unread: 8);
    await GhostReadStore.instance.noteLocalRead(
      _account,
      _chat,
      mark: 1300,
      left: 0,
      serverUnread: 0,
      serverOwnMark: 0,
    );
    expect(_read().mark, 1300);
    expect(_read().serverOwnMark, 400);
    expect(_read().unreadFor(8, lastMessageTime: 1300), 0);
    expect(_read().unreadFor(9, lastMessageTime: 1400), 1);
  });

  test('a partial read keeps what is left below', () async {
    await GhostReadStore.instance.noteLocalRead(
      _account,
      _chat,
      mark: 1000,
      left: 2,
      serverUnread: 5,
      serverOwnMark: 400,
    );
    expect(_read().unreadFor(5, lastMessageTime: 1200), 2);
  });

  test('the count never goes below zero or above the server count', () async {
    await GhostReadStore.instance.noteLocalRead(
      _account,
      _chat,
      mark: 1000,
      left: 4,
      serverUnread: 5,
      serverOwnMark: 400,
    );
    expect(_read().unreadFor(2, lastMessageTime: 1200), 1);
    expect(_read().unreadFor(0, lastMessageTime: 1200), 0);
  });
}
