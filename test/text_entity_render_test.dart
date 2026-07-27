import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/frontend/widgets/text_entity_actions.dart';
import 'package:komet/l10n/app_localizations.dart';

const String _sample = '+70001234567 тест 2200123456789019 @ExampleBot';

CachedMessage _message(String text) => CachedMessage(
  id: '1',
  accountId: 1,
  chatId: 2,
  senderId: 1,
  text: text,
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await tester.pump();
}

TextSpan? _spanWithText(WidgetTester tester, String text) {
  TextSpan? found;
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    widget.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  return found;
}

void main() {
  testWidgets('a bubble highlights the phone, the card and the nickname', (
    tester,
  ) async {
    await _pump(
      tester,
      MessageBubble(
        message: _message(_sample),
        isMe: false,
        myId: 1,
        chatType: 'DIALOG',
      ),
    );

    final accent = ThemeData().colorScheme.primary;
    final phone = _spanWithText(tester, '+70001234567');
    final card = _spanWithText(tester, '2200123456789019');
    final mention = _spanWithText(tester, '@ExampleBot');
    final plain = _spanWithText(tester, ' тест ');

    expect(phone?.style?.color, accent);
    expect(card?.style?.color, accent);
    expect(mention?.style?.color, accent);
    expect(plain?.style?.color, isNot(accent));

    expect(phone?.recognizer, isA<LongPressGestureRecognizer>());
    expect(card?.recognizer, isA<LongPressGestureRecognizer>());
    expect(mention?.recognizer, isA<TapGestureRecognizer>());
  });

  testWidgets('a server USER_MENTION by name opens the profile on tap', (
    tester,
  ) async {
    final message = CachedMessage(
      id: '2',
      accountId: 1,
      chatId: 2,
      senderId: 1,
      text: '@ExampleBot test',
      time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
      status: 'sent',
      payload: const {
        'elements': [
          {'entityName': 'ExampleBot', 'type': 'USER_MENTION', 'length': 11},
        ],
      },
    );

    await _pump(
      tester,
      MessageBubble(message: message, isMe: false, myId: 1, chatType: 'DIALOG'),
    );

    final mention = _spanWithText(tester, '@ExampleBot');
    expect(mention?.style?.color, ThemeData().colorScheme.primary);
    expect(mention?.recognizer, isA<TapGestureRecognizer>());
  });

  testWidgets('copy mode taps instead of opening a menu', (tester) async {
    await _pump(
      tester,
      FormattedMessageText(
        text: _sample,
        ranges: const [],
        entityMode: TextEntityMode.copy,
        style: const TextStyle(fontSize: 16),
      ),
    );

    expect(
      _spanWithText(tester, '+70001234567')?.recognizer,
      isA<TapGestureRecognizer>(),
    );
    expect(
      _spanWithText(tester, '2200123456789019')?.recognizer,
      isA<TapGestureRecognizer>(),
    );
  });

  Future<void> openMenuAt(WidgetTester tester, Offset at) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showCardEntityMenu(context, '2200123456789019', at: at),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Rect menuRect(WidgetTester tester) => tester.getRect(
    find
        .ancestor(
          of: find.text('Скопировать номер карты'),
          matching: find.byType(SingleChildScrollView),
        )
        .first,
  );

  testWidgets('a menu opened near the bottom flips above the anchor', (
    tester,
  ) async {
    await openMenuAt(tester, const Offset(200, 940));

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final rect = menuRect(tester);

    expect(rect.bottom, lessThanOrEqualTo(screen.height - 8));
    expect(rect.bottom, lessThan(940));
    expect(rect.top, greaterThanOrEqualTo(8));
  });

  testWidgets('a menu opened near the top stays below the anchor', (
    tester,
  ) async {
    await openMenuAt(tester, const Offset(200, 100));

    final rect = menuRect(tester);
    expect(rect.top, greaterThanOrEqualTo(100));
  });

  testWidgets('the card menu shows the copy action and the card mask', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showCardEntityMenu(
            context,
            '2200123456789019',
            at: const Offset(200, 300),
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Скопировать номер карты'), findsOneWidget);
    expect(find.text('MIR*9019'), findsOneWidget);
    expect(find.text('МИР'), findsOneWidget);
  });
}
