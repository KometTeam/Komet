import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/history_reconcile.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _account = 101;
const _chat = 909;
const _sender = 202;
const _base = 1700000000000;

int _t(num n) => _base + (n * 1000).round();

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _HistoryApi extends Api {
  List<Map<String, dynamic>> history = const [];
  Future<void> Function()? whileInFlight;
  final requests = <Map<dynamic, dynamic>>[];

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    beforeSend?.call();
    requests.add(payload);
    await whileInFlight?.call();
    return Packet(
      cmd: CmdType.ok,
      opcode: opcode,
      payload: {'messages': history},
    );
  }
}

Map<String, dynamic> _onServer(String id, num at) => {
  'id': id,
  'time': _t(at),
  'sender': _sender,
  'text': 'Synthetic post $id',
};

CachedMessage _cached(String id, int time, {String status = 'sent'}) =>
    CachedMessage(
      id: id,
      accountId: _account,
      chatId: _chat,
      senderId: _sender,
      text: 'Synthetic post $id',
      time: time,
      status: status,
    );

Future<void> _seed(List<CachedMessage> messages) =>
    AppDatabase.saveMessages([for (final m in messages) m.toDbRow()]);

Future<Map<String, bool>> _stored() async {
  final rows = await AppDatabase.loadMessages(_account, _chat);
  return {
    for (final row in rows) row['id'].toString(): (row['deleted'] as int) != 0,
  };
}

