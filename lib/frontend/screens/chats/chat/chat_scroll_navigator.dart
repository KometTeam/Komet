import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'chat_controller.dart';
import 'read_marker_gate.dart';

class ChatScrollNavigator {
  ChatScrollNavigator({
    required this.scrollController,
    required this.chatController,
    required this.shimmerController,
    required this.scrollDownAnimController,
    required this.scrollDownCurved,
    required this.readMarker,
    required this.listKey,
    required this.keyForMessage,
    required this.buildCombinedItems,
    required this.messageIdOf,
    required this.messageOffsetInList,
    required this.loadMessageWindow,
    required this.flushDeferredMessages,
    required this.isDeferred,
    required this.hasDeferredMessages,
    required this.bumpMessages,
    required this.clearPinnedMessage,
    required this.isMounted,
    required this.notifyState,
    required this.showNotification,
    required this.initialMessageIdOf,
    required this.initialMessageTimeOf,
  });

  final ScrollController scrollController;
  final ChatController chatController;
  final AnimationController shimmerController;
  final AnimationController scrollDownAnimController;
  final CurvedAnimation scrollDownCurved;
  final ReadMarkerGate readMarker;
  final GlobalKey listKey;
  final GlobalKey Function(String messageId) keyForMessage;
  final List<Object> Function() buildCombinedItems;
  final String? Function(Object item) messageIdOf;
  final double? Function(String messageId) messageOffsetInList;
  final Future<void> Function(String messageId, int targetTime)
  loadMessageWindow;
  final VoidCallback flushDeferredMessages;
  final bool Function(String messageId) isDeferred;
  final bool Function() hasDeferredMessages;
  final VoidCallback bumpMessages;
  final VoidCallback clearPinnedMessage;
  final bool Function() isMounted;
  final void Function(VoidCallback fn) notifyState;
  final void Function(String message) showNotification;
  final String? Function() initialMessageIdOf;
  final int? Function() initialMessageTimeOf;

  static const int _jumpStallLimit = 8;
  static const int _jumpFrameLimit = 240;
  static const double _jumpStepMaxScreens = 4.0;
  static const double _scrollDownTeleportFactor = 2.0;
  static const double _scrollDownRevealExtent = 72.0 * 30;
  static const double _scrollDownRevealFactor = 0.6;
  static const double jumpCacheExtentPx = 800.0;

  bool navigatingToTarget = false;
  bool initialTargetHandled = false;
  Timer? _goToMessageSettleTimer;
  final ValueNotifier<double?> jumpCacheExtent = ValueNotifier<double?>(null);

  final ValueNotifier<String?> highlightMessageId = ValueNotifier(null);
  Timer? _highlightTimer;

  int gestureEpoch = 0;

  final List<({String id, double pixels, double alignment})> _returnStack =
      [];
  int listEpoch = 0;
  bool _returningToAnchor = false;

  bool _scrollDownVisible = false;
  final ValueNotifier<int> newMessageCount = ValueNotifier(0);
  bool _clearCountScheduled = false;

  void dispose() {
    _goToMessageSettleTimer?.cancel();
    jumpCacheExtent.dispose();
    _highlightTimer?.cancel();
    highlightMessageId.dispose();
    newMessageCount.dispose();
  }

  void bumpGestureEpoch() => gestureEpoch++;

