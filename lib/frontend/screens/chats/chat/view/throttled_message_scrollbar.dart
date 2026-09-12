import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../chat_scroll_navigator.dart';

// #***! Заменяет нативный интерактивный скроллбар Windows/desktop для
// списка сообщений. Проблема нативного: он вызывает ScrollPosition.jumpTo
// напрямую пропорционально позиции курсора — при перетаскивании ползунка
// через тысячи сообщений это один огромный прыжок offset'а, а SliverList
// с сообщениями переменной высоты не умеет мгновенно вычислить геометрию
// для произвольного offset'а — он вынужден синхронно построить/измерить
// весь пропущенный диапазон за один кадр.
//
// Модель управления — чистый джойстик с пружинным возвратом в центр, без
// какой-либо привязки к абсолютной позиции в списке (первая версия
// показывала ползунок и на "реальной позиции", и на "точке захвата"
// одновременно — а поскольку сама позиция двигалась от нашей же скорости,
// эти два источника гонялись друг за другом и визуально дёргались).
// Ползунок всегда покоится ровно по центру трека. Тянешь вниз — едем к
// новым сообщениям, тянешь вверх — к старым, скорость растёт линейно с
// расстоянием оттяжки от центра, достигая потолка на _deadThrowPx.
// Отпустил — скорость падает до нуля, ползунок пружиной уезжает обратно
// в центр.
class ThrottledMessageScrollbar extends StatefulWidget {
  final ScrollController controller;
  final int Function() itemCountOf;
  final ValueNotifier<double?> jumpCacheExtent;
  final double messagesPerSecond;

  const ThrottledMessageScrollbar({
    super.key,
    required this.controller,
    required this.itemCountOf,
    required this.jumpCacheExtent,
    this.messagesPerSecond = 100,
  });

  @override
  State<ThrottledMessageScrollbar> createState() =>
      _ThrottledMessageScrollbarState();
}

class _ThrottledMessageScrollbarState extends State<ThrottledMessageScrollbar>
    with SingleTickerProviderStateMixin {
  static const double _thumbMinHeight = 32;
  static const double _thumbWidth = 4;
  static const double _thumbWidthActive = 7;
  static const double _defaultAvgExtent = 56.0;
  // #***! расстояние от точки захвата до максимальной скорости.
  static const double _deadThrowPx = 90.0;
  // #***! игнорируем дрожание пальца/мыши у самого нуля.
  static const double _deadZonePx = 6.0;

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double? _grabDy;
  double _pullOffset = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _ticker?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_dragging && mounted) setState(() {});
  }

  bool get _hasMetrics =>
      widget.controller.hasClients &&
      widget.controller.position.hasPixels &&
      widget.controller.position.hasContentDimensions;

  double get _avgItemExtent {
    if (!_hasMetrics) return _defaultAvgExtent;
    final maxExtent = widget.controller.position.maxScrollExtent;
    final count = widget.itemCountOf();
    if (count <= 0 || maxExtent <= 0) return _defaultAvgExtent;
    return (maxExtent / count).clamp(16.0, 400.0);
  }

  void _startTicker() {
    _ticker ??= createTicker(_onTick);
    _lastTick = Duration.zero;
    if (!_ticker!.isTicking) _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (!_dragging || !_hasMetrics) {
      _ticker?.stop();
      return;
    }
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final magnitude = _pullOffset.abs() <= _deadZonePx
        ? 0.0
        : ((_pullOffset.abs() - _deadZonePx) / (_deadThrowPx - _deadZonePx))
              .clamp(0.0, 1.0);
    if (magnitude <= 0) return;

    // #***! тянешь вниз (offset > 0) — едем к новым сообщениям, то есть
    // pixels убывает (reverse:true, pixels=0 внизу списка).
    final velocityPxPerSec =
        -_pullOffset.sign * magnitude * widget.messagesPerSecond * _avgItemExtent;

    final pos = widget.controller.position;
    final next = (pos.pixels + velocityPxPerSec * dt).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((next - pos.pixels).abs() >= 0.05) {
      widget.controller.jumpTo(next);
    }
  }

  void _beginDrag(double dy) {
    _dragging = true;
    _grabDy = dy;
    _pullOffset = 0;
    widget.jumpCacheExtent.value = ChatScrollNavigator.jumpCacheExtentPx;
    _startTicker();
    setState(() {});
  }

  void _updatePull(double dy) {
    final grab = _grabDy;
    if (grab == null) return;
    _pullOffset = (dy - grab).clamp(-_deadThrowPx, _deadThrowPx);
    setState(() {});
  }

  void _endDrag() {
    _dragging = false;
    _grabDy = null;
    _pullOffset = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.jumpCacheExtent.value = null;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMetrics || widget.controller.position.maxScrollExtent <= 0) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final pos = widget.controller.position;

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = constraints.maxHeight;
          final totalExtent = pos.maxScrollExtent + pos.viewportDimension;
          final viewportFraction = totalExtent > 0
              ? (pos.viewportDimension / totalExtent).clamp(0.04, 1.0)
              : 1.0;
          final thumbHeight = (trackHeight * viewportFraction).clamp(
            _thumbMinHeight,
            trackHeight,
          );
          final travel = trackHeight - thumbHeight;
          final centerTop = travel / 2;
          final thumbTop = _dragging
              ? (centerTop + _pullOffset).clamp(0.0, travel)
              : centerTop;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (details) =>
                _beginDrag(details.localPosition.dy),
            onVerticalDragUpdate: (details) =>
                _updatePull(details.localPosition.dy),
            onVerticalDragEnd: (_) => _endDrag(),
            onVerticalDragCancel: _endDrag,
            child: SizedBox(
              height: trackHeight,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: _dragging
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    top: thumbTop,
                    right: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: _dragging ? _thumbWidthActive : _thumbWidth,
                      height: thumbHeight,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(
                          alpha: _dragging ? 0.55 : 0.28,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
