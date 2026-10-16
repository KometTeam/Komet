import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'message_list_decorations.dart';

class AnchoredMessageList extends StatefulWidget {
  static const Key centerKey = ValueKey('anchored-message-list-center');
  static const double initialCacheExtent = 250;
  static const double cacheExtentStep = 600;

  const AnchoredMessageList({
    super.key,
    required this.controller,
    required this.cacheExtent,
    required this.padding,
    required this.epoch,
    required this.itemCount,
    required this.anchorIndex,
    required this.itemBuilder,
    required this.bottomSpacer,
    this.loadingOlder = false,
    this.loadingNewer = false,
    this.physics,
    this.cacheGrowthAllowed,
  });

  final ScrollController controller;
  final double cacheExtent;
  final EdgeInsets padding;
  final int epoch;
  final int itemCount;
  final int? anchorIndex;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Widget bottomSpacer;
  final bool loadingOlder;
  final bool loadingNewer;
  final ScrollPhysics? physics;
  final ValueListenable<bool>? cacheGrowthAllowed;

  static double anchoredPixels({
    required double alignment,
    required double viewport,
    required double anchorHeight,
  }) => alignment * viewport - viewport + anchorHeight;

  @override
  State<AnchoredMessageList> createState() => _AnchoredMessageListState();
}

class _AnchoredMessageListState extends State<AnchoredMessageList> {
  late double _cacheExtent = math.min(
    widget.cacheExtent,
    AnchoredMessageList.initialCacheExtent,
  );
  bool _growthScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.cacheGrowthAllowed?.addListener(_scheduleGrowth);
    _scheduleGrowth();
  }

  @override
  void didUpdateWidget(AnchoredMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheGrowthAllowed != widget.cacheGrowthAllowed) {
      oldWidget.cacheGrowthAllowed?.removeListener(_scheduleGrowth);
      widget.cacheGrowthAllowed?.addListener(_scheduleGrowth);
    }
    if (widget.cacheExtent < _cacheExtent) _cacheExtent = widget.cacheExtent;
    _scheduleGrowth();
  }

  @override
  void dispose() {
    widget.cacheGrowthAllowed?.removeListener(_scheduleGrowth);
    super.dispose();
  }

  bool get _canGrow =>
      _cacheExtent < widget.cacheExtent &&
      (widget.cacheGrowthAllowed?.value ?? true);

  void _scheduleGrowth() {
    if (_growthScheduled || !_canGrow) return;
    _growthScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _growthScheduled = false;
      if (!mounted || !_canGrow) return;
      setState(() {
        _cacheExtent = math.min(
          widget.cacheExtent,
          _cacheExtent + AnchoredMessageList.cacheExtentStep,
        );
      });
      _scheduleGrowth();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: widget.controller,
      reverse: true,
      physics: widget.physics,
      center: AnchoredMessageList.centerKey,
      scrollCacheExtent: ScrollCacheExtent.pixels(_cacheExtent),
      slivers: _slivers(),
    );
  }

  List<Widget> _slivers() {
    final itemCount = widget.itemCount;
    final itemBuilder = widget.itemBuilder;
    final bottomSpacer = widget.bottomSpacer;
    final padding = widget.padding;
    final epoch = widget.epoch;
    final anchor = widget.anchorIndex;
    if (anchor == null || anchor < 0 || anchor >= itemCount) {
      return [
        SliverPadding(
          key: AnchoredMessageList.centerKey,
          padding: padding,
          sliver: SliverList(
            key: ValueKey(('bottom', epoch)),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 0) return bottomSpacer;
              if (index > itemCount) {
                return const MessageListLoadMoreIndicator();
              }
              return itemBuilder(context, itemCount - index);
            }, childCount: itemCount + 1 + (widget.loadingOlder ? 1 : 0)),
          ),
        ),
      ];
    }

    final newerCount = itemCount - anchor - 1;
    return [
      SliverPadding(
        padding: padding.copyWith(top: 0),
        sliver: SliverList(
          key: ValueKey(('newer', epoch)),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index < newerCount) {
              return itemBuilder(context, anchor + 1 + index);
            }
            if (widget.loadingNewer && index == newerCount) {
              return const MessageListLoadMoreIndicator();
            }
            return bottomSpacer;
          }, childCount: newerCount + (widget.loadingNewer ? 1 : 0) + 1),
        ),
      ),
      SliverPadding(
        key: AnchoredMessageList.centerKey,
        padding: padding.copyWith(bottom: 0),
        sliver: SliverList(
          key: ValueKey(('older', epoch)),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index > anchor) return const MessageListLoadMoreIndicator();
            return itemBuilder(context, anchor - index);
          }, childCount: anchor + 1 + (widget.loadingOlder ? 1 : 0)),
        ),
      ),
    ];
  }
}
