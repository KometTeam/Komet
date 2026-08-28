import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

double _scale(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getMaxScaleOnAxis();

Offset _translation(WidgetTester tester) {
  final matrix = tester
      .widget<Transform>(
        find
            .descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(Transform),
            )
            .first,
      )
      .transform;
  return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
}

bool _onFirstPage(WidgetTester tester) =>
    tester.any(find.byIcon(Symbols.chevron_right)) &&
    !tester.any(find.byIcon(Symbols.chevron_left));

Future<void> _pumpViewer(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoViewerScreen(
        photos: const [
          PhotoAttachment(baseUrl: 'https://example.com/a.jpg'),
          PhotoAttachment(baseUrl: 'https://example.com/b.jpg'),
        ],
      ),
    ),
  );
  await tester.pump();
}

Future<void> _spread(
  WidgetTester tester,
  TestGesture a,
  TestGesture b, {
  int steps = 10,
  double step = 15,
}) async {
  for (var i = 0; i < steps; i++) {
    await a.moveBy(Offset(-step, 0));
    await b.moveBy(Offset(step, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('щипок увеличивает фото, если первый палец успел сдвинуться', (
    tester,
  ) async {
    await _pumpViewer(tester);
    expect(_scale(tester), 1);

    final first = await tester.startGesture(const Offset(390, 400));
    await tester.pump(const Duration(milliseconds: 40));
    await first.moveBy(const Offset(-8, 2));
    await tester.pump(const Duration(milliseconds: 16));

    final second = await tester.startGesture(const Offset(410, 400));
    await tester.pump(const Duration(milliseconds: 16));

    await _spread(tester, first, second);

    expect(_scale(tester), greaterThan(1.5));

    await first.up();
    await second.up();
    await tester.pump();
  });

  testWidgets('щипок работает, когда один палец неподвижен', (tester) async {
    await _pumpViewer(tester);

    final anchor = await tester.startGesture(const Offset(380, 400));
    await tester.pump(const Duration(milliseconds: 30));
    final moving = await tester.startGesture(const Offset(420, 400));
    await tester.pump(const Duration(milliseconds: 16));

    for (var i = 0; i < 10; i++) {
      await moving.moveBy(const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(_scale(tester), greaterThan(1.5));

    await anchor.up();
    await moving.up();
    await tester.pump();
  });

  testWidgets('одним пальцем страницы всё ещё листаются', (tester) async {
    await _pumpViewer(tester);
    expect(_onFirstPage(tester), isTrue);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_onFirstPage(tester), isFalse);
  });

  testWidgets('увеличенное фото двигается, а не листается', (tester) async {
    await _pumpViewer(tester);

    final first = await tester.startGesture(const Offset(390, 400));
    final second = await tester.startGesture(const Offset(410, 400));
    await _spread(tester, first, second);
    await first.up();
    await second.up();
    await tester.pump();

    expect(_scale(tester), greaterThan(1.5));
    final before = _translation(tester);

    final pan = await tester.startGesture(const Offset(400, 400));
    for (var i = 0; i < 10; i++) {
      await pan.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pan.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_onFirstPage(tester), isTrue);
    expect(_translation(tester), isNot(before));
  });
}
