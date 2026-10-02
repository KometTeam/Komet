import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/backend/modules/outbox.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/storage/token_storage.dart';
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

class _ControlledApi extends Api {
  SessionState currentState = SessionState.disconnected;
  int epoch = 1;
  final changes = StreamController<SessionState>.broadcast();
  final requests = <(int, String)>[];
  Future<Packet> Function(Map<dynamic, dynamic>)? responder;

  @override
  SessionState get state => currentState;

  @override
  int get sessionEpoch => epoch;

  @override
  Stream<SessionState> get stateStream => changes.stream;

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
  }) {
    final message = payload['message'] as Map;
    requests.add((epoch, message['text'] as String));
    final handler = responder;
    if (handler != null) return handler(payload);
    return Future.value(
      Packet(
        cmd: CmdType.ok,
        payload: {
          'message': {'id': 'synthetic-sent-${requests.length}'},
        },
      ),
    );
  }
}

CachedMessage _pending(int accountId, String id, String text, int time) =>
    CachedMessage(
      id: id,
      accountId: accountId,
      chatId: 303,
      senderId: accountId,
      text: text,
      time: time,
      status: 'pending',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _ControlledApi();
  final outbox = OutboxService.instance;

  setUpAll(() {
    outbox.init(api, MessagesModule(api));
  });

  tearDownAll(() async {
    await api.changes.close();
    await api.dispose();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp('synthetic_outbox');
    final previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    await AppDatabase.init();
    await databaseFactory.setDatabasesPath(directory.path);
    await AppDatabase.saveProfile(ProfileData.stub(101));
    await AppDatabase.saveProfile(ProfileData.stub(202));
    await AppDatabase.saveChats([
      for (final accountId in [101, 202])
        {
          'id': 303,
          'account_id': accountId,
          'type': 'CHAT',
          'title': 'Synthetic shared chat',
          'cached_at': 0,
          'participants': '{}',
        },
    ]);
    await TokenStorage.setActiveAccount(101);
    api.currentState = SessionState.online;
    api.epoch = 1;
    api.requests.clear();
    api.responder = null;
    addTearDown(() async {
      await AppDatabase.close();
      PathProviderPlatform.instance = previousProvider;
      await directory.delete(recursive: true);
    });
  });

  test('sends pending messages from the same account in order', () async {
    await AppDatabase.saveMessages([
      _pending(101, 'synthetic-a1', 'Synthetic first', 1).toDbRow(),
      _pending(101, 'synthetic-a2', 'Synthetic second', 2).toDbRow(),
    ]);

    await outbox.flush();

    expect(api.requests, [(1, 'Synthetic first'), (1, 'Synthetic second')]);
    expect(await AppDatabase.loadPendingMessages(101), isEmpty);
  });

  test(
    'a failed encrypted send keeps ciphertext through persistence and retry',
    () async {
      final outgoing = _pending(
        101,
        'synthetic-encrypted',
        'синтетический шифротекст',
        1,
      ).copyWith(status: 'sending');
      final queued = outgoing.withSendFailure(
        TimeoutException('Synthetic timeout'),
      );
      await AppDatabase.saveMessages([queued.toDbRow()]);

      await outbox.flush();

      expect(api.requests, [(1, 'синтетический шифротекст')]);
      expect(await AppDatabase.loadPendingMessages(101), isEmpty);
    },
  );

  test(
    'a permanent rejection retains the outgoing ciphertext and metadata',
    () {
      final outgoing =
          _pending(
            101,
            'synthetic-encrypted',
            'синтетический шифротекст',
            1,
          ).copyWith(
            status: 'sending',
            payload: {
              'link': {'type': 'REPLY', 'messageId': 404},
            },
          );

      final failed = outgoing.withSendFailure(
        const PacketError('Synthetic rejection'),
      );

      expect(failed.status, 'error');
      expect(failed.text, 'синтетический шифротекст');
      expect(failed.id, 'synthetic-encrypted');
      expect(failed.payload, {
        'link': {'type': 'REPLY', 'messageId': 404},
      });
    },
  );

  test(
    'does not send the previous account queue through a new session',
    () async {
      await AppDatabase.saveMessages([
        _pending(101, 'synthetic-a1', 'Synthetic first', 1).toDbRow(),
        _pending(101, 'synthetic-a2', 'Synthetic second', 2).toDbRow(),
        _pending(202, 'synthetic-b1', 'Synthetic other account', 3).toDbRow(),
      ]);
      final started = Completer<void>();
      final response = Completer<Packet>();
      api.responder = (_) {
        api.responder = null;
        started.complete();
        return response.future;
      };
      final flushing = outbox.flush();
      await started.future;
      api.epoch = 2;
      await TokenStorage.setActiveAccount(202);
      final events = <MessageSentEvent>[];
      final subscription = chats.messageEvents
          .where((event) => event is MessageSentEvent)
          .cast<MessageSentEvent>()
          .listen(events.add);
      addTearDown(subscription.cancel);
      final online = api.changes.stream.first;
      api.changes.add(SessionState.online);
      await online;
      response.complete(
        Packet(
          cmd: CmdType.ok,
          payload: {
            'message': {'id': 'synthetic-first-sent'},
          },
        ),
      );

      await flushing;

      expect(api.requests, [
        (1, 'Synthetic first'),
        (2, 'Synthetic other account'),
      ]);
      final previousPending = await AppDatabase.loadPendingMessages(101);
      expect(previousPending.map((row) => row['id']), ['synthetic-a2']);
      expect(await AppDatabase.loadPendingMessages(202), isEmpty);
      expect(events.map((event) => event.message.accountId), [202]);
    },
  );

  test('a reconnect does not resume an old flush in the new session', () async {
    await AppDatabase.saveMessages([
      _pending(101, 'synthetic-a1', 'Synthetic first', 1).toDbRow(),
      _pending(101, 'synthetic-a2', 'Synthetic second', 2).toDbRow(),
    ]);
    final started = Completer<void>();
    final response = Completer<Packet>();
    api.responder = (_) {
      api.responder = null;
      started.complete();
      return response.future;
    };
    final flushing = outbox.flush();
    await started.future;
    api.epoch = 2;
    response.completeError(const PacketError('Synthetic session rejection'));

    await flushing;

    expect(api.requests, [(1, 'Synthetic first')]);
    final pending = await AppDatabase.loadPendingMessages(101);
    expect(pending.map((row) => row['id']), ['synthetic-a1', 'synthetic-a2']);
    await outbox.flush();
    expect(api.requests, [
      (1, 'Synthetic first'),
      (2, 'Synthetic first'),
      (2, 'Synthetic second'),
    ]);
  });
}
