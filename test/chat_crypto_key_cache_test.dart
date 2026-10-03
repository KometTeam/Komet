import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/chat_crypto_key_cache.dart';

void _wipe(Uint8List key) => key.fillRange(0, key.length, 0);

void main() {
  test('rejects a derivation completed after keys are cleared', () async {
    final oldDerivation = Completer<Uint8List?>();
    final newDerivation = Completer<Uint8List?>();
    var derivations = 0;
    final cache = ChatCryptoKeyCache((accountId, chatId) {
      derivations++;
      return derivations == 1 ? oldDerivation.future : newDerivation.future;
    }, wipe: _wipe);

    final oldKey = cache.keyFor(101, 202);
    cache.clear();
    final newKey = cache.keyFor(101, 202);
    newDerivation.complete(Uint8List.fromList([2, 2, 2]));
    expect(await newKey, [2, 2, 2]);

    oldDerivation.complete(Uint8List.fromList([1, 1, 1]));
    expect(await oldKey, isNull);
    expect(await cache.keyFor(101, 202), [2, 2, 2]);
    expect(derivations, 2);
  });

  test(
    'obsolete success preserves the replacement pending derivation',
    () async {
      final oldDerivation = Completer<Uint8List?>();
      final newDerivation = Completer<Uint8List?>();
      var derivations = 0;
      final cache = ChatCryptoKeyCache((accountId, chatId) {
        derivations++;
        return derivations == 1 ? oldDerivation.future : newDerivation.future;
      }, wipe: _wipe);

      final oldKey = cache.keyFor(101, 202);
      cache.clear();
      final newKey = cache.keyFor(101, 202);
      oldDerivation.complete(Uint8List.fromList([1, 1, 1]));
      expect(await oldKey, isNull);

      final sharedKey = cache.keyFor(101, 202);
      expect(identical(sharedKey, newKey), isTrue);
      expect(derivations, 2);
      newDerivation.complete(Uint8List.fromList([2, 2, 2]));
      expect(await newKey, [2, 2, 2]);
      expect(await sharedKey, [2, 2, 2]);
    },
  );

  test(
    'obsolete failure preserves the replacement pending derivation',
    () async {
      final oldDerivation = Completer<Uint8List?>();
      final newDerivation = Completer<Uint8List?>();
      var derivations = 0;
      final cache = ChatCryptoKeyCache((accountId, chatId) {
        derivations++;
        return derivations == 1 ? oldDerivation.future : newDerivation.future;
      }, wipe: _wipe);

      final oldKey = cache.keyFor(101, 202);
      final failure = expectLater(oldKey, throwsStateError);
      cache.clear();
      final newKey = cache.keyFor(101, 202);
      oldDerivation.completeError(StateError('synthetic derivation failure'));
      await failure;

      final sharedKey = cache.keyFor(101, 202);
      expect(identical(sharedKey, newKey), isTrue);
      expect(derivations, 2);
      newDerivation.complete(Uint8List.fromList([2, 2, 2]));
      expect(await newKey, [2, 2, 2]);
      expect(await sharedKey, [2, 2, 2]);
    },
  );

  test(
    'shares pending keys and reuses completed keys by chat and account',
    () async {
      final derivation = Completer<Uint8List?>();
      var derivations = 0;
      final cache = ChatCryptoKeyCache((accountId, chatId) {
        derivations++;
        if (derivations == 1) return derivation.future;
        return Future.value(Uint8List.fromList([accountId, chatId]));
      }, wipe: _wipe);

      final key = cache.keyFor(101, 202);
      expect(identical(cache.keyFor(101, 202), key), isTrue);
      derivation.complete(Uint8List.fromList([3, 3, 3]));
      expect(await key, [3, 3, 3]);
      expect(await cache.keyFor(101, 202), [3, 3, 3]);
      expect(derivations, 1);
      expect(await cache.keyFor(102, 202), [102, 202]);
      expect(await cache.keyFor(101, 203), [101, 203]);
      expect(derivations, 3);
    },
  );

  test('retries a missing key instead of caching it', () async {
    var derivations = 0;
    final cache = ChatCryptoKeyCache((accountId, chatId) async {
      derivations++;
      return derivations == 1 ? null : Uint8List.fromList([4, 4, 4]);
    }, wipe: _wipe);

    expect(await cache.keyFor(101, 202), isNull);
    expect(await cache.keyFor(101, 202), [4, 4, 4]);
    expect(derivations, 2);
  });

  test(
    'clear wipes cached keys and a derivation that finished too late',
    () async {
      final lateDerivation = Completer<Uint8List?>();
      final cached = Uint8List.fromList([5, 5, 5]);
      final late = Uint8List.fromList([6, 6, 6]);
      final cache = ChatCryptoKeyCache(
        (accountId, chatId) =>
            chatId == 202 ? Future.value(cached) : lateDerivation.future,
        wipe: _wipe,
      );

      expect(await cache.keyFor(101, 202), [5, 5, 5]);
      final pending = cache.keyFor(101, 203);
      cache.clear();
      lateDerivation.complete(late);

      expect(await pending, isNull);
      expect(cached, [0, 0, 0]);
      expect(late, [0, 0, 0]);
    },
  );
}
