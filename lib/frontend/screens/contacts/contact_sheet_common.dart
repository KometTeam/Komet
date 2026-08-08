import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/config/app_frost.dart';

Future<T?> showBlurredCard<T>(
  BuildContext context,
  Widget Function(BuildContext hostContext) builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: AppFrost.scrim(),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => builder(context),
    transitionBuilder: (_, anim, _, child) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppFrost.overlaySigma * t,
          sigmaY: AppFrost.overlaySigma * t,
        ),
        child: Opacity(
          opacity: anim.value,
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
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
