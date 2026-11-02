import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_motion.dart';

class SelectionToolbarStyle {
  static const double height = 44;
  static const double radius = 14;
  static const double screenMargin = 8;
  static const double gapAbove = 8;
  static const double gapBelow =
      TextSelectionToolbar.kToolbarContentDistanceBelow;
  static const double labelPadding = 12;
  static const double iconCellWidth = 42;
  static const double minIconCellWidth = 36;
  static const double navCellWidth = 34;
  static const double iconSize = 22;
  static const double navIconSize = 20;
  static const double enterScale = 0.9;
  static const double pageShift = 0.2;
  static const Duration enterDuration = Duration(milliseconds: 200);
  static const Duration pageDuration = Duration(milliseconds: 240);
  static const Duration stateDuration = Duration(milliseconds: 160);

  static TextStyle labelStyle(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
    return MediaQuery.boldTextOf(context)
        ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
        : style;
  }

  static double labelCellWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: labelStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble() + 1 + labelPadding * 2;
  }
}

class SelectionToolbarFloor extends InheritedWidget {
  const SelectionToolbarFloor({super.key, required super.child});

  static double? topOf(BuildContext context) {
    final floor = context
        .getElementForInheritedWidgetOfExactType<SelectionToolbarFloor>()
        ?.renderObject;
    if (floor is! RenderBox || !floor.attached || !floor.hasSize) return null;
    return floor.localToGlobal(Offset.zero).dy;
  }

  @override
  bool updateShouldNotify(SelectionToolbarFloor oldWidget) => false;
}

@immutable
class SelectionToolbarItem {
  const SelectionToolbarItem({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint,
    this.selected,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? tint;
  final bool? selected;
}

class SelectionToolbarSurface extends StatelessWidget {
  const SelectionToolbarSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.all(
        Radius.circular(SelectionToolbarStyle.radius),
      ),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(height: SelectionToolbarStyle.height, child: child),
    );
  }
}

class SelectionToolbarTextButton extends StatelessWidget {
  const SelectionToolbarTextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SelectionToolbarStyle.labelPadding,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: SelectionToolbarStyle.labelStyle(context),
          ),
        ),
      ),
    );
  }
}

class SelectionToolbar extends StatefulWidget {
  const SelectionToolbar({
    super.key,
    required this.anchors,
    required this.items,
    this.depth = 0,
    this.onBack,
    this.floor,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<SelectionToolbarItem> items;
  final int depth;
  final VoidCallback? onBack;
  final double? floor;

  @override
  State<SelectionToolbar> createState() => _SelectionToolbarState();
}

class _SelectionToolbarState extends State<SelectionToolbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.of(SelectionToolbarStyle.enterDuration),
  );
  late final CurvedAnimation _entranceCurve = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _entranceScale = _entranceCurve.drive(
    Tween(begin: SelectionToolbarStyle.enterScale, end: 1),
  );

