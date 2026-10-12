import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/core/utils/seed_scheme.dart';
import 'package:komet/core/utils/wallpaper_seed.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

double _chroma(Color color) => Hct.fromInt(color.toARGB32()).chroma;

double _tone(Color color) => Hct.fromInt(color.toARGB32()).tone;

double _contrast(Color a, Color b) => Contrast.ratioOfTones(_tone(a), _tone(b));

Color _accent(double brightness) =>
    HSVColor.fromAHSV(1, 220, 0.7, brightness).toColor();

bool _isGray(Color color) {
  final argb = color.toARGB32();
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return r == g && g == b;
}

Future<Color> _seedOf(String themeId) async {
  final seed = await computeWallpaperSeed(ChatWallpaper.theme(themeId));
  expect(seed, isNotNull, reason: themeId);
  return seed!;
}

void main() {
  test('серые обои дают серый акцент, а не синий', () async {
    final seed = await _seedOf('graphite');

    expect(isAchromaticSeed(seed), isTrue);
    for (final brightness in Brightness.values) {
      final scheme = schemeFromSeed(seed, brightness);
      expect(_isGray(scheme.primary), isTrue, reason: '$brightness');
      expect(_isGray(scheme.secondaryContainer), isTrue, reason: '$brightness');
    }
  });

  test('цветные встроенные обои остаются цветными', () async {
    for (final theme in kChatWallpaperThemes) {
      if (theme.id == 'graphite') continue;
      final seed = await _seedOf(theme.id);

      expect(isAchromaticSeed(seed), isFalse, reason: theme.id);
      final primary = schemeFromSeed(seed, Brightness.dark).primary;
      expect(_chroma(primary), greaterThan(20), reason: theme.id);
    }
  });

  test('схема от монохромного primary не перекрашивается в синий', () async {
    final seed = await _seedOf('graphite');
    final primary = schemeFromSeed(seed, Brightness.dark).primary;

    final derived = schemeFromSeed(primary, Brightness.dark);

    expect(_isGray(derived.primary), isTrue);
  });

  test('акцент полной яркости не отличается от обычной схемы', () {
    final seed = _accent(1);
    for (final brightness in Brightness.values) {
      expect(
        accentSchemeFromSeed(seed, brightness),
        schemeFromSeed(seed, brightness),
        reason: '$brightness',
      );
    }
  });

  test('ползунок яркости затемняет акцент плавно до самого низа', () {
    final steps = [1.0, 0.8, 0.6, 0.4, kAccentMinBrightness];
    for (final brightness in Brightness.values) {
      final tones = [
        for (final value in steps)
          _tone(
            accentSchemeFromSeed(_accent(value), brightness).primaryContainer,
          ),
      ];
      for (var i = 1; i < tones.length; i++) {
        expect(tones[i], lessThan(tones[i - 1]), reason: '$brightness $tones');
      }
    }
  });

  test('самый тёмный акцент остаётся цветным и читаемым', () {
    final seed = _accent(kAccentMinBrightness);
    for (final brightness in Brightness.values) {
      final scheme = accentSchemeFromSeed(seed, brightness);
      final bubbleText = brightness == Brightness.dark
          ? Colors.white
          : Colors.black;

      expect(_chroma(scheme.primaryContainer), greaterThan(20));
      expect(scheme.surfaceTint, scheme.primary);
      expect(_contrast(bubbleText, scheme.primaryContainer), greaterThan(4.5));
      expect(
        _contrast(scheme.onPrimaryContainer, scheme.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}
