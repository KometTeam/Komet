import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/per_chat_json_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'synthetic_per_chat_settings';
const _channel = MethodChannel('plugins.flutter.io/shared_preferences');

class _ChatFlags extends PerChatJsonStore<bool> {
  _ChatFlags()
    : super(
        prefsKey: _prefsKey,
        fromJson: (value) => value is bool ? value : null,
        toJson: (value) => value,
      );

  bool? valueOf(int accountId, int chatId) => read(accountId, chatId);
  Future<void> setFlag(int accountId, int chatId, bool? value) =>
      write(accountId, chatId, value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(SharedPreferences.resetStatic);
  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    SharedPreferences.resetStatic();
  });

  test(
    'concurrent initial loads and writes preserve existing chat entries',
    () async {
      final started = Completer<void>();
      final initial = Completer<Map<String, Object>>();
      final persisted = <Map<String, dynamic>>[];
      var loadCount = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        switch (call.method) {
          case 'getAll':
            loadCount++;
            started.complete();
            return initial.future;
          case 'setString':
            final arguments = call.arguments as Map;
            expect(arguments['key'], 'flutter.$_prefsKey');
            persisted.add(
              jsonDecode(arguments['value'] as String) as Map<String, dynamic>,
            );
            return true;
          default:
            throw StateError('Unexpected preference operation: ${call.method}');
        }
      });
      final store = _ChatFlags();
      addTearDown(store.revision.dispose);
      final firstLoad = store.load();
      await started.future;
      final secondLoad = store.load();
      final changed = store.setFlag(101, 11, false);
      final added = store.setFlag(202, 22, true);
      expect(store.revision.value, 0);
      expect(persisted, isEmpty);
      initial.complete({
        'flutter.$_prefsKey': jsonEncode({'101/11': true, '101/12': true}),
      });
      await Future.wait([firstLoad, secondLoad, changed, added]);
      expect(loadCount, 1);
      expect(store.valueOf(101, 11), isFalse);
      expect(store.valueOf(101, 12), isTrue);
      expect(store.valueOf(202, 22), isTrue);
      expect(store.revision.value, 2);
      expect(persisted.last, {'101/11': false, '101/12': true, '202/22': true});
      final restored = _ChatFlags();
      addTearDown(restored.revision.dispose);
      await restored.load();
      expect(restored.valueOf(101, 11), isFalse);
      expect(restored.valueOf(101, 12), isTrue);
      expect(restored.valueOf(202, 22), isTrue);
    },
  );

  test(
    'deleting during first load waits for the saved entry before removal',
    () async {
      final started = Completer<void>();
      final initial = Completer<Map<String, Object>>();
      Map<String, dynamic>? persisted;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'getAll') {
          started.complete();
          return initial.future;
        }
        if (call.method == 'setString') {
          persisted =
              jsonDecode((call.arguments as Map)['value'] as String)
                  as Map<String, dynamic>;
          return true;
        }
        throw StateError('Unexpected preference operation: ${call.method}');
      });
      final store = _ChatFlags();
      addTearDown(store.revision.dispose);
      final loading = store.load();
      await started.future;
      final deletion = store.setFlag(101, 11, null);
      initial.complete({
        'flutter.$_prefsKey': jsonEncode({'101/11': true, '202/11': false}),
      });
      await Future.wait([loading, deletion]);
      expect(store.valueOf(101, 11), isNull);
      expect(store.valueOf(202, 11), isFalse);
      expect(persisted, {'202/11': false});
      expect(store.revision.value, 1);
    },
  );

  test(
    'failed initial loading can retry without losing stored chat settings',
    () async {
      var loadCount = 0;
      Map<String, dynamic>? persisted;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'getAll') {
          loadCount++;
          if (loadCount == 1) {
            throw PlatformException(code: 'SYNTHETIC_UNAVAILABLE');
          }
          return <String, Object>{
            'flutter.$_prefsKey': jsonEncode({'101/11': true}),
          };
        }
        if (call.method == 'setString') {
          persisted =
              jsonDecode((call.arguments as Map)['value'] as String)
                  as Map<String, dynamic>;
          return true;
        }
        throw StateError('Unexpected preference operation: ${call.method}');
      });
      final store = _ChatFlags();
      addTearDown(store.revision.dispose);
      await expectLater(store.load(), throwsA(isA<PlatformException>()));
      expect(store.revision.value, 0);
      await store.setFlag(202, 22, false);
      expect(loadCount, 2);
      expect(store.valueOf(101, 11), isTrue);
      expect(store.valueOf(202, 22), isFalse);
      expect(persisted, {'101/11': true, '202/22': false});
    },
  );
}
