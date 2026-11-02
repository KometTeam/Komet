import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class SlowLoginHint extends StatefulWidget {
  const SlowLoginHint({
    super.key,
    required this.active,
    this.idle = const SizedBox.shrink(),
  });

  static const Duration delay = Duration(seconds: 2);

  final bool active;
  final Widget idle;

  @override
  State<SlowLoginHint> createState() => _SlowLoginHintState();
}

class _SlowLoginHintState extends State<SlowLoginHint> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SlowLoginHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sync() {
    _timer?.cancel();
    if (!widget.active) {
      _shown = false;
      return;
    }
    _timer = Timer(SlowLoginHint.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: _shown
          ? Text(
              AppLocalizations.of(context)!.loginSlowSmsHint,
              key: const ValueKey('slow'),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            )
          : KeyedSubtree(key: const ValueKey('idle'), child: widget.idle),
    );
  }
}
