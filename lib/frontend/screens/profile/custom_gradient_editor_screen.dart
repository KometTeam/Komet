import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';
import '../../widgets/color_wheel_picker.dart';
import '../../widgets/mesh_gradient_background.dart';

class CustomGradientResult {
  final List<Color> colors;
  final bool animated;
  final double rotation;

  const CustomGradientResult({
    required this.colors,
    required this.animated,
    this.rotation = 0,
  });
}

class CustomGradientEditorScreen extends StatefulWidget {
  final List<Color>? initialColors;
  final bool initialAnimated;
  final double initialRotation;

  const CustomGradientEditorScreen({
    super.key,
    this.initialColors,
    this.initialAnimated = false,
    this.initialRotation = 0,
  });

  @override
  State<CustomGradientEditorScreen> createState() =>
      _CustomGradientEditorScreenState();
}

class _CustomGradientEditorScreenState
    extends State<CustomGradientEditorScreen> {
  static const int _maxColors = 6;

  late List<Color> _colors;
  late bool _animated;
  late double _rotation;
  int _editingIndex = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialColors;
    _colors = initial != null && initial.isNotEmpty
        ? List.of(initial)
        : [const Color(0xFF000000)];
    _animated = widget.initialAnimated;
    _rotation = widget.initialRotation;
    _editingIndex = 0;
  }

  void _addColor() {
    if (_colors.length >= _maxColors) return;
    setState(() {
      _colors.add(const Color(0xFF000000));
      _editingIndex = _colors.length - 1;
    });
  }

  void _removeColor(int index) {
    if (_colors.length <= 1) return;
    setState(() {
      _colors.removeAt(index);
      if (_editingIndex >= _colors.length) _editingIndex = _colors.length - 1;
    });
  }

  void _save() {
    Navigator.pop(
      context,
      CustomGradientResult(
        colors: List.of(_colors),
        animated: _animated,
        rotation: _rotation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Своя тема',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _preview(cs)),
            _panel(cs),
          ],
        ),
      ),
    );
  }

  Widget _preview(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppShape.cardRadius,
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: MeshGradientBackground(
          colors: _colors,
          animate: _animated,
          rotation: _rotation,
        ),
      ),
    );
  }

  Widget _panel(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            _swatchRow(cs),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ColorWheelPicker(
                key: ValueKey(_editingIndex),
                color: _colors[_editingIndex],
                onChanged: (color) =>
                    setState(() => _colors[_editingIndex] = color),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Анимация',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Плавный перелив цветов',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _animated,
                    onChanged: _colors.length > 1
                        ? (v) => setState(() => _animated = v)
                        : null,
                  ),
                ],
              ),
            ),
            if (!_animated && _colors.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Icon(Symbols.rotate_right, color: cs.onSurfaceVariant, size: 20),
                    Expanded(
                      child: Slider(
                        value: _rotation % 8,
                        min: 0,
                        max: 8,
                        onChanged: (v) => setState(() => _rotation = v),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _SaveButton(onTap: _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatchRow(ColorScheme cs) {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (var i = 0; i < _colors.length; i++)
            _Swatch(
              color: _colors[i],
              selected: i == _editingIndex,
              onTap: () => setState(() => _editingIndex = i),
              onRemove: _colors.length > 1 ? () => _removeColor(i) : null,
            ),
          if (_colors.length < _maxColors) _AddSwatch(onTap: _addColor),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onRemove,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? cs.primary : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Symbols.close, size: 14, color: cs.onSurface),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddSwatch extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSwatch({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant, width: 1.5),
        ),
        child: Icon(Symbols.add, color: cs.onSurface, size: 22),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            'Сохранить',
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
        ),
      ),
    );
  }
}
