import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/ios_typography.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/animoji.dart';

const int _me = 1;
const int _peer = 7;
const Color _primary = Color(0xFF4082E6);

CachedMessage _text({required Map<String, dynamic> reactions}) => CachedMessage(
  id: 'r1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  text: 'привет',
  time: DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch,
  status: 'sent',
  payload: {'reactionInfo': reactions},
);

Future<void> _pump(
  WidgetTester tester,
  CachedMessage message, {
  required String chatType,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(primary: _primary),
      ),
      home: Scaffold(
        body: MessageBubble(
          key: const ValueKey('bubble'),
          message: message,
          isMe: false,
          myId: _me,
          chatType: chatType,
          reactionAnimojiResolver: (emoji) => Animoji(
            id: 1,
            emoji: emoji,
            iconUrl: 'https://example.com/a.png',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> _counter(
  String reaction,
  int count, {
  bool mine = false,
}) => {
  'totalCount': count,
  'counters': [
    {'reaction': reaction, 'count': count},
  ],
  'yourReaction': ?(mine ? reaction : null),
};

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);
final _android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  testWidgets('iOS reaction chip is a 30pt capsule with a 15pt count', (
    tester,
  ) async {
    await _pump(tester, _text(reactions: _counter('👍', 3)), chatType: 'CHAT');

    final chip = find.byKey(const ValueKey('reaction-chip-👍'));
    expect(chip, findsOneWidget);
    expect(tester.getSize(chip).height, 30);

    final count = tester.widget<Text>(find.text('3'));
    expect(count.style?.fontSize, IosTypography.reactionCount);
    expect(count.style?.fontSize, 15);
    expect(count.style?.fontFeatures, IosTypography.tabularDigits);
  }, variant: _ios);

  testWidgets('iOS own reaction is filled with the accent', (tester) async {
    await _pump(
      tester,
      _text(reactions: _counter('🔥', 2, mine: true)),
      chatType: 'CHAT',
    );

    final chip = tester.widget<Container>(
      find.byKey(const ValueKey('reaction-chip-🔥')),
    );
    final decoration = chip.decoration! as BoxDecoration;
    expect(decoration.color, _primary);

    final count = tester.widget<Text>(find.text('2'));
    expect(count.style?.color, const ColorScheme.dark().onPrimary);
  }, variant: _ios);

  testWidgets('iOS dialog avatar is 20pt inside the capsule', (tester) async {
    await _pump(
      tester,
      _text(reactions: _counter('❤️', 1, mine: true)),
      chatType: 'DIALOG',
    );

    final chip = find.byKey(const ValueKey('reaction-chip-❤️'));
    expect(tester.getSize(chip).height, 30);
    final avatar = find.descendant(
      of: chip,
      matching: find.byType(CircleAvatar),
    );
    expect(tester.getSize(avatar), const Size(20, 20));
  }, variant: _ios);

  testWidgets('iOS reaction chips are spaced 6pt apart', (tester) async {
    await _pump(
      tester,
      _text(
        reactions: {
          'totalCount': 2,
          'counters': [
            {'reaction': '👍', 'count': 1},
            {'reaction': '🔥', 'count': 1},
          ],
        },
      ),
      chatType: 'CHAT',
    );

    final first = tester.getRect(
      find.byKey(const ValueKey('reaction-chip-👍')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('reaction-chip-🔥')),
    );
    expect(second.left - first.right, 6);
  }, variant: _ios);

  testWidgets('Android keeps the compact reaction chip', (tester) async {
    await _pump(
      tester,
      _text(reactions: _counter('👍', 3, mine: true)),
      chatType: 'DIALOG',
    );

    expect(find.byKey(const ValueKey('reaction-chip-👍')), findsNothing);
    final count = tester.widget<Text>(find.text('3'));
    expect(count.style?.fontSize, 11);
    expect(count.style?.color, _primary);
    final avatar = tester.getSize(find.byType(CircleAvatar).last);
    expect(avatar, const Size(17, 17));
  }, variant: _android);
}