  int _page = 0;
  bool _forward = true;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
  }

  @override
  void didUpdateWidget(SelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.depth == widget.depth) return;
    _forward = widget.depth > oldWidget.depth;
    _page = 0;
  }

  @override
  void dispose() {
    _entranceCurve.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _turn(int from, int to) {
    setState(() {
      _forward = to > from;
      _page = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty && widget.onBack == null) {
      return const SizedBox.shrink();
    }
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final floor = widget.floor;
    final covered = floor == null
        ? padding.bottom + keyboard
        : math.max(padding.bottom + keyboard, screenHeight - floor);
    const margin = SelectionToolbarStyle.screenMargin;
    final insets = EdgeInsets.fromLTRB(
      padding.left + margin,
      padding.top + margin,
      padding.right + margin,
      covered + margin,
    );
    final anchorAbove = widget.anchors.primaryAnchor;
    final anchorBelow = widget.anchors.secondaryAnchor ?? anchorAbove;
    final placeAbove = _fitsAbove(
      anchorAbove,
      anchorBelow,
      insets,
      screenHeight,
    );
    return CustomSingleChildLayout(
      delegate: _SelectionToolbarLayout(
        anchorAbove: anchorAbove,
        anchorBelow: anchorBelow,
        insets: insets,
        placeAbove: placeAbove,
      ),
      child: FadeTransition(
        opacity: _entranceCurve,
        child: ScaleTransition(
          scale: _entranceScale,
          alignment: placeAbove ? Alignment.bottomCenter : Alignment.topCenter,
          child: SelectionToolbarSurface(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _pages(context, constraints.maxWidth),
            ),
          ),
        ),
      ),
    );
  }

  static bool _fitsAbove(
    Offset anchorAbove,
    Offset anchorBelow,
    EdgeInsets insets,
    double screenHeight,
  ) {
    const height = SelectionToolbarStyle.height;
    final roomAbove =
        anchorAbove.dy - SelectionToolbarStyle.gapAbove - insets.top;
    if (roomAbove >= height) return true;
    final roomBelow =
        screenHeight -
        insets.bottom -
        anchorBelow.dy -
        SelectionToolbarStyle.gapBelow;
    if (roomBelow >= height) return false;
    return roomAbove >= roomBelow;
  }

  Widget _pages(BuildContext context, double maxWidth) {
    final items = widget.items;
    final layout = _ToolbarPagination.of(
      [
        for (final item in items)
          item.icon == null
              ? SelectionToolbarStyle.labelCellWidth(context, item.label)
              : null,
      ],
      maxWidth,
      leadingBack: widget.onBack != null,
    );
    final pages = layout.pages;
    final page = math.min(_page, pages.length - 1);
    final (start, end) = pages[page];
    final onBack = widget.onBack;
    final localizations = MaterialLocalizations.of(context);
    final contentKey = ValueKey((widget.depth, page));
    final duration = AppMotion.of(SelectionToolbarStyle.pageDuration);

    final row = Row(
      key: contentKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (page > 0)
          _ToolbarIconCell(
            icon: Symbols.chevron_left,
            label: localizations.backButtonTooltip,
            width: SelectionToolbarStyle.navCellWidth,
            size: SelectionToolbarStyle.navIconSize,
            onPressed: () => _turn(page, page - 1),
          )
        else if (onBack != null)
          _ToolbarIconCell(
            icon: Symbols.chevron_left,
            label: localizations.backButtonTooltip,
            width: SelectionToolbarStyle.navCellWidth,
            size: SelectionToolbarStyle.navIconSize,
            onPressed: onBack,
          ),
        for (final item in items.sublist(start, end))
          if (item.icon case final icon?)
            _ToolbarIconCell(
              icon: icon,
              label: item.label,
              width: layout.iconWidth,
              tint: item.tint,
              selected: item.selected,
              onPressed: item.onPressed,
            )
          else
            SelectionToolbarTextButton(
              label: item.label,
              onPressed: item.onPressed,
            ),
        if (page < pages.length - 1)
          _ToolbarIconCell(
            icon: Symbols.chevron_right,
            label: localizations.moreButtonTooltip,
            width: SelectionToolbarStyle.navCellWidth,
            size: SelectionToolbarStyle.navIconSize,
            onPressed: () => _turn(page, page + 1),
          ),
      ],
    );

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: duration,
        layoutBuilder: _stackPages,
        transitionBuilder: (child, animation) =>
            _slidePage(child, animation, incoming: child.key == contentKey),
        child: row,
      ),
    );
  }

  Widget _slidePage(
    Widget child,
    Animation<double> animation, {
    required bool incoming,
  }) {
    final shift = incoming == _forward
        ? SelectionToolbarStyle.pageShift
        : -SelectionToolbarStyle.pageShift;
    return FadeTransition(
      opacity: animation.drive(
        CurveTween(curve: incoming ? _fadeInInterval : _fadeOutInterval),
      ),
      child: SlideTransition(
        position: animation.drive(
          Tween(begin: Offset(shift, 0), end: Offset.zero).chain(
            CurveTween(
              curve: incoming ? Curves.easeOutCubic : Curves.easeInCubic,
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  static const _fadeInInterval = Interval(0.3, 1, curve: Curves.easeOut);
  static const _fadeOutInterval = Interval(0.7, 1, curve: Curves.easeIn);

  static Widget _stackPages(Widget? current, List<Widget> previous) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (final child in previous)
          Positioned(top: 0, bottom: 0, child: child),
        ?current,
      ],
    );
  }
}

class _ToolbarPagination {
  const _ToolbarPagination(this.pages, this.iconWidth);

  final List<(int, int)> pages;
  final double iconWidth;

  factory _ToolbarPagination.of(
    List<double?> labelWidths,
    double maxWidth, {
    required bool leadingBack,
  }) {
    const nav = SelectionToolbarStyle.navCellWidth;
    const preferred = SelectionToolbarStyle.iconCellWidth;
    final count = labelWidths.length;
    final icons = labelWidths.where((width) => width == null).length;
    final labels = labelWidths.fold(0.0, (sum, width) => sum + (width ?? 0));
    final room = maxWidth - (leadingBack ? nav : 0) - labels;
    if (icons == 0 && room >= 0) {
      return _ToolbarPagination([(0, count)], preferred);
    }
    if (icons > 0 && room / icons >= SelectionToolbarStyle.minIconCellWidth) {
      final iconWidth = math.min(preferred, (room / icons).floorToDouble());
      return _ToolbarPagination([(0, count)], iconWidth);
    }

    final widths = [for (final width in labelWidths) width ?? preferred];
    final pages = <(int, int)>[];
    var start = 0;
    while (start < count) {
      final leading = pages.isNotEmpty || leadingBack ? nav : 0.0;
      final rest = widths.skip(start).fold(0.0, (sum, width) => sum + width);
      if (leading + rest <= maxWidth) {
        pages.add((start, count));
        break;
      }
      var used = leading + nav;
      var end = start;
      while (end < count && used + widths[end] <= maxWidth) {
        used += widths[end];
        end++;
      }
      if (end == start) end++;
      pages.add((start, end));
      start = end;
    }
    return _ToolbarPagination(pages.isEmpty ? [(0, 0)] : pages, preferred);
  }
}

class _ToolbarIconCell extends StatelessWidget {
  const _ToolbarIconCell({
    required this.icon,
    required this.label,
    required this.width,
    required this.onPressed,
    this.size = SelectionToolbarStyle.iconSize,
    this.tint,
    this.selected,
  });

  final IconData icon;
  final String label;
  final double width;
  final double size;
  final Color? tint;
  final bool? selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = selected ?? false;
    final duration = AppMotion.of(SelectionToolbarStyle.stateDuration);
    final color = active ? cs.primary : (tint ?? cs.onSurface);
    return Semantics(
      toggled: selected,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: width,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                width: math.max(0, width - 6),
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: active ? 0.16 : 0),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: duration,
                  builder: (context, value, _) =>
                      Icon(icon, size: size, weight: 450, color: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionToolbarLayout extends SingleChildLayoutDelegate {
  const _SelectionToolbarLayout({
    required this.anchorAbove,
    required this.anchorBelow,
    required this.insets,
    required this.placeAbove,
  });

  final Offset anchorAbove;
  final Offset anchorBelow;
  final EdgeInsets insets;
  final bool placeAbove;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        math.max(0, constraints.maxWidth - insets.horizontal),
        SelectionToolbarStyle.height,
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor = placeAbove ? anchorAbove : anchorBelow;
    final minLeft = insets.left;
    final maxLeft = math.max(
      minLeft,
      size.width - insets.right - childSize.width,
    );
    final minTop = insets.top;
    final maxTop = math.max(
      minTop,
      size.height - insets.bottom - childSize.height,
    );
    final top = placeAbove
        ? anchorAbove.dy - SelectionToolbarStyle.gapAbove - childSize.height
        : anchorBelow.dy + SelectionToolbarStyle.gapBelow;
    return Offset(
      (anchor.dx - childSize.width / 2).clamp(minLeft, maxLeft),
      top.clamp(minTop, maxTop),
    );
  }

  @override
  bool shouldRelayout(_SelectionToolbarLayout oldDelegate) {
    return oldDelegate.anchorAbove != anchorAbove ||
        oldDelegate.anchorBelow != anchorBelow ||
        oldDelegate.insets != insets ||
        oldDelegate.placeAbove != placeAbove;
  }
}
