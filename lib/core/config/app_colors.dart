import 'package:flutter/material.dart';

// #***! доп цвета поверх ColorScheme
extension AppColorTokens on ColorScheme {
  Color get mutedText => onSurfaceVariant.withValues(alpha: 0.6);
}

// #***! размер аватарки миниатюры, один на всё приложение
const int kAvatarThumbSize = 144;

// #***! цвета статусов фиксированные, иначе доставлено станет неузнаваемым
const Color kSuccessGreen = Color(0xFF2EC36B);
const Color kDangerRed = Color(0xFFE5484D);
const Color kReadReceiptBlue = Color(0xFF4FC3F7);

// #***! тёмная схема для просмотрщика, строится от акцента
class MediaAccent {
  static Color? _seed;
  static ColorScheme? _scheme;

  // #***! схему кэшируем, fromSeed дорогая а зовётся на каждый билд
  static ColorScheme schemeOf(BuildContext context) {
    final seed = Theme.of(context).colorScheme.primary;
    if (_seed != seed || _scheme == null) {
      _seed = seed;
      _scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
    }
    return _scheme!;
  }

  static Color of(BuildContext context) => schemeOf(context).primary;
}
