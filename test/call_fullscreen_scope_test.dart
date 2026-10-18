import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCVideoValue;
import 'package:komet/frontend/screens/calls/call_fullscreen.dart';

const _portraitPhone = Size(390, 844);
const _landscapePhone = Size(844, 390);
const _tablet = Size(820, 1180);
const _desktopShare = RTCVideoValue(width: 1920, height: 1080);
const _webcam = RTCVideoValue(width: 1280, height: 720);
const _phoneShare = RTCVideoValue(width: 720, height: 1280);
const _landscape = [
  'DeviceOrientation.landscapeLeft',
  'DeviceOrientation.landscapeRight',
];

final _android = TargetPlatformVariant.only(TargetPlatform.android);
final _linux = TargetPlatformVariant.only(TargetPlatform.linux);

void main() {
  final orientations = <List<String>>[];
  final uiModes = <String>[];
  bool? fullscreen;
  VoidCallback? toggle;

  setUp(() {
    orientations.clear();
    uiModes.clear();
    fullscreen = null;
    toggle = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'SystemChrome.setPreferredOrientations':
              orientations.add((call.arguments as List).cast<String>());
            case 'SystemChrome.setEnabledSystemUIMode':
              uiModes.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester,
    Size size,
    ValueListenable<RTCVideoValue> video, {
    Object stage = 'stage',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CallFullscreenScope(
          stage: stage,
          video: video,
          builder: (context, value, onToggle) {
            fullscreen = value;
            toggle = onToggle;
            return const SizedBox();
          },
        ),
      ),
    );
  }

  ValueNotifier<RTCVideoValue> videoOf(RTCVideoValue value) {
    final video = ValueNotifier(value);
    addTearDown(video.dispose);
    return video;
  }

  testWidgets('широкая трансляция на телефоне сама на весь экран и набок', (
    tester,
  ) async {
    await pump(tester, _portraitPhone, videoOf(_desktopShare));
    expect(fullscreen, isTrue);
    expect(orientations.single, _landscape);
    expect(uiModes.single, 'SystemUiMode.immersiveSticky');
  }, variant: _android);

  testWidgets('экран телефона в портрете сам не разворачиваем', (tester) async {
    await pump(tester, _landscapePhone, videoOf(_phoneShare));
    expect(fullscreen, isFalse);
    expect(orientations, isEmpty);
    expect(uiModes, isEmpty);
  }, variant: _android);

  testWidgets('кадр пришёл позже, режим по нему', (tester) async {
    final video = videoOf(RTCVideoValue.empty);
    await pump(tester, _portraitPhone, video);
    expect(fullscreen, isFalse);

    video.value = _desktopShare;
    await tester.pump();
    expect(fullscreen, isTrue);
    expect(orientations.single, _landscape);
  }, variant: _android);

  testWidgets('картинка стала узкой, отпускаем ориентацию и панели', (
    tester,
  ) async {
    final video = videoOf(_desktopShare);
    await pump(tester, _landscapePhone, video);

    video.value = _phoneShare;
    await tester.pump();
    expect(fullscreen, isFalse);
    expect(orientations.last, isEmpty);
    expect(uiModes.last, 'SystemUiMode.edgeToEdge');
  }, variant: _android);

  testWidgets('вышли из авто-режима, сам не возвращается', (tester) async {
    final video = videoOf(_desktopShare);
    await pump(tester, _landscapePhone, video);

    toggle!();
    await tester.pump();
    expect(fullscreen, isFalse);
    expect(orientations.last, isEmpty);

    video.value = _webcam;
    await tester.pump();
    expect(fullscreen, isFalse);
    expect(orientations, hasLength(2));
  }, variant: _android);

  testWidgets('новая сцена снова разворачивается сама', (tester) async {
    final video = videoOf(_desktopShare);
    await pump(tester, _landscapePhone, video);
    toggle!();
    await tester.pump();

    await pump(tester, _landscapePhone, video, stage: 'other');
    expect(fullscreen, isTrue);
    expect(orientations.last, _landscape);
  }, variant: _android);

  testWidgets('узкую картинку вручную на весь экран без поворота', (
    tester,
  ) async {
    await pump(tester, _portraitPhone, videoOf(_phoneShare));

    toggle!();
    await tester.pump();
    expect(fullscreen, isTrue);
    expect(orientations, isEmpty);
    expect(uiModes.single, 'SystemUiMode.immersiveSticky');
  }, variant: _android);

  testWidgets('назад выходит из полноэкранного, экран остаётся', (
    tester,
  ) async {
    await pump(tester, _portraitPhone, videoOf(_phoneShare));
    toggle!();
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(fullscreen, isFalse);
    expect(find.byType(CallFullscreenScope), findsOneWidget);
    expect(uiModes.last, 'SystemUiMode.edgeToEdge');
  }, variant: _android);

  testWidgets('Esc на десктопе выходит, системе ничего не шлём', (
    tester,
  ) async {
    await pump(tester, const Size(1280, 800), videoOf(_desktopShare));
    expect(fullscreen, isFalse);

    toggle!();
    await tester.pump();
    expect(fullscreen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(fullscreen, isFalse);
    expect(orientations, isEmpty);
    expect(uiModes, isEmpty);
  }, variant: _linux);

  testWidgets('закрыли сцену, ориентация и панели вернулись', (tester) async {
    await pump(tester, _landscapePhone, videoOf(_desktopShare));
    await tester.pumpWidget(const SizedBox());
    expect(orientations.last, isEmpty);
    expect(uiModes.last, 'SystemUiMode.edgeToEdge');
  }, variant: _android);

  testWidgets('планшет сам не разворачивает и не поворачивается', (
    tester,
  ) async {
    await pump(tester, _tablet, videoOf(_desktopShare));
    expect(fullscreen, isFalse);

    toggle!();
    await tester.pump();
    expect(fullscreen, isTrue);
    expect(orientations, isEmpty);
    expect(uiModes.single, 'SystemUiMode.immersiveSticky');
  }, variant: _android);
}
