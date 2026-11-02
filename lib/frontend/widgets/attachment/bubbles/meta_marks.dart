import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/komet_settings.dart';
import '../../../../core/utils/format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../hint_bubble.dart';

class MetaHintMark extends StatelessWidget {
  final ValueListenable<bool> enabled;
  final IconData icon;
  final String hint;
  final Color color;

  const MetaHintMark({
    super.key,
    required this.enabled,
    required this.icon,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: enabled,
    builder: (context, enabled, _) => enabled
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showHintBubble(context, hint),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Icon(icon, size: 12, fill: 1, color: color),
            ),
          )
        : const SizedBox.shrink(),
  );
}

class LikelyForwardedMark extends StatelessWidget {
  final Color color;

  const LikelyForwardedMark({super.key, required this.color});

  @override
  Widget build(BuildContext context) => MetaHintMark(
    enabled: KometSettings.showForward,
    icon: Symbols.forward,
    hint: AppLocalizations.of(context)!.metaMarksLikelyForwarded,
    color: color,
  );
}

class TypingTimeMark extends StatelessWidget {
  final int typingMs;
  final Color color;

  const TypingTimeMark({
    super.key,
    required this.typingMs,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MetaHintMark(
      enabled: KometSettings.showTypingTime,
      icon: Symbols.timer,
      hint: l10n.metaMarksTypingTime(formatApproxDuration(l10n, typingMs)),
      color: color,
    );
  }
}

class ViewsMark extends StatelessWidget {
  final ValueListenable<int?> views;
  final Color color;
  final double fontSize;

  const ViewsMark({
    super.key,
    required this.views,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int?>(
    valueListenable: views,
    builder: (context, count, _) {
      if (count == null) return const SizedBox.shrink();
      return Semantics(
        label: '${AppLocalizations.of(context)!.channelPostViews}: $count',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.visibility, size: fontSize + 2, color: color),
              const SizedBox(width: 2),
              Text(
                formatCompactCount(count),
                style: TextStyle(color: color, fontSize: fontSize),
              ),
            ],
          ),
        ),
      );
    },
  );
}
