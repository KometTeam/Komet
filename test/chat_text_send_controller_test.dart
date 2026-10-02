import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/comments.dart';
import 'package:komet/backend/modules/forward_sender.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/cache/message_session_cache.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/frontend/screens/chats/chat/chat_controller.dart';
import 'package:komet/frontend/screens/chats/chat/chat_text_send_controller.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
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

class _DelayedApi extends Api {
  final started = Completer<void>();
  final response = Completer<Packet>();
  final requests = <Map<dynamic, dynamic>>[];
  int epoch = 1;
  Future<void> Function()? beforeDispatch;

  @override
  int get sessionEpoch => epoch;

  @override
  SessionState get state => SessionState.online;

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
    if (!started.isCompleted) started.complete();
    return response.future;
  }
}

class _Harness {
  _Harness({this.commentsMode = false});

  final bool commentsMode;
  final api = _DelayedApi();
  late final comments = CommentsModule(api);
  final chat = ChatController()
    ..myId = 101
    ..chatId = 303;
  final composer = RichMessageController()..text = 'Synthetic plaintext';
  final hasText = ValueNotifier(true);
  final replyTo = ValueNotifier<CachedMessage?>(null);
  final forward = ValueNotifier<ForwardRequest?>(null);
  bool mounted = true;
  int bumps = 0;
  final notifications = <String>[];
  final composed = Completer<void>();

  late final sender = ChatTextSendController(
    apiClient: api,
    messageSender: MessagesModule(api),
    commentSender: comments,
    chatController: chat,
    messageController: composer,
    hasText: hasText,
    replyTo: replyTo,
    pendingForward: forward,
    commentsMode: commentsMode,
    commentPostId: commentsMode ? 'synthetic-post' : null,
    bumpMessages: () => bumps++,
    scrollToBottom: () {},
    focusComposer: () {},
    setLastSentId: (_) {
      if (!composed.isCompleted) composed.complete();
    },
    notify: notifications.add,
    isMounted: () => mounted,
    contextOf: () => throw StateError('No UI context needed'),
    chatOf: () => null,
    encryptOutgoing: (text, {notify = true}) async => 'Synthetic ciphertext',
    executeCommand: (_, _) async {},
    checkPrankTrigger: (_) {},
    confirmSend: () async => true,
  );

