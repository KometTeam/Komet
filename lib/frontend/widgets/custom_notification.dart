import 'package:flutter/material.dart';

import 'toast_placement.dart';

const Duration _defaultNotificationDuration = Duration(milliseconds: 2600);
const Duration _actionNotificationDuration = Duration(milliseconds: 4000);
const double _bottomGap = 72;

OverlayEntry? _activeNotification;

typedef NotificationAction = ({String label, VoidCallback onTap});

void showCustomNotification(
  BuildContext context,
  String message, {
  Duration? duration,
  NotificationAction? action,
}) {
  showCustomNotificationOnOverlay(
    Overlay.of(context),
    message,
    duration: duration,
    action: action,
  );
}

void showCustomNotificationOnOverlay(
  OverlayState overlay,
  String message, {
  Duration? duration,
  NotificationAction? action,
}) {
  final total =
      duration ??
      (action == null
          ? _defaultNotificationDuration
          : _actionNotificationDuration);
  _removeNotification(_activeNotification);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => CustomNotification(
      message: message,
      duration: total,
      action: action == null
          ? null
          : (
              label: action.label,
              onTap: () {
                _removeNotification(entry);
                action.onTap();
              },
            ),
    ),
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
  final NotificationAction? action;
  const CustomNotification({
    required this.message,
    this.duration = _defaultNotificationDuration,
    this.action,
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
    final action = widget.action;
    final text = Text(
      widget.message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
    return ToastBottomPositioned(
      left: 12,
      right: 12,
      minBottom: _bottomGap,
      bandHeight: 48,
      minWidth: 160,
      child: IgnorePointer(
        ignoring: action == null,
        child: Material(
          type: MaterialType.transparency,
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
                child: action == null
                    ? text
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: text),
                          const SizedBox(width: 14),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: action.onTap,
                            child: Text(
                              action.label,
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