  void maybeRunInitialTarget() {
    if (initialTargetHandled || initialMessageIdOf() == null) return;
    initialTargetHandled = true;
    beginTargetNavigation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) unawaited(navigateToInitialMessage());
    });
  }

  void beginTargetNavigation() {
    navigatingToTarget = true;
    jumpCacheExtent.value = jumpCacheExtentPx;
    _goToMessageSettleTimer?.cancel();
    if (!shimmerController.isAnimating) shimmerController.repeat();
  }

  void finishTargetNavigation() {
    _goToMessageSettleTimer?.cancel();
    if (!isMounted()) {
      navigatingToTarget = false;
      return;
    }
    if (navigatingToTarget) {
      notifyState(() => navigatingToTarget = false);
    }
    if (shimmerController.isAnimating) shimmerController.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) jumpCacheExtent.value = null;
    });
  }

  void requestGoToMessage(String id, int time) {
    if (!isMounted()) return;
    notifyState(beginTargetNavigation);
    _goToMessageSettleTimer = Timer(const Duration(milliseconds: 340), () {
      if (isMounted()) unawaited(runGoToMessage(id, time));
    });
  }

  void jumpToPinnedMessage({
    required int? pinnedMsgId,
    required int? pinnedMsgTime,
  }) {
    if (pinnedMsgId == null) return;
    final messageId = pinnedMsgId.toString();
    if (chatController.containsId(messageId)) {
      scrollToLoadedMessage(messageId);
      return;
    }
    notifyState(beginTargetNavigation);
    unawaited(runGoToMessage(messageId, pinnedMsgTime ?? 0));
  }

  Future<void> navigateToInitialMessage() async {
    final id = initialMessageIdOf();
    if (id == null) {
      finishTargetNavigation();
      return;
    }
    await runGoToMessage(id, initialMessageTimeOf() ?? 0);
  }

  Future<void> runGoToMessage(String id, int targetTime) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!isMounted()) return;

    if (!chatController.containsId(id)) {
      await loadMessageWindow(id, targetTime);
      if (!isMounted()) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!isMounted()) return;
    }

    if (!chatController.containsId(id)) {
      if (isMounted()) showNotification('Сообщение не загружено');
      finishTargetNavigation();
      return;
    }

    _highlightTimer?.cancel();
    highlightMessageId.value = id;
    _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!isMounted()) return;
      if (highlightMessageId.value == id) highlightMessageId.value = null;
    });

    await scrollToMessagePrecise(id);
    finishTargetNavigation();
  }

  ({int min, int max})? _laidOutMessageRange(List<Object> items) {
    int? lo;
    int? hi;
    for (var i = 0; i < items.length; i++) {
      final id = messageIdOf(items[i]);
      if (id == null) continue;
      final ro = keyForMessage(id).currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        lo ??= i;
        hi = i;
      }
    }
    if (lo == null) return null;
    return (min: lo, max: hi!);
  }

  Future<void> scrollToMessagePrecise(
    String id, {
    double alignment = 0.32,
  }) async {
    if (!isMounted() || !scrollController.hasClients) return;
    if (!chatController.containsId(id)) return;

    final epoch = gestureEpoch;
    readMarker.hold();
    try {
      var stable = 0;
      for (var iter = 0; iter < 120; iter++) {
        if (!isMounted() || !scrollController.hasClients) return;
        if (gestureEpoch != epoch) return;
        final listObj = listKey.currentContext?.findRenderObject();
        final boxObj = keyForMessage(id).currentContext?.findRenderObject();
        final p = scrollController.position;

        if (listObj is RenderBox && boxObj is RenderBox && boxObj.attached) {
          final viewportH = listObj.size.height;
          final actualTop = boxObj
              .localToGlobal(Offset.zero, ancestor: listObj)
              .dy;
          final desiredTop = alignment * viewportH;
          final delta = desiredTop - actualTop;
          final target = (p.pixels + delta).clamp(
            p.minScrollExtent,
            p.maxScrollExtent,
          );

          if (delta.abs() <= 2.0 || (target - p.pixels).abs() <= 1.0) {
            stable++;
            if (stable >= 4) return;
            await Future.delayed(const Duration(milliseconds: 60));
            continue;
          }
          stable = 0;
          scrollController.jumpTo(target);
          await WidgetsBinding.instance.endOfFrame;
          continue;
        }

        stable = 0;
        final items = buildCombinedItems();
        final pos = items.indexWhere((it) => messageIdOf(it) == id);
        if (pos == -1) return;

        final viewportH = listObj is RenderBox ? listObj.size.height : 600.0;
        var stepMag = viewportH * 0.8;
        if (stepMag > 700) stepMag = 700;

        final range = _laidOutMessageRange(items);
        final step = (range != null && pos > range.max) ? -stepMag : stepMag;

        final target = (p.pixels + step).clamp(
          p.minScrollExtent,
          p.maxScrollExtent,
        );
        if ((target - p.pixels).abs() < 1.0) return;
        scrollController.jumpTo(target);
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      readMarker.release();
    }
  }

  void scrollToLoadedMessage(
    String messageId, {
    double alignment = 0.4,
    bool highlight = true,
    bool notifyIfMissing = true,
    VoidCallback? onSettled,
  }) {
    void settle() {
      readMarker.release();
      onSettled?.call();
    }

    readMarker.hold();
    if (!scrollController.hasClients) {
      settle();
      return;
    }
    if (isDeferred(messageId)) flushDeferredMessages();
    final items = buildCombinedItems();
    final pos = items.indexWhere((it) => messageIdOf(it) == messageId);
    if (pos == -1) {
      if (notifyIfMissing) {
        showNotification('Сообщение не загружено');
      }
      settle();
      return;
    }

    final laidOut = keyForMessage(
      messageId,
    ).currentContext?.findRenderObject();
    if (laidOut is! RenderBox || !laidOut.attached) {
      jumpNearMessage(messageId);
    }

    if (highlight) {
      _highlightTimer?.cancel();
      highlightMessageId.value = messageId;
      _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!isMounted()) return;
        if (highlightMessageId.value == messageId) {
          highlightMessageId.value = null;
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => alignLoadedMessage(messageId, alignment, 0, onSettled: settle),
    );
  }

  ({int oldest, int newest}) _visibleItemRange(
    List<Object> items,
    RenderBox listBox,
  ) {
    var oldest = -1;
    var newest = -1;
    final viewportBottom = listBox.size.height;
    for (var i = 0; i < items.length; i++) {
      final id = messageIdOf(items[i]);
      if (id == null) continue;
      final box = keyForMessage(id).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) {
        if (oldest != -1) break;
        continue;
      }
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (top + box.size.height <= 0 || top >= viewportBottom) {
        if (oldest != -1) break;
        continue;
      }
      if (oldest == -1) oldest = i;
      newest = i;
    }
    return (oldest: oldest, newest: newest);
  }

  double _jumpStepScreens(int index, ({int oldest, int newest}) visible) {
    if (visible.oldest == -1) return 1;
    final perScreen = visible.newest - visible.oldest + 1;
    if (perScreen <= 0) return 1;
    final away = index < visible.oldest
        ? visible.oldest - index
        : index - visible.newest;
    return (away / perScreen).clamp(1.0, _jumpStepMaxScreens);
  }

  bool jumpNearMessage(String messageId) {
    if (!scrollController.hasClients) return false;
    final listBox = listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || listBox.size.height <= 0) return false;
    final items = buildCombinedItems();
    final index = items.indexWhere((it) => messageIdOf(it) == messageId);
    if (index == -1) return false;

    final visible = _visibleItemRange(items, listBox);
    final position = scrollController.position;
    final step = position.viewportDimension * _jumpStepScreens(index, visible);
    final double next;
    if (visible.oldest == -1 || index < visible.oldest) {
      next = position.pixels + step;
    } else if (index > visible.newest) {
      next = position.pixels - step;
    } else {
      return false;
    }
    final clamped = next.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 0.5) return false;
    scrollController.jumpTo(clamped);
    return true;
  }

  void alignLoadedMessage(
    String messageId,
    double alignment,
    int attempt, {
    int frames = 0,
    int? epoch,
    VoidCallback? onSettled,
  }) {
    if (!isMounted() ||
        !scrollController.hasClients ||
        (epoch != null && epoch != gestureEpoch)) {
      onSettled?.call();
      return;
    }
    final listBox = listKey.currentContext?.findRenderObject();
    final box = keyForMessage(messageId).currentContext?.findRenderObject();
    if (listBox is! RenderBox || box is! RenderBox || !box.attached) {
      if (attempt >= _jumpStallLimit || frames >= _jumpFrameLimit) {
        onSettled?.call();
        return;
      }
      final moved = jumpNearMessage(messageId);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => alignLoadedMessage(
          messageId,
          alignment,
          moved ? 0 : attempt + 1,
          frames: frames + 1,
          epoch: epoch,
          onSettled: onSettled,
        ),
      );
      return;
    }

    final viewportHeight = listBox.size.height;
    final actualTop = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
    final desiredTop = alignment.clamp(0.0, 1.0) * viewportHeight;
    final delta = desiredTop - actualTop;
    final pos = scrollController.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );

    if (viewportHeight <= 0 ||
        delta.abs() <= 0.5 ||
        (target - pos.pixels).abs() <= 0.5 ||
        attempt >= _jumpStallLimit ||
        frames >= _jumpFrameLimit) {
      onSettled?.call();
      return;
    }

    scrollController.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => alignLoadedMessage(
        messageId,
        alignment,
        attempt + 1,
        frames: frames + 1,
        epoch: epoch,
        onSettled: onSettled,
      ),
    );
  }

  void jumpToMessage(String messageId, {String? fromId}) {
    final index = chatController.indexOfId(messageId);
    if (index == -1) {
      showNotification('Сообщение не загружено');
      return;
    }

    if (fromId != null) _pushReturnAnchor(fromId);

    final key = keyForMessage(messageId);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.4,
      );
    } else {
      unawaited(scrollToMessagePrecise(messageId, alignment: 0.4));
    }

    _highlightTimer?.cancel();
    highlightMessageId.value = messageId;
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!isMounted()) return;
      if (highlightMessageId.value == messageId) {
        highlightMessageId.value = null;
      }
    });
  }

  void scrollToBottom() {
    flushDeferredMessages();
    _returnStack.clear();
    newMessageCount.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final pos = scrollController.position;
      final runway = pos.viewportDimension;
      final teleport = pos.pixels > runway * _scrollDownTeleportFactor;
      if (teleport) {
        clearPinnedMessage();
        listEpoch++;
        jumpCacheExtent.value = jumpCacheExtentPx;
        bumpMessages();
        scrollController.jumpTo(runway);
      }
      unawaited(
        scrollController
            .animateTo(
              pos.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
            .whenComplete(() {
              if (!teleport) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (isMounted()) jumpCacheExtent.value = null;
              });
            }),
      );
    });
  }

  void updateScrollDownVisible() {
    if (!scrollController.hasClients) {
      _setScrollDownVisible(newMessageCount.value > 0);
      return;
    }
    final pos = scrollController.position;
    final atBottom = isNearBottom();
    if (_returnStack.isNotEmpty &&
        atBottom &&
        pos.userScrollDirection != ScrollDirection.idle) {
      _returnStack.clear();
    }
    if (atBottom && (newMessageCount.value > 0 || hasDeferredMessages())) {
      clearNewMessageCountSoon();
    }
    final reveal = math.min(
      _scrollDownRevealExtent,
      pos.viewportDimension * _scrollDownRevealFactor,
    );
    _setScrollDownVisible(
      pos.pixels >= reveal ||
          _returnStack.isNotEmpty ||
          newMessageCount.value > 0,
    );
  }

  void _setScrollDownVisible(bool show) {
    if (show == _scrollDownVisible) return;
    _scrollDownVisible = show;
    if (show) {
      scrollDownAnimController.forward();
    } else {
      scrollDownAnimController.reverse();
    }
  }

  void noteMissedMessage() {
    newMessageCount.value++;
    updateScrollDownVisible();
  }

  void clearNewMessageCountSoon() {
    if (_clearCountScheduled) return;
    _clearCountScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _clearCountScheduled = false;
      if (!isMounted() || !isNearBottom()) return;
      flushDeferredMessages();
      newMessageCount.value = 0;
      updateScrollDownVisible();
    });
  }

  void _pushReturnAnchor(String messageId) {
    if (!scrollController.hasClients) return;
    final listBox = listKey.currentContext?.findRenderObject();
    final dy = messageOffsetInList(messageId);
    final viewportH = listBox is RenderBox ? listBox.size.height : 0.0;
    final alignment = viewportH > 0 && dy != null
        ? (dy / viewportH).clamp(0.0, 1.0)
        : 0.5;
    _returnStack.add((
      id: messageId,
      pixels: scrollController.position.pixels,
      alignment: alignment.toDouble(),
    ));
    if (!_scrollDownVisible) {
      _scrollDownVisible = true;
      scrollDownAnimController.forward();
    }
  }

  void onScrollDownTap() {
    if (_returningToAnchor || navigatingToTarget) return;
    if (!scrollController.hasClients) {
      scrollToBottom();
      return;
    }
    final pixels = scrollController.position.pixels;
    while (_returnStack.isNotEmpty) {
      final anchor = _returnStack.removeLast();
      if (anchor.pixels < pixels && chatController.containsId(anchor.id)) {
        _returningToAnchor = true;
        unawaited(
          _returnToAnchor(anchor).whenComplete(() => _returningToAnchor = false),
        );
        return;
      }
    }
    scrollToBottom();
  }

  Future<void> _returnToAnchor(
    ({String id, double pixels, double alignment}) anchor,
  ) async {
    final pos = scrollController.position;
    final runway = pos.viewportDimension;
    final target = anchor.pixels.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final distance = (pos.pixels - target).abs();
    final far = distance > runway * _scrollDownTeleportFactor;

    if (!far) {
      await scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!isMounted()) return;
      await scrollToMessagePrecise(anchor.id, alignment: anchor.alignment);
      return;
    }

    jumpCacheExtent.value = jumpCacheExtentPx;
    if (target + runway < distance) {
      listEpoch++;
      bumpMessages();
      scrollController.jumpTo(target + runway);
      await scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!isMounted()) return;
    }
    await scrollToMessagePrecise(anchor.id, alignment: anchor.alignment);
    if (!isMounted()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) jumpCacheExtent.value = null;
    });
  }

  bool isNearBottom() {
    if (!scrollController.hasClients) return true;
    return scrollController.position.pixels <= 120;
  }
}
