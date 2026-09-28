import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/voice_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _time = DateTime(2026, 9, 24, 18, 15).millisecondsSinceEpoch;
final _clock = formatClock(DateTime.fromMillisecondsSinceEpoch(_time));

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);
final _android = TargetPlatformVariant.only(TargetPlatform.android);

Widget _bubble({bool showMeta = true, int? audioId = 42}) => MaterialApp(
  theme: ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(primary: Color(0xFF4082E6)),
  ),
  home: Scaffold(
    body: VoiceMessageBubble(
      duration: 27,
      url: '',
      textColor: Colors.white,
      isMe: false,
      showMeta: showMeta,
      time: _time,
      cs: const ColorScheme.dark(primary: Color(0xFF4082E6)),
      chatId: 1,
      messageId: '1',
      senderId: 2,
      audioId: audioId,
      waveData: String.fromCharCodes([10, 40, 80, 20, 60, 90, 30, 50]),
    ),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TranscriptionCache.clear();
  });
  tearDown(TranscriptionCache.clear);

  testWidgets('iOS: the play button is a filled 44 pt circle', (tester) async {
    await tester.pumpWidget(_bubble());
    final play = find.byKey(const ValueKey('voice-play'));
    expect(play, findsOneWidget);
    expect(tester.getSize(play), const Size(44, 44));
    final box = tester.widget<Container>(
      find.descendant(of: play, matching: find.byType(Container)).first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF4082E6));
  }, variant: _ios);

  testWidgets('iOS: the bubble shows its own time without reactions', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble());
    expect(find.text(_clock), findsOneWidget);
    expect(find.text(formatSecondsMmSs(27)), findsOneWidget);
  }, variant: _ios);

  testWidgets('iOS: with reactions the time is not duplicated', (tester) async {
    await tester.pumpWidget(_bubble(showMeta: false));
    expect(find.text(_clock), findsNothing);
  }, variant: _ios);

  testWidgets('Android keeps the current voice bubble', (tester) async {
    await tester.pumpWidget(_bubble(showMeta: false));
    expect(find.byKey(const ValueKey('voice-play')), findsNothing);
    expect(find.text(_clock), findsOneWidget);
  }, variant: _android);

  testWidgets('iOS: the collapsed transcription pill shows «→Т»', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble(audioId: 7));
    expect(find.text('→Т'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('voice-transcribe-expanded')),
      findsNothing,
    );
    final pill = find.byKey(const ValueKey('voice-transcribe'));
    expect(tester.getSize(pill).height, 28);
    final box = tester.widget<Container>(
      find.descendant(of: pill, matching: find.byType(Container)).first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(14));
  }, variant: _ios);

  testWidgets('iOS: expanding shows a chevron and the full-width text', (
    tester,
  ) async {
    TranscriptionCache.put(
      '1',
      TranscriptionResult(status: 1, text: 'синтетическая расшифровка'),
    );
    await tester.pumpWidget(_bubble(audioId: 7));
    await tester.tap(find.byKey(const ValueKey('voice-transcribe')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('voice-transcribe-expanded')),
      findsOneWidget,
    );
    expect(find.text('→Т'), findsNothing);
    expect(find.text('синтетическая расшифровка'), findsOneWidget);
    expect(find.text(_clock), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('voice-transcribe')));
    await tester.pumpAndSettle();
    expect(find.text('→Т'), findsOneWidget);
    expect(find.text('синтетическая расшифровка'), findsNothing);
  }, variant: _ios);

  testWidgets('iOS: no transcription pill without an audio id', (tester) async {
    await tester.pumpWidget(_bubble(audioId: null));
    expect(find.byKey(const ValueKey('voice-transcribe')), findsNothing);
  }, variant: _ios);

  testWidgets('Android keeps the plain «Т» transcription button', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble(audioId: 7));
    expect(find.text('→Т'), findsNothing);
    expect(find.text('Т'), findsOneWidget);
  }, variant: _android);
}
