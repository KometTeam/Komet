import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_bubble_behavior.dart';
import '../../../core/config/app_bubble_shape.dart';
import '../../../core/config/app_pill_gradient.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/utils/bubble_radius.dart';
import '../../../core/utils/haptics.dart';
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
  Timer? _debounce;

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
    _debounce?.cancel();
    _color.dispose();
    _isSystem.dispose();
    super.dispose();
  }

  void _onColorChanged(Color color) {
    _color.value = color;
    _isSystem.value = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) KometApp.stateOf(context)?.applyAccentColor(color);
    });
  }

  void _resetToSystem() {
    Haptics.selection();
    _debounce?.cancel();
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

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Внешний вид',
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
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Визуал',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Material You или объёмные Glossy-капсулы',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<VisualStyle>(
            valueListenable: AppVisualStyle.current,
            builder: (context, current, _) {
              return SegmentedButton<VisualStyle>(
                segments: const [
                  ButtonSegment(
                    value: VisualStyle.materialYou,
                    label: Text('Material You'),
                  ),
                  ButtonSegment(
                    value: VisualStyle.glossy,
                    label: Text('Glossy'),
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

class _GradientToggleCard extends StatelessWidget {
  const _GradientToggleCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                  'Градиент',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Объём и блики в Glossy-капсулах',
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

  static const _messages = <_PreviewMsg>[
    _PreviewMsg('Привет!', true, true, false),
    _PreviewMsg('Как тебе?', true, false, true),
    _PreviewMsg('Привет!', false, true, false),
    _PreviewMsg('хм...', false, false, false),
    _PreviewMsg('Вполне неплохо!', false, false, true),
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
              for (var i = 0; i < _messages.length; i++) ...[
                if (i > 0) SizedBox(height: _messages[i].isTop ? 8 : 2),
                _PreviewBubble(
                  text: _messages[i].text,
                  isMe: _messages[i].isMe,
                  radius: _radiusFor(_messages[i], style, behavior),
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
    return ValueListenableBuilder<bool>(
      valueListenable: isSystem,
      builder: (context, sys, _) {
        return ValueListenableBuilder<Color>(
          valueListenable: color,
          builder: (context, col, _) => _buildBody(cs, col, sys),
        );
      },
    );
  }

  Widget _buildBody(ColorScheme cs, Color col, bool sys) {
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
                          'Акцентный цвет',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sys
                              ? 'Системный'
                              : 'Основной цвет интерфейса и пузырей',
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
                        _HueStripPicker(color: col, onChanged: onColorChanged),
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
                                      ? 'Системный цвет активен'
                                      : 'Сбросить на системный',
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

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Форма сообщения',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Скругление углов пузырей',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<BubbleStyle>(
            valueListenable: AppBubbleShape.current,
            builder: (context, current, _) {
              return SegmentedButton<BubbleStyle>(
                segments: const [
                  ButtonSegment(
                    value: BubbleStyle.mobile,
                    label: Text('TG Mobile'),
                    icon: Icon(Symbols.smartphone),
                  ),
                  ButtonSegment(
                    value: BubbleStyle.desktop,
                    label: Text('TG Desktop'),
                    icon: Icon(Symbols.desktop_windows),
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

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Поведение сообщения',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Меняется ли форма пузыря по соседям в группе',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<BubbleBehavior>(
            valueListenable: AppBubbleBehavior.current,
            builder: (context, current, _) {
              return SegmentedButton<BubbleBehavior>(
                segments: const [
                  ButtonSegment(
                    value: BubbleBehavior.mutable,
                    label: Text('Изменяемая'),
                    icon: Icon(Symbols.auto_fix),
                  ),
                  ButtonSegment(
                    value: BubbleBehavior.immutable,
                    label: Text('Неизменяемая'),
                    icon: Icon(Symbols.lock),
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

class _HueStripPicker extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _HueStripPicker({required this.color, required this.onChanged});

  static const _gradient = LinearGradient(
    colors: [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final hue = HSVColor.fromColor(color).hue;
    const trackHeight = 26.0;
    const thumbDiameter = 30.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void emit(double dx) {
          final clamped = dx.clamp(0.0, width);
          final newHue = (clamped / width) * 360;
          onChanged(HSVColor.fromAHSV(1, newHue, 1, 1).toColor());
        }

        final thumbLeft = (hue / 360) * width - thumbDiameter / 2;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => emit(d.localPosition.dx),
          onPanUpdate: (d) => emit(d.localPosition.dx),
          child: SizedBox(
            height: thumbDiameter + 4,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: trackHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                      gradient: _gradient,
                    ),
                  ),
                ),
                Positioned(
                  left: thumbLeft.clamp(0, width - thumbDiameter),
                  top: (thumbDiameter + 4 - thumbDiameter) / 2,
                  child: Container(
                    width: thumbDiameter,
                    height: thumbDiameter,
                    decoration: BoxDecoration(
                      color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
