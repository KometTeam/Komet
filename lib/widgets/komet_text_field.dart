import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwid/app_sizes.dart';
import 'package:gwid/app_durations.dart';

/// Komet styled text field with consistent design
class KometTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final EdgeInsetsGeometry? contentPadding;

  const KometTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.contentPadding,
  });

  @override
  State<KometTextField> createState() => _KometTextFieldState();
}

class _KometTextFieldState extends State<KometTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;
  bool _obscureText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _obscureText = widget.obscureText;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasError = widget.errorText != null;

    final borderColor = hasError
        ? colors.error
        : (_hasFocus ? colors.primary : colors.outline.withOpacity(0.3));

    final effectivePadding = widget.contentPadding ??
        EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.xl,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w500,
              color: hasError ? colors.error : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AnimatedContainer(
          duration: AppDurations.animation150,
          decoration: BoxDecoration(
            color: widget.enabled
                ? colors.surfaceContainerHighest.withOpacity(0.5)
                : colors.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: AppRadius.lgBorder,
            border: Border.all(
              color: borderColor,
              width: _hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            obscureText: _obscureText,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            textCapitalization: widget.textCapitalization,
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: colors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                color: colors.onSurfaceVariant.withOpacity(0.7),
              ),
              contentPadding: effectivePadding,
              border: InputBorder.none,
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.md),
                      child: Icon(
                        widget.prefixIcon,
                        size: AppIconSize.md,
                        color: _hasFocus
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffix: widget.obscureText
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                      child: Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: AppIconSize.md,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : widget.suffix,
              counterText: '',
            ),
          ),
        ),
        if (widget.errorText != null || widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText ?? widget.helperText!,
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: hasError ? colors.error : colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Search field variant
class KometSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;

  const KometSearchField({
    super.key,
    this.controller,
    this.hintText = 'Поиск...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<KometSearchField> createState() => _KometSearchFieldState();
}

class _KometSearchFieldState extends State<KometSearchField> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _controller.text.isNotEmpty;
    if (newHasText != _hasText) {
      setState(() {
        _hasText = newHasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        minHeight: AppAccessibility.minTouchTarget,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: AppRadius.xlBorder,
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Icon(
              Icons.search,
              size: AppIconSize.md,
              color: colors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                fontSize: AppFontSize.lg,
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant.withOpacity(0.7),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: AppSpacing.xl,
                ),
              ),
            ),
          ),
          if (_hasText && widget.onClear != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: AppIconSize.md,
                color: colors.onSurfaceVariant,
              ),
              onPressed: widget.onClear,
              constraints: AppAccessibility.touchTargetConstraints,
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
