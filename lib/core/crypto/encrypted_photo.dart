import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:komet_crypto/komet_crypto.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import '../utils/media_cache.dart';
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
  final target = await MediaCache.fileFor(
    decryptedCacheName(accountId, chatId, cacheName),
  );
  if (await target.exists() && await target.length() > 0) {
    return EncryptedPhotoResult.ok(target);
  }
  final result = await ChatCryptoService.instance.decryptImageBytes(
    accountId,
    chatId,
    await encrypted.readAsBytes(),
  );
  if (!result.isOk) return EncryptedPhotoResult.failed(result.failure!);
  await target.writeAsBytes(result.bytes!, flush: true);
  return EncryptedPhotoResult.ok(target);
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
  final out = BytesBuilder(copy: false);
  try {
    final sealer = KometCrypto.fileSealer(key, nonce);
    var offset = 0;
    while (true) {
      final last = png.length - offset <= KometCryptoSizes.fileChunk;
      final end = last ? png.length : offset + KometCryptoSizes.fileChunk;
      out.add(sealer.chunk(png.sublist(offset, end), last: last));
      offset = end;
      if (last) break;
    }
    sealer.dispose();
  } catch (e) {
    logger.w('e2ee photo seal: $e');
    return null;
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
  KometCrypto.wipe(key);
  return E2eePhotoPrepared(file, ticket);
}

Future<EncryptedPhotoResult> openE2eePhoto({
  required File encrypted,
  required Uint8List ticket,
}) async {
  if (ticket.length < _ticketHeader) {
    return const EncryptedPhotoResult.failed(CryptoFailure.malformed);
  }
  final target = await MediaCache.fileFor(e2eeDecryptedCacheName(ticket));
  if (await target.exists() && await target.length() > 0) {
    return EncryptedPhotoResult.ok(target);
  }
  final key = ticket.sublist(0, KometCryptoSizes.fileKey);
  final nonce = ticket.sublist(KometCryptoSizes.fileKey, _ticketHeader - 8);
  const step = KometCryptoSizes.fileChunk + KometCryptoSizes.tag;
  final total = await encrypted.length();
  // #***! блоками, размер выбирает сервер и в память вложение не влезет
  final source = await encrypted.open();
  final sink = target.openWrite();
  try {
    final opener = KometCrypto.fileOpener(key, nonce);
    try {
      var offset = 0;
      while (true) {
        final last = total - offset <= step;
        final take = last ? total - offset : step;
        final block = await source.read(take);
        if (block.length != take) throw const FormatException('truncated');
        sink.add(opener.chunk(block, last: last));
        offset += take;
        if (last) break;
      }
    } finally {
      opener.dispose();
    }
    await sink.close();
  } catch (e) {
    logger.w('e2ee photo open: $e');
    try {
      await sink.close();
    } catch (_) {}
    try {
      if (await target.exists()) await target.delete();
    } catch (_) {}
    return EncryptedPhotoResult.failed(cryptoFailureOf(e));
  } finally {
    KometCrypto.wipe(key);
    await source.close();
  }
  return EncryptedPhotoResult.ok(target);
}
