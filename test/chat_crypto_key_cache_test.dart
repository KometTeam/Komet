import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/chat_crypto_key_cache.dart';

void main() {
  test('rejects a derivation completed after keys are cleared', () async {
    final oldDerivation = Completer<Uint8List?>();
    final newDerivation = Completer<Uint8List?>();
    var derivations = 0;
    final cache = ChatCryptoKeyCache((accountId, chatId) {
      derivations++;
      return derivations == 1 ? oldDerivation.future : newDerivation.future;
    });

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
      });

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
      });

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
        return derivation.future;
      });

      final key = cache.keyFor(101, 202);
      expect(identical(cache.keyFor(101, 202), key), isTrue);
      derivation.complete(Uint8List.fromList([3, 3, 3]));
      expect(await key, [3, 3, 3]);
      expect(await cache.keyFor(101, 202), [3, 3, 3]);
      expect(derivations, 1);
      expect(await cache.keyFor(102, 202), [3, 3, 3]);
      expect(await cache.keyFor(101, 203), [3, 3, 3]);
      expect(derivations, 3);
    },
  );

  test('retries a missing key instead of caching it', () async {
    var derivations = 0;
    final cache = ChatCryptoKeyCache((accountId, chatId) async {
      derivations++;
      return derivations == 1 ? null : Uint8List.fromList([4, 4, 4]);
    });

    expect(await cache.keyFor(101, 202), isNull);
    expect(await cache.keyFor(101, 202), [4, 4, 4]);
    expect(derivations, 2);
  });
}
