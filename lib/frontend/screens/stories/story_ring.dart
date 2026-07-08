import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/haptics.dart';
import '../../../models/story.dart';
import '../../widgets/komet_avatar.dart';
import 'story_owner_info.dart';

/// Кольцо-превью истории владельца в шапке списка чатов.
class StoryRing extends StatefulWidget {
  final StoryPreview preview;
  final StoryOwnerInfo? ownerOverride;
  final String? selfLabel;
  final void Function(Offset? center) onTap;
  final double avatarRadius;

  const StoryRing({
    super.key,
    required this.preview,
    required this.onTap,
    this.ownerOverride,
    this.selfLabel,
    this.avatarRadius = 26,
  });

  @override
  State<StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<StoryRing> {
  bool _pressed = false;

  void _handleTap() {
    Haptics.tap();
    Offset? center;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      center = box.localToGlobal(box.size.center(Offset.zero));
    }
    widget.onTap(center);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUnread = widget.preview.hasUnread;
    final diameter = widget.avatarRadius * 2;

    return StoryOwnerBuilder(
      owner: widget.preview.owner,
      overrideInfo: widget.ownerOverride,
      builder: (context, info) {
        final name = widget.selfLabel ??
            (info?.name.isNotEmpty == true ? info!.name : '…');
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 68,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: diameter + 12,
                      height: diameter + 12,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size.square(diameter + 12),
                            painter: _SegmentedRingPainter(
                              total: widget.preview.totalCount,
                              read: widget.preview.readCount,
                              unreadColors: [cs.primary, cs.tertiary, cs.primary],
                              readColor: cs.outlineVariant,
                              strokeWidth: 2.8,
                            ),
                          ),
                          Container(
                            width: diameter + 4,
                            height: diameter + 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.surface,
                            ),
                          ),
                          KometAvatar(
                            name: name == '…' ? '?' : name,
                            size: diameter,
                            imageUrl: info?.avatarUrl,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 11,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Прерывистое кольцо: одна дуга на каждую историю; прочитанные приглушены.
class _SegmentedRingPainter extends CustomPainter {
  final int total;
  final int read;
  final List<Color> unreadColors;
  final Color readColor;
  final double strokeWidth;

  _SegmentedRingPainter({
    required this.total,
    required this.read,
    required this.unreadColors,
    required this.readColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = total < 1 ? 1 : total;
    final center = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final segment = (2 * math.pi) / n;
    final gap = n == 1 ? 0.0 : math.min(0.16, segment * 0.30);
    final sweep = segment - gap;

    final unreadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = n == 1 ? StrokeCap.butt : StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: [...unreadColors, unreadColors.first],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    final readPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = n == 1 ? StrokeCap.butt : StrokeCap.round
      ..color = readColor;

    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + gap / 2 + i * segment;
      canvas.drawArc(rect, start, sweep, false, i < read ? readPaint : unreadPaint);
    }
  }

  @override
  bool shouldRepaint(_SegmentedRingPainter old) =>
      old.total != total ||
      old.read != read ||
      old.readColor != readColor ||
      old.strokeWidth != strokeWidth ||
      !listEquals(old.unreadColors, unreadColors);
}

/// Ведущая плитка «Ваша история»: показывает своё кольцо (если истории есть)
/// и всегда — бейдж «+» для публикации. Тап по кольцу открывает свои истории,
/// тап по «+» — композер. Если своих историй нет — вся плитка ведёт в композер.
class StorySelfTile extends StatefulWidget {
  final StoryPreview? preview;
  final StoryOwnerInfo? selfInfo;
  final void Function(Offset? center) onOpen;
  final VoidCallback onAdd;
  final double avatarRadius;

  const StorySelfTile({
    super.key,
    required this.onOpen,
    required this.onAdd,
    this.preview,
    this.selfInfo,
    this.avatarRadius = 26,
  });

  @override
  State<StorySelfTile> createState() => _StorySelfTileState();
}

class _StorySelfTileState extends State<StorySelfTile> {
  bool _pressed = false;

  bool get _hasStories => widget.preview != null;

  void _handleTap() {
    Haptics.tap();
    if (!_hasStories) {
      widget.onAdd();
      return;
    }
    Offset? center;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      center = box.localToGlobal(box.size.center(Offset.zero));
    }
    widget.onOpen(center);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diameter = widget.avatarRadius * 2;
    final preview = widget.preview;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: 68,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: diameter + 12,
                  height: diameter + 12,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (preview != null)
                        CustomPaint(
                          size: Size.square(diameter + 12),
                          painter: _SegmentedRingPainter(
                            total: preview.totalCount,
                            read: preview.readCount,
                            unreadColors: [cs.primary, cs.tertiary, cs.primary],
                            readColor: cs.outlineVariant,
                            strokeWidth: 2.8,
                          ),
                        )
                      else
                        Container(
                          width: diameter + 6,
                          height: diameter + 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.outlineVariant,
                              width: 2,
                            ),
                          ),
                        ),
                      Container(
                        width: diameter + 4,
                        height: diameter + 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.surface,
                        ),
                      ),
                      KometAvatar(
                        name: widget.selfInfo?.name.isNotEmpty == true
                            ? widget.selfInfo!.name
                            : '+',
                        size: diameter,
                        imageUrl: widget.selfInfo?.avatarUrl,
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Haptics.tap();
                            widget.onAdd();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.surface,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cs.primary,
                              ),
                              child: Icon(
                                Icons.add,
                                size: 14,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ваша история',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Свёрнутая мини-стопка колец, показывается в заголовке при закрытом доке.
class FoldedStoryStack extends StatelessWidget {
  final List<StoryPreview> previews;
  final double opacity;

  const FoldedStoryStack({
    super.key,
    required this.previews,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = previews.take(3).toList();
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Stack(
      children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(
            left: i * 14.0,
            child: StoryOwnerBuilder(
              owner: shown[i].owner,
              builder: (context, info) => Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                  border: Border.all(
                    color: shown[i].hasUnread ? cs.primary : cs.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: KometAvatar(
                  name: info?.name.isNotEmpty == true ? info!.name : '?',
                  size: 28,
                  imageUrl: info?.avatarUrl,
                ),
              ),
            ),
          ),
      ],
      ),
    );
  }
}
