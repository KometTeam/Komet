import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sheet_helpers.dart';
import '../../core/config/app_shape.dart';

class InfoActionSheetItem {
  final IconData icon;
  final String title;
  final String? body;
  final Color? titleColor;
  final Color? iconColor;

  const InfoActionSheetItem({
    required this.icon,
    required this.title,
    this.body,
    this.titleColor,
    this.iconColor,
  });
}

Future<bool> showInfoActionSheet(
  BuildContext context, {
  String? headerEmoji,
  IconData? headerIcon,
  bool headerGlow = false,
  required String title,
  String? subtitle,
  List<InfoActionSheetItem> items = const [],
  String confirmLabel = 'ОК',
  Duration confirmDelay = Duration.zero,
  String? seenKey,
}) async {
  assert(
    headerEmoji == null || headerIcon == null,
    'Use either headerEmoji or headerIcon, not both.',
  );

  if (seenKey != null) {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(seenKey) ?? false) return true;
  }

  if (!context.mounted) return false;

  final cs = Theme.of(context).colorScheme;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (ctx) => _InfoActionSheet(
      headerEmoji: headerEmoji,
      headerIcon: headerIcon,
      headerGlow: headerGlow,
      title: title,
      subtitle: subtitle,
      items: items,
      confirmLabel: confirmLabel,
      confirmDelay: confirmDelay,
    ),
  );

  final ok = confirmed == true;
  if (ok && seenKey != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }
  return ok;
}

class _InfoActionSheet extends StatefulWidget {
  final String? headerEmoji;
  final IconData? headerIcon;
  final bool headerGlow;
  final String title;
  final String? subtitle;
  final List<InfoActionSheetItem> items;
  final String confirmLabel;
  final Duration confirmDelay;

  const _InfoActionSheet({
    this.headerEmoji,
    this.headerIcon,
    this.headerGlow = false,
    required this.title,
    this.subtitle,
    this.items = const [],
    required this.confirmLabel,
    required this.confirmDelay,
  });

  @override
  State<_InfoActionSheet> createState() => _InfoActionSheetState();
}

class _InfoActionSheetState extends State<_InfoActionSheet> {
  Timer? _ticker;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _remaining = widget.confirmDelay.inSeconds;
    if (_remaining > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining--;
          if (_remaining == 0) {
            _ticker?.cancel();
            _ticker = null;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = _remaining == 0;
    final buttonText = enabled
        ? widget.confirmLabel
        : '${widget.confirmLabel}($_remaining)';
    final hasHeader = widget.headerEmoji != null || widget.headerIcon != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasHeader) ...[
                      _buildHeader(cs),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    if (widget.items.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      for (int i = 0; i < widget.items.length; i++) ...[
                        _buildItem(cs, widget.items[i]),
                        if (i < widget.items.length - 1)
                          const SizedBox(height: 18),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: enabled ? () => Navigator.pop(context, true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                disabledBackgroundColor: cs.primary.withValues(alpha: 0.45),
                disabledForegroundColor: cs.onPrimary.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: AppShape.buttonBorder,
              ),
              child: Text(
                buttonText,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    if (widget.headerEmoji != null) {
      final emoji = Text(
        widget.headerEmoji!,
        style: const TextStyle(fontSize: 72, height: 1.0),
      );
      return Center(
        child: widget.headerGlow ? _GlowHalo(child: emoji) : emoji,
      );
    }
    if (!widget.headerGlow) {
      return Center(
        child: Icon(
          widget.headerIcon,
          size: 72,
          color: cs.primary,
          weight: 400,
        ),
      );
    }
    return Center(
      child: _GlowHalo(
        child: Icon(
          widget.headerIcon,
          size: 104,
          fill: 1,
          weight: 300,
          color: Color.lerp(cs.surface, cs.primary, 0.14),
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme cs, InfoActionSheetItem item) {
    final titleColor = item.titleColor ?? cs.onSurface;
    final iconColor = item.iconColor ?? cs.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(item.icon, size: 26, color: iconColor, weight: 400),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: item.body == null
                    ? TextStyle(
                        color: item.titleColor ?? cs.onSurfaceVariant,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      )
                    : TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
              ),
              if (item.body != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.body!,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GlowHalo extends StatelessWidget {
  final Widget child;

  const _GlowHalo({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 208,
      height: 184,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _blob(cs.primary, const Offset(-36, -12)),
                _blob(cs.tertiary, const Offset(34, -24)),
                _blob(cs.secondary, const Offset(6, 30)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(Color color, Offset offset) => Transform.translate(
    offset: offset,
    child: Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.4),
      ),
    ),
  );
}
