import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/e2ee_service.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _accountId = 101;
const _chatId = 202;

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

class _QueryGate {
  final started = Completer<void>();
  final release = Completer<void>();
}

class _ControlledSessionLoader {
  _QueryGate? nextQuery;

  _QueryGate pauseNextQuery() => nextQuery = _QueryGate();

  Future<List<Map<String, dynamic>>> call(int accountId) async {
    final gate = nextQuery;
    nextQuery = null;
    final rows = await AppDatabase.loadE2eeSessions(accountId);
    if (gate != null) {
      gate.started.complete();
      await gate.release.future;
    }
    return rows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late E2eeService service;
  late _ControlledSessionLoader loader;

  setUpAll(AppDatabase.init);

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_e2ee_load',
    );
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    FlutterSecureStorage.setMockInitialValues({});
    loader = _ControlledSessionLoader();
    service = E2eeService(loadSessions: loader.call);
    addTearDown(() async {
      service.forgetAccount(_accountId);
      await AppDatabase.close();
      PathProviderPlatform.instance = previousPathProvider;
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    await AppDatabase.saveProfile(
      ProfileData(
        id: _accountId,
        firstName: 'Synthetic account',
        phone: 100000,
        country: 'ZZ',
        accountStatus: 0,
        updateTime: 1,
      ),
    );
    await AppDatabase.saveE2eeSession({
      'account_id': _accountId,
      'chat_id': _chatId,
      'peer_id': 303,
      'phase': 'established',
      'verified': 1,
      'updated': 1,
    });
  });

  test('concurrent consumers wait until session info is ready', () async {
    final gate = loader.pauseNextQuery();
    final first = service.ensureLoaded(_accountId);
    await gate.started.future;
    expect(service.isLoaded(_accountId), isFalse);
    var secondCompleted = false;
    final second = service.ensureLoaded(_accountId).then((_) {
      secondCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(secondCompleted, isFalse);
    gate.release.complete();
    await Future.wait([first, second]);
    expect(service.isActive(_accountId, _chatId), isTrue);
    expect(service.isLoaded(_accountId), isTrue);
    expect(service.info(_accountId, _chatId)?.verified, isTrue);
  });

  test('load failures reach every consumer and permit a retry', () async {
    final gate = loader.pauseNextQuery();
    final first = service.ensureLoaded(_accountId);
    await gate.started.future;
    final second = service.ensureLoaded(_accountId);
    final firstFailure = expectLater(first, throwsStateError);
    final secondFailure = expectLater(second, throwsStateError);
    gate.release.completeError(StateError('synthetic query failure'));
    await Future.wait([firstFailure, secondFailure]);
    expect(service.isLoaded(_accountId), isFalse);
    expect(service.info(_accountId, _chatId), isNull);
    await service.ensureLoaded(_accountId);
    expect(service.isActive(_accountId, _chatId), isTrue);
  });

  test('a synchronous loader failure permits a retry', () async {
    var attempts = 0;
    service = E2eeService(
      loadSessions: (accountId) {
        if (attempts++ == 0) throw StateError('synthetic loader failure');
        return AppDatabase.loadE2eeSessions(accountId);
      },
    );
    await expectLater(service.ensureLoaded(_accountId), throwsStateError);
    expect(service.isLoaded(_accountId), isFalse);
    await service.ensureLoaded(_accountId);
    expect(service.isActive(_accountId, _chatId), isTrue);
  });

  test('forgotten accounts discard an already running load', () async {
    final gate = loader.pauseNextQuery();
    final first = service.ensureLoaded(_accountId);
    await gate.started.future;
    service.forgetAccount(_accountId);
    expect(service.isLoaded(_accountId), isFalse);
    gate.release.complete();
    await expectLater(first, throwsStateError);
    expect(service.info(_accountId, _chatId), isNull);
    await service.ensureLoaded(_accountId);
    expect(service.isActive(_accountId, _chatId), isTrue);
  });

  test('an obsolete load leaves a replacement load pending', () async {
    final oldGate = loader.pauseNextQuery();
    final first = service.ensureLoaded(_accountId);
    await oldGate.started.future;
    service.forgetAccount(_accountId);
    final replacementGate = loader.pauseNextQuery();
    final replacement = service.ensureLoaded(_accountId);
    await replacementGate.started.future;
    oldGate.release.complete();
    await expectLater(first, throwsStateError);
    expect(service.info(_accountId, _chatId), isNull);
    var consumerCompleted = false;
    final consumer = service.ensureLoaded(_accountId).then((_) {
      consumerCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(consumerCompleted, isFalse);
    replacementGate.release.complete();
    await Future.wait([replacement, consumer]);
    expect(service.isActive(_accountId, _chatId), isTrue);
  });

  test('erased accounts cannot recover info from an obsolete load', () async {
    final gate = loader.pauseNextQuery();
    final first = service.ensureLoaded(_accountId);
    await gate.started.future;
    await service.eraseAccount(_accountId);
    gate.release.complete();
    await expectLater(first, throwsStateError);
    expect(service.info(_accountId, _chatId), isNull);
    expect(await AppDatabase.loadE2eeSessions(_accountId), isEmpty);
    await service.ensureLoaded(_accountId);
    expect(service.info(_accountId, _chatId), isNull);
  });
}
