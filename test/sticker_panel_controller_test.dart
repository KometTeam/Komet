import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/sticker_panel_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

StickerPanelController _controller(WidgetTester tester) {
  return StickerPanelController(vsync: tester, onSendTyping: () {})
    ..maxHeight = 700;
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  await tester.pump();
  await tester.pump(duration);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('панель встаёт на место открытой клавиатуры сразу целиком', (
    tester,
  ) async {
    final stickers = _controller(tester);

    stickers.showInPlaceOfKeyboard(320);

    expect(stickers.showPanel.value, isTrue);
    expect(stickers.visibleHeight, 320);
    stickers.dispose();
  });

  testWidgets('клавиатура закрыла панель целиком — панель убирается сразу', (
    tester,
  ) async {
    final stickers = _controller(tester);
    stickers.showInPlaceOfKeyboard(320);

    stickers.yieldToKeyboard();
    stickers.keyboardChanged(120, landscape: false);
    expect(stickers.visibleHeight, 320);

    stickers.keyboardChanged(320, landscape: false);
    expect(stickers.showPanel.value, isFalse);
    expect(stickers.visibleHeight, 0);
    await _settle(tester, const Duration(milliseconds: 200));
    stickers.dispose();
  });

  testWidgets('клавиатура ниже панели — панель съезжает к ней плавно', (
    tester,
  ) async {
    final stickers = _controller(tester);
    stickers.showInPlaceOfKeyboard(400);

    stickers.yieldToKeyboard();
    stickers.keyboardChanged(300, landscape: false);
    expect(stickers.visibleHeight, 400);

    await tester.pump(const Duration(milliseconds: 150));
    expect(stickers.showPanel.value, isFalse);
    await _settle(tester, const Duration(milliseconds: 100));
    expect(stickers.visibleHeight, inExclusiveRange(0, 400));
    await tester.pump(const Duration(milliseconds: 200));
    expect(stickers.visibleHeight, 0);
    stickers.dispose();
  });

  testWidgets('поиск раскрывает панель до верха и сворачивает обратно', (
    tester,
  ) async {
    final stickers = _controller(tester);
    stickers.showInPlaceOfKeyboard(300);

    stickers.searching.value = true;
    await _settle(tester, const Duration(milliseconds: 300));
    expect(stickers.currentHeight, 700);

    stickers.hide();
    expect(stickers.searching.value, isFalse);
    await _settle(tester, const Duration(milliseconds: 300));
    expect(stickers.currentHeight, 300);
    stickers.dispose();
  });

  testWidgets('без клавиатуры панель открывается на её прошлую высоту', (
    tester,
  ) async {
    final first = _controller(tester);
    first.keyboardChanged(280, landscape: false);
    await tester.pump(const Duration(milliseconds: 150));

    final second = _controller(tester);
    second.show(landscape: false);
    await _settle(tester, const Duration(milliseconds: 240));

    expect(second.visibleHeight, 280);
    first.dispose();
    second.dispose();
  });
}
