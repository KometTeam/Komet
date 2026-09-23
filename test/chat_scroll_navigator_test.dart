import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/chat_controller.dart';
import 'package:komet/frontend/screens/chats/chat/chat_scroll_navigator.dart';
import 'package:komet/frontend/screens/chats/chat/read_marker_gate.dart';
import 'package:komet/frontend/screens/chats/chat/view/anchored_message_list.dart';

const double _viewport = 500;

CachedMessage _message(int n) => CachedMessage(
  id: 'm$n',
  accountId: 1,
  chatId: 2,
  senderId: 3,
  time: 1000 + n * 10,
  status: 'sent',
);

double _heightOf(String id) => 48.0 + (id.hashCode % 5) * 31;

class _Harness {
  _Harness(this.tester, {required List<int> loaded, List<int>? all})
    : all = all ?? loaded {
    controller.messages = [for (final n in loaded) _message(n)];
  }

  final WidgetTester tester;
  final List<int> all;
  final ChatController controller = ChatController();
  final ScrollController scroll = ScrollController();
  final GlobalKey listKey = GlobalKey();
  final Map<String, GlobalKey> keys = {};
  final List<String> notifications = [];
  late final AnimationController shimmer;
  late final AnimationController scrollDown;
  late final ChatScrollNavigator nav;
  Completer<void>? windowGate;
  int windowLoads = 0;

  GlobalKey keyFor(String id) => keys.putIfAbsent(id, GlobalKey.new);

