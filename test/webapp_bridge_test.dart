import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/frontend/screens/webapp/web_app_biometry.dart';
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

class _FakeBiometry implements WebAppBiometry {
  List<String> available = ['finger'];
  bool? consent = true;
  bool passes = true;
  final List<String?> consentReasons = [];
  final List<String?> authReasons = [];

  @override
  Future<List<String>> types() async => available;

  @override
  Future<bool?> confirmAccess(String? reason) async {
    consentReasons.add(reason);
    return consent;
  }

  @override
  Future<bool> authenticate(String? reason) async {
    authReasons.add(reason);
    return passes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<(String, Map<String, dynamic>, bool)> sent;
  late int closeCalls;

  WebAppBridge buildBridge({
    bool privateChannel = false,
    String entryPoint = WebAppEntryPoint.webApp,
    WebAppBiometry? biometry,
  }) {
    return WebAppBridge(
      botId: 777,
      entryPoint: entryPoint,
      privateChannel: privateChannel,
      contextResolver: () => null,
      viewportResolver: () => const Size(420, 800),
      onClose: () => closeCalls++,
      biometry: biometry,
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

  group('biometry', () {
    const accountId = 900501;
    const botId = 777;
    const tokenKey = 'webapp_bio_${accountId}_$botId';
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    late Map<String, String> secureValues;
    late _FakeBiometry biometry;

    Map<String, dynamic> errorOf(
      String slug,
      String reason,
      String requestId,
    ) => {
      'requestId': requestId,
      'error': {'code': 'client.$slug.$reason'},
    };

    Future<void> grantAccess({String? token}) async {
      await AppDatabase.setWebAppBiometryAccess(
        accountId,
        botId,
        requested: true,
        granted: true,
      );
      if (token != null) secureValues[tokenKey] = token;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'active_account_id': '$accountId',
      });
      final directory = Directory.systemTemp.createTempSync(
        'synthetic_biometry_test',
      );
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      secureValues = {};
      biometry = _FakeBiometry();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final arguments = call.arguments as Map;
        final key = arguments['key'] as String?;
        switch (call.method) {
          case 'read':
            return secureValues[key];
          case 'write':
            secureValues[key!] = arguments['value'] as String;
            return null;
          case 'delete':
            secureValues.remove(key);
            return null;
          default:
            throw StateError('Unexpected secure storage call ${call.method}');
        }
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(channel, null);
        await AppDatabase.close();
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

    test('reports what the device offers before any access is given', () async {
      biometry.available = ['face', 'finger'];
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryGetInfo',
        '{"requestId":"synthetic-info"}',
        false,
      );

      expect(sent.single.$2, {
        'requestId': 'synthetic-info',
        'available': true,
        'type': ['face', 'finger'],
        'accessRequested': false,
        'accessGranted': false,
        'tokenSaved': false,
        'deviceId': null,
      });
      expect(biometry.consentReasons, isEmpty);
      expect(biometry.authReasons, isEmpty);
    });

    test('reports biometry as unavailable on a device without it', () async {
      biometry.available = [];
      await grantAccess(token: 'synthetic-token');
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryGetInfo',
        '{"requestId":"synthetic-info"}',
        false,
      );
      for (final method in [
        'WebAppBiometryRequestAccess',
        'WebAppBiometryRequestAuth',
        'WebAppBiometryOpenSettings',
      ]) {
        await bridge.handleEvent(
          method,
          '{"requestId":"synthetic-off"}',
          false,
        );
      }
      await bridge.handleEvent(
        'WebAppBiometryUpdateToken',
        '{"requestId":"synthetic-off","token":"synthetic-replacement"}',
        false,
      );

      expect(sent.first.$2['available'], isFalse);
      expect(sent.first.$2['type'], ['unknown']);
      expect(sent.skip(1).map((event) => event.$2), [
        errorOf('biometry_request_access', 'not_supported', 'synthetic-off'),
        errorOf('biometry_request_auth', 'not_supported', 'synthetic-off'),
        errorOf('biometry_open_settings', 'not_supported', 'synthetic-off'),
        errorOf('biometry_update_token', 'not_supported', 'synthetic-off'),
      ]);
      expect(secureValues, {tokenKey: 'synthetic-token'});
      expect(biometry.authReasons, isEmpty);
    });

    test('asks the user once before granting access', () async {
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryRequestAccess',
        '{"requestId":"synthetic-access","reason":"  Synthetic reason  "}',
        false,
      );
      await bridge.handleEvent(
        'WebAppBiometryRequestAccess',
        '{"requestId":"synthetic-again"}',
        false,
      );

      expect(biometry.consentReasons, ['Synthetic reason']);
      expect(biometry.authReasons, isEmpty);
      for (final event in sent) {
        expect(event.$2['accessRequested'], isTrue);
        expect(event.$2['accessGranted'], isTrue);
        expect(event.$2['tokenSaved'], isFalse);
      }
      expect(await AppDatabase.getWebAppBiometryAccess(accountId, botId), (
        true,
        true,
      ));
    });

    test('remembers a refusal and keeps the device id private', () async {
      biometry.consent = false;
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryRequestAccess',
        '{"requestId":"synthetic-access"}',
        false,
      );
      await bridge.handleEvent(
        'WebAppBiometryRequestAuth',
        '{"requestId":"synthetic-auth"}',
        false,
      );

      expect(sent.first.$2['accessRequested'], isTrue);
      expect(sent.first.$2['accessGranted'], isFalse);
      expect(sent.first.$2['deviceId'], isNull);
      expect(
        sent.last.$2,
        errorOf('biometry_request_auth', 'permission_denied', 'synthetic-auth'),
      );
      expect(biometry.authReasons, isEmpty);
    });

