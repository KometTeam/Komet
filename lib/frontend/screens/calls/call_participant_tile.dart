import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_session.dart';
import '../../../core/config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/hint_bubble.dart';
import '../../widgets/komet_avatar.dart';
import 'call_participant_info.dart';
import 'call_stage.dart';
import 'waving_hand_icon.dart';

typedef CallTileMedia = Widget? Function(Widget avatar);

class CallParticipantTile extends StatefulWidget {
  static const double _radius = 18;

  final String name;
  final String? avatarUrl;
  final int? userId;
  final bool muted;
  final bool speaking;
  final bool handRaised;
  final int? handPosition;
  final bool screenSharing;
  final double? networkRating;
  final bool videoStalled;
  final CallTileMedia? media;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;
  final String? expandTooltip;
  final List<CallInfoRow> Function()? info;

  const CallParticipantTile({
    super.key,
    required this.name,
    this.avatarUrl,
    this.userId,
    this.muted = false,
    this.speaking = false,
    this.handRaised = false,
    this.handPosition,
    this.screenSharing = false,
    this.networkRating,
    this.videoStalled = false,
    this.media,
    this.onTap,
    this.onExpand,
    this.expandTooltip,
    this.info,
  });

  @override
  State<CallParticipantTile> createState() => _CallParticipantTileState();
}

