import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/view/anchored_message_list.dart';

const double _viewport = 600;
const double _spacer = 40;
const EdgeInsets _padding = EdgeInsets.only(top: 30, bottom: 8);

double _heightOf(String id) => 40.0 + (id.hashCode % 7) * 23;

class _Harness {
  _Harness(this.tester, {int count = 400})
    : items = [for (var i = 0; i < count; i++) 'm$i'];

  final WidgetTester tester;
  final List<String> items;
  final GlobalKey listKey = GlobalKey();
  final ScrollController controller = ScrollController();
  final Map<String, GlobalKey> keys = {};
  String? anchorId;
  bool loadingNewer = false;

  GlobalKey keyFor(String id) => keys.putIfAbsent(id, GlobalKey.new);

  Future<void> pump() async {
    final anchor = anchorId == null ? null : items.indexOf(anchorId!);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: listKey,
            height: _viewport,
            child: AnchoredMessageList(
              controller: controller,
              cacheExtent: 250,
              padding: _padding,
              epoch: 0,
              itemCount: items.length,
              anchorIndex: anchor,
              loadingNewer: loadingNewer,
              bottomSpacer: const SizedBox(height: _spacer),
              itemBuilder: (context, index) {
                final id = items[index];
                return SizedBox(
                  key: keyFor(id),
                  height: _heightOf(id),
                  child: Text(id),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double? topOf(String id) {
    final listBox = listKey.currentContext?.findRenderObject();
    final box = keys[id]?.currentContext?.findRenderObject();
    if (listBox is! RenderBox || box is! RenderBox || !box.attached) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: listBox).dy;
  }

  Future<void> anchorAt(String id, double alignment) async {
    anchorId = id;
    controller.jumpTo(
      AnchoredMessageList.anchoredPixels(
        alignment: alignment,
        viewport: _viewport,
        anchorHeight: _heightOf(id),
      ),
    );
    await pump();
  }
}

void main() {
  testWidgets('without an anchor the newest message sits above the spacer', (
    tester,
  ) async {
    final h = _Harness(tester);
    addTearDown(h.controller.dispose);
    await h.pump();

    final newest = h.items.last;
    expect(h.controller.position.pixels, 0);
    expect(h.controller.position.minScrollExtent, 0);
    expect(
      h.topOf(newest)! + _heightOf(newest),
      closeTo(_viewport - _padding.bottom - _spacer, 0.01),
    );
  });

  testWidgets('anchoring puts a far message at the alignment in one jump', (
    tester,
  ) async {
    final h = _Harness(tester);
    addTearDown(h.controller.dispose);
    await h.pump();

    const target = 'm37';
    expect(h.topOf(target), isNull);

    await h.anchorAt(target, 0.3);

    expect(h.topOf(target), closeTo(0.3 * _viewport, 0.01));
    expect(h.topOf('m36'), lessThan(h.topOf(target)!));
    expect(h.topOf('m38'), greaterThan(h.topOf(target)!));
  });

  testWidgets('loading on either side leaves the anchored view in place', (
    tester,
  ) async {
    final h = _Harness(tester);
    addTearDown(h.controller.dispose);
    await h.pump();
    await h.anchorAt('m200', 0.4);
    final before = h.topOf('m200')!;

    h.items.insertAll(0, [for (var i = 0; i < 120; i++) 'old$i']);
    h.items.addAll([for (var i = 0; i < 120; i++) 'new$i']);
    h.loadingNewer = true;
    await h.pump();

    expect(h.topOf('m200'), closeTo(before, 0.01));
  });

  testWidgets('an anchor near the bottom settles at the real bottom', (
    tester,
  ) async {
    final h = _Harness(tester);
    addTearDown(h.controller.dispose);
    await h.pump();
    await h.anchorAt('m398', 0.2);

    final pos = h.controller.position;
    h.controller.jumpTo(
      h.controller.position.pixels.clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      ),
    );
    await tester.pump();

    final newest = h.items.last;
    expect(
      h.topOf(newest)! + _heightOf(newest),
      closeTo(_viewport - _padding.bottom - _spacer, 0.01),
    );
  });

  testWidgets('dropping the anchor at the bottom does not move the view', (
    tester,
  ) async {
    final h = _Harness(tester);
    addTearDown(h.controller.dispose);
    await h.pump();
    await h.anchorAt('m390', 0.3);

    for (var i = 0; i < 5; i++) {
      h.controller.jumpTo(h.controller.position.minScrollExtent);
      await tester.pump();
    }
    final newest = h.items.last;
    final before = h.topOf(newest)!;

    h.anchorId = null;
    h.controller.jumpTo(0);
    await h.pump();

    expect(
      before + _heightOf(newest),
      closeTo(_viewport - _padding.bottom - _spacer, 0.01),
    );
    expect(h.topOf(newest), closeTo(before, 0.01));
    expect(h.controller.position.minScrollExtent, 0);
  });
}
