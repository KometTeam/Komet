import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/forward_sender.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/crypto/e2ee_service.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/storage/chat_encryption_store.dart';
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

class _RecordingApi extends Api {
  int epoch = 1;
  final requests = <Map<dynamic, dynamic>>[];
  Future<void> Function()? beforeDispatch;
  Future<void> Function()? afterDispatch;

  @override
  int get sessionEpoch => epoch;

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    await beforeDispatch?.call();
    beforeSend?.call();
    requests.add(payload);
    await afterDispatch?.call();
    return Packet(
      cmd: CmdType.ok,
      payload: {
        'message': {'id': '', 'text': 'Synthetic delivery', 'time': 1000},
      },
    );
  }
}

final _source = CachedMessage(
  id: '701',
  accountId: 101,
  chatId: 303,
  senderId: 202,
  text: 'Synthetic forward',
  time: 1000,
);

ForwardRequest _request({bool hideSender = false}) => ForwardRequest(
  sourceChatId: 303,
  sourceChatName: 'Synthetic source',
  sourceChatIconUrl: '',
  sourceChatType: 'CHAT',
  messages: [_source],
  hideSender: hideSender,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RecordingApi api;
  late MessagesModule sender;

  setUpAll(AppDatabase.init);

  Future<void> setPhase(String phase) async {
    E2eeService.instance.forgetAccount(101);
    await AppDatabase.saveE2eeSession({
      'account_id': 101,
      'chat_id': 404,
      'peer_id': 202,
      'phase': phase,
      'updated': 1000,
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'synthetic_forward',
    );
    final previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    await databaseFactory.setDatabasesPath(directory.path);
    await AppDatabase.saveProfile(ProfileData.stub(101));
    E2eeService.instance.forgetAccount(101);
    await ChatEncryptionStore.instance.setEnabled(101, 404, false);
    api = _RecordingApi();
    sender = MessagesModule(api);
    addTearDown(() async {
      E2eeService.instance.forgetAccount(101);
      await ChatEncryptionStore.instance.setEnabled(101, 404, false);
      await api.dispose();
      await AppDatabase.close();
      PathProviderPlatform.instance = previousProvider;
      await directory.delete(recursive: true);
    });
  });

  for (final phase in ['established', 'keyChanged']) {
    for (final copy in [false, true]) {
      test(
        '$phase destination rejects direct ${copy ? "copy" : "forward"}',
        () async {
          await setPhase(phase);

          await expectLater(
            copy
                ? ForwardSender.sendCopy(101, 404, _source, sender: sender)
                : ForwardSender.sendForward(
                    101,
                    404,
                    _request(),
                    _source,
                    sender: sender,
                  ),
            throwsA(isA<StateError>()),
          );
          expect(api.requests, isEmpty);
        },
      );
    }
  }

  test('legacy destination rejects a caption-only resumed batch', () async {
    await ChatEncryptionStore.instance.setEnabled(101, 404, true);

    final result = await ForwardSender.send(
      accountId: 101,
      chatIds: [404],
      request: _request(),
      caption: const ForwardCaption('Synthetic caption'),
      resumeFrom: {404: 1},
      sender: sender,
    );

    expect(result.unfinished, {404: 1});
    expect(api.requests, isEmpty);
  });

  test('mixed batch delivers only to the unencrypted destination', () async {
    await setPhase('established');

    final result = await ForwardSender.send(
      accountId: 101,
      chatIds: [404, 505],
      request: _request(hideSender: true),
      caption: const ForwardCaption('Synthetic caption'),
      sender: sender,
    );

    expect(result.delivered, {505});
    expect(result.unfinished, {404: 0});
    expect(api.requests.map((p) => p['chatId']), [505, 505]);
  });

  test('encryption enabled between steps blocks the caption', () async {
    api.afterDispatch = () =>
        ChatEncryptionStore.instance.setEnabled(101, 404, true);

    final result = await ForwardSender.send(
      accountId: 101,
      chatIds: [404],
      request: _request(),
      caption: const ForwardCaption('Synthetic caption'),
      sender: sender,
    );

    expect(result.unfinished, {404: 1});
    expect(api.requests, hasLength(1));
  });

  test(
    'encryption enabled while dispatch waits blocks the wire request',
    () async {
      api.beforeDispatch = () =>
          ChatEncryptionStore.instance.setEnabled(101, 404, true);

      await expectLater(
        ForwardSender.sendCopy(101, 404, _source, sender: sender),
        throwsA(isA<StateError>()),
      );
      expect(api.requests, isEmpty);
    },
  );

  test(
    'forgotten account while dispatch waits blocks the wire request',
    () async {
      api.beforeDispatch = () async => E2eeService.instance.forgetAccount(101);

      await expectLater(
        ForwardSender.sendCopy(101, 404, _source, sender: sender),
        throwsA(isA<StateError>()),
      );
      expect(api.requests, isEmpty);
    },
  );

  test('new session while dispatch waits blocks the wire request', () async {
    api.beforeDispatch = () async => api.epoch++;

    await expectLater(
      ForwardSender.sendCopy(101, 404, _source, sender: sender),
      throwsA(isA<StateError>()),
    );
    expect(api.requests, isEmpty);
  });

  test('a batch cannot continue in the replacement session', () async {
    api.beforeDispatch = () async {
      api.beforeDispatch = null;
      api.epoch++;
    };

    final result = await ForwardSender.send(
      accountId: 101,
      chatIds: [404, 505, 606, 707],
      request: _request(),
      sender: sender,
    );

    expect(result.unfinished, {404: 0, 505: 0, 606: 0, 707: 0});
    expect(api.requests, isEmpty);
  });

  test(
    'a caption cannot follow its forward in a replacement session',
    () async {
      api.afterDispatch = () async => api.epoch++;

      final result = await ForwardSender.send(
        accountId: 101,
        chatIds: [404],
        request: _request(),
        caption: const ForwardCaption('Synthetic caption'),
        sender: sender,
      );

      expect(result.unfinished, {404: 1});
      expect(api.requests, hasLength(1));
    },
  );

  test(
    'v2 encryption enabled while dispatch waits blocks the caption',
    () async {
      api.beforeDispatch = () async {
        await setPhase('established');
        await E2eeService.instance.ensureLoaded(101);
      };

      final result = await ForwardSender.send(
        accountId: 101,
        chatIds: [404],
        request: _request(),
        caption: const ForwardCaption('Synthetic caption'),
        resumeFrom: {404: 1},
        sender: sender,
      );

      expect(result.unfinished, {404: 1});
      expect(api.requests, isEmpty);
    },
  );

  test('ordinary destination supports direct forward and copy', () async {
    await ForwardSender.sendForward(
      101,
      404,
      _request(),
      _source,
      sender: sender,
    );
    await ForwardSender.sendCopy(101, 404, _source, sender: sender);

    expect(api.requests, hasLength(2));
  });
}
