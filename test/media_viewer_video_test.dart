import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

const _video = VideoAttachment(
  videoId: 42,
  videoToken: 'synthetic-token',
  duration: 12000,
  width: 1280,
  height: 720,
);

final _message = CachedMessage(
  id: 'synthetic-message',
  accountId: 1,
  chatId: 2,
  senderId: 3,
  text: 'Синтетическая подпись',
  time: DateTime(2026, 1, 2, 12, 34).millisecondsSinceEpoch,
  attachments: const [_video],
);

Future<void> _pumpVideo(
  WidgetTester tester, {
  PhotoViewerActions? actions,
}) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoViewerScreen.video(
        attachment: _video,
        initialVideoSources: const {
          '720p': 'https://media.example.test/video-720.mp4',
          '360p': 'https://media.example.test/video-360.mp4',
        },
        message: _message,
        actions: actions,
        sourceName: 'Тестовый чат',
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('video uses the shared media chrome and advanced controls', (
    tester,
  ) async {
    await _pumpVideo(tester);

    expect(find.text('1 из 1'), findsOneWidget);
    expect(find.textContaining('Тестовый чат'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('00:12'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-play-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('video-settings')), findsOneWidget);
    expect(find.byIcon(Symbols.rotate_90_degrees_ccw), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsNothing);
    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.text('Синтетическая подпись'), findsOneWidget);

    final playCenter = tester.getCenter(
      find.byKey(const ValueKey('video-play-toggle')),
    );
    expect(playCenter.dx, closeTo(tester.view.physicalSize.width / 4, 0.1));
  });

  testWidgets('video rotates left inside the shared viewer', (tester) async {
    await _pumpVideo(tester);

    RotatedBox rotation() =>
        tester.widget<RotatedBox>(find.byKey(const ValueKey('video-rotation')));

    expect(rotation().quarterTurns, 0);
    await tester.tap(find.byIcon(Symbols.rotate_90_degrees_ccw));
    await tester.pump();
    expect(rotation().quarterTurns, 3);
  });

  testWidgets('settings contain playback speed and available qualities', (
    tester,
  ) async {
    await _pumpVideo(tester);

    await tester.tap(find.byKey(const ValueKey('video-settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Скорость'), findsOneWidget);
    expect(find.text('0.5x'), findsOneWidget);
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('Качество'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);
    expect(find.text('360p'), findsOneWidget);
  });

  testWidgets('video menu reuses media actions without frame sharing', (
    tester,
  ) async {
    await _pumpVideo(
      tester,
      actions: PhotoViewerActions(
        goToMessage: (_, _) {},
        forward: (_) {},
        delete: (_, _) {},
        viewAllMedia: () {},
      ),
    );

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Перейти к сообщению'), findsOneWidget);
    expect(find.text('Переслать'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
    expect(find.text('Сохранить как…'), findsOneWidget);
    expect(find.text('Все медиа чата'), findsOneWidget);
    expect(find.textContaining('Share at'), findsNothing);
    expect(find.textContaining('Copy Frame'), findsNothing);
  });
}
