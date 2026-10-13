import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/edge_stretch_fill.dart';
import 'package:komet/frontend/widgets/upload_progress_ring.dart';

const String _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  test('кольцо берёт долю своего слота, а без слота среднее', () {
    expect(UploadProgressRing.fractionOf(const [0.2, 0.6], 1), 0.6);
    expect(UploadProgressRing.fractionOf(const [0.2, 0.6], null), 0.4);
    expect(UploadProgressRing.fractionOf(const [0.2], 3), 1.0);
    expect(UploadProgressRing.fractionOf(const [], null), 0.0);
  });

  testWidgets('кольцо доезжает до нового процента без пересборки', (
    tester,
  ) async {
    final progress = ValueNotifier<List<double>>(const [0.1, 0.0]);
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
    progress.value = const [0.1, 0.5];
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(UploadProgressRing));
    expect(cancelled, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('догруженный слот перестаёт крутиться', (tester) async {
    final progress = ValueNotifier<List<double>>(const [0.4]);
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

    progress.value = const [1.0];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isFalse);

    progress.value = const [0.2];
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
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
