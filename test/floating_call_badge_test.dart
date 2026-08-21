import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/active_call.dart';
import 'package:komet/core/calls/call_session.dart';
import 'package:komet/core/calls/ws2_signaling.dart';
import 'package:komet/frontend/widgets/floating_call_badge.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

const _name = 'Тестовый собеседник';

CallSession _session() => CallSession(
  ws2Config: Ws2Config(uri: Uri.parse('wss://calls.invalid/ws2'), userId: 42),
  role: CallRole.caller,
);

Widget _host() => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => Stack(
    children: [
      child!,
      const Positioned.fill(child: FloatingCallBadgeLayer()),
    ],
  ),
  home: const Scaffold(body: SizedBox.expand()),
);

final Finder _hangup = find.byIcon(Symbols.call_end);

double _controlsOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find.ancestor(of: _hangup, matching: find.byType(Opacity)).first,
    )
    .opacity;

Finder get _badge => find.descendant(
  of: find.byType(FloatingCallBadgeLayer),
  matching: find.byType(ScaleTransition),
);

Offset _badgeCorner(WidgetTester tester) => tester.getTopLeft(_badge);

void main() {
  tearDown(() {
    ActiveCall.instance.detach();
    while (ActiveCall.instance.screenVisible.value) {
      ActiveCall.instance.leaveScreen();
    }
  });

  testWidgets('бейджик виден только пока экран звонка закрыт', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text(_name), findsNothing);

    ActiveCall.instance.attach(session: _session(), name: _name);
    await tester.pump();
    expect(find.text(_name), findsOneWidget);

    ActiveCall.instance.enterScreen();
    await tester.pump();
    expect(find.text(_name), findsNothing);

    ActiveCall.instance.leaveScreen();
    await tester.pump();
    expect(find.text(_name), findsOneWidget);

    ActiveCall.instance.detach();
    await tester.pump();
    expect(find.text(_name), findsNothing);
  });

  testWidgets('тап раскрывает кнопки и повторный тап их прячет', (
    tester,
  ) async {
    ActiveCall.instance.attach(session: _session(), name: _name);
    await tester.pumpWidget(_host());

    expect(
      _hangup,
      findsNothing,
      reason: 'свёрнутый бейджик не держит кнопки в дереве',
    );

    await tester.tap(find.text(_name));
    await tester.pumpAndSettle();
    expect(_hangup, findsOneWidget);
    expect(_controlsOpacity(tester), 1);

    await tester.tap(find.text(_name));
    await tester.pumpAndSettle();
    expect(_hangup, findsNothing);
  });

  testWidgets('кнопки прячутся сами, если бейджик не трогают', (tester) async {
    ActiveCall.instance.attach(session: _session(), name: _name);
    await tester.pumpWidget(_host());

    await tester.tap(find.text(_name));
    await tester.pumpAndSettle();
    expect(_controlsOpacity(tester), 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_hangup, findsNothing);
  });

  testWidgets('перетаскивание липнет к краю экрана', (tester) async {
    ActiveCall.instance.attach(session: _session(), name: _name);
    await tester.pumpWidget(_host());

    final screen = tester.getSize(find.byType(FloatingCallBadgeLayer)).width;
    final start = _badgeCorner(tester);
    final width = tester.getSize(_badge).width;
    expect(start.dx + width, moreOrLessEquals(screen - 12));

    await tester.timedDrag(
      find.text(_name),
      const Offset(-260, -120),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(_badgeCorner(tester).dx, moreOrLessEquals(12));
    expect(_badgeCorner(tester).dy, lessThan(start.dy));
  });
}
