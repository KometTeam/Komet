import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/forward_sender.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

CachedMessage _message(String id, {List<Map<String, dynamic>>? attaches}) {
  final payload = <String, dynamic>{
    'id': id,
    'text': 'Synthetic $id',
    'attaches': attaches ?? const [],
  };
  final (attachments, isControl) = CachedMessage.parseAttachments(payload);
  return CachedMessage(
    id: id,
    accountId: 1,
    chatId: 10,
    senderId: 9,
    text: 'Synthetic $id',
    time: 1000,
    payload: payload,
    attachments: attachments,
    isControl: isControl,
  );
}

ForwardRequest _request({bool hideSender = false, CachedMessage? extra}) =>
    ForwardRequest(
      sourceChatId: 10,
      sourceChatName: 'Synthetic chat',
      sourceChatIconUrl: '',
      sourceChatType: 'CHAT',
      messages: [_message('701'), _message('702'), ?extra],
      hideSender: hideSender,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'synthetic_forward_resume',
    );
    final previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    await AppDatabase.init();
    await databaseFactory.setDatabasesPath(directory.path);
    addTearDown(() async {
      await AppDatabase.close();
      PathProviderPlatform.instance = previousProvider;
      await directory.delete(recursive: true);
    });
  });

  test('a chat that already got everything is not sent to again', () async {
    final result = await ForwardSender.send(
      accountId: 1,
      chatIds: [20],
      request: _request(),
      resumeFrom: {20: 2},
    );

    expect(result.delivered, {20});
    expect(result.unfinished, isEmpty);
  });

  test('a failed chat reports the step it stopped at', () async {
    final result = await ForwardSender.send(
      accountId: 1,
      chatIds: [20, 30],
      request: _request(),
      caption: const ForwardCaption('Synthetic note'),
      resumeFrom: {20: 2},
    );

    expect(result.delivered, isEmpty);
    expect(result.unfinished, {20: 2, 30: 0});
  });

  test('a batch that cannot hide the sender sends nothing', () async {
    final result = await ForwardSender.send(
      accountId: 1,
      chatIds: [20],
      request: _request(
        hideSender: true,
        extra: _message(
          '703',
          attaches: [
            {'_type': 'POLL', 'title': 'Synthetic poll'},
          ],
        ),
      ),
    );

    expect(result.delivered, isEmpty);
    expect(result.unfinished, {20: 0});
  });
}
