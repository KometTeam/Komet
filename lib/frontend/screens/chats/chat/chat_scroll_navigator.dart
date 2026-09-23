import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'chat_controller.dart';
import 'read_marker_gate.dart';
import 'view/anchored_message_list.dart';

typedef ReturnPoint = ({String id, int time, double alignment});

class ChatScrollNavigator {
  ChatScrollNavigator({
    required this.scrollController,
    required this.chatController,
    required this.shimmerController,
    required this.scrollDownAnimController,
    required this.readMarker,
    required this.listKey,
    required this.existingKeyFor,
    required this.loadMessageWindow,
    required this.resetToLatest,
    required this.flushDeferredMessages,
    required this.isDeferred,
    required this.hasDeferredMessages,
    required this.bumpMessages,
    required this.isMounted,
    required this.notifyState,
    required this.showNotification,
    required this.initialMessageIdOf,
    required this.initialMessageTimeOf,
    required this.onNavigated,
  });

  final ScrollController scrollController;
  final ChatController chatController;
  final AnimationController shimmerController;
  final AnimationController scrollDownAnimController;
  final ReadMarkerGate readMarker;
  final GlobalKey listKey;
  final GlobalKey? Function(String messageId) existingKeyFor;
  final Future<void> Function(
    String messageId,
    int targetTime,
    bool Function() stillWanted,
  )
  loadMessageWindow;
  final Future<void> Function() resetToLatest;
  final VoidCallback flushDeferredMessages;
  final bool Function(String messageId) isDeferred;
  final bool Function() hasDeferredMessages;
  final VoidCallback bumpMessages;
  final bool Function() isMounted;
  final void Function(VoidCallback fn) notifyState;
  final void Function(String message) showNotification;
  final String? Function() initialMessageIdOf;
  final int? Function() initialMessageTimeOf;
  final VoidCallback onNavigated;

  static const double jumpCacheExtentPx = 800.0;
  static const double defaultAlignment = 0.32;
  static const double _visibleMargin = 0.15;
  static const double _nearBottomExtent = 120.0;
  static const int _refineFrames = 4;
  static const int _bottomSettleFrames = 6;
  static const double _scrollDownTeleportFactor = 2.0;
  static const double _scrollDownRevealExtent = 72.0 * 30;
  static const double _scrollDownRevealFactor = 0.6;
  static const Duration _routeSettleDelay = Duration(milliseconds: 340);
  static const Duration _highlightDuration = Duration(milliseconds: 1800);
  static const Duration _nearScrollDuration = Duration(milliseconds: 280);

  String? anchorId;
  int? _anchorTime;
  int listEpoch = 0;

  bool navigatingToTarget = false;
  bool initialTargetHandled = false;
  int _navToken = 0;
  int? _loadingToken;
  int _busy = 0;
  Timer? _settleTimer;

  final ValueNotifier<double?> jumpCacheExtent = ValueNotifier<double?>(null);
  final ValueNotifier<String?> highlightMessageId = ValueNotifier(null);
  Timer? _highlightTimer;

  int gestureEpoch = 0;

  final List<ReturnPoint> _returnStack = [];

  bool _scrollDownVisible = false;
  final ValueNotifier<int> newMessageCount = ValueNotifier(0);
  bool _clearCountScheduled = false;

  bool get busy => _busy > 0;

  void dispose() {
    _settleTimer?.cancel();
    _highlightTimer?.cancel();
    jumpCacheExtent.dispose();
    highlightMessageId.dispose();
    newMessageCount.dispose();
  }

  void bumpGestureEpoch() => gestureEpoch++;

  List<Object>? _indexedItems;
  String? _indexedAnchor;
  int? _anchorIndex;

  int? anchorIndexIn(List<Object> items, String? Function(Object) idOf) {
    if (identical(items, _indexedItems) && _indexedAnchor == anchorId) {
      return _anchorIndex;
    }
    _indexedItems = items;
    _indexedAnchor = anchorId;
    return _anchorIndex = _findAnchor(items, idOf);
  }

