import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  int deferredTail = 0;

  int get visibleCount => items.length - deferredTail;

  GlobalKey keyFor(String id) => keys.putIfAbsent(id, GlobalKey.new);

  Future<void> pump() async {
    final visible = visibleCount;
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
                    final id = items[visible - index];
                    return SizedBox(
                      key: keyFor(id),
                      height: id == 'newest' ? _newestHeight : _itemHeight,
                      child: Text(id),
                    );
                  }, childCount: visible + 1),
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

  testWidgets('отложенный хвост не двигает вьюпорт вообще', (tester) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.controller.jumpTo(600);
    await tester.pump();

    final anchor = h.anchorId();
    final beforeDy = h.dyOf(anchor);

    h.items.add('newest');
    h.deferredTail = 1;
    await h.pump();

    expect(h.dyOf(anchor), beforeDy);
    expect(h.controller.position.pixels, 600);
    expect(find.text('newest'), findsNothing);
  });

  testWidgets('сброс отложенного хвоста показывает новое сообщение', (
    tester,
  ) async {
    final h = _Harness(tester, physics: null);
    addTearDown(h.controller.dispose);

    await h.pump();
    h.items.add('newest');
    h.deferredTail = 1;
    await h.pump();

    expect(find.text('newest'), findsNothing);

    h.deferredTail = 0;
    await h.pump();

    expect(find.text('newest'), findsOneWidget);
    expect(h.controller.position.pixels, 0);
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

  testWidgets('слияние новых сообщений удерживает якорь на месте', (
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

    h.items.addAll([for (var i = 0; i < 3; i++) 'merged$i']);
    await h.pump();
    expect(h.dyOf(anchor), lessThan(beforeDy - 1));

    expect(h.restore(anchor, before), isTrue);
    await tester.pump();

    expect(h.dyOf(anchor), closeTo(beforeDy, 0.5));
    expect(h.controller.position.pixels, 600 + 3 * _itemHeight);
  });
}
