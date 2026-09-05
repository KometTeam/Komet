import 'package:flutter/material.dart';

import 'custom_font_service.dart';

// #***! шрифт заголовков, отдельный от основного
const String kDisplayFontFamily = 'Outfit';

// #***! расширение темы, так шрифт заголовков доезжает через Theme.of
@immutable
class AppDisplayFont extends ThemeExtension<AppDisplayFont> {
  final String? family;

  const AppDisplayFont(this.family);

  @override
  AppDisplayFont copyWith({String? family}) =>
      AppDisplayFont(family ?? this.family);

  @override
  AppDisplayFont lerp(ThemeExtension<AppDisplayFont>? other, double t) =>
      t < 0.5 ? this : (other as AppDisplayFont? ?? this);
}

String? displayFontOf(BuildContext context) =>
    Theme.of(context).extension<AppDisplayFont>()?.family ?? kDisplayFontFamily;

// #***! шрифт в списке выбора, metricScale выравнивает размер разных гарнитур
class AppFont {
  final String id;
  final String label;
  final String? fontFamily;

  final double metricScale;

  const AppFont({
    required this.id,
    required this.label,
    this.fontFamily,
    this.metricScale = 1.0,
  });

  // #***! системный это без семейства, кастомные с префиксом g:
  bool get isSystem => fontFamily == null;
  bool get isCustom => id.startsWith(AppFonts.customPrefix);
}

// #***! реестр шрифтов
class AppFonts {
  static const String prefKey = 'app_font';
  static const String scalePrefKey = 'app_font_scale';
  static const String customPrefix = 'g:';

  static const double minScale = 0.60;
  static const double maxScale = 1.35;
  static const double defaultScale = 1.0;

  // #***! встроенные в assets, остальное качается с гугла
  static const List<AppFont> builtIn = [
    AppFont(id: 'system', label: 'Системный'),
    AppFont(
      id: 'inter',
      label: 'Inter',
      fontFamily: 'Inter',
      metricScale: 0.967,
    ),
    AppFont(
      id: 'unbounded',
      label: 'Unbounded',
      fontFamily: 'Unbounded',
      metricScale: 0.933,
    ),
  ];

  static AppFont get fallback => builtIn.first;

  static String customId(String family) => '$customPrefix$family';

  // #***! по id собираем шрифт, кастомный на лету встроенный из списка
  static AppFont resolve(String id) {
    if (id.startsWith(customPrefix)) {
      final family = id.substring(customPrefix.length);
      return AppFont(
        id: id,
        label: family,
        fontFamily: family,
        metricScale: CustomFontService.metricScaleFor(family),
      );
    }
    return builtIn.firstWhere((f) => f.id == id, orElse: () => fallback);
  }

  // #***! итоговый масштаб, ползунок плюс метрика гарнитуры
  static double effectiveScale(String id, double userScale) =>
      userScale * resolve(id).metricScale;

  static String? displayFamily(String id) {
    final font = resolve(id);
    return font.isSystem ? kDisplayFontFamily : font.fontFamily;
  }

  static TextTheme textTheme(String id, TextTheme base) {
    final family = resolve(id).fontFamily;
    if (family == null) return base;
    return base.apply(fontFamily: family);
  }

  static TextStyle sample(String id, {required double fontSize}) {
    final family = resolve(id).fontFamily;
    return TextStyle(fontFamily: family, fontSize: fontSize);
  }

  static double clampScale(double scale) =>
      scale.clamp(minScale, maxScale).toDouble();

  // #***! принимаем и имя и ссылку на гугл фонтс
  static String? familyFromInput(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.contains('fonts.google.com')) {
      final idx = uri.pathSegments.indexOf('specimen');
      if (idx != -1 && idx + 1 < uri.pathSegments.length) {
        value = uri.pathSegments[idx + 1];
      }
    }

    try {
      value = Uri.decodeComponent(value);
    } catch (_) {}
    value = value.replaceAll('+', ' ').trim();
    return value.isEmpty ? null : value;
  }
}
