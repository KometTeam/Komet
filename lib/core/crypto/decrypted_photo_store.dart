import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../storage/app_instance.dart';
import '../utils/media_cache.dart';
import '../utils/logger.dart';

class DecryptedPhotoStore {
  DecryptedPhotoStore._();
  static Future<Directory>? _initialization;
  static int _generation = 0;
  static int get generation => _generation;
  static const int maxBytes = 64 * 1024 * 1024;
  static const int maxTotalBytes = 128 * 1024 * 1024;
  static Future<void> _publications = Future.value();

  static Future<T> _publish<T>(Future<T> Function() action) {
    final next = _publications.then((_) => action());
    _publications = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  static Future<Directory> _root() => _initialization ??= () async {
    final root = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'komet_decrypted${AppInstance.suffix}',
      ),
    );
    if (await root.exists()) await root.delete(recursive: true);
    await root.create(recursive: true);
    for (final file in await MediaCache.files()) {
      final name = p.basename(file.path);
      if (name.startsWith('decrypted_')) await MediaCache.discard(name);
    }
    return root;
  }();

  static String _filename(String name) =>
      sha256.convert(utf8.encode(name)).toString();

  static Future<File?> existing(String name) async {
    final generation = _generation;
    final root = await _root();
    final file = File(p.join(root.path, '$generation', _filename(name)));
    if (generation != _generation ||
        !await file.exists() ||
        await file.length() == 0) {
      return null;
    }
    return generation == _generation ? file : null;
  }

  static Future<File> write(
    String name,
    Future<void> Function(File) fill,
  ) async {
    final generation = _generation;
    final root = await _root();
    if (generation != _generation) {
      throw StateError('Encryption context changed');
    }
    final staging = await root.createTemp('writing_${generation}_');
    final part = File(p.join(staging.path, 'content.part'));
    try {
      if (generation != _generation) {
        throw StateError('Encryption context changed');
      }
      await fill(part);
      if (generation != _generation) {
        throw StateError('Encryption context changed');
      }
      if (!await part.exists() ||
          await part.length() == 0 ||
          await part.length() > maxBytes) {
        throw const FormatException('Empty decrypted file');
      }
      return await _publish(() async {
        final dir = Directory(p.join(root.path, '$generation'));
        await dir.create(recursive: true);
        var total = await part.length();
        final filename = _filename(name);
        await for (final entity in dir.list()) {
          if (entity is File && p.basename(entity.path) != filename) {
            total += await entity.length();
          }
        }
        if (total > maxTotalBytes) {
          throw const FormatException('Decrypted cache quota exceeded');
        }
        if (generation != _generation) {
          throw StateError('Encryption context changed');
        }
        final target = await part.rename(p.join(dir.path, filename));
        if (generation != _generation) {
          await target.delete();
          throw StateError('Encryption context changed');
        }
        return target;
      });
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  static Future<void> clear() async {
    final generation = ++_generation;
    final root = await _root();
    await for (final entry in root.list()) {
      if (entry is Directory) {
        final name = p.basename(entry.path);
        final oldGeneration =
            int.tryParse(name) ??
            int.tryParse(
              RegExp(r'^writing_(\d+)_').firstMatch(name)?.group(1) ?? '',
            );
        if (oldGeneration != null && oldGeneration < generation) {
          try {
            await entry.delete(recursive: true);
          } on FileSystemException catch (error) {
            logger.w('decrypted cache cleanup: $error');
          }
        }
      }
    }
  }
}
