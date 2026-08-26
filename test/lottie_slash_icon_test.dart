import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/lottie_slash_icon.dart';
import 'package:lottie/lottie.dart';

const _asset = 'assets/lottie/ic_flash_on_to_off.json';

Map<String, dynamic> _doc() =>
    jsonDecode(File(_asset).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _layers(Map<String, dynamic> doc) =>
    (doc['layers'] as List).cast<Map<String, dynamic>>();

List<Map<String, dynamic>> _maskFrames(Map<String, dynamic> layer) {
  final masks = (layer['masksProperties'] as List).cast<Map<String, dynamic>>();
  return ((masks.single['pt'] as Map)['k'] as List)
      .cast<Map<String, dynamic>>();
}

List<List<num>> _quad(Map<String, dynamic> frame) =>
    ((((frame['s'] as List).first as Map)['v']) as List)
        .map((point) => (point as List).cast<num>())
        .toList();

Widget _host(bool slashed) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: LottieSlashIcon(
        asset: _asset,
        slashed: slashed,
        color: const Color(0xFFFFFFFF),
      ),
    ),
  ),
);

void main() {
  group('Ассет перечёркивания', () {
    test('квадратный, из двух слоёв, каждый со своей маской', () {
      final doc = _doc();
      expect(doc['w'], doc['h']);
      expect(doc['op'], greaterThan(0));

      final layers = _layers(doc);
      expect(layers.length, 2);
      for (final layer in layers) {
        expect(_maskFrames(layer).length, 2, reason: 'маска должна ехать');
        final group = (layer['shapes'] as List).first as Map<String, dynamic>;
        final paths = (group['it'] as List).cast<Map<String, dynamic>>().where(
          (item) => item['ty'] == 'sh',
        );
        expect(paths, isNotEmpty);
        for (final path in paths) {
          expect(
            (path['ks'] as Map)['a'],
            0,
            reason: 'глифы статичны — двигается только маска',
          );
        }
      }
    });

    test('маски слоёв дополняют друг друга', () {
      final layers = _layers(_doc());
      final slashed = _maskFrames(layers.first);
      final plain = _maskFrames(layers.last);

      for (var frame = 0; frame < 2; frame++) {
        final a = _quad(slashed[frame]);
        final b = _quad(plain[frame]);
        expect(
          a.take(2),
          b.take(2),
          reason: 'обе маски должны делить одну и ту же диагональ',
        );
        expect(
          a.skip(2),
          isNot(b.skip(2)),
          reason: 'маски должны смотреть в разные стороны от диагонали',
        );
      }
    });

    test('слои двигаются одинаково', () {
      final layers = _layers(_doc());
      expect(layers.first['ks'], layers.last['ks']);
    });

    testWidgets('композиция читается lottie без предупреждений', (
      tester,
    ) async {
      final composition = await AssetLottie(_asset).load();
      expect(composition.warnings, isEmpty);
      expect(composition.layers.length, 2);
    });
  });

  group('LottieSlashIcon', () {
    testWidgets('рисует lottie в обоих состояниях', (tester) async {
      await tester.pumpWidget(_host(false));
      await tester.pump();
      expect(find.byType(Lottie), findsOneWidget);

      await tester.pumpWidget(_host(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Lottie), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Lottie), findsOneWidget);
    });

    testWidgets('перечёркивание анимируется в обе стороны', (tester) async {
      await tester.pumpWidget(_host(false));
      final controller = tester
          .widget<LottieBuilder>(find.byType(LottieBuilder))
          .controller!;
      expect(controller.value, 0);

      await tester.pumpWidget(_host(true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, greaterThan(0));
      expect(controller.value, lessThan(1));

      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.value, 1);

      await tester.pumpWidget(_host(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, lessThan(1));

      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.value, 0);
    });
  });
}
