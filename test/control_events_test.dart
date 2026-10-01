import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_preview.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;
const int _other = 2;

Map<String, dynamic> _control(int sender, Map<String, dynamic> attach) => {
  'id': '6001',
  'time': DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
  'type': 'USER',
  'sender': sender,
  'text': '',
  'attaches': [
    {'_type': 'CONTROL', ...attach},
  ],
};

Future<void> _pump(WidgetTester tester, Map<String, dynamic> raw) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: MessageBubble(
            message: CachedMessage.fromPushPayload(_me, 3, raw),
            isMe: raw['sender'] == _me,
            myId: _me,
            chatType: 'CHAT',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => ContactCache.put(_other, 'Синтетик'));

  testWidgets('my rename speaks in the second person', (tester) async {
    await _pump(
      tester,
      _control(_me, {'event': 'title', 'title': 'Synthetic title'}),
    );

    expect(
      find.text('Вы изменили название чата на «Synthetic title»'),
      findsOneWidget,
    );
  });

  testWidgets('someone else renaming is named', (tester) async {
    await _pump(
      tester,
      _control(_other, {'event': 'title', 'title': 'Synthetic title'}),
    );

    expect(
      find.text('Синтетик изменил(а) название чата на «Synthetic title»'),
      findsOneWidget,
    );
  });

  testWidgets('a new photo shows the photo under the line', (tester) async {
    await _pump(
      tester,
      _control(_me, {
        'event': 'icon',
        'url': 'https://example.test/icon.jpg',
        'fullUrl': 'https://example.test/icon-full.jpg',
      }),
    );

    expect(find.text('Вы изменили фото чата'), findsOneWidget);
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://example.test/icon.jpg');
  });

  testWidgets('creating a chat quotes its name', (tester) async {
    await _pump(tester, _control(_me, {'event': 'new', 'title': 'Synthetic'}));

    expect(find.text('Вы создали чат «Synthetic»'), findsOneWidget);
  });

  group('chat list preview', () {
    test('a rename is spelled out instead of the bare name', () {
      expect(
        messagePreviewText(
          _control(_me, {'event': 'title', 'title': 'Synthetic title'}),
        ),
        'Название чата изменено на «Synthetic title»',
      );
    });

    test('a new photo and a new chat get their own labels', () {
      expect(
        messagePreviewText(
          _control(_me, {'event': 'icon', 'url': 'https://example.test/i'}),
        ),
        'Фото чата обновлено',
      );
      expect(
        messagePreviewText(
          _control(_me, {'event': 'new', 'title': 'Synthetic'}),
        ),
        'Чат создан',
      );
    });
  });
}
