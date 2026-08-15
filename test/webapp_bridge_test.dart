import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/webapp/web_app_bridge.dart';

void main() {
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
}
