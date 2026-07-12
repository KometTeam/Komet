import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/haptics.dart';
import 'adaptive_shell.dart';

Future<ImageProvider?> precacheLoginAvatar(
  BuildContext context,
  String? url,
) async {
  if (url == null || url.isEmpty) return null;
  final provider = CachedNetworkImageProvider(url);
  try {
    await precacheImage(provider, context);
    return provider;
  } catch (_) {
    return null;
  }
}

class LoginSuccessScreen extends StatefulWidget {
  final ImageProvider? avatar;
  final bool preview;

  const LoginSuccessScreen({super.key, this.avatar, this.preview = false});

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 1900);

  static const List<String> _greetings = [
    'С большой силой приходит большая ответственность',
    'All in your hands',
    'Иногда забавные вещи могут быть уголовно наказуемы',
  ];

  late final String _greeting;
  late final AnimationController _controller;
  late final Animation<double> _circleScale;
  late final Animation<double> _ringSweep;
  late final Animation<double> _checkProgress;
  late final Animation<double> _particles;
  late final Animation<double> _haloOpacity;
  late final Animation<double> _haloScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleOffset;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _subtitleOffset;
  late final Animation<double> _fadeOut;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _greeting = _greetings[math.Random().nextInt(_greetings.length)];
    _controller = AnimationController(vsync: this, duration: _duration);

    _circleScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.22, curve: Curves.easeOutBack),
    );
    _ringSweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.45, curve: Curves.easeOutCubic),
    );
    _checkProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.48, curve: Curves.easeOutCubic),
    );
    _haloOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.65, curve: Curves.easeOut),
    );
    _haloScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.85, curve: Curves.easeOutCubic),
    );
    _particles = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.32, 0.78, curve: Curves.easeOutCubic),
    );
    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.62, curve: Curves.easeOut),
    );
    _titleOffset = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.7, curve: Curves.easeOutCubic),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.72, curve: Curves.easeOut),
    );
    _subtitleOffset = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 0.78, curve: Curves.easeOutCubic),
    );
    _fadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.88, 1.0, curve: Curves.easeInCubic),
    );

    _controller.addStatusListener(_onStatus);
    _controller.forward();
    Haptics.success();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_navigated && mounted) {
      _navigated = true;
      if (widget.preview) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => const AdaptiveShell(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: 1.0 - _fadeOut.value,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.9,
                        colors: [
                          cs.primaryContainer.withValues(
                            alpha: 0.35 * _haloOpacity.value,
                          ),
                          cs.surface.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildHalo(cs),
                            _buildParticles(cs),
                            _buildRing(cs),
                            _buildCircle(cs),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildTitle(cs),
                      const SizedBox(height: 8),
                      _buildSubtitle(cs),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHalo(ColorScheme cs) {
    final scale = 0.8 + _haloScale.value * 0.6;
    final opacity = (1.0 - _haloScale.value) * 0.6 * _haloOpacity.value;
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: opacity * 0.25),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: opacity * 0.4),
                blurRadius: 60,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticles(ColorScheme cs) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(220, 220),
        painter: _ParticlesPainter(
          progress: _particles.value,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildRing(ColorScheme cs) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(140, 140),
        painter: _RingPainter(progress: _ringSweep.value, color: cs.primary),
      ),
    );
  }

  Widget _buildCircle(ColorScheme cs) {
    final scale = _circleScale.value.clamp(0.0, 1.0);
    final avatar = widget.avatar;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primary,
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: avatar != null
            ? ClipOval(
                child: Image(
                  image: avatar,
                  fit: BoxFit.cover,
                  width: 120,
                  height: 120,
                ),
              )
            : CustomPaint(
                painter: _CheckPainter(
                  progress: _checkProgress.value,
                  color: cs.onPrimary,
                ),
              ),
      ),
    );
  }

  Widget _buildTitle(ColorScheme cs) {
    return Opacity(
      opacity: _titleOpacity.value,
      child: Transform.translate(
        offset: Offset(0, 18 * (1 - _titleOffset.value)),
        child: Text(
          'Готово!',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(ColorScheme cs) {
    return Opacity(
      opacity: _subtitleOpacity.value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _subtitleOffset.value)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _greeting,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final w = size.width;
    final h = size.height;
    final p1 = Offset(w * 0.30, h * 0.52);
    final p2 = Offset(w * 0.45, h * 0.67);
    final p3 = Offset(w * 0.72, h * 0.38);

    final firstLen = (p2 - p1).distance;
    final secondLen = (p3 - p2).distance;
    final total = firstLen + secondLen;
    final drawn = total * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= firstLen) {
      final t = drawn / firstLen;
      final mid = Offset.lerp(p1, p2, t)!;
      path.lineTo(mid.dx, mid.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = ((drawn - firstLen) / secondLen).clamp(0.0, 1.0);
      final end = Offset.lerp(p2, p3, t)!;
      path.lineTo(end.dx, end.dy);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final rect = Offset.zero & size;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(4),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _ParticlesPainter extends CustomPainter {
  final double progress;
  final Color color;

  static const int _count = 10;
  static const double _startRadius = 60;
  static const double _endRadius = 104;

  _ParticlesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi + (math.pi / 2);
      final radius = _startRadius + (_endRadius - _startRadius) * progress;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final fade = 1.0 - progress;
      final dotSize = 4.5 * fade + 1.0;
      paint.color = color.withValues(alpha: fade * 0.9);
      canvas.drawCircle(pos, dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
