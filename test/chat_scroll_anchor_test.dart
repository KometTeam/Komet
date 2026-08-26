import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/chat_controller.dart';
import 'package:komet/frontend/screens/chats/chat/retain_offset_physics.dart';

const double _itemHeight = 60;
const double _newestHeight = 84;
const double _viewportHeight = 300;

double? _offsetInList(GlobalKey listKey, GlobalKey itemKey) {
  final listBox = listKey.currentContext?.findRenderObject();
  final box = itemKey.currentContext?.findRenderObject();
  if (listBox is! RenderBox || box is! RenderBox || !box.attached) return null;
  return box.localToGlobal(Offset.zero, ancestor: listBox).dy;
}

class _Harness {
  _Harness(this.tester, {required this.physics});

  final WidgetTester tester;
  final ScrollPhysics? physics;
  final GlobalKey listKey = GlobalKey();
  final ScrollController controller = ScrollController();
  final List<String> items = [for (var i = 0; i < 200; i++) 'm$i'];
  final Map<String, GlobalKey> keys = {};

  GlobalKey keyFor(String id) => keys.putIfAbsent(id, GlobalKey.new);

  Future<void> pump() async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: listKey,
            height: _viewportHeight,
            child: CustomScrollView(
              controller: controller,
              reverse: true,
              physics: physics,
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == 0) return const SizedBox(height: 0);
                    final id = items[items.length - index];
                    return SizedBox(
                      key: keyFor(id),
                      height: id == 'newest' ? _newestHeight : _itemHeight,
                      child: Text(id),
                    );
                  }, childCount: items.length + 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String anchorId() => items.firstWhere((id) {
    final dy = _offsetInList(listKey, keyFor(id));
    return dy != null && dy >= 0 && dy <= _viewportHeight;
  });

  double dyOf(String id) => _offsetInList(listKey, keyFor(id))!;

  double? dyOrNull(String id) => _offsetInList(listKey, keyFor(id));

  double contentOffsetOf(String id) => dyOf(id) - controller.position.pixels;

  double alignmentOf(String id) => dyOf(id) / _viewportHeight;

  void insertAt(int index, int count) {
    items.insertAll(index, [for (var i = 0; i < count; i++) 'gap$index-$i']);
  }

  bool restore(String id, double before) {
    final dy = dyOrNull(id);
    if (dy == null) return false;
    final delta = before - (dy - controller.position.pixels);
    if (delta.abs() <= 0.5) return true;
    final pos = controller.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() <= 0.5) return true;
    controller.jumpTo(target);
    return true;
  }

  int visibleOldestIndex() {
    for (var i = 0; i < items.length; i++) {
      final dy = dyOrNull(items[i]);
      if (dy != null && dy + _itemHeight > 0 && dy < _viewportHeight) return i;
    }
    return -1;
  }

  bool jumpNear(String id) {
    final index = items.indexOf(id);
    final oldest = visibleOldestIndex();
    if (index == -1 || oldest == -1) return false;
    final perScreen = (_viewportHeight / _itemHeight).floor();
    final away = (oldest - index).abs();
    final screens = (away / perScreen).clamp(1.0, 4.0);
    final pos = controller.position;
    final step = pos.viewportDimension * screens;
    final next = index < oldest ? pos.pixels + step : pos.pixels - step;
    final clamped = next.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((clamped - pos.pixels).abs() < 0.5) return false;
    controller.jumpTo(clamped);
    return true;
  }

  Future<int> align(String id, double alignment) async {
    for (var frame = 0; frame < 40; frame++) {
      final dy = dyOrNull(id);
      if (dy == null) {
        if (!jumpNear(id)) return frame;
        await tester.pump();
        continue;
      }
      final delta = alignment * _viewportHeight - dy;
      if (delta.abs() <= 0.5) return frame;
      final pos = controller.position;
      final target = (pos.pixels + delta).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if ((target - pos.pixels).abs() <= 0.5) return frame;
      controller.jumpTo(target);
      await tester.pump();
    }
    return -1;
  }
}

