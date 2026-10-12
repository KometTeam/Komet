import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/view/chat_list_tile.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/frontend/widgets/reply_preview.dart';
import 'package:komet/frontend/widgets/toast_placement.dart';
import 'package:komet/frontend/widgets/undo_notification.dart';
import 'package:komet/models/attachment.dart';

int _mounts = 0;

class _MountCounter extends StatefulWidget {
  final String label;

  const _MountCounter(this.label);

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    _mounts++;
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 72, child: Text(widget.label));
}

Widget _chatList(List<String> order, int revision) => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: [
        for (final id in order)
          AnimatedChatTile(
            key: ValueKey('chat_$id'),
            id: id,
            revision: revision,
            isNew: false,
            child: _MountCounter(id),
          ),
      ],
    ),
  ),
);

Widget _notificationHost() => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showCustomNotification(context, 'Синтетика'),
          child: const Text('show'),
        ),
      ),
    ),
  ),
);

void _useScreen(WidgetTester tester, {double keyboard = 0}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  tester.view.viewPadding = const FakeViewPadding(bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a moving chat tile keeps its content mounted', (tester) async {
    _mounts = 0;
    await tester.pumpWidget(_chatList(['a', 'b', 'c'], 0));
    await tester.pump();
    expect(_mounts, 3);

    await tester.pumpWidget(_chatList(['c', 'a', 'b'], 1));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_mounts, 3);
    expect(
      tester.getTopLeft(find.text('c')).dy,
      lessThan(tester.getTopLeft(find.text('a')).dy),
    );
  });

  testWidgets('a new notification replaces the previous one', (tester) async {
    _useScreen(tester);
    await tester.pumpWidget(_notificationHost());

    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CustomNotification), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(CustomNotification), findsNothing);
  });

  testWidgets('a notification stays above the keyboard', (tester) async {
    _useScreen(tester, keyboard: 300);
    await tester.pumpWidget(_notificationHost());

    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 400));

    final pill = tester.getRect(find.text('Синтетика'));
    expect(pill.bottom, lessThan(800 - 300 - 34));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a reply thumbnail decodes at its own size', (tester) async {
    final preview = ReplyPreview.of(
      attachments: const [
        PhotoAttachment(
          baseUrl: 'https://example.test/synthetic.jpg',
          width: 2000,
          height: 2000,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => preview.thumbnail(
            size: const Size(40, 40),
            cs: Theme.of(context).colorScheme,
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.memCacheWidth, 120);
  });

  Widget toastHost({
    required void Function(BuildContext) show,
    required Widget obstruction,
  }) => MaterialApp(
    locale: const Locale('ru'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Stack(
          children: [
            Center(
              child: TextButton(
                onPressed: () => show(context),
                child: const Text('show'),
              ),
            ),
            obstruction,
          ],
        ),
      ),
    ),
  );

  const fab = Positioned(
    right: 20,
    bottom: 110,
    child: ToastObstruction(
      child: SizedBox(key: ValueKey('fab'), width: 56, height: 56),
    ),
  );

  testWidgets('a toast narrows beside a side button instead of rising', (
    tester,
  ) async {
    _useScreen(tester);
    await tester.pumpWidget(
      toastHost(
        show: (context) => showCustomNotification(context, 'Синтетика'),
        obstruction: fab,
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.getRect(find.byKey(const ValueKey('fab')));
    final toast = tester.getRect(find.text('Синтетика'));
    expect(toast.right, lessThan(button.left));
    expect(toast.bottom, greaterThan(button.top));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a toast rises above a full-width bar', (tester) async {
    _useScreen(tester);
    await tester.pumpWidget(
      toastHost(
        show: (context) => showCustomNotification(context, 'Синтетика'),
        obstruction: const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ToastObstruction(
            child: SizedBox(key: ValueKey('bar'), height: 160),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 400));

    final bar = tester.getRect(find.byKey(const ValueKey('bar')));
    expect(
      tester.getRect(find.text('Синтетика')).bottom,
      lessThan(bar.top - ToastBottomPositioned.obstructionGap),
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('continue runs the pending action right away', (tester) async {
    _useScreen(tester);
    var committed = 0;
    var undone = 0;
    await tester.pumpWidget(
      toastHost(
        show: (context) => showUndoNotification(
          context,
          'Чат удалён',
          onCommit: () => committed++,
          onUndo: () => undone++,
        ),
        obstruction: fab,
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('Отменить'), findsOneWidget);

    final button = tester.getRect(find.byKey(const ValueKey('fab')));
    final toast = tester.getRect(
      find
          .ancestor(
            of: find.text('Чат удалён'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(toast.right, lessThan(button.left));

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(committed, 1);
    expect(undone, 0);
    expect(find.text('Чат удалён'), findsNothing);
  });
}
