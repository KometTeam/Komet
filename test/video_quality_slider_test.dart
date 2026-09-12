import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/editor_common.dart';
import 'package:komet/frontend/widgets/attachment/video_edit.dart';
import 'package:komet/frontend/widgets/attachment/video_editor.dart';
import 'package:komet/l10n/app_localizations.dart';

const List<int> _options = [480, 720, 1080];
const double _sliderHeight = 48;

ui.Image _frame() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 16, 16),
    Paint()..color = const Color(0xFF202020),
  );
  return recorder.endRecording().toImageSync(16, 16);
}

Future<List<int>> _pumpEditor(WidgetTester tester) async {
  final picked = <int>[];
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: VideoQualityEditor(
        frame: _frame(),
        geometry: VideoGeometry(
          source: const Size(1280, 720),
          phi: 0,
          flipH: false,
          cropNorm: const Rect.fromLTRB(0, 0, 1, 1),
        ),
        adjust: ColorAdjust(),
        options: _options,
        selected: _options.last,
        fps: 30,
        duration: const Duration(seconds: 12),
        onPreview: (value) async => picked.add(value),
      ),
    ),
  );
  await tester.pump();
  return picked;
}

/// Дорожку качества узнаём по высоте: остальные CustomPaint на экране — кадр.
Rect _sliderRect(WidgetTester tester) {
  for (final element in tester.elementList(find.byType(CustomPaint))) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    if ((box.size.height - _sliderHeight).abs() > 0.5) continue;
    return box.localToGlobal(Offset.zero) & box.size;
  }
  throw StateError('quality slider not laid out');
}

void main() {
  testWidgets('the quality track spans the screen instead of collapsing', (
    tester,
  ) async {
    await _pumpEditor(tester);

    final rect = _sliderRect(tester);
    expect(rect.width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
  });

  testWidgets('tapping the low end picks the smallest option', (tester) async {
    final picked = await _pumpEditor(tester);

    final rect = _sliderRect(tester);
    await tester.tapAt(Offset(rect.left + 2, rect.center.dy));
    await tester.pump();

    await tester.tap(find.text('ГОТОВО'));
    await tester.pump();

    expect(picked, [_options.first]);
  });
}
