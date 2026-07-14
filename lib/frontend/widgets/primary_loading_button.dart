import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'small_spinner.dart';
import 'springy_tap.dart';

class PrimaryLoadingButton extends StatelessWidget {
  final ValueListenable<bool> loading;
  final VoidCallback? onPressed;
  final Widget child;
  final Color? background;
  final Color? foreground;

  const PrimaryLoadingButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.child,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = foreground ?? cs.onPrimary;
    return ValueListenableBuilder<bool>(
      valueListenable: loading,
      builder: (context, isLoading, _) => SpringyTap(
        enabled: !isLoading,
        child: FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: background ?? cs.primary,
            foregroundColor: fg,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? SmallSpinner(size: 20, color: fg)
              : child,
        ),
      ),
    );
  }
}
