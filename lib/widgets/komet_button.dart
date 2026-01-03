import 'package:flutter/material.dart';
import 'package:gwid/app_sizes.dart';
import 'package:gwid/app_durations.dart';

/// Komet styled button with loading, pressed, and disabled states
/// Implements Material 3 design with micro-animations
class KometButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final IconData? icon;
  final double? width;

  const KometButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.icon,
    this.width,
  });

  @override
  State<KometButton> createState() => _KometButtonState();
}

class _KometButtonState extends State<KometButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.animation100,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    final backgroundColor = widget.isPrimary
        ? (isDisabled ? colors.primary.withOpacity(0.5) : colors.primary)
        : Colors.transparent;

    final foregroundColor = widget.isPrimary
        ? colors.onPrimary
        : (isDisabled ? colors.primary.withOpacity(0.5) : colors.primary);

    final borderColor = widget.isPrimary
        ? Colors.transparent
        : (isDisabled ? colors.outline.withOpacity(0.3) : colors.outline);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.animation150,
          curve: Curves.easeOut,
          width: widget.width,
          constraints: AppAccessibility.touchTargetConstraints,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppRadius.lgBorder,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: widget.isPrimary && !isDisabled
                ? [
                    BoxShadow(
                      color: colors.primary.withOpacity(_isPressed ? 0.1 : 0.2),
                      blurRadius: _isPressed ? 4 : 8,
                      offset: Offset(0, _isPressed ? 1 : 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: AppIconSize.sm,
                  height: AppIconSize.sm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: AppIconSize.md, color: foregroundColor),
                const SizedBox(width: AppSpacing.md),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text button variant with minimal styling
class KometTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isDestructive;

  const KometTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isDestructive
        ? colors.error
        : (onPressed == null ? colors.onSurface.withOpacity(0.38) : colors.primary);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(AppAccessibility.minTouchTarget, AppAccessibility.minTouchTarget),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIconSize.sm, color: color),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon button with proper touch target and visual feedback
class KometIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? backgroundColor;

  const KometIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 24.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = color ?? colors.onSurfaceVariant;
    final bgColor = backgroundColor;

    Widget button = Material(
      color: bgColor ?? Colors.transparent,
      borderRadius: AppRadius.circleBorder,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.circleBorder,
        child: Container(
          constraints: AppAccessibility.touchTargetConstraints,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: size,
            color: onPressed == null ? iconColor.withOpacity(0.38) : iconColor,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
