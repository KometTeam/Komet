import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_colors.dart';
import 'call_controls.dart';

class CallTileButton extends StatelessWidget {
  final IconData icon;
  final bool compact;
  final String tooltip;
  final VoidCallback onTap;

  const CallTileButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  });

  static double sideFor({required bool compact}) => compact ? 28 : 34;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: CallPressScale(
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: sideFor(compact: compact),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: compact ? 15 : 18,
                  color: Colors.white,
                  weight: 600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CallExpandButton extends StatelessWidget {
  final bool expanded;
  final bool compact;
  final String tooltip;
  final VoidCallback onTap;

  const CallExpandButton({
    super.key,
    required this.expanded,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => CallTileButton(
    icon: expanded ? Symbols.close_fullscreen : Symbols.open_in_full,
    tooltip: tooltip,
    onTap: onTap,
    compact: compact,
  );
}

class CallStage extends StatefulWidget {
  static const double _radius = 18;

  final Widget media;
  final String label;
  final IconData labelIcon;
  final bool speaking;
  final String collapseTooltip;
  final VoidCallback onCollapse;
  final bool fullscreen;
  final String fullscreenTooltip;
  final VoidCallback onToggleFullscreen;

  const CallStage({
    super.key,
    required this.media,
    required this.label,
    required this.labelIcon,
    required this.collapseTooltip,
    required this.onCollapse,
    required this.fullscreenTooltip,
    required this.onToggleFullscreen,
    this.speaking = false,
    this.fullscreen = false,
  });

  @override
  State<CallStage> createState() => _CallStageState();
}

class _CallStageState extends State<CallStage>
    with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 2.5;

  final TransformationController _zoom = TransformationController();
  late final AnimationController _zoomMotion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addListener(_onZoomTick);
  Animatable<Matrix4>? _zoomPath;
  Offset? _doubleTapAt;

  @override
  void dispose() {
    _zoomMotion.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onZoomTick() {
    final path = _zoomPath;
    if (path != null) _zoom.value = path.evaluate(_zoomMotion);
  }

  void _toggleZoom() {
    final at = _doubleTapAt;
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    final target = zoomed || at == null
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
            ..setTranslationRaw(
              -at.dx * (_doubleTapScale - 1),
              -at.dy * (_doubleTapScale - 1),
              0,
            ));
    _zoomPath = Matrix4Tween(
      begin: _zoom.value,
      end: target,
    ).chain(CurveTween(curve: Curves.easeOutCubic));
    _zoomMotion.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final radius = widget.fullscreen ? 0.0 : CallStage._radius;
    final inset = widget.fullscreen
        ? MediaQuery.paddingOf(context)
        : EdgeInsets.zero;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          GestureDetector(
            onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _zoom,
              maxScale: 5,
              child: SizedBox.expand(child: widget.media),
            ),
          ),
          Positioned(
            left: (wide ? 14 : 10) + inset.left,
            bottom: (wide ? 14 : 10) + inset.bottom,
            right: 64 + inset.right,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StageLabel(icon: widget.labelIcon, text: widget.label),
            ),
          ),
          Positioned(
            top: (wide ? 12 : 8) + inset.top,
            right: (wide ? 12 : 8) + inset.right,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CallTileButton(
                  icon: widget.fullscreen
                      ? Symbols.fullscreen_exit
                      : Symbols.fullscreen,
                  tooltip: widget.fullscreenTooltip,
                  onTap: widget.onToggleFullscreen,
                ),
                if (!widget.fullscreen) ...[
                  const SizedBox(width: 8),
                  CallExpandButton(
                    expanded: true,
                    tooltip: widget.collapseTooltip,
                    onTap: widget.onCollapse,
                  ),
                ],
              ],
            ),
          ),
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: widget.speaking ? kSuccessGreen : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StageLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white, fill: 1),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CallStrip<T extends Object> extends StatelessWidget {
  static const double aspect = 4 / 3;

  final List<T> ids;
  final double height;
  final double gap;
  final Widget Function(BuildContext context, T id, Size size) tileBuilder;

  const CallStrip({
    super.key,
    required this.ids,
    required this.height,
    required this.tileBuilder,
    this.gap = 8,
  });

  static int fittingCount(double width, double height, double gap) =>
      ((width + gap) / (height * aspect + gap)).ceil();

  @override
  Widget build(BuildContext context) {
    final tile = Size(height * aspect, height);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final total = ids.length * (tile.width + gap) - gap;
          Widget item(T id) => SizedBox.fromSize(
            key: ValueKey(id),
            size: tile,
            child: RepaintBoundary(child: tileBuilder(context, id, tile)),
          );
          if (total <= constraints.maxWidth) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, id) in ids.indexed) ...[
                  if (index > 0) SizedBox(width: gap),
                  item(id),
                ],
              ],
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, _) => SizedBox(width: gap),
            itemBuilder: (context, index) => item(ids[index]),
          );
        },
      ),
    );
  }
}