Map<String, dynamic> _row(
  String id,
  num at, {
  String status = 'sent',
  int deleted = 0,
}) => {'id': id, 'time': _t(at), 'status': status, 'deleted': deleted};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HistoryPage', () {
    final page = HistoryPage.of([
      _onServer('2', 2),
      _onServer('4', 4),
      'not a message',
    ])!;
    final settled = _t(100);

    test('spans the times the server returned', () {
      expect(page.oldest, _t(2));
      expect(page.newest, _t(4));
      expect(page.ids, {'2', '4'});
      expect(HistoryPage.of(const []), isNull);
    });

    test('a cached message inside the span but not on the server is gone', () {
      expect(
        page.missingFrom(
          [_row('2', 2), _row('3', 3), _row('4', 4), _row('1', 1)],
          reachesNow: false,
          settledBefore: settled,
        ),
        ['3'],
      );
    });

    test('unsent, already deleted and duplicate rows are skipped', () {
      expect(
        page.missingFrom(
          [
            _row('temp_1', 3),
            _row('31', 3, status: 'pending'),
            _row('32', 3, status: 'sending'),
            _row('33', 3, status: 'error'),
            _row('34', 3, deleted: 1),
            _row('35', 3),
            _row('35', 3),
          ],
          reachesNow: false,
          settledBefore: settled,
        ),
        ['35'],
      );
    });

    test('newer rows count only when the page reaches the present', () {
      final rows = [_row('5', 5)];
      expect(
        page.missingFrom(rows, reachesNow: false, settledBefore: settled),
        isEmpty,
      );
      expect(page.missingFrom(rows, reachesNow: true, settledBefore: settled), [
        '5',
      ]);
    });

    test('messages younger than the settle window are kept', () {
      expect(
        page.missingFrom(
          [_row('3', 3), _row('5', 5)],
          reachesNow: true,
          settledBefore: _t(3),
        ),
        isEmpty,
      );
    });
  });

  group('fetchHistory', () {
    late _HistoryApi api;
    late MessagesModule messages;
    late List<MessageEvent> events;
    late StreamSubscription<MessageEvent> subscription;

    setUpAll(AppDatabase.init);

    setUp(() async {
      SharedPreferences.setMockInitialValues({'active_account_id': '101'});
      final directory = await Directory.systemTemp.createTemp(
        'synthetic_history',
      );
      final previousProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      await databaseFactory.setDatabasesPath(directory.path);
      await AppDatabase.saveProfile(ProfileData.stub(_account));
      await AppDatabase.saveChats([
        {
          'id': _chat,
          'account_id': _account,
          'type': 'CHANNEL',
          'title': 'Synthetic channel',
          'cached_at': 0,
          'participants': '{}',
        },
      ]);
      api = _HistoryApi();
      messages = MessagesModule(api);
      events = [];
      subscription = chats.messageEvents.listen(events.add);
      addTearDown(() async {
        KometSettings.viewDeleted.value = false;
        await subscription.cancel();
        await api.dispose();
        await AppDatabase.close();
        PathProviderPlatform.instance = previousProvider;
        await directory.delete(recursive: true);
      });
    });

    test('a post deleted on the server leaves the cached history', () async {
      await _seed([for (var i = 1; i <= 5; i++) _cached('$i', _t(i))]);
      api.history = [
        _onServer('1', 1),
        _onServer('2', 2),
        _onServer('4', 4),
        _onServer('5', 5),
      ];

      await messages.fetchHistory(_account, _chat);
      await pumpEventQueue();

      expect((await _stored()).keys, unorderedEquals(['1', '2', '4', '5']));
      expect(events.whereType<MessageRemovedEvent>().map((e) => e.messageId), [
        '3',
      ]);
    });

    test(
      'the newest cached post goes when the server has older ones',
      () async {
        await _seed([for (var i = 1; i <= 4; i++) _cached('$i', _t(i))]);
        await AppDatabase.saveChats([
          {
            'id': _chat,
            'account_id': _account,
            'type': 'CHANNEL',
            'title': 'Synthetic channel',
            'cached_at': 0,
            'participants': '{}',
            'last_msg_id': 4,
            'last_msg_text': 'Synthetic post 4',
            'last_msg_time': _t(4),
          },
        ]);
        api.history = [_onServer('1', 1), _onServer('2', 2), _onServer('3', 3)];

        await messages.fetchHistory(_account, _chat);

        expect((await _stored()).keys, unorderedEquals(['1', '2', '3']));
        final chat = (await AppDatabase.loadChat(_account, _chat)).single;
        expect(chat['last_msg_id'], 3);
        expect(chat['last_msg_text'], 'Synthetic post 3');
      },
    );

    test('a message that arrives during the request survives', () async {
      await _seed([for (var i = 1; i <= 3; i++) _cached('$i', _t(i))]);
      api.history = [_onServer('1', 1), _onServer('2', 2), _onServer('3', 3)];
      api.whileInFlight = () => _seed([_cached('4', _t(4))]);

      await messages.fetchHistory(_account, _chat);

      expect((await _stored()).keys, unorderedEquals(['1', '2', '3', '4']));
    });

    test('unsent and fresh messages are left alone', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _seed([
        _cached('1', _t(1)),
        _cached('temp_1', _t(2), status: 'sending'),
        _cached('22', _t(2), status: 'error'),
        _cached('3', _t(3)),
        _cached('9', now),
      ]);
      api.history = [_onServer('1', 1), _onServer('3', 3)];

      await messages.fetchHistory(_account, _chat);

      expect(
        (await _stored()).keys,
        unorderedEquals(['1', 'temp_1', '22', '3', '9']),
      );
      expect(events, isEmpty);
    });

    test('an older page reconciles only the span it covers', () async {
      await _seed([
        for (var i = 4; i <= 8; i++) _cached('$i', _t(i)),
        _cached('65', _t(6.5)),
      ]);
      api.history = [_onServer('5', 5), _onServer('6', 6), _onServer('7', 7)];

      await messages.fetchHistory(_account, _chat, fromTime: _t(7), count: 3);

      expect(
        (await _stored()).keys,
        unorderedEquals(['4', '5', '6', '7', '8']),
      );
    });

    test('with deleted messages shown the ghost is marked instead', () async {
      KometSettings.viewDeleted.value = true;
      await _seed([for (var i = 1; i <= 3; i++) _cached('$i', _t(i))]);
      api.history = [_onServer('1', 1), _onServer('3', 3)];

      await messages.fetchHistory(_account, _chat);
      await pumpEventQueue();

      expect(await _stored(), {'1': false, '2': true, '3': false});
      expect(
        events.whereType<MessageMarkedDeletedEvent>().map((e) => e.messageId),
        ['2'],
      );
    });

    test('an empty answer removes nothing', () async {
      await _seed([_cached('1', _t(1))]);

      await messages.fetchHistory(_account, _chat);

      expect((await _stored()).keys, ['1']);
    });
  });
}
