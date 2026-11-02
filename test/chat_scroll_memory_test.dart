import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/cache/chat_scroll_memory.dart';
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

const _accountId = 7;
const _chatId = 42;
const ChatScrollPoint _point = (id: 'msg-a', time: 1000, pixels: -137.5);
const ChatScrollPoint _newer = (id: 'msg-b', time: 2000, pixels: -40);

Future<void> _queuedWritesDone() =>
    AppDatabase.loadChatScrollPoints(_accountId);

Future<void> _reopenApp() async {
  ChatScrollMemory.forgetAccount(_accountId);
  await ChatScrollMemory.prime(_accountId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_chat_scroll_test',
    );
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    addTearDown(() async {
      ChatScrollMemory.forgetAccount(_accountId);
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

  test('сохранённая позиция переживает перезапуск', () async {
    ChatScrollMemory.remember(_accountId, _chatId, _point);
    await ChatScrollMemory.persist(_accountId, _chatId);

    await _reopenApp();

    expect(ChatScrollMemory.of(_accountId, _chatId), _point);
  });

  test('позиция у низа стирается и из базы', () async {
    ChatScrollMemory.remember(_accountId, _chatId, _point);
    await ChatScrollMemory.persist(_accountId, _chatId);

    ChatScrollMemory.remember(_accountId, _chatId, null);
    await ChatScrollMemory.persist(_accountId, _chatId);
    await _reopenApp();

    expect(ChatScrollMemory.of(_accountId, _chatId), isNull);
  });

  test('пока не вышли из чата, в базу ничего не пишется', () async {
    ChatScrollMemory.remember(_accountId, _chatId, _point);
    ChatScrollMemory.remember(_accountId, _chatId, _newer);
    expect(ChatScrollMemory.of(_accountId, _chatId), _newer);

    await _reopenApp();
    expect(ChatScrollMemory.of(_accountId, _chatId), isNull);
  });

  test('свежая позиция в памяти важнее старой из базы', () async {
    ChatScrollMemory.remember(_accountId, _chatId, _point);
    await ChatScrollMemory.persist(_accountId, _chatId);
    ChatScrollMemory.forgetAccount(_accountId);

    ChatScrollMemory.remember(_accountId, _chatId, _newer);
    await ChatScrollMemory.prime(_accountId);

    expect(ChatScrollMemory.of(_accountId, _chatId), _newer);
  });

  test('очистка истории забывает позицию', () async {
    ChatScrollMemory.remember(_accountId, _chatId, _point);
    await ChatScrollMemory.persist(_accountId, _chatId);

    ChatScrollMemory.forget(_accountId, _chatId);
    await _queuedWritesDone();
    await _reopenApp();

    expect(ChatScrollMemory.of(_accountId, _chatId), isNull);
  });

  test('позиции разных аккаунтов не смешиваются', () async {
    ChatScrollMemory.remember(_accountId, _chatId, _point);

    expect(ChatScrollMemory.of(_accountId + 1, _chatId), isNull);
    ChatScrollMemory.forgetAccount(_accountId + 1);
    expect(ChatScrollMemory.of(_accountId, _chatId), _point);
  });
}
