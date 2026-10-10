import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:komet_crypto/komet_crypto.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import '../storage/chat_encryption_store.dart';
import 'decrypted_photo_store.dart';
import 'chat_crypto_service.dart';

// #***! парольное фото уходит на сервер как png, сквозное как шифртекст без обёртки
const String kEncryptedPhotoExtension = '.png';
const String kE2eePhotoExtension = '.kce';
const int _ticketHeader =
    KometCryptoSizes.fileKey + KometCryptoSizes.fileNonce + 8;

// #***! имя из билета а не из дескриптора, иначе сервер подсунет чужую расшифровку
String decryptedCacheName(int accountId, int chatId, String cacheName) =>
    'decrypted_${accountId}_${chatId}_$cacheName';

String e2eeDecryptedCacheName(Uint8List ticket) {
  final digest = sha256.convert(ticket.sublist(0, _ticketHeader));
  return 'decrypted_e2ee_${digest.toString().substring(0, 40)}';
}

// #***! файл или причина неудачи
class EncryptedPhotoResult {
  final File? file;
  final CryptoFailure? failure;

  const EncryptedPhotoResult.ok(File this.file) : failure = null;
  const EncryptedPhotoResult.failed(CryptoFailure this.failure) : file = null;

  bool get isOk => file != null;
}

// #***! перед шифрованием гоним в png в памяти, жпег после перекодирования байт в байт не совпадёт
Future<Uint8List?> reencodeAsPng(File source) async {
  try {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data?.buffer.asUint8List();
  } catch (e) {
    logger.w('png re-encode failed: $e');
    return null;
  }
}

// #***! временная папка под шифртекст, открытого текста на диске нет
Future<Directory> _scratchDir() async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/komet_enc');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<EncryptedPhotoResult> prepareEncryptedPhoto({
  required int accountId,
  required int chatId,
  required File source,
  required String stamp,
}) async {
  final png = await reencodeAsPng(source);
  if (png == null) {
    return const EncryptedPhotoResult.failed(CryptoFailure.malformed);
  }
  final result = await ChatCryptoService.instance.encryptImageBytes(
    accountId,
    chatId,
    png,
  );
  if (!result.isOk) return EncryptedPhotoResult.failed(result.failure!);
  final dir = await _scratchDir();
  final encrypted = File('${dir.path}/enc_$stamp.png');
  await encrypted.writeAsBytes(result.bytes!, flush: true);
  return EncryptedPhotoResult.ok(encrypted);
}

// #***! скачанный шум обратно в фото, кладём в кэш просмотрщика
Future<EncryptedPhotoResult> openEncryptedPhoto({
  required int accountId,
  required int chatId,
  required File encrypted,
  required String cacheName,
}) async {
  final generation = DecryptedPhotoStore.generation;
  if (await ChatEncryptionStore.instance.readKey(accountId, chatId) == null ||
      generation != DecryptedPhotoStore.generation) {
    return const EncryptedPhotoResult.failed(CryptoFailure.noKey);
  }
  final name = decryptedCacheName(accountId, chatId, cacheName);
  final target = await DecryptedPhotoStore.existing(name);
  if (target != null) return EncryptedPhotoResult.ok(target);
  final result = await ChatCryptoService.instance.decryptImageBytes(
    accountId,
    chatId,
    await encrypted.readAsBytes(),
  );
  if (!result.isOk) return EncryptedPhotoResult.failed(result.failure!);
  if (generation != DecryptedPhotoStore.generation) {
    return const EncryptedPhotoResult.failed(CryptoFailure.noKey);
  }
  final file = await DecryptedPhotoStore.write(name, (part) async {
    await part.writeAsBytes(result.bytes!, flush: true);
  });
  return EncryptedPhotoResult.ok(file);
}

// #***! сквозное фото: свой ключ на файл, билет едет внутри рэтчет-сообщения
class E2eePhotoPrepared {
  final File file;
  final Uint8List ticket;

  const E2eePhotoPrepared(this.file, this.ticket);
}

