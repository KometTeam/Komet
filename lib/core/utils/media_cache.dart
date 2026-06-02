import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_media_cache.dart';

/// Постоянный дисковый кэш скачанных медиа (файлы, видео).
///
/// Хранит файлы в `<appSupport>/media_cache/` под детерминированным именем
/// (обычно по id вложения), чтобы повторные открытия не качали заново.
class MediaCache {
  /// Максимальный размер кэша (настраивается в дев-меню); при превышении
  /// вытесняются старые файлы (LRU).
  static int get maxBytes => AppMediaCacheLimit.current.value;

  static Directory? _dir;

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'media_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// Путь к кэш-файлу с именем [name] (файл может ещё не существовать).
  static Future<File> fileFor(String name) async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, _sanitize(name)));
  }

  /// Существует ли непустой кэш-файл [name].
  ///
  /// При попадании обновляет mtime файла — это делает вытеснение LRU
  /// (часто используемые файлы переживают очистку).
  static Future<File?> existing(String name) async {
    final file = await fileFor(name);
    if (await file.exists() && await file.length() > 0) {
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return file;
    }
    return null;
  }

  /// Возвращает кэш-файл [name], скачивая [url] при отсутствии.
  ///
  /// Загрузка идёт во временный `.part` и переименовывается атомарно —
  /// прерванная закачка не считается валидным кэшем.
  static Future<File?> getOrDownload(
    String name,
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final existingFile = await existing(name);
    if (existingFile != null) return existingFile;

    final file = await fileFor(name);
    final part = File('${file.path}.part');
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final total = response.contentLength;
      var received = 0;
      final sink = part.openWrite();
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
      await part.rename(file.path);
      await _enforceLimit();
      return file;
    } catch (_) {
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Суммарный размер кэша в байтах.
  static Future<int> currentSize() async {
    final dir = await _cacheDir();
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Полностью очищает кэш. Возвращает число удалённых байт.
  static Future<int> clear() async {
    final dir = await _cacheDir();
    var freed = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          freed += await entity.length();
          await entity.delete();
        } catch (_) {}
      }
    }
    return freed;
  }

  /// Вытесняет старые файлы (по mtime), пока размер превышает [maxBytes].
  static Future<void> _enforceLimit() async {
    final dir = await _cacheDir();
    final files = <File>[];
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File && !entity.path.endsWith('.part')) {
        files.add(entity);
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    if (maxBytes <= 0 || total <= maxBytes) return;

    files.sort((a, b) =>
        a.statSync().modified.compareTo(b.statSync().modified));

    for (final file in files) {
      if (total <= maxBytes) break;
      try {
        total -= await file.length();
        await file.delete();
      } catch (_) {}
    }
  }

  static String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}
