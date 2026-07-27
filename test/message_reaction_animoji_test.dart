import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/lottie_image.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/animoji.dart';

const _reaction = '🔥';
const _messageId = 'synthetic-message';

CachedMessage _message() => const CachedMessage(
  id: _messageId,
  accountId: 1,
  chatId: 2,
  senderId: 3,
  text: 'Synthetic message',
  time: 1000,
  payload: {
    'reactionInfo': {
      'counters': [
        {'reaction': _reaction, 'count': 1},
      ],
      'yourReaction': _reaction,
      'totalCount': 1,
    },
  },
);

Future<void> _pumpBubble(
  WidgetTester tester, {
  required Animoji animoji,
  required ValueListenable<ReactionAnimationEvent?> animation,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MessageBubble(
          message: _message(),
          isMe: false,
          myId: 1,
          chatType: 'DIALOG',
          reactionAnimation: animation,
          reactionAnimojiResolver: (emoji) =>
              emoji == _reaction ? animoji : null,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('reaction animoji stays static until its reaction is applied', (
    tester,
  ) async {
    final animation = ValueNotifier<ReactionAnimationEvent?>(null);
    addTearDown(animation.dispose);
    const animoji = Animoji(
      id: 1,
      emoji: _reaction,
      iconUrl: 'https://example.test/reaction.png',
      lottieUrl: 'https://example.test/reaction-idle.json',
      lottiePlayUrl: 'https://example.test/reaction-play.json',
    );

    await _pumpBubble(tester, animoji: animoji, animation: animation);

    var glyph = tester.widget<LottieImage>(find.byType(LottieImage));
    expect(glyph.url, animoji.iconUrl);
    expect(glyph.lottieUrl, isNull);

    animation.value = const ReactionAnimationEvent(
      messageId: 'different-synthetic-message',
      emoji: _reaction,
      token: 1,
    );
    await tester.pump();
    glyph = tester.widget<LottieImage>(find.byType(LottieImage));
    expect(glyph.lottieUrl, isNull);

    animation.value = const ReactionAnimationEvent(
      messageId: _messageId,
      emoji: _reaction,
      token: 2,
    );
    await tester.pump();
    final animatedGlyphs = tester
        .widgetList<LottieImage>(find.byType(LottieImage))
        .toList();
    expect(animatedGlyphs, hasLength(2));
    final body = animatedGlyphs.singleWhere(
      (item) => item.lottieUrl == animoji.lottieUrl,
    );
    final effect = animatedGlyphs.singleWhere(
      (item) => item.lottieUrl == animoji.lottiePlayUrl,
    );
    expect(body.size, 18);
    expect(body.repeat, isFalse);
    expect(effect.size, 36);
    expect(effect.repeat, isFalse);
    final effectFinder = find.byWidgetPredicate(
      (widget) =>
          widget is LottieImage &&
          widget.lottieUrl == animoji.lottiePlayUrl,
    );
    expect(tester.getSize(effectFinder), const Size.square(36));
    final players = tester
        .widgetList<LottiePlayer>(find.byType(LottiePlayer))
        .toList();
    expect(players, hasLength(2));
    expect(players.every((player) => player.animate && !player.repeat), isTrue);
  });

  testWidgets('reaction without an icon holds the first lottie frame', (
    tester,
  ) async {
    final animation = ValueNotifier<ReactionAnimationEvent?>(null);
    addTearDown(animation.dispose);
    const animoji = Animoji(
      id: 2,
      emoji: _reaction,
      lottieUrl: 'https://example.test/reaction-idle.json',
    );

    await _pumpBubble(tester, animoji: animoji, animation: animation);

    final glyph = tester.widget<LottieImage>(find.byType(LottieImage));
    expect(glyph.lottieUrl, animoji.lottieUrl);
    expect(glyph.animate, isFalse);
    expect(glyph.repeat, isFalse);
    final player = tester.widget<LottiePlayer>(find.byType(LottiePlayer));
    expect(player.animate, isFalse);
    expect(player.repeat, isFalse);
  });
}