  int? _findAnchor(List<Object> items, String? Function(Object) idOf) {
    final id = anchorId;
    if (id == null) return null;
    for (var i = 0; i < items.length; i++) {
      if (idOf(items[i]) == id) return i;
    }
    final time = _anchorTime;
    if (time == null) return null;
    for (var i = 0; i < items.length; i++) {
      final itemId = idOf(items[i]);
      if (itemId == null) continue;
      final message = chatController.byId(itemId);
      if (message != null && message.time >= time) return i;
    }
    return null;
  }


  void maybeRunInitialTarget() {
    final id = initialMessageIdOf();
    if (initialTargetHandled || id == null) return;
    initialTargetHandled = true;
    navigatingToTarget = true;
    if (!shimmerController.isAnimating) shimmerController.repeat();
    _afterFrame((_) {
      if (!isMounted()) return;
      notifyState(() {});
      unawaited(goTo(id, time: initialMessageTimeOf() ?? 0));
    });
  }

  void requestGoToMessage(String id, int time) {
    if (!isMounted()) return;
    final token = ++_navToken;
    _settleTimer?.cancel();
    _startLoading(token);
    _settleTimer = Timer(_routeSettleDelay, () {
      if (!isMounted()) return;
      if (token == _navToken) {
        unawaited(goTo(id, time: time));
      } else {
        _finishLoading(token);
      }
    });
  }

  Future<void> goTo(
    String id, {
    int time = 0,
    String? fromId,
    double alignment = defaultAlignment,
    bool highlight = true,
  }) async {
    if (!isMounted()) return;
    final token = ++_navToken;
    _settleTimer?.cancel();
    if (fromId != null && fromId != id) _pushReturnPoint(fromId);

    if (navigatingToTarget) _loadingToken = token;
    _busy++;
    readMarker.hold();
    try {
      if (isDeferred(id)) flushDeferredMessages();
      if (!chatController.containsId(id)) {
        _startLoading(token);
        await WidgetsBinding.instance.endOfFrame;
        if (!_current(token)) return;
        await loadMessageWindow(id, time, () => _current(token));
        if (!_current(token)) return;
        if (!chatController.containsId(id)) {
          showNotification('Сообщение не загружено');
          return;
        }
      }

      if (!_isComfortablyVisible(id)) {
        if (!navigatingToTarget && _laidOutBox(id) != null) {
          await _scrollNear(id, alignment, token);
        } else {
          await _anchorAt(id, alignment, token);
        }
      }
      if (!_current(token)) return;
      if (highlight) _highlight(id);
    } finally {
      _busy--;
      readMarker.release();
      _finishLoading(token);
      if (isMounted() && !busy) onNavigated();
    }
  }

  Future<void> positionAt(String id, double alignment) async {
    if (!isMounted() || !chatController.containsId(id)) return;
    final token = ++_navToken;
    _busy++;
    readMarker.hold();
    try {
      await _anchorAt(id, alignment, token);
    } finally {
      _busy--;
      readMarker.release();
    }
  }

  Future<void> keepInPlace(String id, double alignment) async {
    if (!isMounted() || busy || !chatController.containsId(id)) return;
    final token = _navToken;
    _busy++;
    readMarker.hold();
    try {
      final epoch = gestureEpoch;
      if (_laidOutBox(id) == null) {
        await _anchorAt(id, alignment, token);
      } else {
        await _refine(id, alignment, token, epoch);
      }
    } finally {
      _busy--;
      readMarker.release();
    }
  }

  bool _current(int token) => isMounted() && token == _navToken;

  static void _afterFrame(FrameCallback callback) {
    WidgetsBinding.instance
      ..addPostFrameCallback(callback)
      ..ensureVisualUpdate();
  }

