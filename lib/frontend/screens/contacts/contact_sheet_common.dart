import 'dart:ui';

import 'package:flutter/material.dart';

Future<T?> showBlurredCard<T>(
  BuildContext context,
  Widget Function(BuildContext hostContext) builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (_, anim, _, _) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
        child: Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.94 + 0.06 * t,
            child: builder(context),
          ),
        ),
      );
    },
  );
}

Widget contactSheetDivider(ColorScheme cs) =>
    Divider(height: 1, thickness: 0.5, color: cs.outlineVariant);

String contactFlagEmoji(String code) {
  if (code.length != 2) return '🏳️';
  final upper = code.toUpperCase();
  final a = upper.codeUnitAt(0);
  final b = upper.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🏳️';
  return String.fromCharCode(0x1F1E6 + (a - 65)) +
      String.fromCharCode(0x1F1E6 + (b - 65));
}
