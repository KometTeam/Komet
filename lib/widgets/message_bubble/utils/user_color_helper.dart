import 'package:flutter/material.dart';

bool _currentIsDark = false;

Color getUserColor(int userId, BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  if (isDark != _currentIsDark) {
    _currentIsDark = isDark;
  }

  final List<Color> materialYouColors = isDark
      ? [
          const Color(0xFFEF5350),
          const Color(0xFFEC407A),
          const Color(0xFFAB47BC),
          const Color(0xFF7E57C2),
          const Color(0xFF5C6BC0),
          const Color(0xFF42A5F5),
          const Color(0xFF29B6F6),
          const Color(0xFF26C6DA),
          const Color(0xFF26A69A),
          const Color(0xFF66BB6A),
          const Color(0xFF9CCC65),
          const Color(0xFFD4E157),
          const Color(0xFFFFEB3B),
          const Color(0xFFFFCA28),
          const Color(0xFFFFA726),
          const Color(0xFFFF7043),
          const Color(0xFF8D6E63),
          const Color(0xFF78909C),
          const Color(0xFFB39DDB),
          const Color(0xFF80CBC4),
          const Color(0xFFC5E1A5),
        ]
      : [
          const Color(0xFFF44336),
          const Color(0xFFE91E63),
          const Color(0xFF9C27B0),
          const Color(0xFF673AB7),
          const Color(0xFF3F51B5),
          const Color(0xFF2196F3),
          const Color(0xFF03A9F4),
          const Color(0xFF00BCD4),
          const Color(0xFF009688),
          const Color(0xFF4CAF50),
          const Color(0xFF8BC34A),
          const Color(0xFFCDDC39),
          const Color(0xFFFFEE58),
          const Color(0xFFFFC107),
          const Color(0xFFFF9800),
          const Color(0xFFFF5722),
          const Color(0xFF795548),
          const Color(0xFF607D8B),
          const Color(0xFF9575CD),
          const Color(0xFF4DB6AC),
          const Color(0xFFAED581),
        ];

  final colorIndex = userId % materialYouColors.length;
  final color = materialYouColors[colorIndex];

  return color;
}
