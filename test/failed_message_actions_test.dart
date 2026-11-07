import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/view/message_row_widgets.dart';
import 'package:komet/l10n/app_localizations.dart';

CachedMessage _message({int senderId = 101, String status = 'error'}) =>
    CachedMessage(
      id: 'temp_failed_1',
      accountId: 101,
      chatId: 303,
      senderId: senderId,
      text: 'Synthetic failed message',
      time: 1700000000000,
      status: status,
    );

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('only an outgoing error is treated as a failed send', () {
    expect(isFailedOutgoingMessage(_message(), 101), isTrue);
    expect(isFailedOutgoingMessage(_message(status: 'pending'), 101), isFalse);
    expect(isFailedOutgoingMessage(_message(senderId: 202), 101), isFalse);
  });

  testWidgets(
    'a failed send has a separate retry button and a delete-only menu',
    (tester) async {
      final selected = ValueNotifier<Set<String>>(const {});
      addTearDown(selected.dispose);
      var retries = 0;

      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 340,
            child: SelectableMessageRow(
              message: _message(),
              outgoing: true,
              failedSend: true,
              selectedIds: selected,
              selectionAnim: kAlwaysDismissedAnimation,
              isSelectionActive: () => false,
              onToggleSelection: () {},
              onEnterSelection: () {},
              onStartTextSelection: (_) {},
              onDragTextSelection: (_) {},
              onDelete: () {},
              onRetry: () => retries++,
              onReply: () {},
              onForward: () {},
              onMarkUnread: () {},
              onPin: () {},
              onCopyLink: () {},
              onReact: (_) {},
              onDoubleTapReact: (_) {},
              isPinned: () => false,
              child: const SizedBox(
                height: 72,
                child: Center(child: Text('failed source row')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final retry = find.byKey(
        const ValueKey('failed-message-retry-temp_failed_1'),
      );
      expect(retry, findsOneWidget);
      expect(find.text('Отправить повторно'), findsOneWidget);
      await tester.tap(retry);
      await tester.pump(const Duration(milliseconds: 250));
      expect(retries, 1);
      expect(find.text('Удалить'), findsNothing);

      await tester.tap(find.text('failed source row'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 350));

      final sourceOpacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('message-actions-source-temp_failed_1')),
      );
      expect(sourceOpacity.opacity, 0);
      expect(find.text('Ответить'), findsNothing);
      expect(find.text('Переслать'), findsNothing);
      expect(find.text('Непрочитанное'), findsNothing);
      expect(find.text('Удалить'), findsOneWidget);
      expect(find.text('Отправить повторно'), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final restoredOpacity = tester.widget<Opacity>(
        find.byKey(const ValueKey('message-actions-source-temp_failed_1')),
      );
      expect(restoredOpacity.opacity, 1);
    },
  );
}
