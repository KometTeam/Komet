import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/composer_height.dart';
import 'package:komet/frontend/screens/chats/chat/sticker_panel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bar = 96.0;
const _keyboard = 320.0;

Future<void> _withComposer(
  WidgetTester tester,
  Future<void> Function(StickerPanelController stickers, ComposerHeight height)
  body,
) async {
  final stickers = StickerPanelController(vsync: tester, onSendTyping: () {})
    ..maxHeight = 700;
  final height = ComposerHeight(stickers)..measured(_bar);
  await body(stickers, height);
  height.dispose();
  stickers.dispose();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'takes the panel in at once when it replaces the keyboard',
    (tester) async => _withComposer(tester, (stickers, height) async {
      var notified = 0;
      height.addListener(() => notified++);

      stickers.showInPlaceOfKeyboard(_keyboard);

      expect(height.value, _bar + _keyboard);
      expect(notified, 1);

      height.measured(_bar + _keyboard);
      expect(height.value, _bar + _keyboard);
      expect(notified, 1);
    }),
  );

  testWidgets(
    'drops the panel at once when the keyboard covers it',
    (tester) async => _withComposer(tester, (stickers, height) async {
      stickers.showInPlaceOfKeyboard(_keyboard);
      height.measured(_bar + _keyboard);

      stickers.yieldToKeyboard();
      stickers.keyboardChanged(_keyboard, landscape: false);

      expect(height.value, _bar);
      await tester.pump(const Duration(milliseconds: 300));
    }),
  );

  testWidgets(
    'follows the slide-in frame by frame without a measurement',
    (tester) async => _withComposer(tester, (stickers, height) async {
      stickers.show(landscape: false);

      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(height.value, _bar + stickers.visibleHeight);
      }
      expect(stickers.visibleHeight, greaterThan(0));
    }),
  );

  testWidgets(
    'keeps a change of the bar itself measured under the panel',
    (tester) async => _withComposer(tester, (stickers, height) async {
      stickers.showInPlaceOfKeyboard(_keyboard);
      height.measured(_bar + 40 + _keyboard);

      expect(height.value, _bar + 40 + _keyboard);

      stickers.hide();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(height.value, _bar + 40);
    }),
  );

  testWidgets(
    'hands the safe area over to the panel without a jump',
    (tester) async => _withComposer(tester, (stickers, height) async {
      const navigationBar = 48.0;
      stickers.safeBottom = navigationBar;
      height.measured(_bar + navigationBar);
      final resting = height.value;
      final values = <double>[];

      void expectSeamless() {
        final visible = stickers.visibleHeight;
        expect(stickers.barBottomPadding + visible, stickers.slotHeight);
        expect(
          height.value,
          _bar + (visible > navigationBar ? visible : navigationBar),
        );
        expect(height.value, greaterThanOrEqualTo(resting));
        values.add(height.value);
      }

      stickers.show(landscape: false);
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectSeamless();
      }
      expect(stickers.barBottomPadding, 0);

      stickers.hide();
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectSeamless();
      }
      expect(height.value, resting);
      expect(stickers.barBottomPadding, navigationBar);
      expect(values.first, resting);
    }),
  );
}
