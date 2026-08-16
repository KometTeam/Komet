import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/frontend/widgets/attachment/photo_editor.dart';
import 'package:komet/l10n/app_localizations.dart';

void main() {
  late Directory tmp;
  late File source;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('komet_markup_test');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF224466),
    );
    final image = await recorder.endRecording().toImage(8, 8);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    source = File('${tmp.path}/source.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  testWidgets('пустая разметка закрывается без результата', (tester) async {
    var previews = 0;
    Object? popped = 'untouched';
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold();
          },
        ),
      ),
    );

    unawaited(
      Navigator.of(context)
          .push<Object?>(
            MaterialPageRoute<Object?>(
              builder: (_) => PhotoDrawEditor(
                source: source,
                imageWidth: 8,
                imageHeight: 8,
                onPreview: (_) async => previews++,
              ),
            ),
          )
          .then((value) => popped = value),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.check));
    await tester.pumpAndSettle();

    expect(previews, 0);
    expect(popped, isNull);
  });
}
