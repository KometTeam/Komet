import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/models/attachment.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

const _accountId = 1;

Map<String, dynamic> _dialogCard(
  int chatId,
  int peerId, {
  String status = 'ACTIVE',
}) => {
  'id': chatId,
  'type': 'DIALOG',
  'status': status,
  'participants': {'$_accountId': 0, '$peerId': 0},
};

Map<String, dynamic> _groupWithCall(int chatId) => {
  'id': chatId,
  'type': 'CHAT',
  'status': 'ACTIVE',
  'title': 'Synthetic group',
  'participants': {'$_accountId': 0, '31': 0},
  'videoConversation': {
    'joinLink': 'synthetic-join-token',
    'approxParticipantsCount': 1,
    'previewParticipantIds': [31],
    'callType': 'AUDIO',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_first_message_listing_test',
    );
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    addTearDown(() async {
      await AppDatabase.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    await AppDatabase.init();
    await AppDatabase.saveProfile(
      ProfileData(
        id: _accountId,
        firstName: 'Synthetic owner',
        phone: 100000,
        country: 'ZZ',
        accountStatus: 0,
        updateTime: 1,
      ),
    );
  });

  Future<void> openNewDialog(int chatId, int peerId) async {
    await chats.cacheServerChat(
      _dialogCard(chatId, peerId),
      _accountId,
      inList: false,
    );
  }

  bool shownInChatList(int chatId) =>
      chats.chatsSnapshot().any((chat) => chat.id == chatId);

  test(
    'a confirmed first message puts a new dialog into the chat list',
    () async {
      const chatId = 900001;
      await openNewDialog(chatId, 20);
      expect(await AppDatabase.isChatInList(_accountId, chatId), isFalse);

      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: '501',
        time: 1000,
        text: 'Synthetic hello',
        status: 'sent',
      );

      expect(await AppDatabase.isChatInList(_accountId, chatId), isTrue);
      expect(shownInChatList(chatId), isTrue);
      final chat = (await chats.getChat(_accountId, chatId)).single;
      expect(chat.lastMsgText, 'Synthetic hello');
    },
  );

  test(
    'a message that is still sending keeps the dialog out of the list',
    () async {
      const chatId = 900002;
      await openNewDialog(chatId, 21);

      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: 'temp_1',
        time: 1000,
        text: 'Synthetic draft',
        status: 'sending',
      );

      expect(await AppDatabase.isChatInList(_accountId, chatId), isFalse);
      expect(shownInChatList(chatId), isFalse);
    },
  );

  test('later updates keep a dialog that was put into the list', () async {
    const chatId = 900003;
    await openNewDialog(chatId, 22);
    await chats.applyOutgoing(
      _accountId,
      chatId,
      messageId: '601',
      time: 1000,
      text: 'Synthetic first',
      status: 'sent',
    );

    await chats.applyOutgoing(
      _accountId,
      chatId,
      messageId: 'temp_2',
      time: 2000,
      text: 'Synthetic second',
      status: 'sending',
    );

    expect(await AppDatabase.isChatInList(_accountId, chatId), isTrue);
    expect(shownInChatList(chatId), isTrue);
  });

  test('a confirmed message leaves a hidden chat hidden', () async {
    const chatId = 900004;
    await chats.cacheServerChat(
      _dialogCard(chatId, 23, status: 'HIDDEN'),
      _accountId,
    );

    await chats.applyOutgoing(
      _accountId,
      chatId,
      messageId: '701',
      time: 1000,
      text: 'Synthetic note',
      status: 'sent',
    );

    expect(shownInChatList(chatId), isFalse);
    final rows = await AppDatabase.loadChat(_accountId, chatId);
    expect(rows.single['in_list'], ChatListState.hidden);
  });

  test('a message update keeps the call that is going on', () async {
    const chatId = -900005;
    await chats.cacheServerChat(_groupWithCall(chatId), _accountId);

    await chats.applyOutgoing(
      _accountId,
      chatId,
      messageId: '801',
      time: 1000,
      text: 'Synthetic hello',
      status: 'sent',
    );

    final chat = (await chats.getChat(_accountId, chatId)).single;
    expect(chat.lastMsgText, 'Synthetic hello');
    expect(chat.activeCall?.joinLink, 'synthetic-join-token');
  });

  test('a subscribed channel found only on disk opens a forward', () async {
    const chatId = -900006;
    final row = CachedChat(
      id: chatId,
      accountId: _accountId,
      type: 'CHANNEL',
      title: 'Synthetic private channel',
      unreadCount: 0,
      lastEventTime: 0,
      cachedAt: 0,
      dontDisturbUntil: 0,
      isOnline: false,
      seenTime: 0,
      participants: const {_accountId: 0},
    ).toDbRow()..['in_list'] = ChatListState.visible;
    await AppDatabase.saveChats([row]);
    const forwarded = ForwardedMessageAttachment(
      originalSenderId: 0,
      originalType: 'CHANNEL',
      originalChatId: chatId,
      originalChatAccess: 'PRIVATE',
    );
    final api = Api();
    addTearDown(api.dispose);

    expect(chats.canAccessForwardSource(forwarded), isFalse);
    expect(
      await chats.canOpenForwardSource(api, _accountId, forwarded),
      isTrue,
    );
  });
}
