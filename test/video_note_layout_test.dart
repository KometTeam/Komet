import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/video_note_bubble.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

const int _me = 1;
const int _peer = 7;
const int _longNoteMs = 45000;

CachedMessage _note({required int durationMs}) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
  attachments: [
    VideoAttachment(
      videoId: 4242,
      videoToken: 'synthetic-token',
      videoType: 1,
      width: 400,
      height: 400,
      duration: durationMs,
    ),
  ],
);

Future<void> _pumpNote(WidgetTester tester, {required double screenWidth}) async {
  tester.view.physicalSize = Size(screenWidth * 2, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MessageBubble(
            message: _note(durationMs: _longNoteMs),
            isMe: false,
            myId: _me,
            chatType: 'DIALOG',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('у кружка есть длительность слева на одном Y с временем', (
    tester,
  ) async {
    await _pumpNote(tester, screenWidth: 390);

    final duration = find.text('0:45');
    final clock = find.text('05:46');
    expect(duration, findsOneWidget);
    expect(clock, findsOneWidget);

    final durationBox = tester.getRect(duration);
    final clockBox = tester.getRect(clock);

    expect(
      durationBox.center.dy,
      closeTo(clockBox.center.dy, 1.0),
      reason: 'длительность и время должны быть на одном Y',
    );
    expect(
      durationBox.right,
      lessThan(clockBox.left),
      reason: 'длительность должна быть слева от времени',
    );

    final circle = tester.getRect(find.byType(VideoNoteBubble));
    expect(durationBox.left, closeTo(circle.left, 8.0));
    expect(clockBox.right, closeTo(circle.right, 12.0));
  });

  testWidgets('свёрнутый кружок сохраняет базовый размер', (tester) async {
    await _pumpNote(tester, screenWidth: 390);

    final size = tester.getSize(find.byType(VideoNoteBubble));
    expect(size.width, closeTo(210, 0.5));
  });

  testWidgets('кружку хватает ширины под увеличение', (tester) async {
    const expanded = 210 * 1.7;
    final reached = <double, double>{};

    for (final screenWidth in [360.0, 390.0, 412.0, 800.0]) {
      await _pumpNote(tester, screenWidth: screenWidth);
      expect(
        tester.takeException(),
        isNull,
        reason: 'переполнение раскладки при ширине $screenWidth',
      );

      final box =
          tester.renderObject(find.byType(VideoNoteBubble)) as RenderBox;
      final available = box.constraints.maxWidth;
      reached[screenWidth] = (available / 210).clamp(1.0, 1.7);

      expect(
        available,
        lessThanOrEqualTo(screenWidth),
        reason: 'кружку дали больше ширины, чем есть на экране',
      );
    }

    expect(reached[390.0], closeTo(1.7, 0.001));
    expect(reached[412.0], closeTo(1.7, 0.001));
    expect(reached[800.0], closeTo(1.7, 0.001));
    expect(reached[360.0], closeTo((360 - 24) / 210, 0.001));
    expect(reached[360.0], greaterThan(1.55));
    expect(expanded, 357);
  });
}
