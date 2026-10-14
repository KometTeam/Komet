import 'package:flutter/material.dart';

class BadgedIcon extends StatelessWidget {
  static const double _badgeScale = 0.52;
  static const double _overhangScale = 0.12;
  static const double _liveAreaInset = 2 / 24;
  static const double _gap = 1.5;

  final IconData icon;
  final IconData badge;
  final double size;
  final double? weight;
  final Color? color;

  const BadgedIcon({
    super.key,
    required this.icon,
    required this.badge,
    this.size = 24,
    this.weight,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * _badgeScale;
    final origin = size - badgeSize + size * _overhangScale;
    final badgeRect = Rect.fromLTWH(origin, origin, badgeSize, badgeSize);
    final hole = RRect.fromRectAndRadius(
      badgeRect.deflate(badgeSize * _liveAreaInset).inflate(_gap),
      Radius.circular(badgeSize * 0.25),
    );
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipPath(
            clipper: _HoleClipper(hole),
            child: Icon(icon, size: size, weight: weight, color: color),
          ),
          Positioned.fromRect(
            rect: badgeRect,
            child: Icon(
              badge,
              size: badgeSize,
              weight: weight,
              fill: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final RRect hole;

  const _HoleClipper(this.hole);

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addRRect(hole),
  );

  @override
  bool shouldReclip(_HoleClipper oldClipper) => oldClipper.hole != hole;
}
