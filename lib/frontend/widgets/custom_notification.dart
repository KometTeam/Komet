import 'package:flutter/material.dart';

import 'toast_placement.dart';

const Duration _defaultNotificationDuration = Duration(milliseconds: 2600);
const double _bottomGap = 72;

OverlayEntry? _activeNotification;

void showCustomNotification(
  BuildContext context,
  String message, {
  Duration? duration,
}) {
  showCustomNotificationOnOverlay(
    Overlay.of(context),
    message,
    duration: duration,
  );
}

void showCustomNotificationOnOverlay(
  OverlayState overlay,
  String message, {
  Duration? duration,
}) {
  final total = duration ?? _defaultNotificationDuration;
  _removeNotification(_activeNotification);
  final entry = OverlayEntry(
    builder: (context) => CustomNotification(message: message, duration: total),
  );
  _activeNotification = entry;
  overlay.insert(entry);
  Future.delayed(total, () => _removeNotification(entry));
}

void _removeNotification(OverlayEntry? entry) {
  if (entry == null) return;
  if (identical(_activeNotification, entry)) _activeNotification = null;
  if (!entry.mounted) return;
  entry
    ..remove()
    ..dispose();
}

class CustomNotification extends StatefulWidget {
  final String message;
  final Duration duration;
  const CustomNotification({
    required this.message,
    this.duration = _defaultNotificationDuration,
    super.key,
  });

  @override
  State<CustomNotification> createState() => _CustomNotificationState();
}

class _CustomNotificationState extends State<CustomNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    final fadeOutDelay = widget.duration - const Duration(milliseconds: 300);
    Future.delayed(
      fadeOutDelay > Duration.zero ? fadeOutDelay : Duration.zero,
      () {
        if (mounted) _controller.reverse();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ToastBottomPositioned(
      left: 12,
      right: 12,
      minBottom: _bottomGap,
      bandHeight: 48,
      minWidth: 160,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: FadeTransition(
              opacity: _opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
