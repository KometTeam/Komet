import 'package:flutter/material.dart';

class ReconnectionOverlay extends StatelessWidget {
  final bool isReconnecting;
  final String? message;

  const ReconnectionOverlay({
    super.key,
    required this.isReconnecting,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (!isReconnecting) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  message ?? 'Переподключение...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Пожалуйста, подождите',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReconnectionOverlayController {
  static final ReconnectionOverlayController _instance =
      ReconnectionOverlayController._internal();
  factory ReconnectionOverlayController() => _instance;
  ReconnectionOverlayController._internal();

  bool _isReconnecting = false;
  String? _message;
  VoidCallback? _onStateChanged;

  bool get isReconnecting => _isReconnecting;
  String? get message => _message;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void showReconnecting({String? message}) {
    _isReconnecting = true;
    _message = message;
    _onStateChanged?.call();
  }

  void hideReconnecting() {
    _isReconnecting = false;
    _message = null;
    _onStateChanged?.call();
  }
}
