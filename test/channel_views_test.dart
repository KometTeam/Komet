import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/channel_views.dart';

void main() {
  late List<List<String>> requests;
  late List<String> counted;
  late DateTime now;
  late ChannelViews views;

  setUp(() {
    requests = [];
    counted = [];
    now = DateTime(2026, 1, 1, 12);
    views = ChannelViews((ids, {required count}) async {
      requests.add(ids);
      if (count) counted.addAll(ids);
      return {for (final id in ids) id: int.parse(id) % 1000};
    }, clock: () => now);
  });

  tearDown(() => views.dispose());

  testWidgets('posts seen together are asked for in one request', (
    tester,
  ) async {
    final first = views.of('900801');
    final second = views.of('900802');
    views.of('900802');

    expect(requests, isEmpty);
    await tester.pump(ChannelViews.batchDelay);

    expect(requests, [
      ['900801', '900802'],
    ]);
    expect(first.value, 801);
    expect(second.value, 802);
  });

  testWidgets('unsent posts are not asked for', (tester) async {
    final pending = views.of('temp_1_1700000000000');
    await tester.pump(ChannelViews.batchDelay);

    expect(requests, isEmpty);
    expect(pending.value, isNull);
  });

  testWidgets('views are refreshed only after a minute', (tester) async {
    views.of('900801');
    await tester.pump(ChannelViews.batchDelay);

    views.of('900801');
    await tester.pump(ChannelViews.batchDelay);
    expect(requests, hasLength(1));

    now = now.add(ChannelViews.freshFor);
    views.of('900801');
    await tester.pump(ChannelViews.batchDelay);
    expect(requests, hasLength(2));
    expect(counted, ['900801']);
  });

  testWidgets('a refused request stops asking in this chat', (tester) async {
    var calls = 0;
    final refusing = ChannelViews((ids, {required count}) async {
      calls++;
      return null;
    });
    addTearDown(refusing.dispose);

    refusing.of('900801');
    await tester.pump(ChannelViews.batchDelay);
    refusing.of('900802');
    await tester.pump(ChannelViews.batchDelay);

    expect(calls, 1);
  });

  testWidgets('a long scroll is split into batches', (tester) async {
    for (var i = 0; i < ChannelViews.batchSize + 5; i++) {
      views.of('${900900 + i}');
    }
    await tester.pump(ChannelViews.batchDelay);
    await tester.pump(ChannelViews.batchDelay);

    expect(requests.map((batch) => batch.length), [ChannelViews.batchSize, 5]);
  });
}
