import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/media/preview_image.dart';
import '../../../models/story.dart';

ImageProvider? storyThumbProvider(Story story) {
  final media = story.media;
  if (media == null) return null;
  final url = media.isVideo ? (media.thumbnailUrl ?? media.url) : media.url;
  if (url != null && url.isNotEmpty) {
    return CachedNetworkImageProvider(url, maxWidth: 160, maxHeight: 160);
  }
  return dataUriImage(story, media.previewData);
}

class StoryPeanut extends StatefulWidget {
  final List<Story> stories;
  final double diameter;
  final double strokeWidth;
  final double gap;
  final Color outlineColor;
  final Duration cycle;

  const StoryPeanut({
    super.key,
    required this.stories,
    this.diameter = 30,
    this.strokeWidth = 1.8,
    this.gap = 1.6,
    this.outlineColor = Colors.white,
    this.cycle = const Duration(seconds: 3),
  });

  static const int maxCircles = 3;

  @override
  State<StoryPeanut> createState() => _StoryPeanutState();
}

class _StoryPeanutState extends State<StoryPeanut> {
  Timer? _timer;
  int _cycleIndex = 0;

  bool get _cycling => widget.stories.length > StoryPeanut.maxCircles;

  int get _circleCount =>
      _cycling ? 1 : widget.stories.length.clamp(0, StoryPeanut.maxCircles);

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(StoryPeanut old) {
    super.didUpdateWidget(old);
    if (old.stories.length != widget.stories.length ||
        old.cycle != widget.cycle) {
      _cycleIndex = 0;
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (!_cycling) return;
    _timer = Timer.periodic(widget.cycle, (_) {
      if (!mounted) return;
      setState(() {
        _cycleIndex = (_cycleIndex + 1) % widget.stories.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = _circleCount;
    if (count == 0) return const SizedBox.shrink();

    final d = widget.diameter;
    final step = d * 0.68;
    final pad = widget.strokeWidth + widget.gap;
    final width = d + step * (count - 1);

    return SizedBox(
      width: width,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: step * i,
              top: 0,
              width: d,
              height: d,
              child: ClipPath(
                clipper: i == count - 1
                    ? null
                    : _NotchClipper(
                        center: Offset(step + d / 2, d / 2),
                        radius: d / 2 + widget.gap,
                      ),
                child: Padding(
                  padding: EdgeInsets.all(pad),
                  child: ClipOval(child: _thumb(i)),
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PeanutOutlinePainter(
                  count: count,
                  diameter: d,
                  step: step,
                  strokeWidth: widget.strokeWidth,
                  color: widget.outlineColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(int index) {
    final story = _cycling
        ? widget.stories[_cycleIndex % widget.stories.length]
        : widget.stories[index];
    final provider = storyThumbProvider(story);
    final fill = ColoredBox(color: Colors.white.withValues(alpha: 0.22));
    final image = provider == null
        ? fill
        : Image(image: provider, fit: BoxFit.cover, gaplessPlayback: true);
    if (!_cycling) return image;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: KeyedSubtree(key: ValueKey(story.id), child: image),
    );
  }
}

class _NotchClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  const _NotchClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addOval(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldReclip(_NotchClipper old) =>
      old.center != center || old.radius != radius;
}

class _PeanutOutlinePainter extends CustomPainter {
  final int count;
  final double diameter;
  final double step;
  final double strokeWidth;
  final Color color;

  const _PeanutOutlinePainter({
    required this.count,
    required this.diameter,
    required this.step,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = diameter / 2 - strokeWidth / 2;
    Path union = Path();
    for (var i = 0; i < count; i++) {
      final circle = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(diameter / 2 + step * i, diameter / 2),
            radius: radius,
          ),
        );
      union = i == 0 ? circle : Path.combine(PathOperation.union, union, circle);
    }
    canvas.drawPath(
      union,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PeanutOutlinePainter old) =>
      old.count != count ||
      old.diameter != diameter ||
      old.step != step ||
      old.strokeWidth != strokeWidth ||
      old.color != color;
}
