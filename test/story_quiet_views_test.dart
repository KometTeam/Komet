import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/stories.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/models/story.dart';
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

const _account = 101;
const _owner = StoryOwner(ownerId: 202);

Map<String, dynamic> _preview({int readCount = 0}) => {
  'owner': _owner.toMap(),
  'updateTime': 1000,
  'totalCount': 2,
  'readCount': readCount,
};

Map<String, dynamic> _story(int id, int now) => {
  'id': id,
  'owner': _owner.toMap(),
  'time': now,
  'expiration': const Duration(hours: 24).inMilliseconds,
};

class _StoriesApi extends Api {
  _StoriesApi(this.now);

  final int now;
  int serverReadCount = 0;
  final sentOpcodes = <int>[];

  @override
  SessionState get state => SessionState.online;

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    sentOpcodes.add(opcode);
    final Object body = switch (opcode) {
      Opcode.storiesList => {
        'storiesPreviews': [_preview(readCount: serverReadCount)],
      },
      Opcode.storiesGetByOwner => {
        'storiesPreviews': [_preview(readCount: serverReadCount)],
        'peerStories': [
          {
            'owner': _owner.toMap(),
            'stories': [_story(1, now), _story(2, now)],
          },
        ],
      },
      _ => <String, dynamic>{},
    };
    if (opcode == Opcode.storiesMark) serverReadCount++;
    return Packet(cmd: CmdType.ok, payload: body);
  }
}

Future<void> _drainWrites() async {
  await Future<void>.delayed(Duration.zero);
  await AppDatabase.getSyncValue(_account, 'stories_previews');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _StoriesApi api;
  late StoriesModule stories;

  setUpAll(AppDatabase.init);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'active_account_id': '$_account'});
    final directory = await Directory.systemTemp.createTemp('synthetic_story');
    final previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    await databaseFactory.setDatabasesPath(directory.path);
    await AppDatabase.saveProfile(ProfileData.stub(_account));
    api = _StoriesApi(DateTime.now().millisecondsSinceEpoch);
    stories = StoriesModule(api);
    addTearDown(() async {
      KometSettings.antiStoryView.value = false;
      await _drainWrites();
      await api.dispose();
      await AppDatabase.close();
      PathProviderPlatform.instance = previousProvider;
      await directory.delete(recursive: true);
    });
  });

  test('a quiet view never reaches the server but dims the ring', () async {
    KometSettings.antiStoryView.value = true;
    await stories.loadFeed();
    await stories.getByOwner(_owner);
    api.sentOpcodes.clear();

    expect(await stories.mark(_owner, 1), isTrue);
    expect(api.sentOpcodes, isEmpty);
    expect(stories.previewFor(_owner.ownerId)!.readCount, 1);
    expect(stories.previews.single.hasUnread, isTrue);

    await stories.mark(_owner, 2);
    expect(api.sentOpcodes, isEmpty);
    expect(stories.previewFor(_owner.ownerId)!.readCount, 2);
    expect(stories.previewOf(_owner.ownerId)!.hasUnread, isFalse);
  });

  test('quiet views survive a fresh feed and a restart', () async {
    KometSettings.antiStoryView.value = true;
    await stories.loadFeed();
    await stories.getByOwner(_owner);
    await stories.mark(_owner, 1);

    await stories.loadFeed();
    expect(stories.previewFor(_owner.ownerId)!.readCount, 1);

    await _drainWrites();
    final restarted = StoriesModule(api);
    await restarted.loadCache();
    expect(restarted.previewFor(_owner.ownerId)!.readCount, 1);
  });

  test(
    'turning the mode off marks on the server without double counting',
    () async {
      KometSettings.antiStoryView.value = true;
      await stories.loadFeed();
      await stories.getByOwner(_owner);
      await stories.mark(_owner, 1);

      KometSettings.antiStoryView.value = false;
      api.sentOpcodes.clear();
      await stories.mark(_owner, 1);
      expect(api.sentOpcodes, [Opcode.storiesMark]);

      await stories.loadFeed();
      expect(stories.previewFor(_owner.ownerId)!.readCount, 1);
    },
  );
}