    test('grants nothing when the question cannot be shown', () async {
      biometry.consent = null;
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryRequestAccess',
        '{"requestId":"synthetic-access"}',
        false,
      );

      expect(
        sent.single.$2,
        errorOf('biometry_request_access', 'request_error', 'synthetic-access'),
      );
      expect(await AppDatabase.getWebAppBiometryAccess(accountId, botId), (
        false,
        false,
      ));
    });

    test(
      'hands the token over only after the biometric check passes',
      () async {
        await grantAccess(token: 'synthetic-token');
        final bridge = buildBridge(biometry: biometry);

        biometry.passes = false;
        await bridge.handleEvent(
          'WebAppBiometryRequestAuth',
          '{"requestId":"synthetic-denied","reason":"Synthetic reason"}',
          false,
        );
        biometry.passes = true;
        await bridge.handleEvent(
          'WebAppBiometryRequestAuth',
          '{"requestId":"synthetic-passed"}',
          false,
        );

        expect(
          sent.first.$2,
          errorOf('biometry_request_auth', 'auth_failed', 'synthetic-denied'),
        );
        expect(sent.last.$2, {
          'requestId': 'synthetic-passed',
          'status': 'authorized',
          'token': 'synthetic-token',
        });
        expect(biometry.authReasons, ['Synthetic reason', null]);
      },
    );

    test('does not invent a token when none was saved', () async {
      await grantAccess();
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryRequestAuth',
        '{"requestId":"synthetic-auth"}',
        false,
      );

      expect(
        sent.single.$2,
        errorOf('biometry_request_auth', 'not_found', 'synthetic-auth'),
      );
      expect(secureValues, isEmpty);
      expect(biometry.authReasons, isEmpty);
    });

    test('saves a token only after the biometric check passes', () async {
      await grantAccess(token: 'synthetic-token');
      final bridge = buildBridge(biometry: biometry);

      biometry.passes = false;
      await bridge.handleEvent(
        'WebAppBiometryUpdateToken',
        '{"requestId":"synthetic-denied","token":"synthetic-replacement"}',
        false,
      );
      expect(secureValues, {tokenKey: 'synthetic-token'});

      biometry.passes = true;
      await bridge.handleEvent(
        'WebAppBiometryUpdateToken',
        '{"requestId":"synthetic-passed","token":"synthetic-replacement"}',
        false,
      );

      expect(
        sent.first.$2,
        errorOf('biometry_update_token', 'auth_failed', 'synthetic-denied'),
      );
      expect(sent.last.$2, {
        'requestId': 'synthetic-passed',
        'status': 'updated',
      });
      expect(secureValues, {tokenKey: 'synthetic-replacement'});
    });

    test(
      'refuses a token from an app without access or one too large',
      () async {
        final bridge = buildBridge(biometry: biometry);

        await bridge.handleEvent(
          'WebAppBiometryUpdateToken',
          '{"requestId":"synthetic-stranger","token":"synthetic-replacement"}',
          false,
        );
        await grantAccess();
        await bridge.handleEvent(
          'WebAppBiometryUpdateToken',
          jsonEncode({'requestId': 'synthetic-large', 'token': 'x' * 1025}),
          false,
        );

        expect(sent.map((event) => event.$2), [
          errorOf(
            'biometry_update_token',
            'permission_denied',
            'synthetic-stranger',
          ),
          errorOf('biometry_update_token', 'too_large', 'synthetic-large'),
        ]);
        expect(secureValues, isEmpty);
        expect(biometry.authReasons, isEmpty);
      },
    );

    test('removes the token without asking for a check', () async {
      await grantAccess(token: 'synthetic-token');
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryUpdateToken',
        '{"requestId":"synthetic-remove","token":""}',
        false,
      );

      expect(sent.single.$2, {
        'requestId': 'synthetic-remove',
        'status': 'removed',
      });
      expect(secureValues, isEmpty);
      expect(biometry.authReasons, isEmpty);
    });

    test(
      'settings let the user change the decision and restart the app',
      () async {
        await AppDatabase.setWebAppBiometryAccess(
          accountId,
          botId,
          requested: true,
          granted: false,
        );
        final bridge = buildBridge(biometry: biometry);

        biometry.consent = false;
        await bridge.handleEvent(
          'WebAppBiometryOpenSettings',
          '{"requestId":"synthetic-kept"}',
          false,
        );
        expect(closeCalls, 0);

        biometry.consent = true;
        await bridge.handleEvent(
          'WebAppBiometryOpenSettings',
          '{"requestId":"synthetic-changed"}',
          false,
        );

        expect(sent.map((event) => event.$2), [
          {'requestId': 'synthetic-kept', 'status': 'opened'},
          {'requestId': 'synthetic-changed', 'status': 'opened'},
        ]);
        expect(closeCalls, 1);
        expect(await AppDatabase.getWebAppBiometryAccess(accountId, botId), (
          true,
          true,
        ));
      },
    );

    test('answers on the channel the request came from', () async {
      await grantAccess(token: 'synthetic-token');
      final bridge = buildBridge(privateChannel: true, biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryGetInfo',
        '{"requestId":"synthetic-info"}',
        true,
      );
      await bridge.handleEvent(
        'WebAppBiometryRequestAuth',
        '{"requestId":"synthetic-auth"}',
        true,
      );

      expect(sent.map((event) => event.$3), [true, true]);
      expect(sent.last.$2['token'], 'synthetic-token');
    });

    test('answers nothing useful without an active account', () async {
      SharedPreferences.setMockInitialValues({});
      final bridge = buildBridge(biometry: biometry);

      await bridge.handleEvent(
        'WebAppBiometryGetInfo',
        '{"requestId":"synthetic-info"}',
        false,
      );
      await bridge.handleEvent(
        'WebAppBiometryRequestAuth',
        '{"requestId":"synthetic-auth"}',
        false,
      );

      expect(sent.first.$2['available'], isFalse);
      expect(
        sent.last.$2,
        errorOf('biometry_request_auth', 'access_denied', 'synthetic-auth'),
      );
      expect(biometry.authReasons, isEmpty);
    });
  });
}
