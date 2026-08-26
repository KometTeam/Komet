import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/composer_morph_icon.dart';
import 'package:komet/frontend/widgets/glossy_pill.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';

const _assets = [
  'assets/lottie/ic_mic_to_videocam.json',
  'assets/lottie/ic_videocam_to_mic.json',
  'assets/lottie/ic_mic_to_send.json',
  'assets/lottie/ic_videocam_to_send.json',
  'assets/lottie/ic_send_to_mic.json',
  'assets/lottie/ic_send_to_videocam.json',
];

Widget _host(ComposerAction action) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ComposerMorphIcon(action: action, color: const Color(0xFFFFFFFF)),
    ),
  ),
);

List<Map<String, dynamic>> _paths(Map<String, dynamic> doc) {
  final layer = (doc['layers'] as List).first as Map<String, dynamic>;
  final group = (layer['shapes'] as List).first as Map<String, dynamic>;
  return (group['it'] as List)
      .cast<Map<String, dynamic>>()
      .where((item) => item['ty'] == 'sh')
      .toList();
}

void main() {
  group('Ассеты морфинга', () {
    test('файлы существуют и разбираются', () {
      for (final path in _assets) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path отсутствует');
        final doc =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(doc['w'], doc['h'], reason: '$path должен быть квадратным');
        expect(doc['op'], greaterThan(0));
        expect(_paths(doc), isNotEmpty);
      }
    });

    test('обе ключевые точки контура имеют одинаковое число вершин', () {
      for (final path in _assets) {
        final doc =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        for (final shape in _paths(doc)) {
          final frames = (shape['ks'] as Map)['k'] as List;
          expect(frames.length, 2, reason: '$path: ожидались две ключевые точки');
          final from = ((frames.first as Map)['s'] as List).first as Map;
          final to = ((frames.last as Map)['s'] as List).first as Map;
          for (final key in ['v', 'i', 'o']) {
            expect(
              (to[key] as List).length,
              (from[key] as List).length,
              reason: '$path: «$key» разной длины — морф не построится',
            );
          }
        }
      }
    });

    test('анимации не начинаются и не заканчиваются смещением', () {
      for (final path in _assets) {
        final doc =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        final layer = (doc['layers'] as List).first as Map<String, dynamic>;
        final transform = layer['ks'] as Map<String, dynamic>;
        for (final key in ['r', 's', 'p']) {
          final prop = transform[key] as Map<String, dynamic>;
          if (prop['a'] != 1) continue;
          final frames = (prop['k'] as List).cast<Map<String, dynamic>>();
          expect(
            frames.first['s'],
            frames.last['s'],
            reason: '$path: «$key» должен возвращаться в исходное значение',
          );
        }
      }
    });
  });

  group('ComposerMorphIcon', () {
    testWidgets('в покое рисует обычную иконку', (tester) async {
      await tester.pumpWidget(_host(ComposerAction.mic));

      expect(find.byIcon(Symbols.mic), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
    });

    testWidgets('на смене состояния запускает lottie', (tester) async {
      await tester.pumpWidget(_host(ComposerAction.mic));
      await tester.pumpWidget(_host(ComposerAction.videocam));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Lottie), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('после анимации возвращает обычную иконку', (tester) async {
      await tester.pumpWidget(_host(ComposerAction.mic));
      await tester.pumpWidget(_host(ComposerAction.send));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byIcon(Symbols.send), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
    });

    testWidgets('каждая следующая смена тоже анимируется', (tester) async {
      await tester.pumpWidget(_host(ComposerAction.mic));

      const sequence = [
        ComposerAction.videocam,
        ComposerAction.send,
        ComposerAction.videocam,
        ComposerAction.mic,
        ComposerAction.send,
        ComposerAction.mic,
      ];

      for (final action in sequence) {
        await tester.pumpWidget(_host(action));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byType(Lottie),
          findsOneWidget,
          reason: 'переход в $action должен проигрываться',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(
          find.byType(Lottie),
          findsNothing,
          reason: 'переход в $action должен завершаться статикой',
        );
        expect(find.byIcon(composerActionIcon(action)), findsOneWidget);
      }
    });

    testWidgets('морф переживает появление обработчика нажатия', (tester) async {
      Widget host(bool sendMode) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlossyPill(
              onTap: sendMode ? () {} : null,
              keepInkLayer: true,
              child: ComposerMorphIcon(
                action: sendMode ? ComposerAction.send : ComposerAction.mic,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(host(false));
      await tester.pumpWidget(host(true));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Lottie), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byIcon(Symbols.send), findsOneWidget);
    });

    testWidgets('обратный переход тоже завершается статикой', (tester) async {
      await tester.pumpWidget(_host(ComposerAction.send));
      await tester.pumpWidget(_host(ComposerAction.videocam));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byIcon(Symbols.videocam), findsOneWidget);
      expect(find.byType(Lottie), findsNothing);
    });
  });
}
