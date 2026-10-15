import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/account/account_models.dart';
import 'package:komet/backend/modules/account/privacy_module.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/storage/token_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accountId = 1;

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

class _CategoryApi extends Api {
  final Map<String, dynamic> push = {
    'CHATS_PUSH_NOTIFICATION': 'ON',
    'PUSH_DETAILS': true,
    'M_CALL_PUSH_NOTIFICATION': 'ON',
  };
  final Map<String, dynamic> privacy = {
    'SEARCH_BY_PHONE': 'CONTACTS',
    'PUSH_NEW_CONTACTS': true,
    'SAFE_MODE': true,
  };

  bool online = true;

  @override
  SessionState get state =>
      online ? SessionState.online : SessionState.disconnected;

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    final settings = (payload['settings'] as Map)['user'] as Map;
    final category = settings.keys.every(push.containsKey)
        ? push
        : settings.keys.every(privacy.containsKey)
        ? privacy
        : null;
    if (category == null) {
      throw const PacketError(
        'Неизвестная ошибка',
        errorKey: 'error.push.wrong.category',
      );
    }
    category.addAll(settings.cast<String, dynamic>());
    return Packet(
      cmd: CmdType.ok,
      opcode: opcode,
      payload: {'user': Map<String, dynamic>.of(category)},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CategoryApi api;
  late PrivacyModule module;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_privacy_config_test',
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
    await TokenStorage.setActiveAccount(_accountId);

    api = _CategoryApi();
    module = PrivacyModule(api);
    await module.storeLoginConfig(_accountId, {...api.push, ...api.privacy});
  });

  test('a push answer keeps the stored privacy settings', () async {
    final config = await module.setChatsPushNotification(
      PrivacyConfig.pushReplies,
    );

    expect(config.chatsPushNotification, PrivacyConfig.pushReplies);
    expect(config.searchByPhone, 'CONTACTS');
    expect(config.safeMode, isTrue);
    expect(config.pushNewContacts, isTrue);
    expect(
      (await module.getPrivacyConfig()).chatsPushNotification,
      PrivacyConfig.pushReplies,
    );
  });

  test('a privacy answer keeps the stored push settings', () async {
    await module.setChatsPushNotification(PrivacyConfig.pushOff);

    final config = await module.setNewContacts(false);

    expect(config.pushNewContacts, isFalse);
    expect(config.chatsPushNotification, PrivacyConfig.pushOff);
    expect(config.pushDetails, isTrue);
  });

  test('a partial login config does not reset the other category', () async {
    await module.storeLoginConfig(_accountId, {'PUSH_DETAILS': false});

    final config = await module.getPrivacyConfig();

    expect(config.pushDetails, isFalse);
    expect(config.searchByPhone, 'CONTACTS');
    expect(config.safeMode, isTrue);
  });

  test('a key the server rejects stays switched locally', () async {
    final config = await module.setDialogsPushNotification(
      PrivacyConfig.pushOff,
    );

    expect(config.dialogsPushNotification, PrivacyConfig.pushOff);
    expect(config.safeMode, isTrue);
    expect(
      (await module.getPrivacyConfig()).dialogsPushNotification,
      PrivacyConfig.pushOff,
    );
  });

  test(
    'a switch flipped offline is kept and survives the next login',
    () async {
      api.online = false;

      final config = await module.setChatsPushNotification(
        PrivacyConfig.pushOff,
      );
      await module.storeLoginConfig(_accountId, {
        'CHATS_PUSH_NOTIFICATION': PrivacyConfig.pushOn,
      });

      expect(config.chatsPushNotification, PrivacyConfig.pushOff);
      expect(
        (await module.getPrivacyConfig()).chatsPushNotification,
        PrivacyConfig.pushOff,
      );
    },
  );

  test('once the server accepts a switch it owns the value again', () async {
    await module.setChatsPushNotification(PrivacyConfig.pushReplies);
    await module.storeLoginConfig(_accountId, {
      'CHATS_PUSH_NOTIFICATION': PrivacyConfig.pushOn,
    });

    expect(
      (await module.getPrivacyConfig()).chatsPushNotification,
      PrivacyConfig.pushOn,
    );
  });
}
