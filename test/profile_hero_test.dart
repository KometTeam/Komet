import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/profile_hero.dart';

const _headerStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
const _profileStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w700);

final _tag = UniqueKey();

Widget _header({Object? tag}) => Scaffold(
  body: Row(
    children: [
      ProfileHeroAvatar(
        tag: tag,
        size: 44,
        child: Container(width: 44, height: 44, color: Colors.red),
      ),
      ProfileHeroName(
        tag: tag,
        text: 'Ann',
        style: _headerStyle,
        child: const Text('Ann', style: _headerStyle),
      ),
    ],
  ),
);

Widget _profile({Object? tag, bool loaded = false}) => Scaffold(
  body: Column(
    children: [
      ProfileHeroAvatar(
        tag: tag,
        size: 96,
        child: Container(width: 96, height: 96, color: Colors.red),
      ),
      ProfileHeroName(
        tag: tag,
        text: 'Ann',
        style: _profileStyle,
        child: const Text('Ann', style: _profileStyle),
      ),
      if (loaded) const Text('details'),
    ],
  ),
);

Iterable<double> _fontSizes(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map(
      (t) =>
          t.style?.fontSize ??
          DefaultTextStyle.of(tester.element(find.byWidget(t))).style.fontSize,
    )
    .whereType<double>();

double _flyingAvatarWidth(WidgetTester tester) =>
    tester.getSize(find.byType(FittedBox).first).width;

TextStyle _flyingNameStyle(WidgetTester tester) {
  final transition = find.byType(DefaultTextStyleTransition);
  expect(transition, findsOneWidget);
  return DefaultTextStyle.of(
    tester.element(
      find.descendant(of: transition, matching: find.byType(Text)),
    ),
  ).style;
}

void main() {
  testWidgets('avatar and name fly between header and profile', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: _header(tag: _tag),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => _profile(tag: _tag)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(_fontSizes(tester).any((s) => s > 17 && s < 22), isTrue);
    final pushWidth = _flyingAvatarWidth(tester);
    expect(pushWidth, greaterThan(44));
    expect(pushWidth, lessThan(96));

    await tester.pumpAndSettle();
    expect(find.byType(FittedBox), findsNothing);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(_fontSizes(tester).any((s) => s > 17 && s < 22), isTrue);
    final popWidth = _flyingAvatarWidth(tester);
    expect(popWidth, greaterThan(44));
    expect(popWidth, lessThan(96));

    await tester.pumpAndSettle();
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets(
    'flying name inherits no decoration from the app fallback style',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: _header(tag: _tag),
        ),
      );

      navigator.currentState!.push(
        MaterialPageRoute(builder: (_) => _profile(tag: _tag)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      final style = _flyingNameStyle(tester);
      expect(style.decoration, isNull);
      expect(style.fontFamily, isNull);
      expect(style.fontSize, greaterThan(17));
      expect(style.fontSize, lessThan(22));

      await tester.pumpAndSettle();
    },
  );

  testWidgets('flight stays opaque when the destination finishes loading', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: _header(tag: _tag),
      ),
    );

    var loaded = false;
    late StateSetter setProfileState;
    navigator.currentState!.push(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (_, setState) {
            setProfileState = setState;
            return _profile(tag: _tag, loaded: loaded);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    setProfileState(() => loaded = true);

    var minOpacity = 1.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      final flying = find.byType(FittedBox);
      if (flying.evaluate().isEmpty) break;
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: flying, matching: find.byType(FadeTransition)),
      );
      minOpacity = fade.opacity.value < minOpacity
          ? fade.opacity.value
          : minOpacity;
    }
    expect(minOpacity, 1.0);

    await tester.pumpAndSettle();
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('a null tag opts out of the flight entirely', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: _header(tag: _tag),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute(builder: (_) => _profile(tag: null)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(FittedBox), findsNothing);
    expect(find.byType(DefaultTextStyleTransition), findsNothing);

    await tester.pumpAndSettle();
  });
}
