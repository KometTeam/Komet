import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_parsing.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/core/media/deleted_media_keeper.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/utils/media_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;

  @override
  Future<String?> getTemporaryPath() async => directory;
}

const _accountId = 1;
const _chatId = 900101;
const _photoId = 555001;
const _photoUrl = 'https://synthetic.invalid/photo/555001';
final _photoBytes = List<int>.generate(64, (i) => i);

Map<String, dynamic> _photoMessageRow(String id) => CachedMessage(
  id: id,
  accountId: _accountId,
  chatId: _chatId,
  senderId: 20,
  time: 1000,
  payload: {
    'attaches': [
      {'_type': 'PHOTO', 'photoId': _photoId, 'baseUrl': _photoUrl},
    ],
  },
).toDbRow();

Future<Map<String, dynamic>?> _attachOf(String id) async {
  final row = await AppDatabase.loadMessage(_accountId, _chatId, id);
  final payload = jsonDecode(row!['payload'] as String) as Map;
  return Map<String, dynamic>.from((payload['attaches'] as List).first as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_deleted_media_test',
    );
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    MediaCache.resetForTesting();
    addTearDown(() async {
      await AppDatabase.close();
      MediaCache.resetForTesting();
      KometSettings.viewDeleted.value = false;
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
    await AppDatabase.saveChats([
      CachedChat(
        id: _chatId,
        accountId: _accountId,
        type: 'DIALOG',
        title: 'Synthetic dialog',
        unreadCount: 0,
        lastEventTime: 0,
        cachedAt: 0,
        dontDisturbUntil: 0,
        isOnline: false,
        seenTime: 0,
        participants: const {_accountId: 0, 20: 0},
      ).toDbRow()..['in_list'] = ChatListState.visible,
    ]);
    KometSettings.viewDeleted.value = true;
  });

  test('a deleted photo keeps a pinned copy the payload points at', () async {
    await AppDatabase.saveMessages([_photoMessageRow('101')]);
    final downloaded = await MediaCache.fileFor('photo_$_photoId.jpg');
    await downloaded.writeAsBytes(_photoBytes);

    await keepDeletedMedia(_accountId, _chatId, const ['101']);

    final attach = await _attachOf('101');
    final kept = attach!['localPath'] as String?;
    expect(kept, isNotNull);
    expect(kept, contains(MediaCache.keptPrefix));
    expect(await File(kept!).readAsBytes(), _photoBytes);
  });

  test('without the setting nothing is copied', () async {
    KometSettings.viewDeleted.value = false;
    await AppDatabase.saveMessages([_photoMessageRow('102')]);
    final downloaded = await MediaCache.fileFor('photo_$_photoId.jpg');
    await downloaded.writeAsBytes(_photoBytes);

    await keepDeletedMedia(_accountId, _chatId, const ['102']);

    expect((await _attachOf('102'))!['localPath'], isNull);
  });

  test('a dead link without a cached copy leaves the payload alone', () async {
    await AppDatabase.saveMessages([_photoMessageRow('103')]);

    await keepDeletedMedia(_accountId, _chatId, const ['103']);

    expect((await _attachOf('103'))!['localPath'], isNull);
  });
}
