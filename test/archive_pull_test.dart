import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/view/archive_pull.dart';

class _PullPhysics extends BouncingScrollPhysics {
  const _PullPhysics(this.pull, {super.parent});

  final ArchivePullController pull;

  bool get _claims => pull.claimsDrag(canPull: !pull.revealed);

  @override
  _PullPhysics applyTo(ScrollPhysics? ancestor) =>
      _PullPhysics(pull, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!_claims) return super.applyPhysicsToUserOffset(position, offset);
    final inRange = math.max(0.0, position.pixels - position.minScrollExtent);
    if (offset <= inRange) return offset;
    final pulled = math.max(0.0, position.minScrollExtent - position.pixels);
    return inRange + archivePullOffset(pulled, offset - inRange);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (!_claims &&
        value < position.minScrollExtent &&
        value < position.pixels) {
      return value - math.min(position.pixels, position.minScrollExtent);
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.pull, required this.scroll});

  final ArchivePullController pull;
  final ScrollController scroll;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onScroll);
    widget.pull.addListener(_onPull);
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    widget.pull.removeListener(_onPull);
    super.dispose();
  }

  void _onScroll() => widget.pull.onScroll(
    widget.scroll.offset,
    canPull: !widget.pull.revealed,
  );

  void _onPull() {
    if (!widget.pull.revealed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final position = widget.scroll.position;
      if (position.pixels > 0) {
        widget.scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuint,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Listener(
          onPointerDown: widget.pull.pointerDown,
          onPointerUp: widget.pull.pointerUp,
          onPointerCancel: widget.pull.pointerUp,
          child: CustomScrollView(
            controller: widget.scroll,
            physics: _PullPhysics(
              widget.pull,
              parent: const AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverArchivePull(
                controller: widget.pull,
                child: ArchivePullCell(
                  controller: widget.pull,
                  pullLabel: 'pull',
                  releaseLabel: 'release',
                  rowBuilder: (avatarVisible) => SizedBox(
                    key: const ValueKey('archive-row'),
                    height: kArchiveRowExtent,
                    child: Text(avatarVisible ? 'archive' : 'archive-morph'),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => SizedBox(height: 72, child: Text('chat $i')),
                  childCount: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<TestGesture> _pullDown(
  WidgetTester tester,
  double distance, {
  Duration hold = Duration.zero,
  double step = 6,
}) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(CustomScrollView)),
  );
  for (var moved = 0.0; moved < distance; moved += step) {
    await gesture.moveBy(Offset(0, step));
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (hold > Duration.zero) {
    await tester.runAsync(() => Future<void>.delayed(hold));
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

double _chatTop(WidgetTester tester, int index) =>
    tester.getTopLeft(find.text('chat $index')).dy;

void main() {
  test('сопротивление как в TG: 0.45 в начале, потолок ряд + 72', () {
    expect(archivePullOffset(0, 1), closeTo(0.45, 0.001));
    final ceiling = archivePullOffset(0, 100000);
    expect(ceiling, greaterThan(kArchiveRowExtent));
    expect(ceiling, lessThan(kArchiveRowExtent + 72));
  });

  test('архив подхватывает оттягивание, начатое историями', () async {
    final pull = ArchivePullController();
    pull.pointerDown(const PointerDownEvent(pointer: 1));
    pull.onScroll(-20, canPull: false);
    expect(pull.pulling, isFalse);

    pull.onScroll(-30, canPull: true);
    expect(pull.pulling, isTrue);
    expect(pull.pullBase, 30);

    pull.onScroll(-30 - kArchiveRowExtent * 0.5, canPull: true);
    await Future<void>.delayed(const Duration(milliseconds: 230));
    pull.onScroll(-30 - kArchiveRowExtent, canPull: true);
    pull.pointerUp(const PointerUpEvent(pointer: 1));
    expect(pull.revealed, isTrue);

    pull.onScroll(0, canPull: false);
    expect(pull.pullBase, 0);
    pull.dispose();
  });

  test(
    'потерянное отпускание лечится следующим касанием того же устройства',
    () {
      final pull = ArchivePullController();
      pull.pointerDown(const PointerDownEvent(pointer: 1));
      pull.pointerDown(const PointerDownEvent(pointer: 2));
      expect(pull.touching, isTrue);
      pull.pointerUp(const PointerUpEvent(pointer: 2));
      expect(pull.touching, isFalse);
      pull.dispose();
    },
  );

  test('движение мыши без кнопок снимает залипшее касание', () {
    final pull = ArchivePullController();
    pull.pointerDown(
      const PointerDownEvent(pointer: 1, kind: PointerDeviceKind.mouse),
    );
    pull.pointerHover(const PointerHoverEvent(kind: PointerDeviceKind.mouse));
    expect(pull.touching, isFalse);
    pull.dispose();
  });

  test('пальцы разных устройств и колесо считаются отдельно', () {
    final pull = ArchivePullController();
    pull.pointerDown(const PointerDownEvent(pointer: 1));
    pull.pointerDown(const PointerDownEvent(pointer: 2, device: 1));
    pull.pointerUp(const PointerUpEvent(pointer: 1));
    expect(pull.touching, isTrue);
    pull.pointerUp(const PointerUpEvent(pointer: 2, device: 1));
    expect(pull.touching, isFalse);
    pull.wheelStart();
    expect(pull.touching, isTrue);
    pull.pointerUp(const PointerUpEvent(pointer: 3));
    expect(pull.touching, isTrue);
    pull.wheelEnd();
    expect(pull.touching, isFalse);
    pull.dispose();
  });

  test('без пальца архив не перехватывает отскок', () {
    final pull = ArchivePullController();
    pull.onScroll(-40, canPull: true);
    expect(pull.pulling, isFalse);
    expect(pull.claimsDrag(canPull: true), isFalse);
    pull.dispose();
  });

  testWidgets('архив вытягивается из-под списка вместе с пальцем', (
    tester,
  ) async {
    final pull = ArchivePullController();
    final scroll = ScrollController();
    await tester.pumpWidget(_Harness(pull: pull, scroll: scroll));
    final top = _chatTop(tester, 0);

    final gesture = await _pullDown(tester, 60);
    final pulled = -scroll.offset;
    expect(pull.pulling, isTrue);
    expect(pulled, greaterThan(10));
    expect(pulled, lessThan(60 * 0.45 + 1));
    expect(_chatTop(tester, 0), closeTo(top + pulled, 0.5));
    expect(
      tester.getSize(find.byType(ArchivePullCell)).height,
      closeTo(pulled, 0.5),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pull.revealed, isFalse);
    expect(scroll.offset, 0);
    expect(_chatTop(tester, 0), top);
  });

  testWidgets('отпускание до порога не открывает архив', (tester) async {
    final pull = ArchivePullController();
    final scroll = ScrollController();
    await tester.pumpWidget(_Harness(pull: pull, scroll: scroll));

    final gesture = await _pullDown(
      tester,
      90,
      hold: const Duration(milliseconds: 260),
    );
    expect(pull.armed, isFalse);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(pull.revealed, isFalse);
    expect(scroll.offset, 0);
  });

  testWidgets('быстрый рывок за порог не открывает архив', (tester) async {
    final pull = ArchivePullController();
    final scroll = ScrollController();
    await tester.pumpWidget(_Harness(pull: pull, scroll: scroll));

    final gesture = await _pullDown(tester, 260, step: 26);
    expect(-scroll.offset, greaterThan(kArchiveRowExtent * 0.85));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(pull.revealed, isFalse);
    expect(scroll.offset, 0);
  });

  testWidgets('за порогом архив встаёт в список без скачка', (tester) async {
    final pull = ArchivePullController();
    final scroll = ScrollController();
    await tester.pumpWidget(_Harness(pull: pull, scroll: scroll));
    final top = _chatTop(tester, 0);

    final gesture = await _pullDown(
      tester,
      260,
      hold: const Duration(milliseconds: 260),
    );
    expect(pull.armed, isTrue);
    final before = _chatTop(tester, 0);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(pull.revealed, isTrue);
    expect((_chatTop(tester, 0) - before).abs(), lessThan(8));

    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(_chatTop(tester, 0), top + kArchiveRowExtent);
    expect(tester.getTopLeft(find.byKey(const ValueKey('archive-row'))).dy, 0);
    expect(find.text('archive'), findsOneWidget);
  });

  testWidgets('недотянутый до конца архив доезжает сам', (tester) async {
    final pull = ArchivePullController();
    final scroll = ScrollController();
    await tester.pumpWidget(_Harness(pull: pull, scroll: scroll));
    final top = _chatTop(tester, 0);

    final gesture = await _pullDown(
      tester,
      172,
      hold: const Duration(milliseconds: 260),
    );
    final pulled = -scroll.offset;
    expect(pulled, greaterThan(kArchiveRowExtent * 0.85));
    expect(pulled, lessThan(kArchiveRowExtent));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(pull.revealed, isTrue);
    expect(scroll.offset, 0);
    expect(_chatTop(tester, 0), top + kArchiveRowExtent);
  });

  testWidgets('прокрученный мимо архив снова прячется без сдвига списка', (
    tester,
  ) async {
    final pull = ArchivePullController();
    final scroll = ScrollController();
    await tester.pumpWidget(_Harness(pull: pull, scroll: scroll));

    final gesture = await _pullDown(
      tester,
      260,
      hold: const Duration(milliseconds: 260),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pull.revealed, isTrue);

    final expected = _chatTop(tester, 3) - 200;
    scroll.jumpTo(200);
    expect(pull.revealed, isFalse);

    await tester.pump();
    expect(scroll.offset, 200 - kArchiveRowExtent);
    expect(_chatTop(tester, 3), expected);
  });
}
