import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/ios_bubble_metrics.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show animojiModule;

CachedMessage _long() => CachedMessage(
  id: '1',
  accountId: 1,
  chatId: 2,
  senderId: 3,
  text: List.filled(40, 'слово').join(' '),
  time: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
  status: 'sent',
);

Future<double> _bubbleMaxWidth(
  WidgetTester tester, {
  required String chatType,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MessageBubble(
          message: _long(),
          isMe: false,
          myId: 1,
          chatType: chatType,
          listWidth: 390,
        ),
      ),
    ),
  );
  await tester.pump();
  final boxes = tester.widgetList<Container>(
    find.descendant(
      of: find.byType(MessageBubble),
      matching: find.byType(Container),
    ),
  );
  return boxes
      .map((c) => c.constraints?.maxWidth)
      .whereType<double>()
      .firstWhere((w) => w.isFinite && w > 100);
}

void main() {
  setUpAll(() => expect(animojiModule, isNotNull));

  test('bubble width on a phone and on a tablet', () {
    expect(IosBubbleMetrics.maxBubbleWidth(390, avatarSlot: false), 339);
    expect(IosBubbleMetrics.maxBubbleWidth(390, avatarSlot: true), 301);
    expect(IosBubbleMetrics.maxBubbleWidth(820, avatarSlot: false), 682);
  });

  testWidgets('iOS bubbles follow the iOS width metrics', (tester) async {
    expect(await _bubbleMaxWidth(tester, chatType: 'DIALOG'), 339);
    expect(await _bubbleMaxWidth(tester, chatType: 'CHAT'), 301);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android keeps three quarters of the list width', (tester) async {
    expect(await _bubbleMaxWidth(tester, chatType: 'DIALOG'), 390 * 0.75);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
