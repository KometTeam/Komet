import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final List<String> items = [for (var i = 0; i < 40; i++) 'm$i'];
  late final Map<String, GlobalKey> keys = {
    for (final id in items) id: GlobalKey(),
    'newest': GlobalKey(),
  };

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
                      key: keys[id],
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
    final dy = _offsetInList(listKey, keys[id]!);
    return dy != null && dy >= 0 && dy <= _viewportHeight;
  });

  double dyOf(String id) => _offsetInList(listKey, keys[id]!)!;
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
}
