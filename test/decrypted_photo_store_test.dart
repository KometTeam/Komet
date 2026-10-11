import 'dart:async';
import 'dart:io';
import 'package:komet_crypto/komet_crypto.dart';
import 'package:komet/core/crypto/encrypted_photo.dart';
import 'package:komet/core/crypto/chat_crypto_service.dart';
import 'package:komet/core/crypto/noise_png.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/decrypted_photo_store.dart';
import 'package:komet/core/utils/media_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = File(
    'native/crypto-core/build/${Platform.isWindows
        ? 'komet_crypto.dll'
        : Platform.isMacOS
        ? 'libkomet_crypto.dylib'
        : 'libkomet_crypto.so'}',
  );
  late Directory temp;
  setUpAll(() async {
    if (await library.exists()) KometCrypto.libraryPath = library.absolute.path;
    temp = await Directory.systemTemp.createTemp('komet-photo-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );
  });
  tearDownAll(() async {
    await DecryptedPhotoStore.clear();
    MediaCache.resetForTesting();
    await temp.delete(recursive: true);
  });
  test('migrates old plaintext out of the persistent media cache', () async {
    final legacy = await MediaCache.fileFor('decrypted_101_201_synthetic');
    await legacy.writeAsBytes([1, 2, 3]);
    await DecryptedPhotoStore.clear();
    expect(await legacy.exists(), isFalse);
  });
  test(
    'the image worker decrypts once using the native crypto library',
    () async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => 'synthetic-password',
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        ChatCryptoService.instance.clearKeys();
      });
      final key = KometCrypto.deriveKey('synthetic-password');
      try {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final wrapped = wrapNoisePng(KometCrypto.encryptImageBlob(bytes, key));
        final result = await ChatCryptoService.instance.decryptImageBytes(
          101,
          201,
          wrapped!,
        );
        expect(result.failure, isNull);
        expect(result.bytes, bytes);
      } finally {
        KometCrypto.wipe(key);
      }
    },
  );

  test('aggregate quota rejects a third maximum-size plaintext file', () async {
    await DecryptedPhotoStore.clear();
    Future<File> write(String name) =>
        DecryptedPhotoStore.write(name, (part) async {
          final handle = await part.open(mode: FileMode.write);
          try {
            await handle.truncate(DecryptedPhotoStore.maxBytes);
          } finally {
            await handle.close();
          }
        });
    await write('quota-first');
    await write('quota-second');
    await expectLater(write('quota-third'), throwsFormatException);
    expect(await DecryptedPhotoStore.existing('quota-third'), isNull);
    expect(await DecryptedPhotoStore.existing('quota-first'), isNotNull);
    await DecryptedPhotoStore.clear();
  });

  test('publishes only completely written files', () async {
    final started = Completer<void>(), finish = Completer<void>();
    final job = DecryptedPhotoStore.write('synthetic', (part) async {
      await part.writeAsBytes([1, 2]);
      started.complete();
      await finish.future;
      await part.writeAsBytes([1, 2, 3, 4]);
    });
    await started.future;
    expect(await DecryptedPhotoStore.existing('synthetic'), isNull);
    finish.complete();
    final file = await job;
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect((await DecryptedPhotoStore.existing('synthetic'))?.path, file.path);
  });
  test('rejects a write completed after a key generation change', () async {
    final started = Completer<void>(), finish = Completer<void>();
    final job = DecryptedPhotoStore.write('late', (part) async {
      await part.writeAsBytes([1, 2]);
      started.complete();
      await finish.future;
    });
    final assertion = expectLater(job, throwsStateError);
    await started.future;
    await DecryptedPhotoStore.clear();
    finish.complete();
    await assertion;
    expect(await DecryptedPhotoStore.existing('late'), isNull);
  });
  test('failed writes leave no readable partial result', () async {
    await expectLater(
      DecryptedPhotoStore.write('failed', (part) async {
        await part.writeAsBytes([1, 2]);
        throw const FormatException('synthetic');
      }),
      throwsFormatException,
    );
    expect(await DecryptedPhotoStore.existing('failed'), isNull);
  });
  for (final corrupted in [false, true]) {
    test(
      corrupted
          ? 'authentication failure never publishes a partial E2EE file'
          : 'ticket size mismatch never publishes an E2EE file',
      () async {
        final key = KometCrypto.randomBytes(KometCryptoSizes.fileKey);
        final nonce = KometCrypto.randomBytes(KometCryptoSizes.fileNonce);
        final sealer = KometCrypto.fileSealer(key, nonce);
        try {
          final encryptedBytes = sealer.chunk(
            Uint8List.fromList([1, 2, 3, 4]),
            last: true,
          );
          if (corrupted) encryptedBytes[0] ^= 1;
          final encrypted = File('${temp.path}/synthetic-$corrupted.kce');
          await encrypted.writeAsBytes(encryptedBytes);
          final ticket = Uint8List(
            KometCryptoSizes.fileKey + KometCryptoSizes.fileNonce + 8,
          );
          ticket.setAll(0, key);
          ticket.setAll(KometCryptoSizes.fileKey, nonce);
          ByteData.sublistView(
            ticket,
          ).setUint64(ticket.length - 8, corrupted ? 4 : 5);
          final opened = await openE2eePhoto(
            encrypted: encrypted,
            ticket: ticket,
          );
          expect(opened.isOk, isFalse);
          expect(
            await DecryptedPhotoStore.existing(e2eeDecryptedCacheName(ticket)),
            isNull,
          );
        } finally {
          sealer.dispose();
          KometCrypto.wipe(key);
        }
      },
      skip: !library.existsSync(),
    );
  }
}
