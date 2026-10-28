import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/edge_stretch_fill.dart';
import 'package:komet/frontend/widgets/upload_bytes_label.dart';
import 'package:komet/frontend/widgets/upload_progress_ring.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/upload_bytes.dart';

const String _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  test('кольцо берёт долю своего слота, а без слота среднее', () {
    const slots = [UploadBytes(2, 10), UploadBytes(6, 10)];
    expect(UploadProgressRing.fractionOf(slots, 1), 0.6);
    expect(UploadProgressRing.fractionOf(slots, null), 0.4);
    expect(UploadProgressRing.fractionOf(const [UploadBytes(2, 10)], 3), 1.0);
    expect(UploadProgressRing.fractionOf(const [UploadBytes.none], 0), 0.0);
    expect(UploadProgressRing.fractionOf(const [], null), 0.0);
  });

  testWidgets('кольцо доезжает до нового процента без пересборки', (
    tester,
  ) async {
    final progress = ValueNotifier<List<UploadBytes>>(const [
      UploadBytes(1, 10),
      UploadBytes.none,
    ]);
    addTearDown(progress.dispose);
    var cancelled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: UploadProgressRing(
            progress: progress,
            slot: 1,
            color: Colors.white,
            onCancel: () => cancelled++,
          ),
        ),
      ),
    );
    progress.value = const [UploadBytes(1, 10), UploadBytes(5, 10)];
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(UploadProgressRing));
    expect(cancelled, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('догруженный слот перестаёт крутиться', (tester) async {
    final progress = ValueNotifier<List<UploadBytes>>(const [
      UploadBytes(4, 10),
    ]);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: UploadProgressRing(
            progress: progress,
            slot: 0,
            color: Colors.white,
          ),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isTrue);

    progress.value = const [UploadBytes(10, 10)];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isFalse);

    progress.value = const [UploadBytes(2, 10)];
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('над медиа видно, сколько уже залито из скольких', (
    tester,
  ) async {
    final progress = ValueNotifier<List<UploadBytes>>(const [
      UploadBytes.none,
      UploadBytes.none,
    ]);
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Center(
          child: SizedBox(
            width: 200,
            child: UploadBytesLabel(progress: progress, slot: 1),
          ),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);

    progress.value = const [
      UploadBytes(1, 2),
      UploadBytes(512 * 1024, 3 * 1024 * 1024),
    ];
    await tester.pump();
    expect(find.text('512.0 KB / 3.0 MB'), findsOneWidget);
  });

  testWidgets('заливка краёв рисуется и без превью, и с ним', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 200,
          height: 100,
          child: EdgeStretchFill(
            source: null,
            imageAspect: 0.3,
            fallback: Colors.grey,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 200,
            height: 100,
            child: EdgeStretchFill(
              source: MemoryImage(base64Decode(_pixel)),
              imageAspect: 0.3,
              fallback: Colors.grey,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
