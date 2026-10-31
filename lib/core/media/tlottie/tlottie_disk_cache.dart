import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../cache/cache_janitor.dart';
import '../../utils/logger.dart';

// #***! кадры кэшируем на диск, рендерить заново слишком дорого
class TlottieDiskCache {
  TlottieDiskCache._();
  static final TlottieDiskCache instance = TlottieDiskCache._();

  static const _extension = '.ktlf';
  static const _legacyDirName = 'rlottie_frames';
  // #***! под кадры отдаём 256 МБ
  static const int maxBytes = 256 * 1024 * 1024;

  Future<Directory>? _dirFuture;

  Future<Directory> _directory() {
    return _dirFuture ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/tlottie_frames');
      if (!await dir.exists()) await dir.create(recursive: true);
      unawaited(_dropLegacy(base));
      return dir;
    }();
  }

  Future<void> _dropLegacy(Directory base) async {
    final legacy = Directory('${base.path}/$_legacyDirName');
    try {
      if (await legacy.exists()) await legacy.delete(recursive: true);
    } catch (e) {
      logger.w('TlottieDiskCache legacy cleanup failed: $e');
    }
  }

  // #***! ключ это url плюс размер, на каждый размер свои кадры
  String _key(String url, int px) {
    final digest = sha1.convert(url.codeUnits).toString().substring(0, 20);
    return '${digest}_$px$_extension';
  }

  Future<String> pathFor(String url, int px) async {
    final dir = await _directory();
    return '${dir.path}/${_key(url, px)}';
  }

  void noteWritten() => CacheJanitor.instance.schedule();

  Future<List<File>> files() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) return const [];
      return await dir
          .list()
          .where((e) => e is File && e.path.endsWith(_extension))
          .cast<File>()
          .toList();
    } catch (e) {
      logger.w('TlottieDiskCache listing failed: $e');
      return const [];
    }
  }
}
