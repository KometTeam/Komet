import 'package:flutter/material.dart';

class AnimatedSlashIcon extends StatefulWidget {
  const AnimatedSlashIcon({
    super.key,
    required this.icon,
    required this.slashedIcon,
    required this.slashed,
    this.size,
    this.color,
    this.fill,
    this.weight,
    this.grade,
    this.opticalSize,
    this.semanticLabel,
    this.duration = const Duration(milliseconds: 260),
    this.curve = Curves.easeInOutCubic,
  });

  final IconData icon;
  final IconData slashedIcon;
  final bool slashed;
  final double? size;
  final Color? color;
  final double? fill;
  final double? weight;
  final double? grade;
  final double? opticalSize;
  final String? semanticLabel;
  final Duration duration;
  final Curve curve;

  @override
  State<AnimatedSlashIcon> createState() => _AnimatedSlashIconState();
}

class _AnimatedSlashIconState extends State<AnimatedSlashIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.slashed ? 1 : 0,
  );

  late final Animation<double> _wipe = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
    reverseCurve: widget.curve.flipped,
  );

  @override
  void didUpdateWidget(AnimatedSlashIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (widget.slashed == oldWidget.slashed) return;
    if (widget.slashed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Icon _glyph(IconData data) => Icon(
    data,
    size: widget.size,
    color: widget.color,
    fill: widget.fill,
    weight: widget.weight,
    grade: widget.grade,
    opticalSize: widget.opticalSize,
    semanticLabel: widget.semanticLabel,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wipe,
      builder: (context, _) {
        final progress = _wipe.value;
        if (progress <= 0.001) return _glyph(widget.icon);
        if (progress >= 0.999) return _glyph(widget.slashedIcon);
        return Stack(
          alignment: Alignment.center,
          children: [
            ClipPath(
              clipper: _SlashWipeClipper(progress, slashedSide: false),
              child: _glyph(widget.icon),
            ),
            ClipPath(
              clipper: _SlashWipeClipper(progress, slashedSide: true),
              child: _glyph(widget.slashedIcon),
            ),
          ],
        );
      },
    );
  }
}

class _SlashWipeClipper extends CustomClipper<Path> {
  const _SlashWipeClipper(this.progress, {required this.slashedSide});

  static const double _seamOverlap = 0.75;
  static const double _slashStart = 0.08;
  static const double _slashEnd = 0.92;

  final double progress;
  final bool slashedSide;

  @override
  Path getClip(Size size) {
    final travel = _slashStart + (_slashEnd - _slashStart) * progress;
    final cut =
        (size.width + size.height) * travel + (slashedSide ? _seamOverlap : 0);
    final slashed = _cornerPath(size, cut);
    if (slashedSide) return slashed;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      slashed,
    );
  }

  Path _cornerPath(Size size, double cut) {
    final width = size.width;
    final height = size.height;
    final path = Path()..moveTo(0, 0);
    path.lineTo(cut < width ? cut : width, 0);
    if (cut > width) path.lineTo(width, (cut - width).clamp(0, height));
    if (cut > height) path.lineTo((cut - height).clamp(0, width), height);
    path.lineTo(0, cut < height ? cut : height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_SlashWipeClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.slashedSide != slashedSide;
}
