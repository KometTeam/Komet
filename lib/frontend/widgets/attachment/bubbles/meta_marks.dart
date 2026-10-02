import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/komet_settings.dart';
import '../../../../core/utils/format.dart';
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
    hint: 'Сообщения скорее всего пересланы',
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
  Widget build(BuildContext context) => MetaHintMark(
    enabled: KometSettings.showTypingTime,
    icon: Symbols.timer,
    hint: 'Сообщение печаталось примерно ~${formatApproxDuration(typingMs)}',
    color: color,
  );
}
