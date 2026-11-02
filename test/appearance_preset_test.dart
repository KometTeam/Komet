import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_bottom_navigation_style.dart';
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/core/config/app_nav_pill_style.dart';
import 'package:komet/core/config/app_visual_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppVisualStyle.current.value = VisualStyle.glossy;
    AppElementsBlur.current.value = false;
  });

  tearDown(() {
    AppVisualStyle.current.value = VisualStyle.glossy;
    AppElementsBlur.current.value = false;
  });

  test('Glossy is the default style', () async {
    expect(await AppVisualStyle.load(), VisualStyle.glossy);
    expect(await AppElementsBlur.load(), false);
  });

  test(
    'a stored Liquid Glass style opens as Glossy while glass is off',
    () async {
      SharedPreferences.setMockInitialValues({
        AppVisualStyle.prefKey: VisualStyle.liquidGlass.name,
      });
      expect(await AppVisualStyle.load(), VisualStyle.glossy);
    },
  );

  test('Glossy sets every dependent element', () {
    expect(AppChatChrome.current.value, ChatChromeStyle.none);
    expect(AppComposerStyle.current.value, ComposerStyle.glossy);
    expect(AppComposerBackground.current.value, ComposerBackground.standard);
    expect(AppNavPillStyle.current.value, NavPillStyle.glossy);
    expect(
      AppBottomNavigationStyle.current.value,
      BottomNavigationStyle.floating,
    );
  });

  test('Material You sets every dependent element', () {
    AppVisualStyle.current.value = VisualStyle.materialYou;
    expect(AppChatChrome.current.value, ChatChromeStyle.color);
    expect(AppComposerStyle.current.value, ComposerStyle.materialYou);
    expect(AppComposerBackground.current.value, ComposerBackground.standard);
    expect(AppNavPillStyle.current.value, NavPillStyle.auto);
    expect(
      AppBottomNavigationStyle.current.value,
      BottomNavigationStyle.compact,
    );
  });

  test('element blur frosts the switcher only in Glossy', () async {
    await AppElementsBlur.save(true);
    expect(AppNavPillStyle.current.value, NavPillStyle.frostBlur);
    expect(AppComposerBackground.current.value, ComposerBackground.standard);

    AppVisualStyle.current.value = VisualStyle.materialYou;
    expect(AppNavPillStyle.current.value, NavPillStyle.auto);

    AppVisualStyle.current.value = VisualStyle.glossy;
    await AppElementsBlur.save(false);
    expect(AppNavPillStyle.current.value, NavPillStyle.glossy);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppElementsBlur.prefKey), false);
  });
}
