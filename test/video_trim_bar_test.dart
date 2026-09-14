import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:komet/frontend/widgets/attachment/video_preview_screen.dart';

const Duration _total = Duration(seconds: 10);

Future<(Duration?, Duration?)> _dragHandle(
  WidgetTester tester, {
  required double fromFraction,
  required double toFraction,
  Duration start = Duration.zero,
  Duration end = _total,
}) async {
  final controller = VideoPlayerController.file(File('trim_bar_fixture.mp4'));
  addTearDown(controller.dispose);

  Duration? settledStart;
  Duration? settledEnd;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: TrimBar(
              frames: const [],
              controller: controller,
              duration: _total,
              start: start,
              end: end,
              onScrub: (_, _) {},
              onTrim: (trimStart, trimEnd, active) {
                if (active) return;
                settledStart = trimStart;
                settledEnd = trimEnd;
              },
            ),
          ),
        ),
      ),
    ),
  );

  final bar = tester.getRect(find.byType(TrimBar));
  final gesture = await tester.startGesture(
    Offset(bar.left + bar.width * fromFraction, bar.center.dy),
  );
  await gesture.moveTo(
    Offset(bar.left + bar.width * toFraction, bar.center.dy),
  );
  await gesture.up();
  await tester.pump();

  return (settledStart, settledEnd);
}

void main() {
  testWidgets('the end handle keeps the dragged position after the lift', (
    tester,
  ) async {
    final (start, end) = await _dragHandle(
      tester,
      fromFraction: 0.99,
      toFraction: 0.5,
    );

    expect(start, Duration.zero);
    expect(end, isNotNull);
    expect(end!.inMilliseconds, closeTo(5000, 200));
  });

  testWidgets('the end handle dragged back reports the full duration', (
    tester,
  ) async {
    final (start, end) = await _dragHandle(
      tester,
      fromFraction: 0.3,
      toFraction: 1.0,
      end: const Duration(seconds: 3),
    );

    expect(start, Duration.zero);
    expect(end, _total);
  });

  testWidgets('the start handle keeps the dragged position after the lift', (
    tester,
  ) async {
    final (start, end) = await _dragHandle(
      tester,
      fromFraction: 0.0,
      toFraction: 0.4,
    );

    expect(end, _total);
    expect(start, isNotNull);
    expect(start!.inMilliseconds, closeTo(4000, 200));
  });
}
