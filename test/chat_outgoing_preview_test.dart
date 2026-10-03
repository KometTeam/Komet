import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/core/storage/app_database.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_outgoing_preview_test',
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

  Future<CachedChat> chatRow(int chatId) async =>
      (await chats.getChat(_accountId, chatId)).single;

  test(
    'a confirmation dated before the phone clock still clears the clock',
    () async {
      const chatId = 900101;
      await openNewDialog(chatId, 40);

      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: 'temp_1',
        time: 2000,
        text: 'Synthetic ping',
        status: 'sending',
      );
      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: '601',
        time: 1990,
        text: 'Synthetic ping',
        status: 'sent',
        replacesTime: 2000,
      );

      final chat = await chatRow(chatId);
      expect(chat.lastMsgStatus, 'sent');
      expect(chat.lastMsgId, 601);
      expect(chat.lastMsgTime, 1990);
    },
  );

  test(
    'confirming an earlier message keeps a newer one still sending',
    () async {
      const chatId = 900102;
      await openNewDialog(chatId, 41);

      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: 'temp_1',
        time: 2000,
        text: 'Synthetic first',
        status: 'sending',
      );
      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: 'temp_2',
        time: 2005,
        text: 'Synthetic second',
        status: 'sending',
      );
      await chats.applyOutgoing(
        _accountId,
        chatId,
        messageId: '602',
        time: 1995,
        text: 'Synthetic first',
        status: 'sent',
        replacesTime: 2000,
      );

      final chat = await chatRow(chatId);
      expect(chat.lastMsgText, 'Synthetic second');
      expect(chat.lastMsgStatus, 'sending');
    },
  );
}
