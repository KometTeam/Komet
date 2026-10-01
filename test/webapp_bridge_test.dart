import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/core/storage/app_instance.dart';
import 'package:komet/frontend/screens/webapp/web_app_bridge.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<(String, Map<String, dynamic>, bool)> sent;
  late int closeCalls;

  WebAppBridge buildBridge({
    bool privateChannel = false,
    String entryPoint = WebAppEntryPoint.webApp,
  }) {
    return WebAppBridge(
      botId: 777,
      entryPoint: entryPoint,
      privateChannel: privateChannel,
      contextResolver: () => null,
      viewportResolver: () => const Size(420, 800),
      onClose: () => closeCalls++,
      emitter: (method, payload, private) => sent.add((
        method,
        jsonDecode(payload) as Map<String, dynamic>,
        private,
      )),
    );
  }

  setUp(() {
    sent = [];
    closeCalls = 0;
  });

  test('reports the launch context it was created with', () async {
    final bridge = buildBridge(entryPoint: WebAppEntryPoint.inlineButton);

    await bridge.handleEvent(
      'WebAppGetLaunchContext',
      '{"requestId":"r1"}',
      false,
    );

    expect(sent, hasLength(1));
    expect(sent.first.$1, 'WebAppGetLaunchContext');
    expect(sent.first.$2, {
      'requestId': 'r1',
      'entryPoint': 'inline_button',
    });
  });

  test('answers viewport requests with the current webview size', () async {
    final bridge = buildBridge();

    await bridge.handleEvent(
      'WebAppGetViewportSize',
      '{"requestId":"r2"}',
      false,
    );

    expect(sent.first.$2['width'], 420);
    expect(sent.first.$2['height'], 800);
    expect(sent.first.$2['isStateStable'], isTrue);
  });

  test('rejects an unknown method with the client error code', () async {
    final bridge = buildBridge();

    await bridge.handleEvent('WebAppSomethingElse', '{"requestId":"r3"}', false);

    expect(sent.first.$2['error'], {
      'code': 'client.unsupported_method.unsupported_method',
    });
  });

  test('stays silent for methods that never get an answer', () async {
    final bridge = buildBridge();

    await bridge.handleEvent('WebAppReady', '{}', false);
    await bridge.handleEvent('WebAppStat', '{}', false);

    expect(sent, isEmpty);
  });

  test('drops gesture-gated methods until the user touches the page', () async {
    final bridge = buildBridge();

    await bridge.handleEvent(
      'WebAppShare',
      '{"requestId":"r4","text":"hi"}',
      false,
    );
    expect(sent, isEmpty);

    bridge.registerGesture();
    await bridge.handleEvent(
      'WebAppShare',
      '{"requestId":"r5"}',
      false,
    );

    expect(sent.single.$2['error'], {'code': 'client.web_app_share.invalid_request'});
  });

  test('ignores private-channel events when the channel is off', () async {
    final bridge = buildBridge();

    await bridge.handleEvent(
      'WebAppVerifyMobileId',
      '{"requestId":"r6","url":"https://example.test/verify"}',
      true,
    );

    expect(sent, isEmpty);
  });

  test('reports malformed payloads as a decode error', () async {
    final bridge = buildBridge();

    await bridge.handleEvent('WebAppGetViewportSize', 'not-json', false);

    expect(sent, isEmpty);
  });

  test('tracks the back button and closing behaviour the app asked for', () async {
    final bridge = buildBridge();

    expect(bridge.handlesBackButton, isFalse);
    expect(bridge.needsCloseConfirmation, isFalse);

    await bridge.handleEvent(
      'WebAppSetupBackButton',
      '{"isVisible":true}',
      false,
    );
    await bridge.handleEvent(
      'WebAppSetupClosingBehavior',
      '{"needConfirmation":true}',
      false,
    );

    expect(bridge.handlesBackButton, isTrue);
    expect(bridge.needsCloseConfirmation, isTrue);

    bridge.notifyBackPressed();
    expect(sent.single.$1, 'WebAppBackButtonPressed');
  });

  test('closes the screen when the app asks to', () async {
    final bridge = buildBridge();

    await bridge.handleEvent('WebAppClose', '{}', false);

    expect(closeCalls, 1);
  });

  test('echoes the screen capture behaviour back', () async {
    final bridge = buildBridge();

    await bridge.handleEvent(
      'WebAppSetupScreenCaptureBehavior',
      '{"requestId":"r7","isScreenCaptureEnabled":true}',
      false,
    );

    expect(sent.first.$2, {
      'requestId': 'r7',
      'isScreenCaptureEnabled': true,
    });
  });

  test('answers NFC availability without pretending to support it', () async {
    final bridge = buildBridge();

    await bridge.handleEvent('WebAppNfcGetInfo', '{"requestId":"r8"}', false);
    await bridge.handleEvent(
      'WebAppNfcEmulateNfcTag',
      '{"requestId":"r9"}',
      false,
    );

    expect(sent[0].$2, {
      'requestId': 'r8',
      'available': false,
      'enabled': false,
    });
    expect(sent[1].$2['error'], {
      'code': 'client.nfc_emulate_nfc_tag.not_supported',
    });
  });

  group('unsupported biometry', () {
    const accountId = 900501;
    const tokenKey = 'webapp_bio_900501_777';
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    const methods = {
      'WebAppBiometryRequestAccess': 'biometry_request_access',
      'WebAppBiometryRequestAuth': 'biometry_request_auth',
      'WebAppBiometryUpdateToken': 'biometry_update_token',
      'WebAppBiometryOpenSettings': 'biometry_open_settings',
    };
    late Map<String, String> secureValues;
    late List<String> secureCalls;

    setUpAll(() async {
      final previousProvider = PathProviderPlatform.instance;
      final directory = Directory.systemTemp.createTempSync(
        'synthetic_biometry',
      );
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      File('${directory.path}/komet${AppInstance.suffix}.db').createSync();
      addTearDown(() async {
        await AppDatabase.close();
        PathProviderPlatform.instance = previousProvider;
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      await AppDatabase.init();
      await AppDatabase.saveProfile(
        ProfileData(
          id: accountId,
          firstName: 'Synthetic biometry owner',
          phone: 100501,
          country: 'ZZ',
          accountStatus: 0,
          updateTime: 1,
        ),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'active_account_id': '$accountId',
      });
      await AppDatabase.setWebAppBiometryAccess(
        accountId,
        777,
        requested: true,
        granted: true,
      );
      secureValues = {tokenKey: 'synthetic-legacy-token'};
      secureCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            secureCalls.add(call.method);
            final arguments = call.arguments as Map;
            final key = arguments['key'] as String;
            switch (call.method) {
              case 'read':
                return secureValues[key];
              case 'write':
                secureValues[key] = arguments['value'] as String;
                return null;
              case 'delete':
                secureValues.remove(key);
                return null;
              default:
                throw StateError('Unexpected secure storage operation');
            }
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
    });

    for (final private in [false, true]) {
      test(
        'reports unavailable despite legacy grants on private=$private',
        () async {
          final bridge = buildBridge(privateChannel: private);

          await bridge.handleEvent(
            'WebAppBiometryGetInfo',
            '{"requestId":"synthetic-info"}',
            private,
          );

          expect(sent, hasLength(1));
          expect(sent.single.$1, 'WebAppBiometryGetInfo');
          expect(sent.single.$3, private);
          expect(sent.single.$2, containsPair('available', false));
          expect(sent.single.$2, containsPair('accessRequested', false));
          expect(sent.single.$2, containsPair('accessGranted', false));
          expect(sent.single.$2, containsPair('tokenSaved', false));
          expect(sent.single.$2, containsPair('requestId', 'synthetic-info'));
          expect(sent.single.$2, isNot(contains('token')));
          expect(secureCalls, isEmpty);
        },
      );

      for (final method in methods.entries) {
        test(
          'rejects ${method.key} on private=$private without token changes',
          () async {
            final bridge = buildBridge(privateChannel: private);

            await bridge.handleEvent(
              method.key,
              '{"requestId":"synthetic-reject","token":"synthetic-replacement"}',
              private,
            );

            expect(sent, hasLength(1));
            expect(sent.single.$1, method.key);
            expect(sent.single.$2, {
              'requestId': 'synthetic-reject',
              'error': {'code': 'client.${method.value}.not_supported'},
            });
            expect(sent.single.$3, private);
            expect(secureCalls, isEmpty);
            expect(secureValues, {tokenKey: 'synthetic-legacy-token'});
            expect(await AppDatabase.getWebAppBiometryAccess(accountId, 777), (
              true,
              true,
            ));
          },
        );
      }
    }

    test(
      'rejects empty token updates without deleting the legacy token',
      () async {
        final bridge = buildBridge();

        await bridge.handleEvent(
          'WebAppBiometryUpdateToken',
          '{"requestId":"synthetic-empty","token":""}',
          false,
        );

        expect(sent.single.$2['error'], {
          'code': 'client.biometry_update_token.not_supported',
        });
        expect(secureValues, {tokenKey: 'synthetic-legacy-token'});
        expect(secureCalls, isEmpty);
      },
    );

    test(
      'rejects authorization without creating a token or granting access',
      () async {
        secureValues.clear();
        await AppDatabase.setWebAppBiometryAccess(
          accountId,
          777,
          requested: false,
          granted: false,
        );
        final bridge = buildBridge();

        await bridge.handleEvent(
          'WebAppBiometryRequestAuth',
          '{"requestId":"synthetic-auth"}',
          false,
        );

        expect(sent.single.$2['error'], {
          'code': 'client.biometry_request_auth.not_supported',
        });
        expect(secureValues, isEmpty);
        expect(secureCalls, isEmpty);
        expect(await AppDatabase.getWebAppBiometryAccess(accountId, 777), (
          false,
          false,
        ));
      },
    );

    test(
      'stays silent without a request ID and leaves storage untouched',
      () async {
        final bridge = buildBridge();

        for (final method in methods.keys) {
          await bridge.handleEvent(
            method,
            '{"token":"synthetic-replacement"}',
            false,
          );
        }

        expect(sent, isEmpty);
        expect(secureCalls, isEmpty);
        expect(secureValues, {tokenKey: 'synthetic-legacy-token'});
      },
    );

    test('ignores biometric events when the private channel is off', () async {
      final bridge = buildBridge();

      for (final method in ['WebAppBiometryGetInfo', ...methods.keys]) {
        await bridge.handleEvent(
          method,
          '{"requestId":"synthetic-private"}',
          true,
        );
      }

      expect(sent, isEmpty);
      expect(secureCalls, isEmpty);
    });
  });
}
