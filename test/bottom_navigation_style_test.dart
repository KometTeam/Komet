import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_bottom_navigation_style.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/frontend/widgets/bottom_navigation_style_card.dart';
import 'package:komet/frontend/widgets/compact_bottom_navigation_bar.dart';
import 'package:komet/frontend/widgets/main_navigation_items.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppBottomNavigationStyle.current.value = BottomNavigationStyle.floating;
    Haptics.enabled = false;
  });

  tearDown(() {
    AppBottomNavigationStyle.current.value = BottomNavigationStyle.floating;
    Haptics.enabled = true;
  });

  test(
    'keeps the existing style by default and restores the saved choice',
    () async {
      expect(
        await AppBottomNavigationStyle.load(),
        BottomNavigationStyle.floating,
      );
      await AppBottomNavigationStyle.save(BottomNavigationStyle.compact);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppBottomNavigationStyle.prefKey), 'compact');
      AppBottomNavigationStyle.current.value = BottomNavigationStyle.floating;
      expect(
        await AppBottomNavigationStyle.load(),
        BottomNavigationStyle.compact,
      );
      await prefs.setString(AppBottomNavigationStyle.prefKey, 'unknown-style');
      expect(
        await AppBottomNavigationStyle.load(),
        BottomNavigationStyle.floating,
      );
    },
  );

  testWidgets(
    'the appearance setting applies live and keeps the selected tab',
    (tester) async {
      var selected = 2;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: const Align(
                alignment: Alignment.topCenter,
                child: BottomNavigationStyleCard(),
              ),
              bottomNavigationBar:
                  ValueListenableBuilder<BottomNavigationStyle>(
                    valueListenable: AppBottomNavigationStyle.current,
                    builder: (context, style, _) =>
                        style == BottomNavigationStyle.compact
                        ? CompactBottomNavigationBar(
                            items: mainNavigationItems,
                            currentIndex: selected,
                            onTap: (index) => setState(() => selected = index),
                          )
                        : const SizedBox(height: 68),
                  ),
            ),
          ),
        ),
      );
      expect(find.byType(CompactBottomNavigationBar), findsNothing);
      await tester.tap(find.text('Компактная'));
      await tester.pumpAndSettle();
      expect(find.byType(CompactBottomNavigationBar), findsOneWidget);
      expect(
        tester
            .widget<CompactBottomNavigationBar>(
              find.byType(CompactBottomNavigationBar),
            )
            .currentIndex,
        2,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppBottomNavigationStyle.prefKey), 'compact');

      final semantics = tester.ensureSemantics();
      for (var index = 0; index < mainNavigationItems.length; index++) {
        final label = mainNavigationItems[index].label;
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(selected, index);
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
      }
      semantics.dispose();

      await tester.tap(find.text('Плавающая'));
      await tester.pumpAndSettle();
      expect(find.byType(CompactBottomNavigationBar), findsNothing);
      expect(selected, 3);
      expect(prefs.getString(AppBottomNavigationStyle.prefKey), 'floating');
    },
  );

  testWidgets(
    'compact tabs reserve the iPhone home indicator and all tap areas',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: CompactBottomNavigationBar(
                items: mainNavigationItems,
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      final bar = find.byType(CompactBottomNavigationBar);
      expect(tester.getSize(bar).height, 84);
      final bottom = tester.getBottomLeft(bar).dy;
      for (final item in mainNavigationItems) {
        final gesture = find.ancestor(
          of: find.text(item.label),
          matching: find.byType(GestureDetector),
        );
        expect(tester.getSize(gesture).height, 50);
        expect(tester.getBottomLeft(gesture).dy, bottom - 34);
      }
    },
  );

  testWidgets(
    'settings long press retains account switching without selecting',
    (tester) async {
      int? pressedIndex;
      Offset? pressedPosition;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.bottomCenter,
            child: CompactBottomNavigationBar(
              items: mainNavigationItems,
              currentIndex: 0,
              onTap: (_) => taps++,
              onItemLongPress: (index, position) {
                pressedIndex = index;
                pressedPosition = position;
              },
            ),
          ),
        ),
      );
      await tester.longPress(find.text('Настройки'));
      await tester.pumpAndSettle();
      expect(pressedIndex, 3);
      expect(pressedPosition, isNotNull);
      expect(taps, 0);
    },
  );

  testWidgets('the compact bar hides with the keyboard and returns afterward', (
    tester,
  ) async {
    var keyboardHeight = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQueryData(
                viewInsets: EdgeInsets.only(bottom: keyboardHeight),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: CompactBottomNavigationBar(
                  items: mainNavigationItems,
                  currentIndex: 2,
                  onTap: (_) {},
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('Контакты'), findsOneWidget);
    update(() => keyboardHeight = 300);
    await tester.pump();
    expect(find.text('Контакты'), findsNothing);
    expect(tester.getSize(find.byType(CompactBottomNavigationBar)).height, 0);
    update(() => keyboardHeight = 0);
    await tester.pump();
    expect(find.text('Контакты'), findsOneWidget);
  });

  testWidgets('compact tabs support large text in a narrow dark layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 320,
              child: CompactBottomNavigationBar(
                items: mainNavigationItems,
                currentIndex: 3,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(CompactBottomNavigationBar)).height, 58);
    for (final item in mainNavigationItems) {
      expect(find.text(item.label), findsOneWidget);
    }
  });
}
