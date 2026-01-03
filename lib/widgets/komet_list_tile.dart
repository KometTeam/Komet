import 'package:flutter/material.dart';
import 'package:gwid/app_sizes.dart';
import 'package:gwid/app_durations.dart';

/// Komet styled list tile with consistent design and accessibility
class KometListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isDense;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final double? borderRadius;

  const KometListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isDense = false,
    this.contentPadding,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<KometListTile> createState() => _KometListTileState();
}

class _KometListTileState extends State<KometListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final bgColor = widget.isSelected
        ? colors.primaryContainer.withOpacity(0.5)
        : (widget.backgroundColor ?? Colors.transparent);

    final hoverColor = colors.onSurface.withOpacity(0.04);

    final effectivePadding = widget.contentPadding ??
        EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: widget.isDense ? AppSpacing.md : AppSpacing.xl,
        );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: AppDurations.animation150,
        constraints: BoxConstraints(
          minHeight: widget.isDense
              ? AppAccessibility.minTouchTarget
              : AppAccessibility.listTileMinHeight,
        ),
        decoration: BoxDecoration(
          color: _isHovered ? hoverColor : bgColor,
          borderRadius: widget.borderRadius != null
              ? BorderRadius.circular(widget.borderRadius!)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: widget.borderRadius != null
                ? BorderRadius.circular(widget.borderRadius!)
                : null,
            child: Padding(
              padding: effectivePadding,
              child: Row(
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: AppSpacing.xxl),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: AppFontSize.lg,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: widget.isSelected
                                ? colors.primary
                                : colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: AppFontSize.md,
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation list tile with chevron indicator
class KometNavigationTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const KometNavigationTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Icon container size slightly smaller than min touch target (40dp)
    const iconContainerSize = AppAccessibility.minTouchTarget - 4;

    return KometListTile(
      leading: icon != null
          ? Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(0.5),
                borderRadius: AppRadius.mdBorder,
              ),
              child: Icon(
                icon,
                size: AppIconSize.md,
                color: colors.primary,
              ),
            )
          : null,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: colors.onSurfaceVariant,
        size: AppIconSize.lg,
      ),
    );
  }
}

/// Switch list tile variant
class KometSwitchTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const KometSwitchTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Icon container size slightly smaller than min touch target (40dp)
    const iconContainerSize = AppAccessibility.minTouchTarget - 4;

    return KometListTile(
      leading: icon != null
          ? Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(0.5),
                borderRadius: AppRadius.mdBorder,
              ),
              child: Icon(
                icon,
                size: AppIconSize.md,
                color: colors.primary,
              ),
            )
          : null,
      title: title,
      subtitle: subtitle,
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
