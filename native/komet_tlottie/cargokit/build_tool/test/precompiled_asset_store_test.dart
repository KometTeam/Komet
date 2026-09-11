import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:build_tool/src/options.dart';
import 'package:build_tool/src/precompiled_asset_store.dart';
import 'package:build_tool/src/precompiled_generation.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('transport', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('asset-transport-'));
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('streams a bounded asset with exact EOF and incremental digest',
        () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final transport = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(
          Stream<List<int>>.fromIterable([
            bytes.sublist(0, 2),
            bytes.sublist(2),
          ]),
          200,
          headers: {'content-length': '${bytes.length}'},
        ),
      );
      final destination = File(path.join(temp.path, 'asset.staging'));

      await transport.downloadToFile(
        Uri.https('assets.example', '/asset'),
        destination,
        limit: 8,
        expectedLength: bytes.length,
        expectedSha256: sha256.convert(bytes).toString(),
        deleteOnFailure: true,
      );

      expect(destination.readAsBytesSync(), bytes);
    });

    test('rejects caps, content-length mismatches, and short or long EOF',
        () async {
      Future<void> fails(
        StreamedResponse response, {
        int limit = 4,
        int? expectedLength,
      }) async {
        final transport =
            PrecompiledAssetTransport(send: (_) async => response);
        await expectLater(
          transport.getBytes(
            Uri.https('assets.example', '/bounded'),
            limit: limit,
            expectedLength: expectedLength,
          ),
          throwsA(isA<PrecompiledTransportException>()),
        );
      }

      await fails(
        StreamedResponse(Stream.value([1, 2, 3, 4, 5]), 200),
      );
      await fails(
        StreamedResponse(Stream.value([1, 2]), 200,
            headers: {'content-length': '3'}),
        expectedLength: 2,
      );
      await fails(
        StreamedResponse(Stream.value([1]), 200),
        expectedLength: 2,
      );
      await fails(
        StreamedResponse(Stream.value([1, 2, 3]), 200),
        expectedLength: 2,
      );
      await fails(
        StreamedResponse(Stream.value([1]), 200,
            headers: {'content-length': 'invalid'}),
      );
    });

    test('manifest body must exactly match its declared content length',
        () async {
      for (final response in [
        StreamedResponse(
          Stream.value([1]),
          200,
          headers: {'content-length': '2'},
        ),
        StreamedResponse(
          Stream.value([1, 2]),
          200,
          headers: {'content-length': '1'},
        ),
      ]) {
        final transport =
            PrecompiledAssetTransport(send: (_) async => response);

        await expectLater(
          transport.getBytes(
            Uri.https('assets.example', '/manifest.json'),
            limit: 8,
          ),
          throwsA(isA<PrecompiledTransportException>()),
        );
      }
    });

    test('cancels 200 response bodies rejected by header validation', () async {
      Future<void> rejects(
        String reason,
        Map<String, String> headers, {
        int limit = 8,
      }) async {
        var listened = false;
        var cancelled = false;
        final body = StreamController<List<int>>(
          onListen: () => listened = true,
          onCancel: () => cancelled = true,
        );
        final transport = PrecompiledAssetTransport(
          send: (_) async => StreamedResponse(
            body.stream,
            200,
            headers: headers,
          ),
        );

        await expectLater(
          transport.getBytes(
            Uri.https('assets.example', '/invalid-$reason'),
            limit: limit,
          ),
          throwsA(isA<PrecompiledTransportException>()),
        );
        expect(listened, isTrue, reason: reason);
        expect(cancelled, isTrue, reason: reason);
        await body.close();
      }

      await rejects('malformed', {'content-length': 'invalid'});
      await rejects('conflicting', {
        'content-length': '1',
        'transfer-encoding': 'chunked',
      });
      await rejects('oversized', {'content-length': '9'});
    });

    test('bounds non-cooperative cancellation after header rejection',
        () async {
      final never = Completer<void>();
      final body = StreamController<List<int>>(
        onCancel: () => never.future,
      );
      var closes = 0;
      final transport = PrecompiledAssetTransport(
        exchangeFactory: () => (
          send: (_) async => StreamedResponse(
                body.stream,
                200,
                headers: {'content-length': 'invalid'},
              ),
          close: () => closes++,
        ),
        policy: const PrecompiledTransportPolicy(
          maxAttempts: 1,
          idleDeadline: Duration(milliseconds: 20),
          totalDeadline: Duration(milliseconds: 100),
        ),
      );

      final outcome = await Future.any<Object>([
        transport
            .getBytes(Uri.https('assets.example', '/invalid-header'), limit: 1)
            .then<Object>((value) => value ?? 'null',
                onError: (Object error) => error),
        Future<void>.delayed(const Duration(milliseconds: 500))
            .then<Object>((_) => 'watchdog'),
      ]);

      expect(outcome, isA<PrecompiledTransportException>());
      expect(closes, 1);
      transport.close();
    });

    test('bounds non-cooperative cancellation after body timeout', () async {
      final never = Completer<void>();
      final body = StreamController<List<int>>(
        onCancel: () => never.future,
      );
      var closes = 0;
      var deadlineCall = 0;
      final transport = PrecompiledAssetTransport(
        exchangeFactory: () => (
          send: (_) async => StreamedResponse(body.stream, 200),
          close: () => closes++,
        ),
        policy: const PrecompiledTransportPolicy(maxAttempts: 1),
        deadlineSleeper: (_) => deadlineCall++ == 0
            ? Completer<void>().future
            : Future<void>.value(),
      );

      final outcome = await Future.any<Object>([
        transport
            .getBytes(Uri.https('assets.example', '/stalled-body'), limit: 1)
            .then<Object>((value) => value ?? 'null',
                onError: (Object error) => error),
        Future<void>.delayed(const Duration(milliseconds: 500))
            .then<Object>((_) => 'watchdog'),
      ]);

      expect(outcome, isA<PrecompiledTransportException>());
      expect(closes, 1);
      transport.close();
    });

    test('retries only classified failures three total attempts', () async {
      var attempts = 0;
      final delays = <Duration>[];
      final transport = PrecompiledAssetTransport(
        send: (_) async {
          attempts++;
          if (attempts < 3) {
            return StreamedResponse(
              const Stream<List<int>>.empty(),
              503,
              headers: {'retry-after': '120'},
            );
          }
          return StreamedResponse(Stream.value([7]), 200);
        },
        policy: const PrecompiledTransportPolicy(
          retryAfterCap: Duration(seconds: 4),
        ),
        sleeper: (delay) {
          if (delay == const Duration(seconds: 4)) {
            delays.add(delay);
            return Future.value();
          }
          return Completer<void>().future;
        },
      );

      expect(
        await transport.getBytes(
          Uri.https('assets.example', '/retry'),
          limit: 1,
        ),
        [7],
      );
      expect(attempts, 3);
      expect(delays, const [Duration(seconds: 4), Duration(seconds: 4)]);

      attempts = 0;
      final noRetry = PrecompiledAssetTransport(send: (_) async {
        attempts++;
        return StreamedResponse(const Stream<List<int>>.empty(), 401);
      });
      await expectLater(
        noRetry.getBytes(Uri.https('assets.example', '/no-retry'), limit: 1),
        throwsA(isA<PrecompiledTransportException>()),
      );
      expect(attempts, 1);
    });

    test('retries every retryable HTTP status exactly three attempts',
        () async {
      for (final status in const [408, 429, 500, 502, 503, 504]) {
        var attempts = 0;
        final transport = PrecompiledAssetTransport(
          send: (_) async {
            attempts++;
            return StreamedResponse(const Stream<List<int>>.empty(), status);
          },
          sleeper: (_) async {},
        );

        await expectLater(
          transport.getBytes(
            Uri.https('assets.example', '/status-$status'),
            limit: 1,
          ),
          throwsA(isA<PrecompiledTransportException>()),
        );
        expect(attempts, 3, reason: 'HTTP $status');
      }
    });

    test('retries classified network failures exactly three attempts',
        () async {
      final failures = <String, Object>{
        'socket': const SocketException('connection reset'),
        'http': const HttpException('connection closed'),
        'client': ClientException('connection failed'),
        'timeout': TimeoutException('connection deadline'),
      };
      for (final entry in failures.entries) {
        var attempts = 0;
        final transport = PrecompiledAssetTransport(
          send: (_) async {
            attempts++;
            throw entry.value;
          },
          sleeper: (_) async {},
        );

        await expectLater(
          transport.getBytes(
            Uri.https('assets.example', '/${entry.key}'),
            limit: 1,
          ),
          throwsA(isA<PrecompiledTransportException>()),
        );
        expect(attempts, 3, reason: entry.key);
      }
    });

    test('manifest signature and asset bodies enforce length contracts',
        () async {
      Future<void> succeeds(
        String role,
        StreamedResponse response, {
        int? expectedLength,
      }) async {
        final transport =
            PrecompiledAssetTransport(send: (_) async => response);
        expect(
          await transport.getBytes(
            Uri.https('assets.example', '/$role'),
            limit: 64,
            expectedLength: expectedLength,
          ),
          List<int>.filled(expectedLength ?? 2, 7),
          reason: role,
        );
      }

      Future<void> fails(
        String role,
        StreamedResponse response, {
        int? expectedLength,
      }) async {
        final transport =
            PrecompiledAssetTransport(send: (_) async => response);
        await expectLater(
          transport.getBytes(
            Uri.https('assets.example', '/$role'),
            limit: 64,
            expectedLength: expectedLength,
          ),
          throwsA(isA<PrecompiledTransportException>()),
          reason: role,
        );
      }

      await succeeds(
        'manifest-without-content-length',
        StreamedResponse(Stream.value([7, 7]), 200),
      );
      await succeeds(
        'signature-without-content-length',
        StreamedResponse(Stream.value(List<int>.filled(64, 7)), 200),
        expectedLength: 64,
      );
      await succeeds(
        'asset-without-content-length',
        StreamedResponse(Stream.value([7, 7]), 200),
        expectedLength: 2,
      );
      for (final role in const ['manifest', 'signature', 'asset']) {
        await fails(
          '$role-malformed-content-length',
          StreamedResponse(
            Stream.value([7, 7]),
            200,
            headers: {'content-length': 'two'},
          ),
          expectedLength: role == 'manifest' ? null : 2,
        );
      }
      for (final declaredLength in const [1, 3]) {
        await fails(
          'manifest-declared-$declaredLength',
          StreamedResponse(
            Stream.value([7, 7]),
            200,
            headers: {'content-length': '$declaredLength'},
          ),
        );
        await fails(
          'signature-declared-$declaredLength',
          StreamedResponse(
            Stream.value([7, 7]),
            200,
            headers: {'content-length': '$declaredLength'},
          ),
          expectedLength: 2,
        );
        await fails(
          'asset-declared-$declaredLength',
          StreamedResponse(
            Stream.value([7, 7]),
            200,
            headers: {'content-length': '$declaredLength'},
          ),
          expectedLength: 2,
        );
      }
      for (final role in const ['signature', 'asset']) {
        await fails(
          '$role-chunked-early-eof',
          StreamedResponse(
            Stream.value([7]),
            200,
            headers: {'transfer-encoding': 'chunked'},
          ),
          expectedLength: 2,
        );
        await fails(
          '$role-chunked-overrun',
          StreamedResponse(
            Stream.value([7, 7, 7]),
            200,
            headers: {'transfer-encoding': 'chunked'},
          ),
          expectedLength: 2,
        );
      }
    });

    test('total deadline bounds a stalled retry sleep', () async {
      final transport = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(
          const Stream<List<int>>.empty(),
          503,
        ),
        policy: const PrecompiledTransportPolicy(
          totalDeadline: Duration(seconds: 1),
        ),
        sleeper: (_) => Completer<void>().future,
        deadlineSleeper: (_) async {},
      );

      await expectLater(
        transport.getBytes(
          Uri.https('assets.example', '/stalled-retry'),
          limit: 1,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );
    });

    test('does not start a retry delay that consumes the total budget',
        () async {
      var retrySleeps = 0;
      final transport = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(
          const Stream<List<int>>.empty(),
          503,
        ),
        policy: const PrecompiledTransportPolicy(
          baseBackoff: Duration(seconds: 1),
          totalDeadline: Duration(seconds: 1),
        ),
        sleeper: (_) {
          retrySleeps++;
          return Completer<void>().future;
        },
        deadlineSleeper: (_) async {},
        monotonicClock: () => Duration.zero,
      );

      await expectLater(
        transport.getBytes(
          Uri.https('assets.example', '/exhausted-retry'),
          limit: 1,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );
      expect(retrySleeps, 0);
    });

    test('body retry resets partial bytes and digest state', () async {
      final complete = Uint8List.fromList([1, 2, 3]);
      var attempts = 0;
      final transport = PrecompiledAssetTransport(
        send: (_) async {
          attempts++;
          if (attempts == 1) {
            return StreamedResponse(
              Stream<List<int>>.fromIterable(const [
                [9, 9],
              ]).transform(
                StreamTransformer.fromHandlers(
                  handleDone: (sink) =>
                      sink.addError(const SocketException('reset')),
                ),
              ),
              200,
            );
          }
          return StreamedResponse(Stream.value(complete), 200);
        },
        sleeper: (duration) => duration <= const Duration(seconds: 5)
            ? Future.value()
            : Completer<void>().future,
      );
      final destination = File(path.join(temp.path, 'retried.staging'));

      await transport.downloadToFile(
        Uri.https('assets.example', '/retried'),
        destination,
        limit: complete.length,
        expectedLength: complete.length,
        expectedSha256: sha256.convert(complete).toString(),
        deleteOnFailure: true,
      );

      expect(attempts, 2);
      expect(destination.readAsBytesSync(), complete);
    });

    test('getBytes retry discards bytes from a failed body attempt', () async {
      var attempts = 0;
      final transport = PrecompiledAssetTransport(
        send: (_) async {
          attempts++;
          if (attempts == 1) {
            return StreamedResponse(
              Stream<List<int>>.fromIterable(const [
                [9, 9],
              ]).transform(
                StreamTransformer.fromHandlers(
                  handleDone: (sink) =>
                      sink.addError(const SocketException('reset')),
                ),
              ),
              200,
            );
          }
          return StreamedResponse(Stream.value([1, 2, 3]), 200);
        },
        sleeper: (_) async {},
      );

      expect(
        await transport.getBytes(
          Uri.https('assets.example', '/retried-bytes'),
          limit: 3,
        ),
        [1, 2, 3],
      );
      expect(attempts, 2);
    });

    test('follows at most five manual redirects and rejects HTTPS downgrade',
        () async {
      final visited = <Uri>[];
      final transport = PrecompiledAssetTransport(send: (request) async {
        visited.add(request.url);
        final step = int.parse(request.url.queryParameters['step'] ?? '0');
        if (step < 5) {
          return StreamedResponse(
            const Stream<List<int>>.empty(),
            302,
            headers: {'location': '?step=${step + 1}'},
          );
        }
        return StreamedResponse(Stream.value([9]), 200);
      });
      expect(
        await transport.getBytes(
          Uri.parse('https://assets.example/file?step=0'),
          limit: 1,
        ),
        [9],
      );
      expect(visited, hasLength(6));

      final tooMany = PrecompiledAssetTransport(send: (request) async {
        final step = int.parse(request.url.queryParameters['step'] ?? '0');
        return StreamedResponse(
          const Stream<List<int>>.empty(),
          302,
          headers: {'location': '?step=${step + 1}'},
        );
      });
      await expectLater(
        tooMany.getBytes(
          Uri.parse('https://assets.example/file?step=0'),
          limit: 1,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );

      final downgrade = PrecompiledAssetTransport(
          send: (_) async => StreamedResponse(
              const Stream<List<int>>.empty(), 302,
              headers: {'location': 'http://assets.example/file'}));
      await expectLater(
        downgrade.getBytes(
          Uri.https('assets.example', '/file'),
          limit: 1,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );

      final foreignScheme = PrecompiledAssetTransport(
          send: (_) async => StreamedResponse(
              const Stream<List<int>>.empty(), 302,
              headers: {'location': 'file:///tmp/asset'}));
      await expectLater(
        foreignScheme.getBytes(
          Uri.https('assets.example', '/file'),
          limit: 1,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );
    });

    test('enforces injected header deadline', () async {
      final header = PrecompiledAssetTransport(
        send: (_) => Completer<StreamedResponse>().future,
        policy: const PrecompiledTransportPolicy(maxAttempts: 1),
        deadlineSleeper: (_) async {},
      );
      await expectLater(
        header.getBytes(Uri.https('assets.example', '/header'), limit: 1),
        throwsA(isA<PrecompiledTransportException>()),
      );
    });

    test('header timeout closes its exchange and discards a late response',
        () async {
      final firstHeaders = Completer<StreamedResponse>();
      final lateBody = StreamController<List<int>>();
      var lateBodyCancelled = false;
      lateBody.onCancel = () => lateBodyCancelled = true;
      final closeCounts = <int>[0, 0];
      var exchangeCount = 0;
      var deadlineCount = 0;
      final transport = PrecompiledAssetTransport(
        exchangeFactory: () {
          final index = exchangeCount++;
          return (
            send: (_) => index == 0
                ? firstHeaders.future
                : Future.value(StreamedResponse(Stream.value([7]), 200)),
            close: () => closeCounts[index]++,
          );
        },
        sleeper: (_) async {},
        deadlineSleeper: (_) =>
            deadlineCount++ == 0 ? Future.value() : Completer<void>().future,
      );

      expect(
        await transport.getBytes(
          Uri.https('assets.example', '/late-headers'),
          limit: 1,
        ),
        [7],
      );
      firstHeaders.complete(StreamedResponse(lateBody.stream, 200));
      await Future<void>.delayed(Duration.zero);

      expect(exchangeCount, 2);
      expect(closeCounts, [1, 1]);
      expect(lateBodyCancelled, isTrue);
      await lateBody.close();
    });

    test('enforces idle deadline and cancels the response stream', () async {
      var cancelled = false;
      final idleDeadline = Completer<void>();
      final idleController = StreamController<List<int>>(
        onListen: idleDeadline.complete,
        onCancel: () => cancelled = true,
      );
      final idle = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(idleController.stream, 200),
        policy: const PrecompiledTransportPolicy(maxAttempts: 1),
        deadlineSleeper: (_) => idleDeadline.future,
      );
      await expectLater(
        idle.getBytes(Uri.https('assets.example', '/idle'), limit: 1),
        throwsA(isA<PrecompiledTransportException>()),
      );
      expect(cancelled, isTrue);
      await idleController.close();
    });

    test('enforces total deadline between streamed chunks', () async {
      var tick = 0;
      final total = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(Stream.value([1]), 200),
        policy: const PrecompiledTransportPolicy(
          maxAttempts: 1,
          totalDeadline: Duration(seconds: 1),
        ),
        monotonicClock: () => Duration(seconds: tick++),
        deadlineSleeper: (_) => Completer<void>().future,
      );
      await expectLater(
        total.getBytes(Uri.https('assets.example', '/total'), limit: 1),
        throwsA(isA<PrecompiledTransportException>()),
      );
    });

    test('bounds a stalled chunk wait by the remaining total deadline',
        () async {
      final requestedDeadlines = <Duration>[];
      final stalled = StreamController<List<int>>();
      var deadlineCall = 0;
      final stalledTotal = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(stalled.stream, 200),
        policy: const PrecompiledTransportPolicy(
          maxAttempts: 1,
          idleDeadline: Duration(seconds: 10),
          totalDeadline: Duration(seconds: 3),
        ),
        monotonicClock: () => Duration.zero,
        deadlineSleeper: (duration) {
          requestedDeadlines.add(duration);
          return deadlineCall++ == 0
              ? Completer<void>().future
              : Future.value();
        },
      );
      await expectLater(
        stalledTotal.getBytes(
          Uri.https('assets.example', '/stalled-total'),
          limit: 1,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );
      expect(requestedDeadlines, contains(const Duration(seconds: 3)));
      await stalled.close();
    });

    test('404 can be represented and failed owned staging is deleted',
        () async {
      final missing = PrecompiledAssetTransport(
          send: (_) async =>
              StreamedResponse(const Stream<List<int>>.empty(), 404));
      expect(
        await missing.getBytes(
          Uri.https('assets.example', '/missing'),
          limit: 1,
          allowNotFound: true,
        ),
        isNull,
      );

      final destination = File(path.join(temp.path, 'owned.staging'));
      final invalid = PrecompiledAssetTransport(
        send: (_) async => StreamedResponse(Stream.value([1]), 200),
      );
      await expectLater(
        invalid.downloadToFile(
          Uri.https('assets.example', '/invalid'),
          destination,
          limit: 1,
          expectedLength: 1,
          expectedSha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          deleteOnFailure: true,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );
      expect(destination.existsSync(), isFalse);

      final timedOutFile = File(path.join(temp.path, 'timeout.staging'));
      final timedOut = PrecompiledAssetTransport(
        send: (_) => Completer<StreamedResponse>().future,
        policy: const PrecompiledTransportPolicy(maxAttempts: 1),
        deadlineSleeper: (_) async {},
      );
      await expectLater(
        timedOut.downloadToFile(
          Uri.https('assets.example', '/timeout'),
          timedOutFile,
          limit: 1,
          expectedLength: 1,
          expectedSha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          deleteOnFailure: true,
        ),
        throwsA(isA<PrecompiledTransportException>()),
      );
      expect(timedOutFile.existsSync(), isFalse);
    });
  });

  group('store', () {
    late Directory temp;
    late KeyPair keyPair;
    late PrecompiledBuildRecipe recipe;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('immutable-asset-store-');
      final private = newKeyFromSeed(
        Uint8List.fromList(List<int>.generate(32, (index) => index)),
      );
      keyPair = KeyPair(private, public(private));
      recipe = PrecompiledBuildRecipe(
        rustToolchain: '1.88.0',
        flutterVersion: '3.32.8',
        xcodeVersion: '16.4',
        sdkVersions: const {'macosx': '15.5'},
        deploymentTargets: const {'macos': '10.14'},
        rustTargets: const ['x86_64-unknown-linux-gnu'],
      );
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('request key is canonical JSON over sorted expanded names', () {
      expect(
        PrecompiledAssetStore.requestKey(const {'b.bin', 'a.bin'}),
        '8403c9156da61d825f0df4908c298ec94fc54c5c84d25d3ecbb268bc8fb3bca4',
      );
    });

    test('installs scoped snapshots and expands only requested composites',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final calls = <String>[];
      final store = _store(temp.path, recipe, keyPair, fixture, calls: calls);

      final targetOnly = await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );

      expect(targetOnly, isNotNull);
      expect(File(targetOnly!.pathFor('a.bin')).readAsBytesSync(), [1, 2, 3]);
      expect(calls.where((call) => call.endsWith('/archive.zip')), isEmpty);
      expect(calls.where((call) => call.endsWith('/archive.zip.checksum')),
          isEmpty);

      calls.clear();
      final composite = await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'archive.zip'},
      );
      expect(
          composite!.assetNames, const {'archive.zip', 'archive.zip.checksum'});
      expect(calls, contains(endsWith('/archive.zip')));
      expect(calls, contains(endsWith('/archive.zip.checksum')));
      expect(composite.directory, isNot(targetOnly.directory));
    });

    test('preserves slash and legacy concatenated URL prefixes', () async {
      final fixture = _storeFixture(recipe, keyPair);
      final slashCalls = <String>[];
      await _store(
        path.join(temp.path, 'slash'),
        recipe,
        keyPair,
        fixture,
        calls: slashCalls,
        uriPrefix: Uri.parse('https://assets.example/precompiled/'),
      ).snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      expect(slashCalls.first,
          '/precompiled/$_storeGeneration/$precompiledGenerationManifestFileName');

      final legacyCalls = <String>[];
      await _store(
        path.join(temp.path, 'legacy'),
        recipe,
        keyPair,
        fixture,
        calls: legacyCalls,
        uriPrefix: Uri.parse('https://assets.example/precompiled_'),
      ).snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      expect(legacyCalls.first,
          '/precompiled_$_storeGeneration/$precompiledGenerationManifestFileName');
    });

    test('supports nested safe asset names with recursive inventory checks',
        () async {
      final fixture = _nestedStoreFixture(recipe, keyPair);
      final store = _store(temp.path, recipe, keyPair, fixture);

      final snapshot = await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'nested/a.bin'},
      );

      expect(
          File(snapshot!.pathFor('nested/a.bin')).readAsBytesSync(), [6, 7, 8]);
      final adopted = await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'nested/a.bin'},
      );
      expect(adopted!.directory, snapshot.directory);
    });

    test('published anchor and snapshot tamper fail closed without repair',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final store = _store(temp.path, recipe, keyPair, fixture);
      final first = await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      final asset = File(first!.pathFor('a.bin'))..writeAsBytesSync([0]);

      await expectLater(
        store.snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );
      expect(asset.readAsBytesSync(), [0]);

      final anchor = File(path.join(
        temp.path,
        'v2',
        _storeGeneration,
        'anchor',
        precompiledGenerationManifestFileName,
      ));
      anchor.writeAsBytesSync([0]);
      await expectLater(
        store.snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'b.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );
      expect(anchor.readAsBytesSync(), [0]);
    });

    test('canonicalizes caller root but rejects links and wrong managed types',
        () async {
      if (Platform.isWindows) return;
      final fixture = _storeFixture(recipe, keyPair);
      final realRoot = Directory(path.join(temp.path, 'real'))..createSync();
      final linkedRoot = Link(path.join(temp.path, 'linked'))
        ..createSync(realRoot.path);
      final linkedStore = _store(linkedRoot.path, recipe, keyPair, fixture);
      final snapshot = await linkedStore.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      expect(
          path.isWithin(
              realRoot.resolveSymbolicLinksSync(), snapshot!.directory),
          isTrue);

      final unsafeRoot = Directory(path.join(temp.path, 'unsafe'))
        ..createSync();
      Link(path.join(unsafeRoot.path, 'v2')).createSync(realRoot.path);
      await expectLater(
        _store(unsafeRoot.path, recipe, keyPair, fixture).snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );

      final wrongRoot = Directory(path.join(temp.path, 'wrong'))..createSync();
      File(path.join(wrongRoot.path, 'v2')).writeAsStringSync('wrong');
      await expectLater(
        _store(wrongRoot.path, recipe, keyPair, fixture).snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );
    });

    test('failed caller staging is removed and foreign staging is retained',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final store = _store(temp.path, recipe, keyPair, fixture);
      await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      final snapshots = Directory(path.join(
        temp.path,
        'v2',
        _storeGeneration,
        'snapshots',
      ));
      final foreign = Directory(path.join(snapshots.path, 'foreign.staging-x'))
        ..createSync();
      fixture.responses['/$_storeGeneration/b.bin'] = [0];

      await expectLater(
        store.snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'b.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );

      expect(foreign.existsSync(), isTrue);
      expect(
        snapshots.listSync(followLinks: false).where(
            (entity) => path.basename(entity.path).contains('.staging-')),
        hasLength(1),
      );
      expect(
        snapshots
            .listSync(followLinks: false)
            .where((entity) => path.basename(entity.path).contains('.staging-'))
            .single
            .path,
        foreign.path,
      );
    });

    test('remote signatures are exactly 64 bytes and limits apply before data',
        () async {
      for (final length in const [63, 65]) {
        final manifestFixture = _storeFixture(recipe, keyPair);
        manifestFixture.responses[
                '/$_storeGeneration/$precompiledGenerationManifestSignatureFileName'] =
            List<int>.filled(length, 0);
        await expectLater(
          _store(
            path.join(temp.path, 'manifest-signature-$length'),
            recipe,
            keyPair,
            manifestFixture,
          ).snapshot(
            generationHash: _storeGeneration,
            requestedAssetNames: const {'a.bin'},
          ),
          throwsA(isA<PrecompiledGenerationException>()),
        );

        final assetFixture = _storeFixture(recipe, keyPair);
        assetFixture.responses['/$_storeGeneration/a.bin.sig'] =
            List<int>.filled(length, 0);
        await expectLater(
          _store(
            path.join(temp.path, 'asset-signature-$length'),
            recipe,
            keyPair,
            assetFixture,
          ).snapshot(
            generationHash: _storeGeneration,
            requestedAssetNames: const {'a.bin'},
          ),
          throwsA(isA<PrecompiledGenerationException>()),
        );
      }

      final perAssetFixture = _storeFixture(recipe, keyPair);
      await expectLater(
        _store(
          path.join(temp.path, 'per-asset-limit'),
          recipe,
          keyPair,
          perAssetFixture,
          policy: const PrecompiledAssetStorePolicy(perAssetLimit: 2),
        ).snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );

      final aggregateFixture = _storeFixture(recipe, keyPair);
      await expectLater(
        _store(
          path.join(temp.path, 'aggregate-limit'),
          recipe,
          keyPair,
          aggregateFixture,
          policy: const PrecompiledAssetStorePolicy(
            perAssetLimit: 4,
            aggregateAssetLimit: 4,
          ),
        ).snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin', 'b.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );
    });

    test('publishes by same-parent absent renames and reports exact metrics',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final renames = <List<String>>[];
      final lifecycle = <String, List<String>>{};
      final logs = <String>[];
      final store = _store(
        temp.path,
        recipe,
        keyPair,
        fixture,
        fileRecorder: (event, filePath) =>
            lifecycle.putIfAbsent(filePath, () => []).add(event),
        rename: (source, destination) {
          renames.add([source, destination]);
          expect(path.dirname(source), path.dirname(destination));
          expect(FileSystemEntity.typeSync(destination, followLinks: false),
              FileSystemEntityType.notFound);
          for (final entity in Directory(source)
              .listSync(recursive: true, followLinks: false)) {
            if (FileSystemEntity.typeSync(entity.path, followLinks: false) ==
                FileSystemEntityType.file) {
              expect(lifecycle[entity.path], const ['open', 'flush', 'close']);
            }
          }
          Directory(source).renameSync(destination);
        },
        logger: logs.add,
      );
      final snapshot = await store.snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      expect(renames, hasLength(2));
      expect(path.basename(renames[0][0]), startsWith('anchor.staging-'));
      expect(path.basename(renames[0][1]), 'anchor');
      expect(path.basename(renames[1][0]),
          startsWith('${snapshot!.requestKey}.staging-'));
      expect(path.basename(renames[1][1]), snapshot.requestKey);

      final metrics = store.metrics(
        generationHash: _storeGeneration,
        requestKey: snapshot.requestKey,
      );
      expect(metrics.snapshotCount, 1);
      expect(metrics.totalBytes, greaterThan(0));
      expect(metrics.oldestMtime, isNotNull);
      expect(
        logs.last,
        'precompiled-cache generation=$_storeGeneration '
        'request=${snapshot.requestKey} snapshots=1 bytes=${metrics.totalBytes} '
        'oldest_mtime=${metrics.oldestMtime!.toUtc().toIso8601String()}',
      );
    });

    test('publication bounds sharing retries and aborts other rename errors',
        () async {
      Future<int> failsAfter({required bool transient}) async {
        final fixture = _storeFixture(recipe, keyPair);
        var attempts = 0;
        final store = _store(
          path.join(temp.path, transient ? 'sharing' : 'fatal'),
          recipe,
          keyPair,
          fixture,
          policy: const PrecompiledAssetStorePolicy(
            renameAttempts: 3,
            renameRetryDelay: Duration.zero,
          ),
          sleeper: (_) async {},
          transientRenameError: (_) => transient,
          rename: (source, destination) {
            attempts++;
            throw FileSystemException(
              transient ? 'sharing violation' : 'permission denied',
              destination,
              OSError(transient ? 'sharing violation' : 'permission denied',
                  transient ? 32 : 13),
            );
          },
        );
        await expectLater(
          store.snapshot(
            generationHash: _storeGeneration,
            requestedAssetNames: const {'a.bin'},
          ),
          throwsA(isA<PrecompiledGenerationException>()),
        );
        return attempts;
      }

      expect(await failsAfter(transient: true), 3);
      expect(await failsAfter(transient: false), 1);
    });

    test('same request serializes across store instances in one isolate',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final calls = <String>[];
      final root = path.join(temp.path, 'same-isolate');
      final stores = [
        _store(root, recipe, keyPair, fixture, calls: calls),
        _store(root, recipe, keyPair, fixture, calls: calls),
      ];

      final snapshots = await Future.wait(stores.map((store) => store.snapshot(
            generationHash: _storeGeneration,
            requestedAssetNames: const {'a.bin'},
          )));

      expect(snapshots, everyElement(isNotNull));
      expect(snapshots[0]!.directory, snapshots[1]!.directory);
      expect(calls.where((call) => call.endsWith('/a.bin.sig')), hasLength(1));
      expect(calls.where((call) => call.endsWith('/a.bin')), hasLength(1));
    });

    test('in-process lock deadline and exception release queued callers',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final root = path.join(temp.path, 'isolate-deadline');
      final entered = Completer<void>();
      final release = Completer<void>();
      final failing = _store(
        root,
        recipe,
        keyPair,
        fixture,
        send: (request) async {
          if (request.url.path.endsWith('/a.bin.sig')) {
            if (!entered.isCompleted) entered.complete();
            await release.future;
            return StreamedResponse(
              Stream.value(List<int>.filled(64, 0)),
              200,
              headers: {'content-length': '64'},
            );
          }
          final bytes = fixture.responses[request.url.path];
          return bytes == null
              ? StreamedResponse(const Stream<List<int>>.empty(), 404)
              : StreamedResponse(
                  Stream.value(bytes),
                  200,
                  headers: {'content-length': '${bytes.length}'},
                );
        },
      ).snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      await entered.future;

      final contenderCalls = <String>[];
      var tick = 0;
      final contender = _store(
        root,
        recipe,
        keyPair,
        fixture,
        calls: contenderCalls,
        policy: const PrecompiledAssetStorePolicy(
          lockTimeout: Duration(seconds: 3),
          lockPollInterval: Duration.zero,
        ),
        sleeper: (_) async {},
        monotonicClock: () => Duration(seconds: tick++),
      );
      await expectLater(
        contender.snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );
      expect(
        contenderCalls.where((call) => call.endsWith('/a.bin.sig')),
        isEmpty,
      );
      expect(contenderCalls.where((call) => call.endsWith('/a.bin')), isEmpty);

      release.complete();
      await expectLater(
        failing,
        throwsA(isA<PrecompiledGenerationException>()),
      );
      final recovered = await _store(root, recipe, keyPair, fixture).snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      expect(recovered, isNotNull);
    });

    test('process lock deadline fails closed and crashed owner releases lock',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final installed =
          await _store(temp.path, recipe, keyPair, fixture).snapshot(
        generationHash: _storeGeneration,
        requestedAssetNames: const {'a.bin'},
      );
      final lockPath = path.join(
        temp.path,
        'v2',
        _storeGeneration,
        'locks',
        'request-${installed!.requestKey}.lock',
      );
      final owner = await _startWorker('hold-request-lock', lockPath);
      await owner.proceed();
      expect((await owner.next())['acquired'], isTrue);

      var tick = 0;
      final contender = _store(
        temp.path,
        recipe,
        keyPair,
        fixture,
        policy: const PrecompiledAssetStorePolicy(
          lockTimeout: Duration(seconds: 2),
          lockPollInterval: Duration.zero,
        ),
        sleeper: (_) async {},
        monotonicClock: () => Duration(seconds: tick++),
      );
      await expectLater(
        contender.snapshot(
          generationHash: _storeGeneration,
          requestedAssetNames: const {'a.bin'},
        ),
        throwsA(isA<PrecompiledGenerationException>()),
      );
      expect(File(lockPath).existsSync(), isTrue);
      await owner.release();
      expect(await owner.exitCode, 0);

      final crashed = await _startWorker('crash-with-lock', lockPath);
      await crashed.proceed();
      expect((await crashed.next())['acquired'], isTrue);
      expect(await crashed.exitCode, 23);

      final acquired = await _startWorker('acquire', lockPath);
      await acquired.proceed();
      expect((await acquired.next())['acquired'], isTrue);
      expect(await acquired.exitCode, 0);
    });

    test(
        'process installs adopt identical anchor and serialize same overlapping and disjoint requests',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final server = await _FixtureServer.start({'/': fixture});
      final root = path.join(temp.path, 'parallel');
      try {
        final requests = <List<String>>[
          ['a.bin'],
          ['a.bin'],
          ['a.bin', 'b.bin'],
          ['archive.zip'],
        ];
        final workers = <_WorkerHandle>[];
        for (final requested in requests) {
          workers.add(await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: requested,
          )));
        }
        await Future.wait(workers.map((worker) => worker.proceed()));
        final results =
            await Future.wait(workers.map((worker) => worker.next()));
        expect(
          results.map((result) => result.keys.toSet()),
          everyElement(const {'event', 'ok', 'path', 'error'}),
        );
        expect(results, everyElement(containsPair('ok', true)));
        expect(results[0]['path'], results[1]['path']);
        expect(results[2]['path'], isNot(results[0]['path']));
        expect(results[3]['path'], isNot(results[0]['path']));
        final expectedAssets = <Set<String>>[
          {'a.bin'},
          {'a.bin'},
          {'a.bin', 'b.bin'},
          {'archive.zip', 'archive.zip.checksum'},
        ];
        for (var index = 0; index < results.length; index++) {
          final directory = Directory(results[index]['path'] as String);
          expect(directory.existsSync(), isTrue);
          for (final name in expectedAssets[index]) {
            expect(File(path.join(directory.path, name)).existsSync(), isTrue);
          }
        }
        expect(await Future.wait(workers.map((worker) => worker.exitCode)),
            everyElement(0));

        final fresh = await _startWorkerConfig(_installWorkerConfig(
          root: root,
          uriPrefix: server.prefix('/'),
          recipe: recipe,
          keyPair: keyPair,
          fixture: fixture,
          requested: const ['a.bin'],
        ));
        await fresh.proceed();
        final freshResult = await fresh.next();
        expect(
            freshResult.keys.toSet(), const {'event', 'ok', 'path', 'error'});
        expect(freshResult['path'], results[0]['path']);
        expect(await fresh.exitCode, 0);
      } finally {
        await server.close();
      }
    });

    test('same request is serialized directly across processes', () async {
      final fixture = _storeFixture(recipe, keyPair);
      final server = await _FixtureServer.start({'/': fixture});
      final root = path.join(temp.path, 'same-request');
      try {
        final workers = await Future.wait([
          _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: const ['a.bin'],
          )),
          _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: const ['a.bin'],
          )),
        ]);
        await Future.wait(workers.map((worker) => worker.proceed()));
        final results =
            await Future.wait(workers.map((worker) => worker.next()));

        expect(results, everyElement(containsPair('ok', true)));
        expect(results[0]['path'], results[1]['path']);
        expect(
          server.requests.where((request) => request.endsWith('/a.bin.sig')),
          hasLength(1),
        );
        expect(
          server.requests.where((request) => request.endsWith('/a.bin')),
          hasLength(1),
        );
        expect(await Future.wait(workers.map((worker) => worker.exitCode)),
            everyElement(0));
      } finally {
        await server.close();
      }
    });

    test('different valid manifests for one generation expose one winner only',
        () async {
      final first = _storeFixture(recipe, keyPair);
      final second = _variantFixture(
        first,
        recipe,
        keyPair,
        sourceCommit: '2222222222222222222222222222222222222222',
      );
      final server = await _FixtureServer.start({
        '/first_': first,
        '/second_': second,
      });
      final root = path.join(temp.path, 'conflict');
      try {
        final workers = [
          await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/first_'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: first,
            requested: const ['a.bin'],
          )),
          await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/second_'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: second,
            requested: const ['a.bin'],
          )),
        ];
        await Future.wait(workers.map((worker) => worker.proceed()));
        final results =
            await Future.wait(workers.map((worker) => worker.next()));
        expect(results.where((result) => result['ok'] == true), hasLength(1));
        expect(results.where((result) => result['ok'] == false), hasLength(1));
        await Future.wait(workers.map((worker) => worker.exitCode));

        final anchor = File(path.join(
          root,
          'v2',
          _storeGeneration,
          'anchor',
          precompiledGenerationManifestFileName,
        )).readAsBytesSync();
        expect(
          _sameTestBytes(anchor, first.manifest.canonicalBytes()) ||
              _sameTestBytes(anchor, second.manifest.canonicalBytes()),
          isTrue,
        );
        final published = Directory(path.join(
          root,
          'v2',
          _storeGeneration,
          'snapshots',
        )).listSync(followLinks: false).where((entity) =>
            RegExp(r'^[0-9a-f]{64}$').hasMatch(path.basename(entity.path)));
        expect(published, hasLength(1));
      } finally {
        await server.close();
      }
    });

    test('fresh processes reject every immutable tamper without repair',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final server = await _FixtureServer.start({'/': fixture});
      try {
        for (final tamper in const [
          'anchored manifest',
          'metadata signature',
          'regular-file type',
          'exact length',
          'digest',
          'composite checksum',
        ]) {
          final root =
              path.join(temp.path, 'fresh-${tamper.replaceAll(' ', '-')}');
          final requested = tamper == 'composite checksum'
              ? const ['archive.zip']
              : const ['a.bin'];
          final first = await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: requested,
          ));
          await first.proceed();
          final installed = await first.next();
          expect(installed['ok'], true, reason: tamper);
          expect(await first.exitCode, 0, reason: tamper);
          final snapshotPath = installed['path'] as String;
          late void Function() verifyUnchanged;
          switch (tamper) {
            case 'anchored manifest':
              final manifest = File(path.join(
                root,
                'v2',
                _storeGeneration,
                'anchor',
                precompiledGenerationManifestFileName,
              ))
                ..writeAsBytesSync([0]);
              verifyUnchanged = () => expect(manifest.readAsBytesSync(), [0]);
            case 'metadata signature':
              final signature = File(path.join(snapshotPath, 'a.bin.sig'))
                ..writeAsBytesSync(List<int>.filled(64, 0));
              verifyUnchanged = () => expect(
                    signature.readAsBytesSync(),
                    List<int>.filled(64, 0),
                  );
            case 'regular-file type':
              final assetPath = path.join(snapshotPath, 'a.bin');
              File(assetPath).deleteSync();
              final directory = Directory(assetPath)..createSync();
              verifyUnchanged = () => expect(directory.existsSync(), isTrue);
            case 'exact length':
              final asset = File(path.join(snapshotPath, 'a.bin'))
                ..writeAsBytesSync([1, 2]);
              verifyUnchanged = () => expect(asset.readAsBytesSync(), [1, 2]);
            case 'digest':
              final asset = File(path.join(snapshotPath, 'a.bin'))
                ..writeAsBytesSync([9, 9, 9]);
              verifyUnchanged =
                  () => expect(asset.readAsBytesSync(), [9, 9, 9]);
            case 'composite checksum':
              final checksum =
                  File(path.join(snapshotPath, 'archive.zip.checksum'))
                    ..writeAsBytesSync(List<int>.filled(65, 0));
              verifyUnchanged = () => expect(
                    checksum.readAsBytesSync(),
                    List<int>.filled(65, 0),
                  );
          }

          final fresh = await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: requested,
          ));
          await fresh.proceed();
          final result = await fresh.next();
          expect(result.keys.toSet(), const {'event', 'ok', 'path', 'error'},
              reason: tamper);
          expect(result['ok'], false, reason: tamper);
          expect(result['path'], isNull, reason: tamper);
          expect(result['error'], isA<String>(), reason: tamper);
          verifyUnchanged();
          expect(await fresh.exitCode, 1, reason: tamper);
        }
      } finally {
        await server.close();
      }
    });

    test('fresh processes reject extra anchor inventory without repair',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final server = await _FixtureServer.start({'/': fixture});
      final tampers = <String>[
        'regular file',
        'directory',
        if (!Platform.isWindows) 'symlink',
      ];
      try {
        for (final tamper in tampers) {
          final root =
              path.join(temp.path, 'anchor-${tamper.replaceAll(' ', '-')}');
          final seed = await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: const ['a.bin'],
          ));
          await seed.proceed();
          final installed = await seed.next();
          expect(installed['ok'], true, reason: tamper);
          expect(await seed.exitCode, 0, reason: tamper);
          final anchor = path.join(root, 'v2', _storeGeneration, 'anchor');
          late void Function() verifyUnchanged;
          switch (tamper) {
            case 'regular file':
              final extra = File(path.join(anchor, 'extra.txt'))
                ..writeAsBytesSync([4, 2]);
              verifyUnchanged =
                  () => expect(extra.readAsBytesSync(), const [4, 2]);
            case 'directory':
              final extra = Directory(path.join(anchor, 'extra'))..createSync();
              verifyUnchanged = () => expect(extra.existsSync(), isTrue);
            case 'symlink':
              final extra = Link(path.join(anchor, 'extra-link'))
                ..createSync(
                  path.join(anchor, precompiledGenerationManifestFileName),
                );
              verifyUnchanged = () {
                expect(
                  FileSystemEntity.typeSync(extra.path, followLinks: false),
                  FileSystemEntityType.link,
                );
              };
          }

          final fresh = await _startWorkerConfig(_installWorkerConfig(
            root: root,
            uriPrefix: server.prefix('/'),
            recipe: recipe,
            keyPair: keyPair,
            fixture: fixture,
            requested: const ['a.bin'],
          ));
          await fresh.proceed();
          final result = await fresh.next();
          expect(result['ok'], false, reason: tamper);
          expect(result['path'], isNull, reason: tamper);
          verifyUnchanged();
          expect(await fresh.exitCode, 1, reason: tamper);
        }
      } finally {
        await server.close();
      }
    });

    test('generation lock deadline and generation-before-request order',
        () async {
      final fixture = _storeFixture(recipe, keyPair);
      final server = await _FixtureServer.start({'/': fixture});
      final root = path.join(temp.path, 'lock-order');
      try {
        final seed = await _startWorkerConfig(_installWorkerConfig(
          root: root,
          uriPrefix: server.prefix('/'),
          recipe: recipe,
          keyPair: keyPair,
          fixture: fixture,
          requested: const ['a.bin'],
        ));
        await seed.proceed();
        expect((await seed.next())['ok'], true);
        await seed.exitCode;
        final locks = path.join(root, 'v2', _storeGeneration, 'locks');
        final generationLock = path.join(locks, 'generation.lock');

        final heldGeneration =
            await _startWorker('hold-generation-lock', generationLock);
        await heldGeneration.proceed();
        expect((await heldGeneration.next())['acquired'], true);
        final timedOut = await _startWorkerConfig(_installWorkerConfig(
          root: root,
          uriPrefix: server.prefix('/'),
          recipe: recipe,
          keyPair: keyPair,
          fixture: fixture,
          requested: const ['b.bin'],
          lockTimeoutMs: 100,
        ));
        await timedOut.proceed();
        expect((await timedOut.next())['ok'], false);
        expect(File(generationLock).existsSync(), true);
        expect(await timedOut.exitCode, 1);
        await heldGeneration.release();
        expect(await heldGeneration.exitCode, 0);

        final bKey = PrecompiledAssetStore.requestKey(const {'b.bin'});
        final requestLock = path.join(locks, 'request-$bKey.lock');
        File(requestLock).createSync();
        final heldRequest =
            await _startWorker('hold-request-lock', requestLock);
        await heldRequest.proceed();
        expect((await heldRequest.next())['acquired'], true);
        final installer = await _startWorkerConfig(_installWorkerConfig(
          root: root,
          uriPrefix: server.prefix('/'),
          recipe: recipe,
          keyPair: keyPair,
          fixture: fixture,
          requested: const ['b.bin'],
        ));
        await installer.proceed();
        final generationProbe = await _startWorker('acquire', generationLock);
        await generationProbe.proceed();
        expect((await generationProbe.next())['acquired'], true);
        expect(await generationProbe.exitCode, 0);
        await heldRequest.release();
        expect((await installer.next())['ok'], true);
        expect(await installer.exitCode, 0);
        expect(await heldRequest.exitCode, 0);
      } finally {
        await server.close();
      }
    });
  });
}