void main() {
  testWidgets('appending to a reversed list drags the view toward the newest '
      'message', (tester) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final beforeDy = h.dyOf(anchor);

    h.items.add('newest');
    await h.pump();

    expect(h.dyOf(anchor), lessThan(beforeDy - 1));
    expect(h.controller.position.pixels, 600);
  });

  testWidgets('RetainOffsetScrollPhysics holds the view in place when a '
      'message is appended', (tester) async {
    var retainOnce = false;
    final h = _Harness(
      tester,
      physics: RetainOffsetScrollPhysics(
        retain: () {
          if (!retainOnce) return false;
          retainOnce = false;
          return true;
        },
      ),
    );
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final beforeDy = h.dyOf(anchor);

    retainOnce = true;
    h.items.add('newest');
    await h.pump();

    expect(h.dyOf(anchor), closeTo(beforeDy, 0.5));
    expect(h.controller.position.pixels, greaterThan(600));
  });

  testWidgets('RetainOffsetScrollPhysics stays inert while the flag is unset', (
    tester,
  ) async {
    final h = _Harness(
      tester,
      physics: RetainOffsetScrollPhysics(retain: () => false),
    );
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final beforeDy = h.dyOf(anchor);

    h.items.add('newest');
    await h.pump();

    expect(h.dyOf(anchor), lessThan(beforeDy - 1));
    expect(h.controller.position.pixels, 600);
  });

  testWidgets('вставка старее вьюпорта не двигает его вообще', (tester) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final beforeDy = h.dyOf(anchor);

    h.insertAt(10, 60);
    await h.pump();

    expect(h.dyOf(anchor), closeTo(beforeDy, 0.5));
    expect(h.controller.position.pixels, 600);
  });

  testWidgets('заполнение дыры не двигает то, что новее её', (tester) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final before = h.contentOffsetOf(anchor);
    final beforeDy = h.dyOf(anchor);

    h.insertAt(10, 5);
    await h.pump();
    h.restore(anchor, before);
    await tester.pump();

    expect(h.dyOf(anchor), closeTo(beforeDy, 0.5));
    expect(h.controller.position.pixels, 600);
  });

  testWidgets('заполнение дыры удерживает то, что старее её', (tester) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final before = h.contentOffsetOf(anchor);
    final beforeDy = h.dyOf(anchor);

    h.insertAt(195, 5);
    await h.pump();
    expect(h.dyOf(anchor), lessThan(beforeDy - 1));

    h.restore(anchor, before);
    await tester.pump();

    expect(h.dyOf(anchor), closeTo(beforeDy, 0.5));
    expect(h.controller.position.pixels, 600 + 5 * _itemHeight);
  });

  testWidgets('скролл пользователя во время дозагрузки не отменяется', (
    tester,
  ) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final before = h.contentOffsetOf(anchor);
    final beforeDy = h.dyOf(anchor);

    h.insertAt(195, 5);
    await h.pump();
    h.controller.jumpTo(h.controller.position.pixels + 120);
    await tester.pump();

    h.restore(anchor, before);
    await tester.pump();

    expect(h.dyOf(anchor), closeTo(beforeDy + 120, 0.5));
    expect(h.controller.position.pixels, 600 + 120 + 5 * _itemHeight);
  });

  testWidgets('большой блок уносит якорь за пределы отрисованного окна', (
    tester,
  ) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final before = h.contentOffsetOf(anchor);

    h.insertAt(195, 60);
    await h.pump();

    expect(h.dyOrNull(anchor), isNull);
    expect(h.restore(anchor, before), isFalse);
    expect(h.controller.position.pixels, 600);
  });

  testWidgets('после большого блока выравнивание возвращает якорь на место', (
    tester,
  ) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final before = h.contentOffsetOf(anchor);
    final beforeDy = h.dyOf(anchor);
    final alignment = h.alignmentOf(anchor);

    h.insertAt(195, 60);
    await h.pump();
    expect(h.restore(anchor, before), isFalse);

    final frames = await h.align(anchor, alignment);

    expect(frames, greaterThanOrEqualTo(0));
    expect(frames, lessThan(10));
    expect(h.dyOf(anchor), closeTo(beforeDy, 0.5));
    expect(h.controller.position.pixels, 600 + 60 * _itemHeight);
  });

  group('дыру можно заполнять только с новой стороны', () {
    final gap = HistoryGap(edgeId: 'e', edgeTime: 1100, tailTime: 9000);

    test('пользователь в хвосте — вставка ляжет выше вьюпорта', () {
      expect(ChatController.gapFillLeavesViewportInPlace(gap, 9000), isTrue);
      expect(ChatController.gapFillLeavesViewportInPlace(gap, 9050), isTrue);
    });

    test('пользователь у закрепа — вставка утащила бы вьюпорт', () {
      expect(ChatController.gapFillLeavesViewportInPlace(gap, 1050), isFalse);
      expect(ChatController.gapFillLeavesViewportInPlace(gap, 8999), isFalse);
    });

    test('без отрисованных сообщений заполнять нечего', () {
      expect(ChatController.gapFillLeavesViewportInPlace(gap, null), isFalse);
    });
  });
}
