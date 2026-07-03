import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/frontend/widgets/chat_wallpaper_view.dart';

class ChatWallpaperPreviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final WallpaperImageSettings initial;

  const ChatWallpaperPreviewScreen({
    super.key,
    required this.imageBytes,
    this.initial = const WallpaperImageSettings(dim: 0.2),
  });

  @override
  State<ChatWallpaperPreviewScreen> createState() =>
      _ChatWallpaperPreviewScreenState();
}

class _ChatWallpaperPreviewScreenState
    extends State<ChatWallpaperPreviewScreen> {
  late double _dim = widget.initial.dim;
  late bool _blur = widget.initial.blur;
  late bool _motion = widget.initial.motion;
  late double _offsetX = widget.initial.offsetX;

  late final MemoryImage _image = MemoryImage(widget.imageBytes);

  void _pan(double dx, double width) {
    if (width <= 0) return;
    setState(() {
      _offsetX = (_offsetX - dx / width * 2).clamp(-1.0, 1.0);
    });
  }

  void _apply() {
    Navigator.pop(
      context,
      WallpaperImageSettings(
        dim: _dim,
        blur: _blur,
        motion: _motion,
        offsetX: _offsetX,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => _pan(d.delta.dx, width),
            child: WallpaperImageLayer(
              image: _image,
              dim: _dim,
              blur: _blur,
              motion: _motion,
              offsetX: _offsetX,
            ),
          ),
          const IgnorePointer(child: _EdgeScrim()),
          SafeArea(
            child: Column(
              children: [
                _appBar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _DimmingSlider(
                    value: _dim,
                    onChanged: (v) => setState(() => _dim = v),
                  ),
                ),
                const Expanded(child: IgnorePointer(child: _SamplePreview())),
                _controls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Symbols.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Обои',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: 'Размытие',
                  value: _blur,
                  onTap: () => setState(() => _blur = !_blur),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToggleChip(
                  label: 'Движение',
                  value: _motion,
                  onTap: () => setState(() => _motion = !_motion),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ApplyButton(onTap: _apply),
        ],
      ),
    );
  }
}

class _Frosted extends StatelessWidget {
  final double radius;
  final Widget child;

  const _Frosted({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _EdgeScrim extends StatelessWidget {
  const _EdgeScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x59000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0x66000000),
          ],
          stops: [0.0, 0.16, 0.74, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _DimmingSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _DimmingSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(double dx) => onChanged((dx / width).clamp(0.0, 1.0));
        final fraction = value.clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
          child: _Frosted(
            radius: 14,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  _DimLabel(value: fraction, color: Colors.white),
                  ClipRect(
                    clipper: _RevealClipper(fraction),
                    child: _DimLabel(value: fraction, color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DimLabel extends StatelessWidget {
  final double value;
  final Color color;

  const _DimLabel({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: color,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: 'Outfit',
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text('Затемнение', style: style),
          const Spacer(),
          Text('${(value * 100).round()}%', style: style),
        ],
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  final double fraction;

  const _RevealClipper(this.fraction);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Frosted(
        radius: 24,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.white : Colors.transparent,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: value
                    ? const Icon(Symbols.check, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ApplyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Frosted(
        radius: 26,
        child: const SizedBox(
          height: 52,
          child: Center(
            child: Text(
              'Применить',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SamplePreview extends StatelessWidget {
  const _SamplePreview();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bubble(
              text: 'Как насчёт новых обоев для этого чата?',
              color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
              textColor: cs.onSurface,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 8),
            _bubble(
              text: 'Отличная идея.',
              color: cs.primary,
              textColor: cs.onPrimary,
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble({
    required String text,
    required Color color,
    required Color textColor,
    required Alignment alignment,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }
}