const _storeGeneration =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _storeCommit = '1111111111111111111111111111111111111111';

class _StoreFixture {
  _StoreFixture(this.manifest, this.responses);

  final PrecompiledGenerationManifest manifest;
  final Map<String, List<int>> responses;
}

_StoreFixture _storeFixture(PrecompiledBuildRecipe recipe, KeyPair keyPair) {
  final data = <String, List<int>>{
    'a.bin': [1, 2, 3],
    'b.bin': [4, 5],
    'archive.zip': [7, 8, 9],
  };
  data['archive.zip.checksum'] =
      ascii.encode('${sha256.convert(data['archive.zip']!)}\n');
  final assets = [
    for (final entry in data.entries)
      PrecompiledAsset(
        name: entry.key,
        length: entry.value.length,
        sha256: sha256.convert(entry.value).toString(),
      ),
  ]..sort((left, right) => left.name.compareTo(right.name));
  final manifest = PrecompiledGenerationManifest(
    generationHash: _storeGeneration,
    sourceCommit: _storeCommit,
    provenance: PrecompiledGenerationProvenance.fromRecipe(recipe),
    assets: assets,
    compositeChecksums: const [
      PrecompiledCompositeChecksum(
        archive: 'archive.zip',
        checksum: 'archive.zip.checksum',
      ),
    ],
  );
  return _StoreFixture(manifest, {
    '/$_storeGeneration/$precompiledGenerationManifestFileName':
        manifest.canonicalBytes(),
    '/$_storeGeneration/$precompiledGenerationManifestSignatureFileName':
        manifest.sign(keyPair.privateKey),
    for (final entry in data.entries) ...{
      '/$_storeGeneration/${entry.key}': entry.value,
      '/$_storeGeneration/${entry.key}.sig': signPrecompiledAssetMetadata(
        keyPair.privateKey,
        generationHash: _storeGeneration,
        name: entry.key,
        length: entry.value.length,
        sha256: sha256.convert(entry.value).toString(),
      ),
    },
  });
}

