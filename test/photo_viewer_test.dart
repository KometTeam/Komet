import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

CachedMessage _message({String? text}) => CachedMessage(
  id: '77',
  accountId: 1,
  chatId: 2,
  senderId: 5,
  text: text,
  time: DateTime.now().millisecondsSinceEpoch,
  status: 'sent',
  attachments: const [],
);

Future<void> _pumpViewer(
  WidgetTester tester, {
  CachedMessage? message,
  PhotoViewerActions? actions,
}) async {
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
        message: message,
        actions: actions,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows who sent the photo and when', (tester) async {
    await _pumpViewer(tester, message: _message());

    expect(find.textContaining('сегодня в'), findsOneWidget);
  });

  testWidgets('rotate button turns the photo by 90 degrees', (tester) async {
    await _pumpViewer(tester, message: _message());

    expect(
      tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns,
      0,
    );

    await tester.tap(find.byIcon(Symbols.rotate_90_degrees_ccw));
    await tester.pump();

    expect(
      tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns,
      1,
    );
  });

  testWidgets('shows the photo caption when there is one', (tester) async {
    await _pumpViewer(tester, message: _message(text: 'Делу время'));

    expect(find.text('Делу время'), findsOneWidget);
  });

  testWidgets('arrows step between photos', (tester) async {
    await _pumpViewer(tester, message: _message());

    expect(find.byIcon(Symbols.chevron_left), findsNothing);
    expect(find.byIcon(Symbols.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.chevron_left), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right), findsNothing);

    await tester.tap(find.byIcon(Symbols.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.chevron_right), findsOneWidget);
  });

  testWidgets('arrow keys step between photos', (tester) async {
    await _pumpViewer(tester, message: _message());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.chevron_left), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right), findsNothing);
  });

  testWidgets('single tap hides the chrome, another tap brings it back', (
    tester,
  ) async {
    await _pumpViewer(tester, message: _message());

    double chromeOpacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    expect(chromeOpacity(), 1);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(chromeOpacity(), 0);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(chromeOpacity(), 1);
  });

  testWidgets('three-dot menu appears only with actions', (tester) async {
    await _pumpViewer(tester, message: _message());
    expect(find.byIcon(Symbols.more_vert), findsNothing);

    await _pumpViewer(
      tester,
      message: _message(),
      actions: PhotoViewerActions(
        goToMessage: (_, _) {},
        delete: (_, _) {},
      ),
    );
    expect(find.byIcon(Symbols.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Перейти к сообщению'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
    expect(find.text('Сохранить как…'), findsOneWidget);
    expect(find.text('Переслать'), findsNothing);
  });

  testWidgets('menu action closes the viewer before running', (tester) async {
    var ran = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      photos: const [
                        PhotoAttachment(baseUrl: 'https://example.com/a.jpg'),
                      ],
                      message: _message(),
                      actions: PhotoViewerActions(
                        goToMessage: (_, _) => ran = true,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Перейти к сообщению'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(ran, isTrue);
    expect(find.byType(PhotoViewerScreen), findsNothing);
  });
}
