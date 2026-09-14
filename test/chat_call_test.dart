import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/models/chat_call.dart';
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

Map<String, dynamic> _ongoingCall({String callType = 'AUDIO'}) => {
  'conversationId': 'synthetic-conversation',
  'joinLink': 'synthetic-join-token',
  'type': 1,
  'approxParticipantsCount': 2,
  'previewParticipantIds': [11, 12],
  'callType': callType,
};

Map<String, dynamic> _endedCall() => {
  'conversationId': 'synthetic-conversation',
  'joinLink': 'synthetic-join-token',
  'type': 1,
  'previewParticipantIds': const [],
  'callType': 'AUDIO',
};

Map<String, dynamic> _groupChat(int id, {Map<String, dynamic>? call}) => {
  'id': id,
  'type': 'CHAT',
  'status': 'ACTIVE',
  'title': 'Synthetic group',
  'participants': {'$_accountId': 0, '11': 0, '12': 0},
  'videoConversation': ?call,
};

void main() {
  group('ChatCall', () {
    test('reads an ongoing call', () {
      final call = ChatCall.fromServer(_ongoingCall())!;

      expect(call.joinLink, 'synthetic-join-token');
      expect(call.participantsCount, 2);
      expect(call.participantIds, [11, 12]);
      expect(call.isVideo, isFalse);
      expect(
        ChatCall.fromServer(_ongoingCall(callType: 'VIDEO'))!.isVideo,
        isTrue,
      );
    });

    test('treats a call without participants as ended', () {
      expect(ChatCall.fromServer(_endedCall()), isNull);
      expect(ChatCall.fromServer(null), isNull);
    });

    test('survives a round trip through its stored form', () {
      final call = ChatCall.fromServer(_ongoingCall(callType: 'VIDEO'))!;
      final restored = ChatCall.decode(call.encode())!;

      expect(restored.joinLink, call.joinLink);
      expect(restored.isVideo, isTrue);
      expect(restored.participantsCount, 2);
      expect(restored.participantIds, [11, 12]);
    });

    test('a chat row carries its call and notices when it ends', () {
      final ongoing = parseChatRow(
        _groupChat(-500, call: _ongoingCall()),
        _accountId,
        _accountId,
        const {},
        const {},
        const {},
        const {},
        0,
      )!;
      final ended = parseChatRow(
        _groupChat(-500, call: _endedCall()),
        _accountId,
        _accountId,
        const {},
        const {},
        const {},
        const {},
        0,
      )!;

      expect(ongoing.activeCall?.joinLink, 'synthetic-join-token');
      expect(CachedChat.fromDbRow(ongoing.toDbRow()).activeCall, isNotNull);
      expect(ended.activeCall, isNull);
      expect(sameChatContent(ongoing, ended), isFalse);
    });
  });

  group('stored chat', () {
    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'synthetic_chat_call_test',
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

    test('keeps a call until the server reports it ended', () async {
      const chatId = -600;
      await chats.cacheServerChat(
        _groupChat(chatId, call: _ongoingCall()),
        _accountId,
      );
      final during = (await chats.getChat(_accountId, chatId)).single;
      expect(during.activeCall?.participantsCount, 2);

      await chats.cacheServerChat(
        _groupChat(chatId, call: _endedCall()),
        _accountId,
      );
      final after = (await chats.getChat(_accountId, chatId)).single;
      expect(after.activeCall, isNull);
    });
  });
}
