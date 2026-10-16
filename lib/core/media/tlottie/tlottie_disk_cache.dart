import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

// #***! кадры кэшируем на диск, рендерить заново слишком дорого
class TlottieDiskCache {
  TlottieDiskCache._();
  static final TlottieDiskCache instance = TlottieDiskCache._();

  static const _extension = '.ktlf';
  static const _legacyDirName = 'rlottie_frames';
  // #***! под кадры отдаём 256 МБ
  static const int _maxBytes = 256 * 1024 * 1024;
  static const Duration _evictDelay = Duration(seconds: 2);

  Directory? _dir;
  Future<Directory>? _dirFuture;
  Timer? _evictTimer;

  Future<Directory> _directory() {
    return _dirFuture ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/tlottie_frames');
      if (!await dir.exists()) await dir.create(recursive: true);
      unawaited(_dropLegacy(base));
      _dir = dir;
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

  void noteWritten() {
    _evictTimer?.cancel();
    _evictTimer = Timer(_evictDelay, () {
      _evictTimer = null;
      unawaited(_evict());
    });
  }

  // #***! вытеснение по времени доступа
  Future<void> _evict() async {
    try {
      final dir = _dir ?? await _directory();
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith(_extension))
          .cast<File>()
          .toList();
      var total = 0;
      final stats = <(File, FileStat)>[];
      for (final f in files) {
        final st = await f.stat();
        total += st.size;
        stats.add((f, st));
      }
      if (total <= _maxBytes) return;
      stats.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, st) in stats) {
        if (total <= _maxBytes) break;
        total -= st.size;
        await file.delete().catchError((_) => file);
      }
    } catch (e) {
      logger.w('TlottieDiskCache.evict failed: $e');
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
      _dirFuture = null;
    } catch (_) {}
  }
}
