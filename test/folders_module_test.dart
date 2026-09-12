import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/models/chat_folder.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/folders.dart';

const int _me = 4242;
const int _contactId = 777;

CachedChat _chat({
  required int id,
  required String type,
  int unreadCount = 0,
  int dontDisturbUntil = 0,
  Set<String> options = const {},
  int? owner,
}) => CachedChat(
  id: id,
  accountId: _me,
  type: type,
  title: 'chat $id',
  unreadCount: unreadCount,
  lastEventTime: 1700000000000,
  cachedAt: 0,
  dontDisturbUntil: dontDisturbUntil,
  isOnline: false,
  seenTime: 0,
  participants: {_me: 1700000000000},
  options: options,
  owner: owner,
);

bool _matches(CachedChat chat, ChatFolder folder) =>
    FoldersModule.chatMatchesFolder(
      chat,
      folder,
      myId: _me,
      contactIds: const {_contactId},
    );

void main() {
  group('ChatFolder.fromJson', () {
    test('reads the server payload of FOLDERS_UPDATE', () {
      final folder = ChatFolder.fromJson(const {
        'id': '6fd177c5-ba2e-4360-9593-3ae798326806',
        'title': 'Каналы',
        'include': [111, -222],
        'filters': [0, 11, 2],
        'favorites': [111],
        'options': [1, 2],
        'updateTime': 1700000000000,
        'sourceId': 1,
      });

      expect(folder.id, '6fd177c5-ba2e-4360-9593-3ae798326806');
      expect(folder.include, [111, -222]);
      expect(folder.filters, [
        FolderFilter.unread,
        FolderFilter.notMuted,
        FolderFilter.channel,
      ]);
      expect(folder.favorites, [111]);
      expect(folder.updateTime, 1700000000000);
      expect(folder.sourceId, 1);
      expect(folder.canDelete, isFalse);
      expect(folder.canEditTitle, isFalse);
      expect(folder.canEditFilters, isTrue);
    });

    test('normalizes legacy string filters and the hideEmpty flag', () {
      final folder = ChatFolder.fromJson(const {
        'id': 'legacy',
        'title': 'legacy',
        'filters': ['CHANNEL', 'GROUP'],
        'hideEmpty': true,
      });

      expect(folder.filters, [FolderFilter.channel, FolderFilter.chat]);
      expect(folder.options, [FolderOption.hideEmpty]);
      expect(folder.hideEmpty, isTrue);
    });
  });

  group('chatMatchesFolder', () {
    const channelsFolder = ChatFolder(
      id: 'f1',
      title: 'Каналы',
      filters: [FolderFilter.channel],
    );

    test('type filters are combined with OR', () {
      const folder = ChatFolder(
        id: 'f2',
        title: 'Каналы и боты',
        filters: [FolderFilter.channel, FolderFilter.bot],
      );

      expect(_matches(_chat(id: 1, type: 'CHANNEL'), folder), isTrue);
      expect(
        _matches(_chat(id: 2, type: 'DIALOG', options: {'BOT'}), folder),
        isTrue,
      );
      expect(_matches(_chat(id: 3, type: 'CHAT'), folder), isFalse);
    });

    test('a folder without filters only holds its included chats', () {
      const folder = ChatFolder(id: 'f3', title: 'Свои', include: [10]);

      expect(_matches(_chat(id: 10, type: 'CHAT'), folder), isTrue);
      expect(_matches(_chat(id: 11, type: 'CHAT'), folder), isFalse);
    });

    test('show-only filters narrow both types and included chats', () {
      const folder = ChatFolder(
        id: 'f4',
        title: 'Непрочитанные каналы',
        include: [10],
        filters: [FolderFilter.channel, FolderFilter.unread],
      );

      expect(
        _matches(_chat(id: 1, type: 'CHANNEL', unreadCount: 3), folder),
        isTrue,
      );
      expect(_matches(_chat(id: 2, type: 'CHANNEL'), folder), isFalse);
      expect(
        _matches(_chat(id: 10, type: 'CHAT', unreadCount: 1), folder),
        isTrue,
      );
      expect(_matches(_chat(id: 10, type: 'CHAT'), folder), isFalse);
    });

    test('show-only filters are combined with AND', () {
      const folder = ChatFolder(
        id: 'f5',
        title: 'Непрочитанные с уведомлениями',
        filters: [
          FolderFilter.channel,
          FolderFilter.unread,
          FolderFilter.notMuted,
        ],
      );

      expect(
        _matches(_chat(id: 1, type: 'CHANNEL', unreadCount: 1), folder),
        isTrue,
      );
      expect(
        _matches(
          _chat(id: 2, type: 'CHANNEL', unreadCount: 1, dontDisturbUntil: -1),
          folder,
        ),
        isFalse,
      );
    });

    test('an expired mute counts as not muted', () {
      const folder = ChatFolder(
        id: 'f6',
        title: 'С уведомлениями',
        filters: [FolderFilter.channel, FolderFilter.notMuted],
      );

      expect(
        _matches(
          _chat(id: 1, type: 'CHANNEL', dontDisturbUntil: 1700000000000),
          folder,
        ),
        isTrue,
      );
    });

    test('unknown filters do not empty a folder', () {
      const folder = ChatFolder(
        id: 'f7',
        title: 'Каналы',
        filters: [FolderFilter.channel, FolderFilter.markedUnread],
      );

      expect(_matches(_chat(id: 1, type: 'CHANNEL'), folder), isTrue);
    });

    test('role filters keep only chats with that role', () {
      const folder = ChatFolder(
        id: 'f8',
        title: 'Мои группы',
        filters: [FolderFilter.chat, FolderFilter.owner],
      );

      expect(_matches(_chat(id: 1, type: 'CHAT', owner: _me), folder), isTrue);
      expect(_matches(_chat(id: 2, type: 'CHAT', owner: 5), folder), isFalse);
    });

    test('channels folder ignores groups and dialogs', () {
      expect(_matches(_chat(id: 1, type: 'CHANNEL'), channelsFolder), isTrue);
      expect(_matches(_chat(id: 2, type: 'CHAT'), channelsFolder), isFalse);
      expect(_matches(_chat(id: 3, type: 'DIALOG'), channelsFolder), isFalse);
    });
  });

  group('chatsForFolder', () {
    List<int> ids(
      List<CachedChat> chats,
      ChatFolder folder, {
      Set<int> archived = const {},
    }) => FoldersModule.chatsForFolder(
      chats,
      folder,
      myId: _me,
      contactIds: const {_contactId},
      archivedIds: archived,
    ).map((c) => c.id).toList();

    test('an archived chat stays in the folder it was added to by hand', () {
      const folder = ChatFolder(id: 'f10', title: 'Свои', include: [10, 11]);
      final chats = [_chat(id: 10, type: 'CHAT'), _chat(id: 11, type: 'CHAT')];

      expect(ids(chats, folder, archived: {10, 11}), [10, 11]);
    });

    test('archiving hides a chat that only matched a type filter', () {
      const folder = ChatFolder(
        id: 'f11',
        title: 'Каналы',
        filters: [FolderFilter.channel],
      );
      final chats = [
        _chat(id: 20, type: 'CHANNEL'),
        _chat(id: 21, type: 'CHANNEL'),
      ];

      expect(ids(chats, folder, archived: {21}), [20]);
    });

    test('show-only filters still apply to an archived included chat', () {
      const folder = ChatFolder(
        id: 'f12',
        title: 'Непрочитанные',
        include: [30, 31],
        filters: [FolderFilter.unread],
      );
      final chats = [
        _chat(id: 30, type: 'CHAT', unreadCount: 2),
        _chat(id: 31, type: 'CHAT'),
      ];

      expect(ids(chats, folder, archived: {30, 31}), [30]);
    });

    test('without an archive the result matches chatMatchesFolder', () {
      const folder = ChatFolder(
        id: 'f13',
        title: 'Каналы и свои',
        include: [41],
        filters: [FolderFilter.channel],
      );
      final chats = [
        _chat(id: 40, type: 'CHANNEL'),
        _chat(id: 41, type: 'CHAT'),
        _chat(id: 42, type: 'DIALOG'),
      ];

      expect(ids(chats, folder), [40, 41]);
    });
  });

  group('newFolderId', () {
    test('generates distinct uuid v4 ids', () {
      final a = FoldersModule.newFolderId();
      final b = FoldersModule.newFolderId();

      expect(a, isNot(b));
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(a),
        isTrue,
      );
    });
  });
}
