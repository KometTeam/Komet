import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CallGridLayout {
  static const double idealAspect = 4 / 3;
  static const double narrowestAspect = 9 / 16;
  static const double widestAspect = 2.2;

  final int count;
  final int columns;
  final int rows;
  final Size tile;
  final Offset origin;
  final double gap;

  const CallGridLayout._({
    required this.count,
    required this.columns,
    required this.rows,
    required this.tile,
    required this.origin,
    required this.gap,
  });

  factory CallGridLayout.fit(Size area, int count, {double gap = 8}) {
    if (count <= 0 || area.isEmpty) {
      return CallGridLayout._(
        count: 0,
        columns: 1,
        rows: 0,
        tile: Size.zero,
        origin: Offset.zero,
        gap: gap,
      );
    }
    var bestColumns = 1;
    var bestScore = -1.0;
    for (var columns = 1; columns <= count; columns++) {
      final rows = (count / columns).ceil();
      final cell = _cell(area, columns, rows, gap);
      if (cell.isEmpty) continue;
      final width = math.min(cell.width, cell.height * idealAspect);
      final score = width * width / idealAspect;
      if (score > bestScore) {
        bestScore = score;
        bestColumns = columns;
      }
    }
    final rows = (count / bestColumns).ceil();
    final cell = _cell(area, bestColumns, rows, gap);
    final tile = _clampAspect(cell);
    final gridWidth = bestColumns * tile.width + (bestColumns - 1) * gap;
    final gridHeight = rows * tile.height + (rows - 1) * gap;
    return CallGridLayout._(
      count: count,
      columns: bestColumns,
      rows: rows,
      tile: tile,
      origin: Offset(
        (area.width - gridWidth) / 2,
        (area.height - gridHeight) / 2,
      ),
      gap: gap,
    );
  }

  static int capacity(Size area, {double gap = 8, required double minSide}) {
    var fits = 1;
    for (var count = 2; count <= 64; count++) {
      final layout = CallGridLayout.fit(area, count, gap: gap);
      if (layout.tile.shortestSide < minSide) break;
      fits = count;
    }
    return fits;
  }

  static Size _cell(Size area, int columns, int rows, double gap) {
    final width = (area.width - (columns - 1) * gap) / columns;
    final height = (area.height - (rows - 1) * gap) / rows;
    if (width <= 0 || height <= 0) return Size.zero;
    return Size(width, height);
  }

  static Size _clampAspect(Size cell) {
    final aspect = cell.width / cell.height;
    if (aspect > widestAspect) {
      return Size(cell.height * widestAspect, cell.height);
    }
    if (aspect < narrowestAspect) {
      return Size(cell.width, cell.width / narrowestAspect);
    }
    return cell;
  }

  Rect rectAt(int index) {
    final row = index ~/ columns;
    final column = index % columns;
    final inRow = row == rows - 1 ? count - row * columns : columns;
    final fullWidth = columns * tile.width + (columns - 1) * gap;
    final rowWidth = inRow * tile.width + (inRow - 1) * gap;
    return Rect.fromLTWH(
      origin.dx + (fullWidth - rowWidth) / 2 + column * (tile.width + gap),
      origin.dy + row * (tile.height + gap),
      tile.width,
      tile.height,
    );
  }
}

typedef CallGridVisibility<T> = void Function(List<T> ids, Size tile);

class CallGrid<T extends Object> extends StatefulWidget {
  final List<T> ids;
  final Widget Function(BuildContext context, T id, Size size) tileBuilder;
  final double gap;
  final double minTileSide;
  final EdgeInsets padding;
  final Color indicatorColor;
  final CallGridVisibility<T>? onVisibleChanged;

  const CallGrid({
    super.key,
    required this.ids,
    required this.tileBuilder,
    required this.indicatorColor,
    this.gap = 8,
    this.minTileSide = 120,
    this.padding = EdgeInsets.zero,
    this.onVisibleChanged,
  });

  @override
  State<CallGrid<T>> createState() => _CallGridState<T>();
}

class _CallGridState<T extends Object> extends State<CallGrid<T>> {
  static const Duration _move = Duration(milliseconds: 260);
  static const double _indicatorHeight = 18;

  final PageController _pages = PageController();
  final Map<(Size, double, double), int> _capacities = {};
  int _page = 0;
  List<T> _reportedIds = const [];
  Size? _reportedTile;
  bool _reportScheduled = false;

  int _capacity(Size area) {
    final key = (area, widget.gap, widget.minTileSide);
    final known = _capacities[key];
    if (known != null) return known;
    if (_capacities.length >= 8) _capacities.clear();
    return _capacities[key] = CallGridLayout.capacity(
      area,
      gap: widget.gap,
      minSide: widget.minTileSide,
    );
  }

  void _report(List<T> ids, Size tile) {
    if (widget.onVisibleChanged == null) return;
    if (tile == _reportedTile && listEquals(ids, _reportedIds)) return;
    _reportedIds = ids;
    _reportedTile = tile;
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (mounted) widget.onVisibleChanged?.call(_reportedIds, _reportedTile!);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = widget.padding.deflateSize(constraints.biggest);
        final fitsOnePage = widget.ids.length <= _capacity(full);
        final area = fitsOnePage
            ? full
            : Size(full.width, full.height - _indicatorHeight);
        final capacity = _capacity(area);
        final pageCount = math.max(1, (widget.ids.length / capacity).ceil());
        final current = _page.clamp(0, pageCount - 1);
        final visible = widget.ids
            .skip(current * capacity)
            .take(capacity)
            .toList(growable: false);
        _report(
          visible,
          CallGridLayout.fit(area, visible.length, gap: widget.gap).tile,
        );
        return Padding(
          padding: widget.padding,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: pageCount,
                  physics: pageCount > 1
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, page) => _GridPage<T>(
                    ids: widget.ids
                        .skip(page * capacity)
                        .take(capacity)
                        .toList(growable: false),
                    gap: widget.gap,
                    duration: _move,
                    tileBuilder: widget.tileBuilder,
                  ),
                ),
              ),
              if (pageCount > 1)
                SizedBox(
                  height: _indicatorHeight,
                  child: _PageDots(
                    count: pageCount,
                    current: current,
                    color: widget.indicatorColor,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _GridPage<T extends Object> extends StatefulWidget {
  final List<T> ids;
  final double gap;
  final Duration duration;
  final Widget Function(BuildContext context, T id, Size size) tileBuilder;

  const _GridPage({
    required this.ids,
    required this.gap,
    required this.duration,
    required this.tileBuilder,
  });

  @override
  State<_GridPage<T>> createState() => _GridPageState<T>();
}

class _GridPageState<T extends Object> extends State<_GridPage<T>> {
  Size? _laidOutFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final resized = _laidOutFor != null && _laidOutFor != area;
        _laidOutFor = area;
        final layout = CallGridLayout.fit(
          area,
          widget.ids.length,
          gap: widget.gap,
        );
        final duration = resized ? Duration.zero : widget.duration;
        return Stack(
          children: [
            for (var i = 0; i < widget.ids.length; i++)
              _tile(context, widget.ids[i], layout.rectAt(i), duration),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, T id, Rect rect, Duration duration) {
    return AnimatedPositioned(
      key: ValueKey(id),
      duration: duration,
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: RepaintBoundary(child: widget.tileBuilder(context, id, rect.size)),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final Color color;

  const _PageDots({
    required this.count,
    required this.current,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.withValues(alpha: i == current ? 1 : 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