  Future<void> mount() async {
    shimmer = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
    scrollDown = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 1),
    );
    nav = ChatScrollNavigator(
      scrollController: scroll,
      chatController: controller,
      shimmerController: shimmer,
      scrollDownAnimController: scrollDown,
      readMarker: ReadMarkerGate(onFlush: () {}),
      listKey: listKey,
      existingKeyFor: (id) => keys[id],
      loadMessageWindow: _loadWindow,
      resetToLatest: _resetToLatest,
      flushDeferredMessages: () {},
      isDeferred: (_) => false,
      hasDeferredMessages: () => false,
      bumpMessages: controller.bump,
      isMounted: () => true,
      notifyState: (fn) {
        fn();
        controller.bump();
      },
      showNotification: notifications.add,
      initialMessageIdOf: () => null,
      initialMessageTimeOf: () => null,
      onNavigated: () {},
    );
    addTearDown(() {
      controller.dispose();
      nav.dispose();
      shimmer.dispose();
      scrollDown.dispose();
      scroll.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: listKey,
            height: _viewport,
            child: ValueListenableBuilder<int>(
              valueListenable: controller.messagesRev,
              builder: (context, _, _) {
                final ids = [for (final m in controller.messages) m.id];
                return AnchoredMessageList(
                  controller: scroll,
                  cacheExtent: 250,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  epoch: nav.listEpoch,
                  itemCount: ids.length,
                  anchorIndex: nav.anchorIndexIn(ids, (item) => item as String),
                  bottomSpacer: const SizedBox(height: 60),
                  itemBuilder: (context, index) => SizedBox(
                    key: keyFor(ids[index]),
                    height: _heightOf(ids[index]),
                    child: Text(ids[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadWindow(
    String id,
    int time,
    bool Function() stillWanted,
  ) async {
    windowLoads++;
    final gate = windowGate;
    if (gate != null) await gate.future;
    if (!stillWanted()) return;
    final target = int.parse(id.substring(1));
    if (!all.contains(target)) return;
    final window = [
      for (final n in all)
        if (n >= target - 40 && n <= target + 20) n,
    ];
    controller.messages = [for (final n in window) _message(n)];
    controller.hasNewer = window.last < all.last;
    controller.bump();
  }

  Future<void> _resetToLatest() async {
    controller.messages = [
      for (final n in all.sublist(all.length - 50)) _message(n),
    ];
    controller.hasNewer = false;
    controller.bump();
  }

  double? topOf(String id) {
    final list = listKey.currentContext?.findRenderObject();
    final box = keys[id]?.currentContext?.findRenderObject();
    if (list is! RenderBox || box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: list).dy;
  }

  Future<void> run(Future<void> Function() action) async {
    final done = action();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await done;
  }

  Future<void> drainTimers() => tester.pump(const Duration(seconds: 3));
}

List<int> _range(int from, int to) => [for (var n = from; n < to; n++) n];

void main() {
  testWidgets('a loaded message far above lands at the alignment', (
    tester,
  ) async {
    final h = _Harness(tester, loaded: _range(0, 300));
    await h.mount();
    expect(h.topOf('m40'), isNull);

    await h.run(() => h.nav.goTo('m40'));

    expect(
      h.topOf('m40'),
      closeTo(ChatScrollNavigator.defaultAlignment * _viewport, 0.5),
    );
    expect(h.nav.highlightMessageId.value, 'm40');
    expect(h.nav.navigatingToTarget, isFalse);
    expect(h.nav.busy, isFalse);

    await h.drainTimers();
  });

  testWidgets('a message outside the loaded range loads a window around it', (
    tester,
  ) async {
    final h = _Harness(tester, loaded: _range(950, 1000), all: _range(0, 1000));
    await h.mount();

    await h.run(() => h.nav.goTo('m300', time: 4000));

    expect(h.windowLoads, 1);
    expect(h.controller.hasNewer, isTrue);
    expect(
      h.topOf('m300'),
      closeTo(ChatScrollNavigator.defaultAlignment * _viewport, 0.5),
    );
    expect(h.nav.navigatingToTarget, isFalse);
    expect(h.notifications, isEmpty);

    await h.drainTimers();
  });

  testWidgets('scrolling down from a detached window returns to the latest', (
    tester,
  ) async {
    final h = _Harness(tester, loaded: _range(950, 1000), all: _range(0, 1000));
    await h.mount();
    await h.run(() => h.nav.goTo('m300', time: 4000));

    h.nav.scrollToBottom();
    await h.run(() async {});

    expect(h.controller.hasNewer, isFalse);
    expect(h.nav.anchorId, isNull);
    expect(h.scroll.position.pixels, 0);
    expect(h.topOf('m999'), isNotNull);
    expect(h.nav.navigatingToTarget, isFalse);

    await h.drainTimers();
  });

  testWidgets('scrolling down from an anchor drops it at the bottom', (
    tester,
  ) async {
    final h = _Harness(tester, loaded: _range(0, 300));
    await h.mount();
    await h.run(() => h.nav.goTo('m280'));
    expect(h.nav.anchorId, 'm280');

    h.nav.scrollToBottom();
    await h.run(() async {});

    expect(h.nav.anchorId, isNull);
    expect(h.scroll.position.pixels, 0);
    expect(h.topOf('m299'), isNotNull);

    await h.drainTimers();
  });

  testWidgets('a visible message is only highlighted', (tester) async {
    final h = _Harness(tester, loaded: _range(0, 300));
    await h.mount();
    await h.run(() => h.nav.goTo('m40'));
    final pixels = h.scroll.position.pixels;
    final visible = h.topOf('m41')!;

    await h.run(() => h.nav.goTo('m41'));

    expect(h.scroll.position.pixels, pixels);
    expect(h.topOf('m41'), visible);
    expect(h.nav.highlightMessageId.value, 'm41');

    await h.drainTimers();
  });

  testWidgets('a newer jump wins over one still loading', (tester) async {
    final h = _Harness(tester, loaded: _range(900, 1000), all: _range(0, 1000));
    await h.mount();
    h.windowGate = Completer<void>();

    final slow = h.nav.goTo('m100', time: 2000);
    await tester.pump();
    expect(h.nav.navigatingToTarget, isTrue);

    await h.run(() => h.nav.goTo('m905'));
    expect(h.nav.highlightMessageId.value, 'm905');
    h.windowGate!.complete();
    await h.run(() => slow);

    expect(
      h.topOf('m905'),
      closeTo(ChatScrollNavigator.defaultAlignment * _viewport, 0.5),
    );
    expect(h.nav.navigatingToTarget, isFalse);
    expect(h.windowLoads, 1);
    expect(h.controller.containsId('m100'), isFalse);

    await h.drainTimers();
  });

  testWidgets('a reply jump can be walked back with the down button', (
    tester,
  ) async {
    final h = _Harness(tester, loaded: _range(0, 300));
    await h.mount();

    await h.run(() => h.nav.goTo('m60', fromId: 'm295'));
    expect(h.topOf('m295'), isNull);

    h.nav.onScrollDownTap();
    await h.run(() async {});

    expect(h.topOf('m295'), isNotNull);
    expect(h.nav.anchorId, 'm295');

    await h.drainTimers();
  });

  testWidgets('a missing message reports instead of scrolling', (tester) async {
    final h = _Harness(tester, loaded: _range(0, 300));
    await h.mount();

    await h.run(() => h.nav.goTo('m5000', time: 99999));

    expect(h.notifications, ['Сообщение не загружено']);
    expect(h.nav.navigatingToTarget, isFalse);
    expect(h.scroll.position.pixels, 0);

    await h.drainTimers();
  });
}