Future<E2eePhotoPrepared?> prepareE2eePhoto({
  required File source,
  required String stamp,
}) async {
  final png = await reencodeAsPng(source);
  if (png == null) return null;
  final key = KometCrypto.randomBytes(KometCryptoSizes.fileKey);
  final nonce = KometCrypto.randomBytes(KometCryptoSizes.fileNonce);
  FileSealer? sealer;
  try {
    final out = BytesBuilder(copy: false);
    sealer = KometCrypto.fileSealer(key, nonce);
    var offset = 0;
    while (true) {
      final last = png.length - offset <= KometCryptoSizes.fileChunk;
      final end = last ? png.length : offset + KometCryptoSizes.fileChunk;
      out.add(sealer.chunk(png.sublist(offset, end), last: last));
      offset = end;
      if (last) break;
    }
    final dir = await _scratchDir();
    final file = File('${dir.path}/enc_$stamp$kE2eePhotoExtension');
    await file.writeAsBytes(out.toBytes(), flush: true);
    final name = Uint8List.fromList(utf8.encode('photo_$stamp.png'));
    final ticket = Uint8List(_ticketHeader + name.length);
    ticket.setAll(0, key);
    ticket.setAll(KometCryptoSizes.fileKey, nonce);
    var size = png.length;
    for (var i = _ticketHeader - 1; i >= _ticketHeader - 8; i--) {
      ticket[i] = size & 0xff;
      size >>= 8;
    }
    ticket.setAll(_ticketHeader, name);
    return E2eePhotoPrepared(file, ticket);
  } catch (error) {
    logger.w('e2ee photo seal: $error');
    return null;
  } finally {
    sealer?.dispose();
    KometCrypto.wipe(key);
  }
}

Future<EncryptedPhotoResult> openE2eePhoto({
  required File encrypted,
  required Uint8List ticket,
}) async {
  final generation = DecryptedPhotoStore.generation;
  if (ticket.length < _ticketHeader) {
    return const EncryptedPhotoResult.failed(CryptoFailure.malformed);
  }
  final name = e2eeDecryptedCacheName(ticket);
  final target = await DecryptedPhotoStore.existing(name);
  if (target != null) {
    return EncryptedPhotoResult.ok(target);
  }
  final key = ticket.sublist(0, KometCryptoSizes.fileKey);
  final nonce = ticket.sublist(KometCryptoSizes.fileKey, _ticketHeader - 8);
  const step = KometCryptoSizes.fileChunk + KometCryptoSizes.tag;
  // #***! блоками, размер выбирает сервер и в память вложение не влезет
  var expectedSize = 0;
  for (var i = _ticketHeader - 8; i < _ticketHeader; i++) {
    expectedSize = (expectedSize << 8) | ticket[i];
  }
  if (expectedSize <= 0 || expectedSize > DecryptedPhotoStore.maxBytes) {
    KometCrypto.wipe(key);
    return const EncryptedPhotoResult.failed(CryptoFailure.malformed);
  }
  if (generation != DecryptedPhotoStore.generation) {
    KometCrypto.wipe(key);
    return const EncryptedPhotoResult.failed(CryptoFailure.noKey);
  }
  try {
    final total = await encrypted.length();
    if (generation != DecryptedPhotoStore.generation) {
      return const EncryptedPhotoResult.failed(CryptoFailure.noKey);
    }
    final file = await DecryptedPhotoStore.write(name, (part) async {
      final source = await encrypted.open();
      IOSink? sink;
      FileOpener? opener;
      var written = 0;
      try {
        sink = part.openWrite();
        opener = KometCrypto.fileOpener(key, nonce);
        var offset = 0;
        while (true) {
          final last = total - offset <= step;
          final take = last ? total - offset : step;
          final block = await source.read(take);
          if (block.length != take) throw const FormatException('truncated');
          final plain = opener.chunk(block, last: last);
          written += plain.length;
          if (written > expectedSize) {
            throw const FormatException('invalid file size');
          }
          sink.add(plain);
          offset += take;
          if (last) break;
        }
        if (written != expectedSize) {
          throw const FormatException('invalid file size');
        }
        await sink.flush();
      } finally {
        opener?.dispose();
        try {
          await sink?.close();
        } finally {
          await source.close();
        }
      }
    });
    return EncryptedPhotoResult.ok(file);
  } catch (e) {
    logger.w('e2ee photo open: $e');
    return EncryptedPhotoResult.failed(cryptoFailureOf(e));
  } finally {
    KometCrypto.wipe(key);
  }
}
