import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import '../utils/media_cache.dart';
import 'chat_crypto_service.dart';

const String kEncryptedPhotoExtension = '.png';

String decryptedCacheName(String cacheName) => 'decrypted_$cacheName';

class EncryptedPhotoResult {
  final File? file;
  final CryptoFailure? failure;

  const EncryptedPhotoResult.ok(File this.file) : failure = null;
  const EncryptedPhotoResult.failed(CryptoFailure this.failure) : file = null;

  bool get isOk => file != null;
}

/// Re-encodes an arbitrary image into lossless PNG. Encryption needs a format
/// that survives byte-for-byte; a re-encoded JPEG would not.
Future<File?> reencodeAsPng(File source, String destPath) async {
  try {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data == null) return null;
    final dest = File(destPath);
    await dest.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return dest;
  } catch (e) {
    logger.w('png re-encode failed: $e');
    return null;
  }
}

Future<Directory> _scratchDir() async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/komet_enc');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Picked image → PNG → encrypted noise PNG, ready to upload as a file.
Future<EncryptedPhotoResult> prepareEncryptedPhoto({
  required int accountId,
  required int chatId,
  required File source,
  required String stamp,
}) async {
  final dir = await _scratchDir();
  final pngPath = '${dir.path}/plain_$stamp.png';
  final encPath = '${dir.path}/enc_$stamp.png';

  final png = await reencodeAsPng(source, pngPath);
  if (png == null) {
    return const EncryptedPhotoResult.failed(CryptoFailure.malformed);
  }

  final failure = await ChatCryptoService.instance.encryptImageFile(
    accountId,
    chatId,
    png.path,
    encPath,
  );
  await _quietDelete(png);
  if (failure != null) return EncryptedPhotoResult.failed(failure);
  return EncryptedPhotoResult.ok(File(encPath));
}

/// Downloaded noise PNG → original photo, cached for the viewer.
Future<EncryptedPhotoResult> openEncryptedPhoto({
  required int accountId,
  required int chatId,
  required File encrypted,
  required String cacheName,
}) async {
  final target = await MediaCache.fileFor(decryptedCacheName(cacheName));
  if (await target.exists() && await target.length() > 0) {
    return EncryptedPhotoResult.ok(target);
  }
  final failure = await ChatCryptoService.instance.decryptImageFile(
    accountId,
    chatId,
    encrypted.path,
    target.path,
  );
  if (failure != null) {
    await _quietDelete(target);
    return EncryptedPhotoResult.failed(failure);
  }
  return EncryptedPhotoResult.ok(target);
}

Future<void> _quietDelete(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
