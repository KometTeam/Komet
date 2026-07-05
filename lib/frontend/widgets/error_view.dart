import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Повторить',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.cloud_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
