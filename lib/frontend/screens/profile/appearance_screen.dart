import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_bubble_behavior.dart';
import '../../../core/config/app_bubble_shape.dart';
import '../../../core/config/app_pill_gradient.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/config/app_chat_chrome.dart';
import '../../../core/utils/bubble_radius.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/glossy_pill.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  static const _fallback = Color(0xFFC1C4FF);

  final ValueNotifier<Color> _color = ValueNotifier(_fallback);
  final ValueNotifier<bool> _isSystem = ValueNotifier(false);
  bool _initialized = false;
  bool _accentExpanded = false;
  final _debounce = Debouncer(const Duration(milliseconds: 350));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final seed = KometApp.stateOf(context)?.accentSeed.value;
      _isSystem.value = seed == null;
      _color.value = seed ?? _fallback;
    }
  }

  @override
  void dispose() {
    _debounce.dispose();
    _color.dispose();
    _isSystem.dispose();
    super.dispose();
  }

  void _onColorChanged(Color color) {
    _color.value = color;
    _isSystem.value = false;
    _debounce.run(() {
      if (mounted) KometApp.stateOf(context)?.applyAccentColor(color);
    });
  }

  void _resetToSystem() {
    Haptics.selection();
    _debounce.cancel();
    _isSystem.value = true;
    _color.value = _fallback;
    KometApp.stateOf(context)?.applyAccentColor(null);
  }

  void _toggleAccentExpanded() {
    Haptics.tap();
    setState(() => _accentExpanded = !_accentExpanded);
  }

  void _onStyleChanged(BubbleStyle style) {
    Haptics.selection();
    AppBubbleShape.save(style);
  }

  void _onBehaviorChanged(BubbleBehavior behavior) {
    Haptics.selection();
    AppBubbleBehavior.save(behavior);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.appearanceTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _PreviewSection(color: _color, isSystem: _isSystem),
            const SizedBox(height: 16),
            _ColorPickerCard(
              color: _color,
              isSystem: _isSystem,
              expanded: _accentExpanded,
              onToggle: _toggleAccentExpanded,
              onColorChanged: _onColorChanged,
              onReset: _resetToSystem,
            ),
            const SizedBox(height: 12),
            _BubbleShapeCard(onChanged: _onStyleChanged),
            const SizedBox(height: 12),
            _BubbleBehaviorCard(onChanged: _onBehaviorChanged),
            const SizedBox(height: 12),
            const _VisualStyleCard(),
            const SizedBox(height: 12),
            const _ChatChromeCard(),
            const SizedBox(height: 12),
            const _GradientToggleCard(),
          ],
        ),
      ),
    );
  }
}