  Future<void> dispose() async {
    comments.dispose();
    chat.dispose();
    composer.dispose();
    hasText.dispose();
    replyTo.dispose();
    forward.dispose();
    await api.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database database;

  setUpAll(AppDatabase.init);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MessageSessionCache.clearAll();
    Haptics.enabled = false;
    final directory = await Directory.systemTemp.createTemp('synthetic_send');
    final previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    await databaseFactory.setDatabasesPath(directory.path);
    await AppDatabase.saveProfile(ProfileData.stub(101));
    await AppDatabase.saveProfile(ProfileData.stub(202));
    await AppDatabase.saveChats([
      for (final accountId in [101, 202])
        for (final chatId in [303, 404])
          {
            'id': chatId,
            'account_id': accountId,
            'type': 'CHAT',
            'title': 'Synthetic chat',
            'cached_at': 0,
            'participants': '{}',
          },
    ]);
    database = await databaseFactory.openDatabase(
      '${directory.path}${Platform.pathSeparator}komet.db',
    );
    addTearDown(() async {
      await AppDatabase.close();
      MessageSessionCache.clearAll();
      Haptics.enabled = true;
      PathProviderPlatform.instance = previousProvider;
      await directory.delete(recursive: true);
    });
  });

  for (final scenario in [
    (
      name: 'closed chat',
      mounted: false,
      keepMessage: true,
      changeChat: false,
      error: TimeoutException('Synthetic timeout'),
      status: 'pending',
    ),
    (
      name: 'missing optimistic row',
      mounted: true,
      keepMessage: false,
      changeChat: false,
      error: TimeoutException('Synthetic timeout'),
      status: 'pending',
    ),
    (
      name: 'changed chat',
      mounted: true,
      keepMessage: true,
      changeChat: true,
      error: TimeoutException('Synthetic timeout'),
      status: 'pending',
    ),
    (
      name: 'permanent rejection in a closed chat',
      mounted: false,
      keepMessage: true,
      changeChat: false,
      error: const PacketError('Synthetic rejection'),
      status: 'error',
    ),
  ]) {
    test('a failed send persists after ${scenario.name}', () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final sending = harness.sender.sendTextMessage();
      await harness.api.started.future;
      final composed = harness.chat.messages.single;
      harness.chat.persistSessionCache();
      harness.mounted = scenario.mounted;
      if (!scenario.keepMessage) harness.chat.messages = [];
      final bumps = harness.bumps;
      if (scenario.changeChat) {
        harness.chat
          ..myId = 202
          ..chatId = 404;
      }

      harness.api.response.completeError(scenario.error);
      await sending;

      final rows = await AppDatabase.loadMessages(101, 303);
      expect(rows, hasLength(1));
      expect(rows.single['status'], scenario.status);
      expect(rows.single['text'], 'Synthetic ciphertext');
      expect(rows.single['id'], composed.id);
      final pending = await AppDatabase.loadPendingMessages(101);
      expect(pending, hasLength(scenario.status == 'pending' ? 1 : 0));
      expect(await AppDatabase.loadPendingMessages(202), isEmpty);
      expect(
        MessageSessionCache.get(101, 303)!.messages.single.status,
        scenario.status,
      );
      expect(
        (await chats.getChat(101, 303)).single.lastMsgStatus,
        scenario.status,
      );
      expect((await chats.getChat(202, 404)).single.lastMsgStatus, isNull);
      expect(harness.bumps, bumps);
      expect(harness.notifications, isEmpty);
    });
  }

  test('an active chat displays and persists a failed send', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final sending = harness.sender.sendTextMessage();
    await harness.api.started.future;
    final bumps = harness.bumps;

    harness.api.response.completeError(TimeoutException('Synthetic timeout'));
    await sending;

    expect(harness.chat.messages.single.status, 'pending');
    expect(harness.chat.messages.single.text, 'Synthetic ciphertext');
    expect(harness.bumps, bumps + 1);
    expect(await AppDatabase.loadPendingMessages(101), hasLength(1));
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, 'pending');
  });

  test('a failed comment stays outside the ordinary message outbox', () async {
    final harness = _Harness(commentsMode: true);
    addTearDown(harness.dispose);
    final sending = harness.sender.sendTextMessage();
    await harness.api.started.future;
    harness.mounted = false;
    final bumps = harness.bumps;

    harness.api.response.completeError(TimeoutException('Synthetic timeout'));
    await sending;

    expect(await AppDatabase.loadMessages(101, 303), isEmpty);
    expect(await AppDatabase.loadPendingMessages(101), isEmpty);
    expect(MessageSessionCache.get(101, 303), isNull);
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, isNull);
    expect(harness.bumps, bumps);
  });

  test('a deleted in-flight message is not restored after failure', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final sending = harness.sender.sendTextMessage();
    await harness.api.started.future;
    final composed = harness.chat.messages.single;
    harness.chat.persistSessionCache();

    harness.chat.messages = [];
    MessageSessionCache.remove(101, 303);
    await AppDatabase.deleteMessage(101, 303, composed.id);
    await chats.reconcileLastMessage(101, 303);

    harness.api.response.completeError(TimeoutException('Synthetic timeout'));
    await sending;

    expect(await AppDatabase.loadMessages(101, 303), isEmpty);
    expect(await AppDatabase.loadPendingMessages(101), isEmpty);
    expect(harness.chat.messages, isEmpty);
    expect(MessageSessionCache.get(101, 303), isNull);
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, isNull);
  });

  test('a fast network failure follows durable sending state', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final sending = harness.sender.sendTextMessage();
    await harness.api.started.future;

    expect(
      (await AppDatabase.loadMessages(101, 303)).single['status'],
      'sending',
    );
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, 'sending');
    harness.api.response.completeError(TimeoutException('Synthetic timeout'));
    await sending;

    expect(
      (await AppDatabase.loadMessages(101, 303)).single['status'],
      'pending',
    );
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, 'pending');
  });

  test('a failed initial write prevents network dispatch', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.chat.chatId = 505;

    await harness.sender.sendTextMessage();

    expect(harness.api.requests, isEmpty);
    expect(harness.chat.messages.single.status, 'error');
    expect(harness.notifications, hasLength(1));
    expect(await AppDatabase.loadPendingMessages(101), isEmpty);
  });

  test('a direct forward batch stops after its session changes', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final request = ForwardRequest(
      sourceChatId: 404,
      sourceChatName: 'Synthetic source',
      sourceChatIconUrl: '',
      sourceChatType: 'CHAT',
      messages: [
        for (final id in ['701', '702'])
          CachedMessage(
            id: id,
            accountId: 101,
            chatId: 404,
            senderId: 202,
            text: 'Synthetic forward $id',
            time: 1000,
          ),
      ],
    );
    harness.sender.setForwardRequest(request);
    final sending = harness.sender.sendForwardRequest();
    await harness.api.started.future;
    harness.api.epoch = 2;
    harness.api.response.complete(
      Packet(
        cmd: CmdType.ok,
        payload: {
          'message': {'id': 'synthetic-sent', 'time': 1000},
        },
      ),
    );

    expect(await sending, isFalse);
    expect(harness.api.requests, hasLength(1));
    expect(harness.forward.value!.messages.single.id, '702');
    final rows = await AppDatabase.loadMessages(101, 303);
    expect(rows.map((row) => row['id']), ['synthetic-sent']);
    expect(await AppDatabase.loadPendingMessages(101), isEmpty);
  });

  test('a session change during the initial write prevents dispatch', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.api.response.complete(
      Packet(
        cmd: CmdType.ok,
        payload: {
          'message': {'id': 'synthetic-sent'},
        },
      ),
    );
    final locked = Completer<void>();
    final release = Completer<void>();
    final lock = database.transaction((_) async {
      locked.complete();
      await release.future;
    });
    await locked.future;
    final sending = harness.sender.sendTextMessage();
    await harness.composed.future;
    harness.api.epoch = 2;
    release.complete();
    await lock;
    await sending;

    expect(harness.api.requests, isEmpty);
    expect(await AppDatabase.loadPendingMessages(101), hasLength(1));
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, 'pending');
  });

  test('deleting during the initial write prevents dispatch', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    harness.api.response.complete(
      Packet(
        cmd: CmdType.ok,
        payload: {
          'message': {'id': 'synthetic-sent'},
        },
      ),
    );
    final locked = Completer<void>();
    final release = Completer<void>();
    final lock = database.transaction((_) async {
      locked.complete();
      await release.future;
    });
    await locked.future;
    final sending = harness.sender.sendTextMessage();
    await harness.composed.future;
    final composed = harness.chat.messages.single;
    harness.chat.messages = [];
    MessageSessionCache.remove(101, 303);
    final deletion = AppDatabase.deleteMessage(
      101,
      303,
      composed.id,
    ).then((_) => chats.reconcileLastMessage(101, 303));
    await Future<void>.delayed(Duration.zero);
    release.complete();
    await lock;
    await deletion;
    await sending;

    expect(harness.api.requests, isEmpty);
    expect(await AppDatabase.loadMessages(101, 303), isEmpty);
    expect(MessageSessionCache.get(101, 303), isNull);
    expect((await chats.getChat(101, 303)).single.lastMsgStatus, isNull);
  });

  test('a session change at wire dispatch keeps the original queue', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final waiting = Completer<void>();
    final release = Completer<void>();
    harness.api.beforeDispatch = () async {
      waiting.complete();
      await release.future;
    };
    final sending = harness.sender.sendTextMessage();
    await waiting.future;
    harness.api.epoch = 2;
    release.complete();
    await sending;

    expect(harness.api.requests, isEmpty);
    expect(await AppDatabase.loadPendingMessages(101), hasLength(1));
  });
}