_StoreFixture _nestedStoreFixture(
    PrecompiledBuildRecipe recipe, KeyPair keyPair) {
  final bytes = <int>[6, 7, 8];
  final asset = PrecompiledAsset(
    name: 'nested/a.bin',
    length: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
  final manifest = PrecompiledGenerationManifest(
    generationHash: _storeGeneration,
    sourceCommit: _storeCommit,
    provenance: PrecompiledGenerationProvenance.fromRecipe(recipe),
    assets: [asset],
    compositeChecksums: const [],
  );
  return _StoreFixture(manifest, {
    '/$_storeGeneration/$precompiledGenerationManifestFileName':
        manifest.canonicalBytes(),
    '/$_storeGeneration/$precompiledGenerationManifestSignatureFileName':
        manifest.sign(keyPair.privateKey),
    '/$_storeGeneration/nested/a.bin': bytes,
    '/$_storeGeneration/nested/a.bin.sig': signPrecompiledAssetMetadata(
      keyPair.privateKey,
      generationHash: _storeGeneration,
      name: asset.name,
      length: asset.length,
      sha256: asset.sha256,
    ),
  });
}

_StoreFixture _variantFixture(
  _StoreFixture base,
  PrecompiledBuildRecipe recipe,
  KeyPair keyPair, {
  required String sourceCommit,
}) {
  final manifest = PrecompiledGenerationManifest(
    generationHash: _storeGeneration,
    sourceCommit: sourceCommit,
    provenance: PrecompiledGenerationProvenance.fromRecipe(recipe),
    assets: base.manifest.assets,
    compositeChecksums: base.manifest.compositeChecksums,
  );
  return _StoreFixture(manifest, {
    ...base.responses,
    '/$_storeGeneration/$precompiledGenerationManifestFileName':
        manifest.canonicalBytes(),
    '/$_storeGeneration/$precompiledGenerationManifestSignatureFileName':
        manifest.sign(keyPair.privateKey),
  });
}

PrecompiledAssetStore _store(
  String root,
  PrecompiledBuildRecipe recipe,
  KeyPair keyPair,
  _StoreFixture fixture, {
  List<String>? calls,
  PrecompiledRename? rename,
  PrecompiledRenameErrorClassifier? transientRenameError,
  void Function(String event, String filePath)? fileRecorder,
  PrecompiledHttpSend? send,
  void Function(String message)? logger,
  Uri? uriPrefix,
  PrecompiledAssetStorePolicy? policy,
  PrecompiledSleeper? sleeper,
  PrecompiledMonotonicClock? monotonicClock,
}) {
  return PrecompiledAssetStore(
    cacheRoot: root,
    uriPrefix: uriPrefix ?? Uri.parse('https://assets.example/'),
    publicKey: keyPair.publicKey,
    recipe: recipe,
    expectedAssetNames:
        fixture.manifest.assets.map((asset) => asset.name).toSet(),
    expectedCompositeChecksums: fixture.manifest.compositeChecksums
        .map((binding) => '${binding.archive}\u0000${binding.checksum}')
        .toSet(),
    transport: PrecompiledAssetTransport(
      fileRecorder: fileRecorder,
      send: send ??
          (request) async {
            calls?.add(request.url.path);
            final generationIndex = request.url.path.indexOf(_storeGeneration);
            final fixturePath = generationIndex < 0
                ? request.url.path
                : '/${request.url.path.substring(generationIndex)}';
            final bytes = fixture.responses[fixturePath];
            return bytes == null
                ? StreamedResponse(const Stream<List<int>>.empty(), 404)
                : StreamedResponse(
                    Stream.value(bytes),
                    200,
                    headers: {'content-length': '${bytes.length}'},
                  );
          },
    ),
    stagingId: () => 'test-${DateTime.now().microsecondsSinceEpoch}',
    rename: rename,
    transientRenameError: transientRenameError,
    fileRecorder: fileRecorder,
    logger: logger,
    policy: policy ?? const PrecompiledAssetStorePolicy(),
    sleeper: sleeper,
    monotonicClock: monotonicClock,
  );
}

class _WorkerHandle {
  _WorkerHandle(this.process, this.lines);

  final Process process;
  final StreamIterator<String> lines;

  Future<int> get exitCode => process.exitCode;

  Future<Map<String, dynamic>> next() async {
    if (!await lines.moveNext()) {
      throw StateError(
          'Worker exited before its next message (exit ${await process.exitCode}).');
    }
    final value = (jsonDecode(lines.current) as Map).cast<String, dynamic>();
    if (value['event'] == 'result' &&
        !value.keys
            .toSet()
            .containsAll(const {'event', 'ok', 'path', 'error'})) {
      throw StateError('Worker emitted an unstable result: $value');
    }
    return value;
  }

  Future<void> proceed() async {
    process.stdin.writeln(jsonEncode({'command': 'proceed'}));
    await process.stdin.flush();
  }

  Future<void> release() async {
    process.stdin.writeln(jsonEncode({'command': 'release'}));
    await process.stdin.flush();
    await process.stdin.close();
  }
}

Future<_WorkerHandle> _startWorker(String mode, String lockPath) async {
  return _startWorkerConfig({'mode': mode, 'lock_path': lockPath});
}

Future<_WorkerHandle> _startWorkerConfig(
    Map<String, dynamic> configuration) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    [
      'run',
      'test/support/precompiled_asset_store_worker.dart',
      jsonEncode(configuration),
    ],
    workingDirectory: Directory.current.path,
  );
  final lines = StreamIterator(
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
  );
  final worker = _WorkerHandle(process, lines);
  final ready = await worker.next();
  if (ready.keys.toSet().length != 2 ||
      ready['event'] != 'ready' ||
      ready['mode'] != configuration['mode']) {
    throw StateError('Worker did not emit ready: $ready');
  }
  return worker;
}

