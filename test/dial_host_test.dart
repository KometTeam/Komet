import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/transport/dial_host.dart';

void main() {
  test('IP-адрес не резолвится', () async {
    var lookups = 0;
    await resolveDialHost(
      '203.0.113.10',
      lookup: (host) async {
        lookups++;
        return const [];
      },
    );
    expect(lookups, 0);
  });

  test('зависший DNS обрывается по таймауту', () async {
    final hung = Completer<List<InternetAddress>>();
    final watch = Stopwatch()..start();
    await expectLater(
      resolveDialHost(
        'example.invalid',
        timeout: const Duration(milliseconds: 50),
        lookup: (host) => hung.future,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('ошибка DNS доходит до вызывающего', () async {
    await expectLater(
      resolveDialHost(
        'example.invalid',
        lookup: (host) async =>
            throw const SocketException('Failed host lookup'),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('успешный DNS пропускает дальше', () async {
    await resolveDialHost(
      'example.invalid',
      lookup: (host) async => [InternetAddress('203.0.113.10')],
    );
  });
}
