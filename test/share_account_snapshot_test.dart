import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/share/native_share_account_channel.dart';
import 'package:komet/core/share/share_account_snapshot.dart';

ShareAccountSnapshot _snapshot({String token = 'synthetic-session-token'}) =>
    ShareAccountSnapshot(
      accountId: 42,
      accountName: 'Synthetic Account',
      token: token,
      session: const {'host': 'server.example.invalid', 'port': 443},
      login: {
        'token': 'ignored-login-token',
        'chatCacheFingerprint': Uint8List.fromList([1, 2, 3]),
        'interactive': false,
        'exp': {
          'chatsCountGroups': Uint8List.fromList([11, 50]),
        },
      },
      chats: const [
        ShareRecipientSnapshot(
          id: 9007199254741001,
          title: 'Synthetic Group',
          type: 'CHAT',
        ),
        ShareRecipientSnapshot(
          id: 20,
          title: 'Synthetic Encrypted Chat',
          type: 'DIALOG',
          disabledReason: 'Open Komet to send encrypted messages',
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('test.komet/share-account');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(method, null));

  test('snapshot keeps binary login fields and exact large recipient IDs', () {
    final map = _snapshot().toMap();
    final serialized = jsonDecode(jsonEncode(map)) as Map;
    expect(serialized['accountId'], '42');
    expect(serialized['token'], 'synthetic-session-token');
    final login = serialized['login'] as Map;
    expect(login.containsKey('token'), isFalse);
    expect(login.containsKey('chatCacheFingerprint'), isFalse);
    expect(login['interactive'], isFalse);
    expect(login['exp'], {
      'chatsCountGroups': {r'$bin': 'CzI='},
    });
    final chats = serialized['chats'] as List;
    expect(chats.first['id'], '9007199254741001');
    expect(chats.last['disabledReason'], contains('encrypted'));
  });

  test('logout invalidates queued and stale account exports', () async {
    final calls = <MethodCall>[];
    final started = Completer<void>();
    final finish = Completer<void>();
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      if (call.method == 'syncShareAccount') {
        started.complete();
        await finish.future;
      }
      return null;
    });
    final channel = NativeShareAccountChannel(channel: method, enabled: true);
    final generation = channel.generation(42);
    final first = channel.publish(_snapshot(), generation);
    await started.future;
    final queued = channel.publish(_snapshot(), generation);
    final removal = channel.remove(42);
    finish.complete();
    await Future.wait([first, queued, removal]);
    await channel.publish(_snapshot(), generation);
    expect(calls.map((call) => call.method), [
      'syncShareAccount',
      'clearShareAccount',
    ]);
    expect(calls.last.arguments, {'accountId': '42'});
  });

  test('a failed sync does not prevent clearing the account', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call.method);
      if (call.method == 'syncShareAccount') {
        throw PlatformException(code: 'UNAVAILABLE');
      }
      return null;
    });
    final channel = NativeShareAccountChannel(channel: method, enabled: true);
    await expectLater(
      channel.publish(_snapshot(), channel.generation(42)),
      throwsA(isA<PlatformException>()),
    );
    await channel.remove(42);
    expect(calls, ['syncShareAccount', 'clearShareAccount']);
  });

  test(
    'token renewal supplies the current token for native matching',
    () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(method, (call) async {
        captured = call;
        return 'synthetic-renewed-token';
      });
      final channel = NativeShareAccountChannel(channel: method, enabled: true);
      expect(
        await channel.renewedToken(42, 'synthetic-original-token'),
        'synthetic-renewed-token',
      );
      expect(captured!.method, 'readShareToken');
      expect(captured!.arguments, {
        'accountId': '42',
        'knownToken': 'synthetic-original-token',
      });
    },
  );

  test('disabled platforms do not access native sharing credentials', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return null;
    });
    final channel = NativeShareAccountChannel(channel: method, enabled: false);
    await channel.publish(_snapshot(), 0);
    await channel.remove(42);
    expect(await channel.renewedToken(42, 'synthetic-token'), isNull);
    expect(calls, isEmpty);
  });
}