class _VisualStyleCard extends StatelessWidget {
  const _VisualStyleCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceVisualStyleTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appearanceVisualStyleSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<VisualStyle>(
            valueListenable: AppVisualStyle.current,
            builder: (context, current, _) {
              return SegmentedButton<VisualStyle>(
                segments: [
                  ButtonSegment(
                    value: VisualStyle.materialYou,
                    label: Text(l10n.appearanceVisualStyleMaterialYou),
                  ),
                  ButtonSegment(
                    value: VisualStyle.glossy,
                    label: Text(l10n.appearanceVisualStyleGlossy),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    Haptics.selection();
                    AppVisualStyle.save(set.first);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChatChromeCard extends StatelessWidget {
  const _ChatChromeCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceChatChromeTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appearanceChatChromeSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<ChatChromeStyle>(
            valueListenable: AppChatChrome.current,
            builder: (context, current, _) {
              return SegmentedButton<ChatChromeStyle>(
                segments: [
                  ButtonSegment(
                    value: ChatChromeStyle.color,
                    label: Text(l10n.appearanceChatChromeColor),
                  ),
                  ButtonSegment(
                    value: ChatChromeStyle.blur,
                    label: Text(l10n.appearanceChatChromeBlur),
                  ),
                  ButtonSegment(
                    value: ChatChromeStyle.none,
                    label: Text(l10n.appearanceChatChromeNone),
                  ),
                  ButtonSegment(
                    value: ChatChromeStyle.transparent,
                    label: Text(l10n.appearanceChatChromeTransparent),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    Haptics.selection();
                    AppChatChrome.save(set.first);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GradientToggleCard extends StatelessWidget {
  const _GradientToggleCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      depth: 6,
      child: Row(
        children: [
          Icon(Symbols.blur_on, color: cs.onSurface, size: 24, weight: 500),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appearanceGradientTitle,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.appearanceGradientSubtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AppPillGradient.current,
            builder: (context, value, _) => Switch(
              value: value,
              onChanged: (v) {
                Haptics.selection();
                AppPillGradient.save(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatefulWidget {
  final ValueNotifier<Color> color;
  final ValueNotifier<bool> isSystem;

  const _PreviewSection({required this.color, required this.isSystem});

  @override
  State<_PreviewSection> createState() => _PreviewSectionState();
}

class _PreviewSectionState extends State<_PreviewSection> {
  ColorScheme? _cachedScheme;
  Color? _cachedColor;
  Brightness? _cachedBrightness;

  ColorScheme _schemeFor(Color color, Brightness brightness) {
    if (_cachedScheme != null &&
        _cachedColor == color &&
        _cachedBrightness == brightness) {
      return _cachedScheme!;
    }
    _cachedColor = color;
    _cachedBrightness = brightness;
    _cachedScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: brightness,
    );
    return _cachedScheme!;
  }

  @override
  Widget build(BuildContext context) {
    final outerCs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return ValueListenableBuilder<bool>(
      valueListenable: widget.isSystem,
      builder: (context, isSystem, _) {
        if (isSystem) {
          return Theme(
            data: Theme.of(context).copyWith(colorScheme: outerCs),
            child: const _ChatPreview(),
          );
        }
        return ValueListenableBuilder<Color>(
          valueListenable: widget.color,
          builder: (context, color, _) {
            return Theme(
              data: Theme.of(
                context,
              ).copyWith(colorScheme: _schemeFor(color, brightness)),
              child: const _ChatPreview(),
            );
          },
        );
      },
    );
  }
}

class _ChatPreview extends StatelessWidget {
  const _ChatPreview();

  List<_PreviewMsg> _messagesFor(AppLocalizations l10n) => [
    _PreviewMsg(l10n.appearancePreviewHello, true, true, false),
    _PreviewMsg(l10n.appearancePreviewHowIsIt, true, false, true),
    _PreviewMsg(l10n.appearancePreviewHello, false, true, false),
    _PreviewMsg(l10n.appearancePreviewHmm, false, false, false),
    _PreviewMsg(l10n.appearancePreviewNotBad, false, false, true),
  ];

  BorderRadius _radiusFor(
    _PreviewMsg msg,
    BubbleStyle style,
    BubbleBehavior behavior,
  ) {
    return computeBubbleRadius(
      isMe: msg.isMe,
      isTop: msg.isTop,
      isBottom: msg.isBottom,
      style: style,
      behavior: behavior,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final messages = _messagesFor(l10n);

    return ListenableBuilder(
      listenable: Listenable.merge([
        AppBubbleShape.current,
        AppBubbleBehavior.current,
      ]),
      builder: (context, _) {
        final style = AppBubbleShape.current.value;
        final behavior = AppBubbleBehavior.current.value;
        return GlossyPill(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          depth: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < messages.length; i++) ...[
                if (i > 0) SizedBox(height: messages[i].isTop ? 8 : 2),
                _PreviewBubble(
                  text: messages[i].text,
                  isMe: messages[i].isMe,
                  radius: _radiusFor(messages[i], style, behavior),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PreviewMsg {
  final String text;
  final bool isMe;
  final bool isTop;
  final bool isBottom;
  const _PreviewMsg(this.text, this.isMe, this.isTop, this.isBottom);
}

class _PreviewBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final BorderRadius radius;

  const _PreviewBubble({
    required this.text,
    required this.isMe,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isMe ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Text(
          text,
          style: TextStyle(color: fg, fontSize: 15, height: 1.3),
        ),
      ),
    );
  }
}

class _ColorPickerCard extends StatelessWidget {
  final ValueNotifier<Color> color;
  final ValueNotifier<bool> isSystem;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onReset;

  const _ColorPickerCard({
    required this.color,
    required this.isSystem,
    required this.expanded,
    required this.onToggle,
    required this.onColorChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: isSystem,
      builder: (context, sys, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: color,
          builder: (context, col, _) => _buildBody(cs, l10n, col, sys),
        );
      },
    );
  }

  Widget _buildBody(ColorScheme cs, AppLocalizations l10n, Color col, bool sys) {
    final swatchColor = sys ? cs.primary : col;

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      depth: 6,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: swatchColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appearanceAccentColorTitle,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sys
                              ? l10n.appearanceAccentColorSystem
                              : l10n.appearanceAccentColorSubtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: expanded ? 0.5 : 0,
                    child: Icon(
                      Symbols.expand_more,
                      color: cs.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ColorWheelPicker(
                          color: col,
                          onChanged: onColorChanged,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: sys ? null : onReset,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Symbols.auto_awesome,
                                  size: 18,
                                  weight: 500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sys
                                      ? l10n.appearanceAccentColorSystemActive
                                      : l10n.appearanceAccentColorReset,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _BubbleShapeCard extends StatelessWidget {
  final ValueChanged<BubbleStyle> onChanged;

  const _BubbleShapeCard({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceBubbleShapeTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appearanceBubbleShapeSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<BubbleStyle>(
            valueListenable: AppBubbleShape.current,
            builder: (context, current, _) {
              return SegmentedButton<BubbleStyle>(
                segments: [
                  ButtonSegment(
                    value: BubbleStyle.mobile,
                    label: Text(l10n.appearanceBubbleShapeMobile),
                    icon: const Icon(Symbols.smartphone),
                  ),
                  ButtonSegment(
                    value: BubbleStyle.desktop,
                    label: Text(l10n.appearanceBubbleShapeDesktop),
                    icon: const Icon(Symbols.desktop_windows),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) onChanged(set.first);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BubbleBehaviorCard extends StatelessWidget {
  final ValueChanged<BubbleBehavior> onChanged;

  const _BubbleBehaviorCard({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.appearanceBubbleBehaviorTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appearanceBubbleBehaviorSubtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<BubbleBehavior>(
            valueListenable: AppBubbleBehavior.current,
            builder: (context, current, _) {
              return SegmentedButton<BubbleBehavior>(
                segments: [
                  ButtonSegment(
                    value: BubbleBehavior.mutable,
                    label: Text(l10n.appearanceBubbleBehaviorMutable),
                    icon: const Icon(Symbols.auto_fix),
                  ),
                  ButtonSegment(
                    value: BubbleBehavior.immutable,
                    label: Text(l10n.appearanceBubbleBehaviorImmutable),
                    icon: const Icon(Symbols.lock),
                  ),
                ],
                selected: {current},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) onChanged(set.first);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ColorWheelPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _ColorWheelPicker({required this.color, required this.onChanged});

  @override
  State<_ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<_ColorWheelPicker> {
  late HSVColor _hsv;
  late Color _lastEmitted;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color).withValue(1);
    _lastEmitted = widget.color;
  }

  @override
  void didUpdateWidget(covariant _ColorWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != _lastEmitted) {
      _hsv = HSVColor.fromColor(widget.color).withValue(1);
      _lastEmitted = widget.color;
    }
  }

  void _handleWheel(Offset local, double size) {
    final radius = size / 2;
    final dx = local.dx - radius;
    final dy = local.dy - radius;
    final sat = (math.sqrt(dx * dx + dy * dy) / radius).clamp(0.0, 1.0);
    var hue = math.atan2(dy, dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    final hsv = _hsv.withHue(hue).withSaturation(sat);
    setState(() => _hsv = hsv);
    final color = hsv.toColor();
    _lastEmitted = color;
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wheelSize = math.min(260.0, constraints.maxWidth);

        return Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _handleWheel(d.localPosition, wheelSize),
            onPanUpdate: (d) => _handleWheel(d.localPosition, wheelSize),
            child: SizedBox(
              width: wheelSize,
              height: wheelSize,
              child: CustomPaint(painter: _WheelPainter(hsv: _hsv)),
            ),
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  final HSVColor hsv;

  const _WheelPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final hueShader = SweepGradient(
      colors: [
        for (var i = 0; i <= 360; i += 30)
          HSVColor.fromAHSV(1, (i % 360).toDouble(), 1, 1).toColor(),
      ],
      stops: [for (var i = 0; i <= 360; i += 30) i / 360],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = hueShader);

    final satShader = RadialGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = satShader);

    final angle = hsv.hue * math.pi / 180;
    final thumb = Offset(
      center.dx + hsv.saturation * radius * math.cos(angle),
      center.dy + hsv.saturation * radius * math.sin(angle),
    );
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: thumb, radius: 13)),
      Colors.black,
      2,
      false,
    );
    canvas.drawCircle(thumb, 13, Paint()..color = Colors.white);
    canvas.drawCircle(thumb, 10, Paint()..color = hsv.toColor());
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => oldDelegate.hsv != hsv;
}