Map<String, dynamic> _installWorkerConfig({
  required String root,
  required String uriPrefix,
  required PrecompiledBuildRecipe recipe,
  required KeyPair keyPair,
  required _StoreFixture fixture,
  required List<String> requested,
  int lockTimeoutMs = 30000,
}) {
  return {
    'mode': 'install',
    'cache_root': root,
    'uri_prefix': uriPrefix,
    'public_key': keyPair.publicKey.bytes,
    'recipe': {
      'rust_toolchain': recipe.rustToolchain,
      'flutter_version': recipe.flutterVersion,
      'xcode_version': recipe.xcodeVersion,
      'sdk_versions': recipe.sdkVersions,
      'deployment_targets': recipe.deploymentTargets,
      'rust_targets': recipe.rustTargets,
    },
    'expected_asset_names':
        fixture.manifest.assets.map((asset) => asset.name).toList(),
    'expected_composites': fixture.manifest.compositeChecksums
        .map((binding) => '${binding.archive}\u0000${binding.checksum}')
        .toList(),
    'generation_hash': _storeGeneration,
    'requested_assets': requested,
    'lock_timeout_ms': lockTimeoutMs,
  };
}

class _FixtureServer {
  _FixtureServer(this.server, this.fixtures, this.requests, this.subscription);

  final HttpServer server;
  final Map<String, _StoreFixture> fixtures;
  final List<String> requests;
  final StreamSubscription<HttpRequest> subscription;

  static Future<_FixtureServer> start(
      Map<String, _StoreFixture> fixtures) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String>[];
    late StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      requests.add(request.uri.path);
      final prefixes = fixtures.keys.toList()
        ..sort((left, right) => right.length.compareTo(left.length));
      final prefix = prefixes.firstWhere(
        (candidate) => request.uri.path.startsWith(candidate),
        orElse: () => '/',
      );
      final fixture = fixtures[prefix];
      final markerIndex = request.uri.path.indexOf(_storeGeneration);
      final fixturePath = markerIndex < 0
          ? request.uri.path
          : '/${request.uri.path.substring(markerIndex)}';
      final bytes = fixture?.responses[fixturePath];
      if (bytes == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
      }
      await request.response.close();
    });
    return _FixtureServer(server, fixtures, requests, subscription);
  }

  String prefix(String pathPrefix) =>
      'http://${server.address.address}:${server.port}$pathPrefix';

  Future<void> close() async {
    await subscription.cancel();
    await server.close(force: true);
  }
}

bool _sameTestBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
