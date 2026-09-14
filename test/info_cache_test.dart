import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/cache/info_cache.dart';

void main() {
  test('a missing entry is asked again instead of being cached', () async {
    var calls = 0;
    final cache = InfoCache<String>(
      ttl: const Duration(minutes: 5),
      failureBackoff: Duration.zero,
      fetcher: (id) async {
        calls++;
        return calls == 1 ? null : 'synthetic-$id';
      },
    );

    expect(await cache.get(7), isNull);
    expect(cache.peek(7), isNull);
    expect(await cache.get(7), 'synthetic-7');
    expect(await cache.get(7), 'synthetic-7');
    expect(calls, 2);
  });

  test('a missing entry waits out the failure backoff', () async {
    var calls = 0;
    final cache = InfoCache<String>(
      ttl: const Duration(minutes: 5),
      failureBackoff: const Duration(minutes: 1),
      fetcher: (id) async {
        calls++;
        return null;
      },
    );

    expect(await cache.get(8), isNull);
    expect(await cache.get(8), isNull);
    expect(await cache.get(8, forceRefresh: true), isNull);
    expect(calls, 2);
  });
}
