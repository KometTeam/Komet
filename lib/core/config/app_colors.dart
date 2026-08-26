import 'package:flutter/material.dart';

extension AppColorTokens on ColorScheme {
  Color get mutedText => onSurfaceVariant.withValues(alpha: 0.6);
}

const int kAvatarThumbSize = 144;

const Color kSuccessGreen = Color(0xFF2EC36B);
const Color kDangerRed = Color(0xFFE5484D);
const Color kReadReceiptBlue = Color(0xFF4FC3F7);

class MediaAccent {
  static Color? _seed;
  static ColorScheme? _scheme;

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
