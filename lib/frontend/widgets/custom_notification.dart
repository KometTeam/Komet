import 'package:flutter/material.dart';

const Duration _defaultNotificationDuration = Duration(milliseconds: 2600);

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
  final entry = OverlayEntry(
    builder: (context) => CustomNotification(message: message, duration: total),
  );
  overlay.insert(entry);
  Future.delayed(total, () {
    if (entry.mounted) entry.remove();
  });
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
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                widget.message,
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
    );
  }
}
