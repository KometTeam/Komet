import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/core/utils/seed_scheme.dart';
import 'package:komet/core/utils/wallpaper_seed.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

double _chroma(Color color) => Hct.fromInt(color.toARGB32()).chroma;

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
      expect(
        _isGray(scheme.secondaryContainer),
        isTrue,
        reason: '$brightness',
      );
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
}