  void _startLoading(int token) {
    _loadingToken = token;
    if (!isMounted() || navigatingToTarget) return;
    notifyState(() => navigatingToTarget = true);
    if (!shimmerController.isAnimating) shimmerController.repeat();
  }

  void _finishLoading(int token) {
    if (_loadingToken != token) return;
    _loadingToken = null;
    if (!isMounted() || !navigatingToTarget) return;
    notifyState(() => navigatingToTarget = false);
    if (shimmerController.isAnimating) shimmerController.stop();
  }

  void _highlight(String id) {
    _highlightTimer?.cancel();
    highlightMessageId.value = id;
    _highlightTimer = Timer(_highlightDuration, () {
      if (isMounted() && highlightMessageId.value == id) {
        highlightMessageId.value = null;
      }
    });
  }

  RenderBox? get _listBox {
    final box = listKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize && box.size.height > 0 ? box : null;
  }

  RenderBox? _laidOutBox(String id) {
    final box = existingKeyFor(id)?.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  double? _topOf(String id) {
    final list = _listBox;
    final box = _laidOutBox(id);
    if (list == null || box == null) return null;
    return box.localToGlobal(Offset.zero, ancestor: list).dy;
  }

  bool _isComfortablyVisible(String id) {
    final list = _listBox;
    final box = _laidOutBox(id);
    final top = _topOf(id);
    if (list == null || box == null || top == null) return false;
    final height = list.size.height;
    final margin = height * _visibleMargin;
    return top >= margin && top + box.size.height <= height - margin;
  }

  Future<void> _anchorAt(String id, double alignment, int token) async {
    if (!scrollController.hasClients) return;
    final viewport = scrollController.position.viewportDimension;
    final height = _laidOutBox(id)?.size.height ?? 0;
    anchorId = id;
    _anchorTime = chatController.byId(id)?.time;
    bumpMessages();
    scrollController.jumpTo(
      AnchoredMessageList.anchoredPixels(
        alignment: alignment,
        viewport: viewport,
        anchorHeight: height,
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    await _refine(id, alignment, token, gestureEpoch);
  }

  Future<void> _scrollNear(String id, double alignment, int token) async {
    final top = _topOf(id);
    final list = _listBox;
    if (top == null || list == null || !scrollController.hasClients) {
      await _anchorAt(id, alignment, token);
      return;
    }
    final epoch = gestureEpoch;
    final pos = scrollController.position;
    final target = (pos.pixels + alignment * list.size.height - top).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    await scrollController.animateTo(
      target,
      duration: _nearScrollDuration,
      curve: Curves.easeOutCubic,
    );
    if (!_current(token) || epoch != gestureEpoch) return;
    await _refine(id, alignment, token, epoch);
  }

  Future<void> _refine(
    String id,
    double alignment,
    int token,
    int epoch,
  ) async {
    for (var frame = 0; frame < _refineFrames; frame++) {
      if (!_current(token) || epoch != gestureEpoch) return;
      if (!scrollController.hasClients) return;
      final list = _listBox;
      final top = _topOf(id);
      if (list == null || top == null) return;
      final pos = scrollController.position;
      final target = (pos.pixels + alignment * list.size.height - top).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if ((target - pos.pixels).abs() <= 0.5) return;
      scrollController.jumpTo(target);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void scrollToBottom() {
    flushDeferredMessages();
    _returnStack.clear();
    newMessageCount.value = 0;
    if (chatController.hasNewer) {
      unawaited(_returnToLatest());
      return;
    }
    _afterFrame((_) {
      if (!isMounted() || !scrollController.hasClients) return;
      final pos = scrollController.position;
      final runway = pos.viewportDimension;
      final distance = pos.pixels - pos.minScrollExtent;
      if (distance > runway * _scrollDownTeleportFactor) {
        _teleportToBottom(runway);
        return;
      }
      unawaited(_slideToBottom());
    });
  }

  void _teleportToBottom(double runway) {
    final token = ++_navToken;
    anchorId = null;
    _anchorTime = null;
    listEpoch++;
    jumpCacheExtent.value = jumpCacheExtentPx;
    bumpMessages();
    scrollController.jumpTo(runway);
    unawaited(
      scrollController
          .animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
          .whenComplete(() {
            _afterFrame((_) {
              if (isMounted()) jumpCacheExtent.value = null;
            });
            if (token == _navToken) unawaited(_settleAtBottom(token));
          }),
    );
  }

  Future<void> _slideToBottom() async {
    final token = ++_navToken;
    await scrollController.animateTo(
      scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    if (!_current(token)) return;
    await _settleAtBottom(token);
  }

  Future<void> _settleAtBottom(int token) async {
    for (var frame = 0; frame < _bottomSettleFrames; frame++) {
      if (!_current(token) || !scrollController.hasClients) return;
      final pos = scrollController.position;
      if ((pos.pixels - pos.minScrollExtent).abs() <= 0.5) break;
      scrollController.jumpTo(pos.minScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!_current(token) || anchorId == null) return;
    final pos = scrollController.position;
    if ((pos.pixels - pos.minScrollExtent).abs() > 0.5) return;
    anchorId = null;
    _anchorTime = null;
    bumpMessages();
    scrollController.jumpTo(0);
  }

  Future<void> _returnToLatest() async {
    final token = ++_navToken;
    _busy++;
    _startLoading(token);
    try {
      await resetToLatest();
      if (!_current(token)) return;
      anchorId = null;
      _anchorTime = null;
      listEpoch++;
      bumpMessages();
      if (scrollController.hasClients) scrollController.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
    } finally {
      _busy--;
      _finishLoading(token);
      if (isMounted() && !busy) onNavigated();
    }
  }

  bool isNearBottom() {
    if (chatController.hasNewer) return false;
    if (!scrollController.hasClients) return true;
    final pos = scrollController.position;
    return pos.pixels - pos.minScrollExtent <= _nearBottomExtent;
  }

  double distanceFromBottom() {
    if (!scrollController.hasClients) return 0;
    final pos = scrollController.position;
    return pos.pixels - pos.minScrollExtent;
  }

  void updateScrollDownVisible() {
    if (!scrollController.hasClients) {
      _setScrollDownVisible(
        newMessageCount.value > 0 || chatController.hasNewer,
      );
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
      distanceFromBottom() >= reveal ||
          chatController.hasNewer ||
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
    _afterFrame((_) {
      _clearCountScheduled = false;
      if (!isMounted() || !isNearBottom()) return;
      flushDeferredMessages();
      newMessageCount.value = 0;
      updateScrollDownVisible();
    });
  }

  void _pushReturnPoint(String messageId) {
    final message = chatController.byId(messageId);
    if (message == null) return;
    final list = _listBox;
    final top = _topOf(messageId);
    final alignment = list != null && top != null
        ? (top / list.size.height).clamp(0.0, 1.0)
        : defaultAlignment;
    _returnStack.add((
      id: messageId,
      time: message.time,
      alignment: alignment.toDouble(),
    ));
    _setScrollDownVisible(true);
  }

  int? _newestVisibleTime() {
    final list = _listBox;
    if (list == null) return null;
    final height = list.size.height;
    final messages = chatController.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final top = _topOf(messages[i].id);
      if (top == null) continue;
      final box = _laidOutBox(messages[i].id)!;
      if (top < height && top + box.size.height > 0) return messages[i].time;
    }
    return null;
  }

  void onScrollDownTap() {
    if (busy) return;
    final newestVisible = _newestVisibleTime();
    while (_returnStack.isNotEmpty) {
      final point = _returnStack.removeLast();
      if (newestVisible == null || point.time > newestVisible) {
        unawaited(
          goTo(
            point.id,
            time: point.time,
            alignment: point.alignment,
            highlight: false,
          ),
        );
        return;
      }
    }
    scrollToBottom();
  }
}
