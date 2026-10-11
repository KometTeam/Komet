import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/plugins/plugin_storage.dart';
import 'package:komet/core/storage/temporary_password_recovery.dart';
import 'package:komet/core/utils/log_redact.dart';
import 'package:komet/frontend/screens/webapp/web_app_bridge.dart';
import 'package:komet/frontend/screens/webapp/web_app_origin_policy.dart';
import 'package:komet/frontend/widgets/sliding_pill_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wire redaction hides nested credentials and malformed payloads', () {
    final payload = jsonEncode({
      'items': [
        {'token': 'synthetic-token', 'smsCode': 123456},
      ],
      'phone': '+79990000000',
      'qrLink': 'https://example.test/secret',
      'text': 'synthetic-message',
      'count': 2,
    });
    final redacted = redactJsonForLog(payload);
    for (final secret in [
      'synthetic-token',
      '123456',
      '+79990000000',
      'https://example.test/secret',
      'synthetic-message',
    ]) {
      expect(redacted, isNot(contains(secret)));
    }
    expect(jsonDecode(redacted)['count'], 2);
    expect(
      redactJsonForLog('{"token":"synthetic-token"'),
      '<invalid payload hidden>',
    );
  });

  test(
    'plugin storage separates accounts and invalidates deleted contexts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = PluginStorage('synthetic.scoped', accountId: 101);
      final second = PluginStorage('synthetic.scoped', accountId: 102);
      await Future.wait([
        first.set('value', 'one'),
        second.set('value', 'two'),
      ]);
      expect(await first.get('value'), 'one');
      expect(await second.get('value'), 'two');
      await PluginStorage.eraseAccount(101);
      await expectLater(first.set('value', 'late'), throwsStateError);
      final fresh = PluginStorage('synthetic.scoped', accountId: 101);
      expect(await fresh.get('value'), isNull);
      expect(await second.get('value'), 'two');
      await PluginStorage.erasePlugin('synthetic.scoped');
      await expectLater(second.set('value', 'late'), throwsStateError);
    },
  );

  test('temporary password survives failure until matching rollback', () async {
    final secure = <String, String>{};
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments as Map;
      final key = arguments['key'] as String;
      switch (call.method) {
        case 'read':
          return secure[key];
        case 'write':
          secure[key] = arguments['value'] as String;
          return null;
        case 'delete':
          secure.remove(key);
          return null;
        default:
          throw StateError('Unexpected synthetic secure-storage call');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final recovery = await TemporaryPasswordRecovery.save(
      101,
      'synthetic-password',
    );
    expect(
      (await TemporaryPasswordRecovery.read(101))?.password,
      'synthetic-password',
    );
    expect(await TemporaryPasswordRecovery.read(102), isNull);
    await expectLater(
      TemporaryPasswordRecovery.save(101, 'replacement'),
      throwsStateError,
    );
    await TemporaryPasswordRecovery(
      accountId: 101,
      operationId: 'unrelated',
      password: '',
    ).clearAfterRollback();
    expect(await TemporaryPasswordRecovery.read(101), isNotNull);
    await recovery.clearAfterRollback();
    expect(await TemporaryPasswordRecovery.read(101), isNull);
  });

  test(
    'same-origin reload rejects an earlier asynchronous bridge response',
    () async {
      final started = Completer<void>();
      final response = Completer<Map<String, dynamic>?>();
      final sent = <String>[];
      final bridge = WebAppBridge(
        botId: 777,
        entryPoint: WebAppEntryPoint.webApp,
        contextResolver: () => null,
        viewportResolver: () => const Size(300, 500),
        onClose: () {},
        onRestart: () {},
        originPolicy: WebAppOriginPolicy('https://example.test/app'),
        mobileIdVerifier: (_) {
          started.complete();
          return response.future;
        },
        emitter: (_, payload, private) => sent.add(payload),
      );
      bridge.documentStarted(Uri.parse('https://example.test/app'));
      final job = bridge.handleEvent(
        'WebAppVerifyMobileId',
        '{"requestId":"synthetic","url":"https://example.test/verify"}',
        false,
      );
      await started.future;
      bridge.documentStarted(Uri.parse('https://example.test/reloaded'));
      response.complete({'statusCode': 200, 'data': 'synthetic-secret'});
      await job;
      expect(sent, isEmpty);
      bridge.dispose();
    },
  );

  test(
    'desktop gallery keeps pagination stable and refreshes its first page',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'synthetic-gallery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      for (var i = 0; i < 3; i++) {
        final file = await File('${directory.path}/$i.jpg').writeAsBytes([0]);
        await file.setLastModified(DateTime.utc(2020, 1, i + 1));
      }
      final source = GallerySource.desktopForTesting([
        directory,
      ], refreshInterval: Duration.zero);
      final first = await source.load(limit: 1);
      expect(first.items.single.id, endsWith('2.jpg'));
      await File('${directory.path}/new.jpg').writeAsBytes([0]);
      final second = await source.load(offset: 1, limit: 1);
      expect(second.items.single.id, endsWith('1.jpg'));
      final refreshed = await source.load(limit: 1);
      expect(refreshed.items.single.id, endsWith('new.jpg'));
    },
  );

  for (final width in [240.0, 320.0]) {
    testWidgets('pill tabs remain clickable at width $width and large text', (
      tester,
    ) async {
      var tapped = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Center(
              child: SizedBox(
                width: width,
                child: SlidingPillNav(
                  items: const [
                    PillNavItem(icon: Icons.photo, label: 'Галерея'),
                    PillNavItem(icon: Icons.folder, label: 'Выбрать файл'),
                  ],
                  position: 0,
                  geometry: PillNavGeometry.fromInnerWidth(width - 4, 2),
                  onTap: (index) => tapped = index,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pill-nav-item-1')));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
