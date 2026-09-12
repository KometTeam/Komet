import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';

void main() {
  test('active chats stay in the list', () {
    expect(chatListStateForStatus('ACTIVE'), ChatListState.visible);
  });

  test('closed, removed and left chats are hidden', () {
    for (final status in const ['CLOSED', 'REMOVED', 'LEFT', 'HIDDEN']) {
      expect(chatListStateForStatus(status), ChatListState.hidden);
    }
  });

  test('unknown status is treated as not live', () {
    expect(chatListStateForStatus('ARCHIVED_FOREVER'), ChatListState.hidden);
  });

  test('missing status keeps the state the chat already had', () {
    expect(
      chatListStateForStatus(null, previous: ChatListState.hidden),
      ChatListState.hidden,
    );
    expect(
      chatListStateForStatus(null, previous: ChatListState.visible),
      ChatListState.visible,
    );
    expect(chatListStateForStatus(null), ChatListState.visible);
    expect(
      chatListStateForStatus(null, previous: ChatListState.notInList),
      ChatListState.visible,
    );
  });
}
