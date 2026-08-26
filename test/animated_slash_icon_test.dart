import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/animated_slash_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

Widget _host({required bool slashed}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: AnimatedSlashIcon(
        icon: Symbols.mic,
        slashedIcon: Symbols.mic_off,
        slashed: slashed,
        size: 24,
      ),
    ),
  ),
);

void main() {
  testWidgets('в покое рисуется ровно одна исходная иконка', (tester) async {
    await tester.pumpWidget(_host(slashed: false));

    expect(find.byIcon(Symbols.mic), findsOneWidget);
    expect(find.byIcon(Symbols.mic_off), findsNothing);
    expect(find.byType(ClipPath), findsNothing);
  });

  testWidgets('в перечёркнутом покое рисуется ровно off-иконка', (
    tester,
  ) async {
    await tester.pumpWidget(_host(slashed: true));

    expect(find.byIcon(Symbols.mic_off), findsOneWidget);
    expect(find.byIcon(Symbols.mic), findsNothing);
    expect(find.byType(ClipPath), findsNothing);
  });

  testWidgets('переключение проходит через клип обеих иконок', (tester) async {
    await tester.pumpWidget(_host(slashed: false));
    await tester.pumpWidget(_host(slashed: true));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byIcon(Symbols.mic), findsOneWidget);
    expect(find.byIcon(Symbols.mic_off), findsOneWidget);
    expect(find.byType(ClipPath), findsNWidgets(2));

    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.mic_off), findsOneWidget);
    expect(find.byIcon(Symbols.mic), findsNothing);
  });

  testWidgets('обратное переключение возвращает исходную иконку', (
    tester,
  ) async {
    await tester.pumpWidget(_host(slashed: true));
    await tester.pumpWidget(_host(slashed: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Symbols.mic), findsOneWidget);
    expect(find.byIcon(Symbols.mic_off), findsNothing);
  });

  testWidgets('размер и цвет прокидываются в обе иконки', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedSlashIcon(
              icon: Symbols.visibility,
              slashedIcon: Symbols.visibility_off,
              slashed: false,
              size: 14,
              color: const Color(0xFF00FF00),
            ),
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.size, 14);
    expect(icon.color, const Color(0xFF00FF00));
  });
}
