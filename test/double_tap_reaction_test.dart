import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/account/account_models.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/view/message_row_widgets.dart';
import 'package:komet/frontend/widgets/lottie_image.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show api;
import 'package:komet/models/animoji.dart';

const _reaction = '🔥';
const _messageId = 'synthetic-message';
const _glyphSize = 18.0;
const _effectSize = 36.0;
const _peak = 1.65;

const _animoji = Animoji(
  id: 1,
  emoji: _reaction,
  iconUrl: 'https://example.test/reaction.png',
  lottieUrl: 'https://example.test/reaction-idle.json',
  lottiePlayUrl: 'https://example.test/reaction-play.json',
);

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

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

Future<void> _pumpBubble(
  WidgetTester tester,
  ValueListenable<ReactionAnimationEvent?> animation, {
  Animoji? animoji = _animoji,
}) async {
  await tester.pumpWidget(
    _app(
      MessageBubble(
        message: _message(),
        isMe: false,
        myId: 1,
        chatType: 'DIALOG',
        reactionAnimation: animation,
        reactionAnimojiResolver: (emoji) => emoji == _reaction ? animoji : null,
      ),
    ),
  );
  await tester.pump();
}

Finder _lottie(String url) => find.byWidgetPredicate(
  (widget) => widget is LottieImage && widget.lottieUrl == url,
);

double _width(WidgetTester tester, Finder finder) =>
    tester.getRect(finder).width;

void main() {
  group('PrivacyConfig.doubleTapReaction', () {
    test('falls back to the heart when the server sends nothing', () {
      expect(PrivacyConfig.fromMap(const {}).doubleTapReaction, '❤️');
      expect(
        PrivacyConfig.fromMap(const {
          'DOUBLE_TAP_REACTION_VALUE': '',
        }).doubleTapReaction,
        '❤️',
      );
    });

    test('uses the chosen reaction', () {
      expect(
        PrivacyConfig.fromMap(const {
          'DOUBLE_TAP_REACTION_VALUE': _reaction,
        }).doubleTapReaction,
        _reaction,
      );
    });

    test('is absent when double tap reactions are switched off', () {
      expect(
        PrivacyConfig.fromMap(const {
          'DOUBLE_TAP_REACTION_DISABLED': true,
          'DOUBLE_TAP_REACTION_VALUE': _reaction,
        }).doubleTapReaction,
        isNull,
      );
    });
  });

  testWidgets('a double tap sends the configured reaction, one tap does not', (
    tester,
  ) async {
    final selected = ValueNotifier<Set<String>>(const {});
    addTearDown(selected.dispose);
    final reacted = <String>[];
    final menuReacted = <String>[];
    await tester.pumpWidget(
      _app(
        SelectableMessageRow(
          message: _message(),
          isMe: false,
          selectedIds: selected,
          selectionAnim: kAlwaysDismissedAnimation,
          isSelectionActive: () => false,
          onToggleSelection: () {},
          onEnterSelection: () {},
          onStartTextSelection: (_) {},
          onDragTextSelection: (_) {},
          onDelete: () {},
          isPinned: () => false,
          onReact: menuReacted.add,
          onDoubleTapReact: reacted.add,
          child: const SizedBox(height: 60, child: Text('synthetic row')),
        ),
      ),
    );

    await tester.tap(find.text('synthetic row'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('synthetic row'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(reacted, ['❤️']);
    expect(menuReacted, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await api.dispose();
  });

  testWidgets('a double-tapped reaction grows with its effect and settles', (
    tester,
  ) async {
    final animation = ValueNotifier<ReactionAnimationEvent?>(null);
    addTearDown(animation.dispose);
    await _pumpBubble(tester, animation);

    animation.value = const ReactionAnimationEvent(
      messageId: _messageId,
      emoji: _reaction,
      token: 1,
      emphasized: true,
    );
    await tester.pump();
    final body = _lottie(_animoji.lottieUrl!);
    final effect = _lottie(_animoji.lottiePlayUrl!);
    expect(_width(tester, body), closeTo(_glyphSize, 0.01));

    await tester.pump(const Duration(milliseconds: 150));
    expect(_width(tester, body), closeTo(_glyphSize * _peak, 0.01));
    expect(_width(tester, effect), closeTo(_effectSize * _peak, 0.01));

    await tester.pump(const Duration(milliseconds: 990));
    expect(_width(tester, body), closeTo(_glyphSize * _peak, 0.01));

    await tester.pump(const Duration(milliseconds: 160));
    final settling = _width(tester, body);
    expect(settling, lessThan(_glyphSize * _peak));
    expect(settling, greaterThan(_glyphSize));

    await tester.pump(const Duration(milliseconds: 150));
    expect(_width(tester, body), closeTo(_glyphSize, 0.01));
  });

  testWidgets('a reaction picked from the menu keeps its size', (tester) async {
    final animation = ValueNotifier<ReactionAnimationEvent?>(null);
    addTearDown(animation.dispose);
    await _pumpBubble(tester, animation);

    animation.value = const ReactionAnimationEvent(
      messageId: _messageId,
      emoji: _reaction,
      token: 1,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _width(tester, _lottie(_animoji.lottieUrl!)),
      closeTo(_glyphSize, 0.01),
    );
  });

  testWidgets('a plain emoji reaction is emphasised too', (tester) async {
    final animation = ValueNotifier<ReactionAnimationEvent?>(null);
    addTearDown(animation.dispose);
    await _pumpBubble(tester, animation, animoji: null);
    final emoji = find.text(_reaction);
    final rest = _width(tester, emoji);

    animation.value = const ReactionAnimationEvent(
      messageId: _messageId,
      emoji: _reaction,
      token: 1,
      emphasized: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(_width(tester, emoji), closeTo(rest * _peak, 0.01));
    await tester.pumpAndSettle();
    expect(_width(tester, emoji), closeTo(rest, 0.01));
  });
}
