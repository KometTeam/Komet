import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

const int _me = 1;
const int _peer = 7;
const double _photoWidth = 180;

CachedMessage _message({
  required String text,
  bool withReply = false,
  int senderId = _peer,
}) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: senderId,
  text: text,
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
  payload: withReply
      ? {
          'link': {
            'type': 'REPLY',
            'message': {
              'id': '9',
              'sender': _me,
              'text': 'Пётр Синицын написал очень длинный ответ',
              'time': 0,
              'attaches': [],
            },
          },
        }
      : null,
);

CachedMessage _photoReply() => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  text: 'Вот те раз, не может быть',
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
  attachments: [
    PhotoAttachment(
      baseUrl: 'https://example.com/synthetic.jpg',
      width: _photoWidth.toInt(),
      height: 240,
    ),
  ],
  payload: {
    'link': {
      'type': 'REPLY',
      'message': {
        'id': '9',
        'sender': _me,
        'text':
            'Эта функция, она для «спамеров - скамеров» и «мутных - анонимов»',
        'time': 0,
        'attaches': [],
      },
    },
  },
);

Future<void> _pumpColumn(
  WidgetTester tester,
  List<CachedMessage> messages, {
  required String chatType,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < messages.length; i++)
                MessageBubble(
                  key: ValueKey('bubble$i'),
                  message: messages[i],
                  prevMessage: i > 0 ? messages[i - 1] : null,
                  nextMessage: i < messages.length - 1 ? messages[i + 1] : null,
                  isMe: false,
                  myId: _me,
                  chatType: chatType,
                ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _bubbleRect(WidgetTester tester, int index, String text) {
  final label = find.descendant(
    of: find.byKey(ValueKey('bubble$index')),
    matching: find.text(text),
  );
  final box = find.ancestor(of: label, matching: find.byType(Container)).first;
  return tester.getTopLeft(box) & tester.getSize(box);
}

Future<void> _pumpBubble(WidgetTester tester, CachedMessage message) async {
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
            chatType: 'CHAT',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _rectOf(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  final topLeft = tester.getTopLeft(finder);
  return topLeft & size;
}

void main() {
  setUp(() => ContactCache.put(_peer, 'Пётр Синицын'));

  testWidgets('a long sender name pushes the clock to the bubble edge', (
    tester,
  ) async {
    await _pumpBubble(tester, _message(text: 'нет'));

    final header = _rectOf(tester, find.text('Пётр Синицын'));
    final clock = _rectOf(tester, find.textContaining('05:46'));
    final body = _rectOf(tester, find.text('нет'));

    expect(header.width, greaterThan(body.width + clock.width));
    expect(clock.right, closeTo(header.right, 1));
  });

  testWidgets('the reply quote fills the width the sender name opened up', (
    tester,
  ) async {
    await _pumpBubble(tester, _message(text: 'нет', withReply: true));

    final header = _rectOf(tester, find.text('Пётр Синицын'));
    final label = _rectOf(tester, find.text('Вы'));
    final quote = _rectOf(
      tester,
      find
          .ancestor(of: find.text('Вы'), matching: find.byType(Container))
          .first,
    );
    final clock = _rectOf(tester, find.textContaining('05:46'));

    expect(quote.right, greaterThan(label.right));
    expect(quote.right, closeTo(header.right, 1));
    expect(clock.right, closeTo(header.right, 1));
  });

  testWidgets('grouped bubbles keep the same gap with and without avatars', (
    tester,
  ) async {
    final stream = [
      for (var i = 0; i < 4; i++)
        CachedMessage(
          id: '$i',
          accountId: _me,
          chatId: 2,
          senderId: 404,
          text: 'm$i',
          time: DateTime(2026, 1, 1, 12, 54).millisecondsSinceEpoch + i * 1000,
          status: 'sent',
        ),
    ];

    double gapAt(WidgetTester tester, int index) =>
        _bubbleRect(tester, index + 1, 'm${index + 1}').top -
        _bubbleRect(tester, index, 'm$index').bottom;

    await _pumpColumn(tester, stream, chatType: 'DIALOG', textScale: 0.35);
    final dialogGaps = [for (var i = 0; i < 3; i++) gapAt(tester, i)];

    await _pumpColumn(tester, stream, chatType: 'CHAT', textScale: 0.35);
    final groupGaps = [for (var i = 0; i < 3; i++) gapAt(tester, i)];

    expect(dialogGaps, everyElement(2.0));
    expect(groupGaps, dialogGaps);
  });

  testWidgets('a reply above a photo stays inside the photo width', (
    tester,
  ) async {
    await _pumpBubble(tester, _photoReply());

    final quote = _rectOf(
      tester,
      find
          .ancestor(of: find.text('Вы'), matching: find.byType(Container))
          .first,
    );
    final caption = _rectOf(tester, find.text('Вот те раз, не может быть'));

    expect(quote.width, closeTo(_photoWidth - 16, 1));
    expect(quote.left, greaterThan(0));
    expect(quote.right, lessThanOrEqualTo(caption.left + _photoWidth));
  });

  testWidgets('a bubble without a header or reply still hugs its text', (
    tester,
  ) async {
    await _pumpBubble(tester, _message(text: 'нет', senderId: 404));

    final clock = _rectOf(tester, find.textContaining('05:46'));
    final body = _rectOf(tester, find.text('нет'));

    expect(clock.left, closeTo(body.right + 8, 1));
  });
}
