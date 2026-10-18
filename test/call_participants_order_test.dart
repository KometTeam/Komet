import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/calls/call_session.dart';
import 'package:komet/frontend/screens/calls/call_grid.dart';
import 'package:komet/frontend/screens/calls/call_participants_sheet.dart';

CallParticipant _p(
  int id, {
  bool self = false,
  int? handAt,
  List<String> roles = const [],
}) {
  final p = CallParticipant(
    id: id,
    isSelf: self,
    handRaised: handAt != null,
    roles: roles,
  );
  if (handAt != null) p.handRaisedAt = handAt;
  return p;
}

void main() {
  test('участники: я, затем руки по времени, затем админы', () {
    final sorted = sortCallParticipants([
      _p(1),
      _p(2, roles: const ['ADMIN']),
      _p(3, handAt: 200),
      _p(4, self: true),
      _p(5, handAt: 100),
      _p(6),
    ]);
    expect(sorted.map((p) => p.id), [4, 5, 3, 2, 1, 6]);
  });

  testWidgets('сетка раскладывает все плитки без переполнения', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallGrid<int>(
            ids: const [1, 2, 3, 4, 5],
            indicatorColor: Colors.white,
            tileBuilder: (context, id, size) =>
                ColoredBox(key: ValueKey('tile$id'), color: Colors.grey),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    for (var id = 1; id <= 5; id++) {
      expect(find.byKey(ValueKey('tile$id')), findsOneWidget);
    }
  });

  testWidgets('лишние участники уходят на следующую страницу', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallGrid<int>(
            ids: [for (var i = 0; i < 40; i++) i],
            minTileSide: 120,
            indicatorColor: Colors.white,
            tileBuilder: (context, id, size) =>
                ColoredBox(key: ValueKey('tile$id'), color: Colors.grey),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('tile0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile39')), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
  });
}