class _CallParticipantTileState extends State<CallParticipantTile>
    with SingleTickerProviderStateMixin {
  static const Duration _revealDuration = Duration(milliseconds: 600);

  AnimationController? _reveal;
  bool _infoOpen = false;

  AnimationController get _revealController =>
      _reveal ??= AnimationController(vsync: this, duration: _revealDuration)
        ..addStatusListener(_onRevealStatus);

  bool get _infoVisible {
    final reveal = _reveal;
    return widget.info != null &&
        reveal != null &&
        (_infoOpen || !reveal.isDismissed);
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  void _toggleInfo() {
    setState(() => _infoOpen = !_infoOpen);
    if (_infoOpen) {
      _revealController.forward();
    } else {
      _revealController.reverse();
    }
  }

  @override
  void didUpdateWidget(CallParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.info == null && _infoOpen) {
      _infoOpen = false;
      _reveal?.value = 0;
    }
  }

  @override
  void dispose() {
    _reveal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final side = size.shortestSide;
        final compact = side < 140;
        final inset = compact ? 6.0 : 10.0;
        final buttonSide = CallTileButton.sideFor(compact: compact);
        final avatar = Center(
          child: KometAvatar(
            name: widget.name,
            imageUrl: widget.avatarUrl,
            userId: widget.userId,
            size: (side * 0.42).clamp(36.0, 176.0),
          ),
        );
        final media = widget.media?.call(avatar);
        final infoVisible = _infoVisible;
        return Material(
          color: cs.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CallParticipantTile._radius),
          ),
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                media ?? avatar,
                _StallVeil(stalled: widget.videoStalled && media != null),
                Positioned(
                  left: compact ? 8 : 14,
                  right: compact ? 8 : 14,
                  bottom: compact ? 6 : 12,
                  child: _NameLabel(
                    name: widget.name,
                    muted: widget.muted,
                    networkRating: widget.networkRating,
                    overVideo: media != null,
                    compact: compact,
                  ),
                ),
                Positioned(
                  top: inset,
                  left: inset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BadgeSwitcher(
                        child: widget.handRaised
                            ? Padding(
                                key: const ValueKey('hand'),
                                padding: const EdgeInsets.only(right: 6),
                                child: _HandBadge(
                                  position: widget.handPosition,
                                  compact: compact,
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('no-hand')),
                      ),
                      _BadgeSwitcher(
                        child: widget.screenSharing
                            ? _IconBadge(
                                key: const ValueKey('screen'),
                                icon: Symbols.screen_share,
                                background: cs.primaryContainer,
                                foreground: cs.onPrimaryContainer,
                                compact: compact,
                              )
                            : const SizedBox.shrink(key: ValueKey('no-screen')),
                      ),
                    ],
                  ),
                ),
                if (infoVisible)
                  _InfoReveal(
                    animation: _reveal!,
                    center: Offset(
                      size.width - inset - buttonSide / 2,
                      inset + buttonSide / 2,
                    ),
                    color: cs.primaryContainer,
                    child: _InfoPanel(
                      name: widget.name,
                      rows: widget.info!(),
                      compact: compact,
                      topGap: inset + buttonSide,
                      sideGap: inset * 2 + buttonSide,
                    ),
                  ),
                Positioned(
                  top: inset,
                  right: inset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BadgeSwitcher(
                        child: widget.onExpand == null || _infoOpen
                            ? const SizedBox.shrink(key: ValueKey('no-expand'))
                            : Padding(
                                key: const ValueKey('expand'),
                                padding: EdgeInsets.only(
                                  right: widget.info == null ? 0 : 6,
                                ),
                                child: CallExpandButton(
                                  expanded: false,
                                  compact: compact,
                                  tooltip: widget.expandTooltip ?? '',
                                  onTap: widget.onExpand!,
                                ),
                              ),
                      ),
                      if (widget.info != null)
                        CallTileButton(
                          icon: _infoOpen ? Symbols.close : Symbols.info,
                          compact: compact,
                          tooltip: _infoOpen
                              ? l10n.callInfoHide
                              : l10n.callInfoTooltip,
                          onTap: _toggleInfo,
                        ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        CallParticipantTile._radius,
                      ),
                      border: Border.all(
                        color: widget.speaking && !infoVisible
                            ? kSuccessGreen
                            : Colors.transparent,
                        width: 2.5,
                      ),
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

class _InfoReveal extends StatelessWidget {
  final Animation<double> animation;
  final Offset center;
  final Color color;
  final Widget child;

  const _InfoReveal({
    required this.animation,
    required this.center,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final dx = math.max(center.dx, size.width - center.dx);
        final dy = math.max(center.dy, size.height - center.dy);
        final maxRadius = math.sqrt(dx * dx + dy * dy);
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = Curves.easeInOutCubic.transform(animation.value);
            if (t >= 1) return child!;
            final fill = t * t * t * t;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (fill > 0) ColoredBox(color: color.withValues(alpha: fill)),
                ClipOval(
                  clipper: _CircleClipper(center, maxRadius * t),
                  child: child,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CircleClipper extends CustomClipper<Rect> {
  final Offset center;
  final double radius;

  const _CircleClipper(this.center, this.radius);

  @override
  Rect getClip(Size size) => Rect.fromCircle(center: center, radius: radius);

  @override
  bool shouldReclip(_CircleClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}

class _InfoPanel extends StatelessWidget {
  final String name;
  final List<CallInfoRow> rows;
  final bool compact;
  final double topGap;
  final double sideGap;

  const _InfoPanel({
    required this.name,
    required this.rows,
    required this.compact,
    required this.topGap,
    required this.sideGap,
  });

  void _copy(BuildContext anchor, String value) {
    Clipboard.setData(ClipboardData(text: value));
    showHintBubble(anchor, AppLocalizations.of(anchor)!.msgActionsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fontSize = compact ? 11.0 : 12.5;
    final labelStyle = TextStyle(
      color: cs.onPrimaryContainer.withValues(alpha: 0.7),
      fontSize: fontSize,
    );
    final valueStyle = TextStyle(
      color: cs.onPrimaryContainer,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final horizontal = compact ? 8.0 : 14.0;
    final top = compact ? 8.0 : 12.0;
    return ColoredBox(
      color: cs.primaryContainer,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          top,
          horizontal,
          compact ? 6 : 10,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: topGap - top),
                  child: Padding(
                    padding: EdgeInsets.only(right: sideGap - horizontal),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 2 : 6),
                for (final row in rows)
                  Builder(
                    builder: (anchor) => InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _copy(anchor, row.value),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 2 : 3,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelStyle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                row.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: valueStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _StallVeil extends StatelessWidget {
  final bool stalled;

  const _StallVeil({required this.stalled});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: stalled ? 1 : 0),
        duration: Duration(milliseconds: stalled ? 700 : 300),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          if (t == 0) return const SizedBox.shrink();
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.95 * t),
                  backgroundBlendMode: BlendMode.saturation,
                ),
              ),
              ColoredBox(color: Colors.black.withValues(alpha: 0.22 * t)),
              Center(
                child: Opacity(
                  opacity: 0.55 * t,
                  child: const RepaintBoundary(
                    child: SizedBox.square(
                      dimension: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NameLabel extends StatelessWidget {
  final String name;
  final bool muted;
  final double? networkRating;
  final bool overVideo;
  final bool compact;

  const _NameLabel({
    required this.name,
    required this.muted,
    required this.networkRating,
    required this.overVideo,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = overVideo ? Colors.white : cs.onSurface;
    final shadows = overVideo
        ? const [Shadow(blurRadius: 4, color: Colors.black)]
        : null;
    final iconSize = compact ? 14.0 : 16.0;
    final rating = networkRating;
    final weak = rating != null && rating <= CallParticipant.goodNetworkRating;
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              shadows: shadows,
            ),
          ),
        ),
        _BadgeSwitcher(
          child: muted
              ? Padding(
                  key: const ValueKey('muted'),
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Symbols.mic_off,
                    size: iconSize,
                    color: color,
                    shadows: shadows,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('unmuted')),
        ),
        _BadgeSwitcher(
          child: weak
              ? Padding(
                  key: const ValueKey('weak-network'),
                  padding: const EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: AppLocalizations.of(
                      context,
                    )!.callNetworkTooltip((rating * 100).round()),
                    child: _SignalBars(
                      rating: rating,
                      size: iconSize,
                      shadow: overVideo,
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('good-network')),
        ),
      ],
    );
  }
}

class _SignalBars extends StatelessWidget {
  final double rating;
  final double size;
  final bool shadow;

  const _SignalBars({
    required this.rating,
    required this.size,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: rating),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: Size.square(size),
        painter: _SignalBarsPainter(
          level: value,
          color: value <= CallParticipant.badNetworkRating
              ? kDangerRed
              : kWarningAmber,
          shadow: shadow,
        ),
      ),
    );
  }
}

class _SignalBarsPainter extends CustomPainter {
  static const int _bars = 4;
  static const List<double> _heights = [0.34, 0.56, 0.78, 1];

  final double level;
  final Color color;
  final bool shadow;

  const _SignalBarsPainter({
    required this.level,
    required this.color,
    required this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / 5.5;
    final gap = (size.width - barWidth * _bars) / (_bars - 1);
    final radius = Radius.circular(barWidth / 3);
    final filled = level.clamp(0.0, 1.0) * _bars;
    final paint = Paint();
    final shade = shadow
        ? (Paint()
            ..color = Colors.black.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2))
        : null;
    for (var i = 0; i < _bars; i++) {
      final height = size.height * _heights[i];
      final bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * (barWidth + gap),
          size.height - height,
          barWidth,
          height,
        ),
        radius,
      );
      if (shade != null) canvas.drawRRect(bar, shade);
      final fill = (filled - i).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: 0.28 + 0.72 * fill);
      canvas.drawRRect(bar, paint);
    }
  }

  @override
  bool shouldRepaint(_SignalBarsPainter old) =>
      old.level != level || old.color != color || old.shadow != shadow;
}

class _HandBadge extends StatelessWidget {
  final int? position;
  final bool compact;

  const _HandBadge({required this.position, required this.compact});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final position = this.position;
    final size = compact ? 14.0 : 16.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WavingHandIcon(
            raised: true,
            waveOnMount: true,
            size: size,
            color: cs.onTertiaryContainer,
          ),
          if (position != null) ...[
            const SizedBox(width: 4),
            Text(
              '$position',
              style: TextStyle(
                color: cs.onTertiaryContainer,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool compact;

  const _IconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 4 : 5),
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: compact ? 14 : 16, color: foreground, fill: 1),
    );
  }
}

class _BadgeSwitcher extends StatelessWidget {
  final Widget child;

  const _BadgeSwitcher({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: child,
    );
  }
}
