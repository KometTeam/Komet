import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

const int _me = 1;
const int _peer = 7;
const String _pixel =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

CachedMessage _replyingTo({
  required Map<String, dynamic> attach,
  String? quotedText,
  String text = 'ответ',
}) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  text: text,
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
  payload: {
    'link': {
      'type': 'REPLY',
      'message': {
        'id': '9',
        'sender': _peer,
        'text': quotedText,
        'time': 0,
        'attaches': [attach],
      },
    },
  },
);

Map<String, dynamic> _photo() => {
  '_type': 'PHOTO',
  'previewData': _pixel,
  'width': 800,
  'height': 600,
};

Map<String, dynamic> _video() => {
  '_type': 'VIDEO',
  'previewData': _pixel,
  'width': 720,
  'height': 1280,
  'duration': 4000,
};

Map<String, dynamic> _voice() => {
  '_type': 'AUDIO',
  'duration': 3000,
};

Map<String, dynamic> _file(String name) => {'_type': 'FILE', 'name': name};

Future<void> _pump(WidgetTester tester, CachedMessage message) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MessageBubble(
            message: message,
            isMe: false,
            myId: _me,
            chatType: 'DIALOG',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => ContactCache.put(_peer, 'Олег Козлов'));

  testWidgets('ответ на фото без подписи рисует само фото', (tester) async {
    await _pump(tester, _replyingTo(attach: _photo()));

    expect(find.byType(Image), findsWidgets);
    expect(find.text('Фото'), findsNothing);
  });

  testWidgets('ответ на видео без подписи рисует первый кадр', (tester) async {
    await _pump(tester, _replyingTo(attach: _video()));

    expect(find.byType(Image), findsWidgets);
    expect(find.text('Видео'), findsNothing);
  });

  testWidgets('ответ на видео с подписью — подпись и иконка видео', (
    tester,
  ) async {
    await _pump(
      tester,
      _replyingTo(attach: _video(), quotedText: 'смотри что нашёл'),
    );

    expect(find.text('смотри что нашёл'), findsOneWidget);
    expect(find.byIcon(Symbols.videocam), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('ответ на голосовое — иконка микрофона и подпись', (
    tester,
  ) async {
    await _pump(tester, _replyingTo(attach: _voice()));

    expect(find.text('Голосовое сообщение'), findsOneWidget);
    expect(find.byIcon(Symbols.mic), findsOneWidget);
  });

  testWidgets('ответ на файл — имя файла, а не слово «Файл»', (tester) async {
    await _pump(tester, _replyingTo(attach: _file('otchet-2026.pdf')));

    expect(find.text('otchet-2026.pdf'), findsOneWidget);
    expect(find.text('Файл'), findsNothing);
    expect(find.byIcon(Symbols.description), findsOneWidget);
  });

  testWidgets('файл без имени остаётся «Файл»', (tester) async {
    await _pump(tester, _replyingTo(attach: {'_type': 'FILE'}));

    expect(find.text('Файл'), findsOneWidget);
  });
}
