import 'dart:async';

import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart';

import '../../backend/api.dart';
import '../../main.dart' show api;
import 'small_spinner.dart';

final ValueNotifier<bool> debugForceOffline = ValueNotifier<bool>(false);

String? connectionStatusLabel(SessionState state) {
  if (debugForceOffline.value) return 'Ожидание сети...';
  return switch (state) {
    SessionState.online => null,
    SessionState.connecting || SessionState.connected => 'Соединение...',
    SessionState.disconnected => 'Ожидание сети...',
  };
}

class ConnectionStatusBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, String? label) builder;

  const ConnectionStatusBuilder({super.key, required this.builder});

  @override
  State<ConnectionStatusBuilder> createState() =>
      _ConnectionStatusBuilderState();
}

class _ConnectionStatusBuilderState extends State<ConnectionStatusBuilder> {
  late SessionState _state = api.state;
  StreamSubscription<SessionState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = api.stateStream.listen((s) {
      if (mounted && s != _state) setState(() => _state = s);
    });
    debugForceOffline.addListener(_onOverrideChanged);
  }

  void _onOverrideChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    debugForceOffline.removeListener(_onOverrideChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, connectionStatusLabel(_state));
}

class ConnectionStatusLine extends StatelessWidget {
  final TextAlign? textAlign;
  final EdgeInsetsGeometry padding;

  const ConnectionStatusLine({
    super.key,
    this.textAlign,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConnectionStatusBuilder(
      builder: (context, label) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: label == null
            ? const SizedBox(width: double.infinity, key: ValueKey('online'))
            : Padding(
                key: const ValueKey('offline'),
                padding: padding,
                child: Text(
                  label,
                  textAlign: textAlign,
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
      ),
    );
  }
}

class ConnectionTitleText extends StatelessWidget {
  final String title;
  final TextStyle? style;
  final TextAlign? textAlign;

  const ConnectionTitleText(
    this.title, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) => ConnectionStatusBuilder(
    builder: (context, label) => Text(
      label ?? title,
      style: style,
      textAlign: textAlign,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class ConnectionTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final Color? backgroundColor;

  const ConnectionTitleBar({
    super.key,
    required this.titleText,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => ConnectionStatusBuilder(
    builder: (context, label) => AppBarM3E(
      titleText: label ?? titleText,
      backgroundColor: backgroundColor,
    ),
  );
}

class ConnectionSpinner extends StatelessWidget {
  const ConnectionSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConnectionStatusBuilder(
      builder: (context, label) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: label == null
            ? const SizedBox.shrink(key: ValueKey('online'))
            : Container(
                key: const ValueKey('offline'),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: SmallSpinner(size: 20, color: cs.primary),
                ),
              ),
      ),
    );
  }
}
