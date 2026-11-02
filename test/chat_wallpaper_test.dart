import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/core/storage/per_chat_json_store.dart';
import 'package:komet/frontend/widgets/chat_wallpaper_sheet.dart';
import 'package:komet/frontend/widgets/theme_wallpaper.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _account = 900901;
const int _chat = 900902;
const int _otherChat = 900903;
const List<Color> _colors = [Color(0xFF223344), Color(0xFF556677)];

const String _none = 'Без обоев';
const String _inherit = 'Как у всех';
const String _current = 'Текущие';
const String _apply = 'Применить';

Future<WallpaperPick?> _pick(
  WidgetTester tester, {
  required ChatWallpaper? current,
  ChatWallpaper? inherited,
  bool perChat = false,
  required Future<void> Function() choose,
}) async {
  WallpaperPick? result;
  var closed = false;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showChatWallpaperSheet(
              context,
              current: current,
              inherited: inherited,
              perChat: perChat,
            );
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await choose();
  await tester.pumpAndSettle();
  expect(closed, isTrue);
  return result;
}

FilledButton _applyButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(of: find.text(_apply), matching: find.byType(FilledButton)),
);

void main() {
  group('store', () {
    final store = ChatWallpaperStore.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await store.clearAll();
      await store.load();
    });

    test('no wallpaper in a chat beats the wallpaper of all chats', () async {
      await store.setGradient(_account, kGlobalWallpaperChatId, _colors);
      await store.setNone(_account, _chat);

      expect(store.effective(_account, _chat), isNull);
      expect(store.effective(_account, _otherChat)?.gradientColors, _colors);
    });

    test('going back to default inherits the wallpaper of all chats', () async {
      await store.setGradient(_account, kGlobalWallpaperChatId, _colors);
      await store.setNone(_account, _chat);
      await store.clear(_account, _chat);

      expect(store.effective(_account, _chat)?.gradientColors, _colors);
    });

    test('no wallpaper is saved as such', () async {
      await store.setNone(_account, _chat);
      await PerChatJsonStore.flushAll();

      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('chat_wallpapers')!) as Map;
      expect(saved['$_account/$_chat'], {'none': true});
    });
  });

  test('retired presets open as their strict replacements', () {
    expect(chatWallpaperThemeById('ocean')?.id, 'ink');
    expect(chatWallpaperThemeById('rose')?.id, 'powder');
    expect(chatWallpaperThemeById('graphite')?.id, 'graphite');
    expect(chatWallpaperThemeById('unknown'), isNull);
  });

  group('gallery', () {
    testWidgets('a gradient is shown as current and can be turned off', (
      tester,
    ) async {
      final pick = await _pick(
        tester,
        current: const ChatWallpaper.gradient(_colors),
        perChat: true,
        choose: () async {
          expect(find.text(_current), findsOneWidget);
          expect(_applyButton(tester).onPressed, isNull);
          await tester.tap(find.text(_none));
          await tester.pumpAndSettle();
          expect(_applyButton(tester).onPressed, isNotNull);
          await tester.tap(find.text(_apply));
        },
      );

      expect(pick?.type, WallpaperPickType.none);
    });

    testWidgets('a chat without its own wallpaper starts from the default', (
      tester,
    ) async {
      final pick = await _pick(
        tester,
        current: null,
        inherited: const ChatWallpaper.gradient(_colors),
        perChat: true,
        choose: () async {
          expect(find.text(_inherit), findsOneWidget);
          expect(_applyButton(tester).onPressed, isNull);
          await tester.tap(find.text('Хвоя'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_apply));
        },
      );

      expect(pick?.type, WallpaperPickType.theme);
      expect(pick?.theme?.id, 'pine');
    });

    testWidgets('the explicit none of a chat can go back to the default', (
      tester,
    ) async {
      final pick = await _pick(
        tester,
        current: const ChatWallpaper.none(),
        perChat: true,
        choose: () async {
          await tester.tap(find.text(_inherit));
          await tester.pumpAndSettle();
          await tester.tap(find.text(_apply));
        },
      );

      expect(pick?.type, WallpaperPickType.inherit);
    });

    testWidgets('the wallpaper of all chats has no default to fall back to', (
      tester,
    ) async {
      await _pick(
        tester,
        current: null,
        choose: () async {
          expect(find.text(_inherit), findsNothing);
          expect(_applyButton(tester).onPressed, isNull);
          await tester.tap(find.byIcon(Symbols.arrow_back));
        },
      );
    });
  });

  group('pattern', () {
    testWidgets('a resize within one step reuses the rendered pattern', (
      tester,
    ) async {
      final pattern = kChatWallpaperThemes
          .firstWhere((theme) => theme.pattern != null)
          .pattern!;
      await tester.runAsync(() => WallpaperPatternLayer.load(pattern.asset));

      Future<Object?> renderedAt(Size size) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2),
            child: Center(
              child: SizedBox.fromSize(
                size: size,
                child: WallpaperPatternLayer(pattern: pattern),
              ),
            ),
          ),
        );
        return tester.widget<RawImage>(find.byType(RawImage)).image;
      }

      final first = await renderedAt(const Size(300, 600));
      expect(first, isNotNull);
      expect(await renderedAt(const Size(310, 620)), same(first));
      expect(await renderedAt(const Size(520, 620)), isNot(same(first)));
    });
  });
}
