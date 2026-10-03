import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_media_cache.dart';
import 'logger.dart';
import '../storage/app_instance.dart';

// #***! дисковый кэш медиа, имя детерминированное поэтому повторно не качаем
/// Постоянный дисковый кэш скачанных медиа (файлы, видео).
///
/// Хранит файлы в `<appSupport>/media_cache/` под детерминированным именем
/// (обычно по id вложения), чтобы повторные открытия не качали заново.
class MediaCache {
  /// Максимальный размер кэша (настраивается в дев-меню); при превышении
  /// вытесняются старые файлы (LRU), кроме закреплённых.
  static int get maxBytes => AppMediaCacheLimit.current.value;

  static const String keptPrefix = 'keep_';

  // #***! размер держим в памяти, каталог не пересканируем
  static Directory? _dir;
  static int? _cachedSize;
  static final Map<String, Future<File?>> _inFlight = {};
  static final Set<String> _present = {};
  static final Map<String, ValueNotifier<bool>> _presence = {};

  @visibleForTesting
  static void resetForTesting() {
    _dir = null;
    _cachedSize = null;
    _inFlight.clear();
    _present.clear();
    for (final notifier in _presence.values) {
      notifier.dispose();
    }
    _presence.clear();
  }

  // #***! у каждой копии приложения свой каталог
  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(base.path, 'media_cache${AppInstance.suffix}'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// Имя закреплённой копии файла [name].
  ///
  /// Закреплённые файлы не вытесняются по LRU: удалённое медиа сервер уже
  /// стёр, скачать его заново неоткуда.
  static String keptName(String name) => '$keptPrefix${_sanitize(name)}';

  /// Кладёт [name] в закреплённую часть кэша — копией готового [source]
  /// либо загрузкой [url]. Возвращает закреплённый файл.
  static Future<File?> keep(String name, {File? source, String? url}) async {
    final pinned = keptName(name);
    final ready = await existing(pinned);
    if (ready != null) return ready;
    if (source != null) {
      try {
        final target = await fileFor(pinned);
        await source.copy(target.path);
        _markPresent(pinned, true);
        _cachedSize = null;
        return target;
      } catch (e) {
        logger.w('[cache] не закрепил $name: $e');
      }
    }
    if (url == null || url.isEmpty) return null;
    return getOrDownload(pinned, url);
  }

  /// Путь к кэш-файлу с именем [name] (файл может ещё не существовать).
  static Future<File> fileFor(String name) async {
    final dir = await _cacheDir();
    return File(p.join(dir.path, _sanitize(name)));
  }

  static Future<List<File>> files() async {
    final dir = await _cacheDir();
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && !entity.path.endsWith('.part')) files.add(entity);
    }
    return files;
  }

  // #***! попадание обновляет mtime, на нём держится LRU
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
      _markPresent(name, true);
      return file;
    }
    _markPresent(name, false);
    return null;
  }

  static Future<void> discard(String name) async {
    final file = await fileFor(name);
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      logger.w('[cache] не удалил $name: $e');
    }
    _markPresent(name, false);
    _cachedSize = null;
  }

  // #***! скачивание с защитой от параллельных запросов
  /// Возвращает кэш-файл [name], скачивая [url] при отсутствии.
  ///
  /// Загрузка идёт во временный `.part` и переименовывается атомарно —
  /// прерванная закачка не считается валидным кэшем.
  // #***! maxBytes рвёт поток, объявленный килобайт бывает гигабайтами
  static Future<File?> getOrDownload(
    String name,
    String url, {
    void Function(double progress)? onProgress,
    int? maxBytes,
  }) async {
    final existingFile = await existing(name);
    if (existingFile != null) return existingFile;

    final running = _inFlight[name];
    if (running != null) return running;

    final future = _download(name, url, onProgress, maxBytes);
    _inFlight[name] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(name);
    }
  }

  // #***! качаем в .part и переименовываем, недокачанное не станет валидным кэшем
  static Future<File?> _download(
    String name,
    String url,
    void Function(double progress)? onProgress,
    int? maxBytes,
  ) async {
    final file = await fileFor(name);
    final part = File('${file.path}.part');
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final total = response.contentLength;
      // #***! сервер врёт и в обещанном размере, и в потоке
      if (maxBytes != null && total > maxBytes) {
        logger.w('[cache] $name: обещано $total байт, предел $maxBytes');
        return null;
      }
      var received = 0;
      final sink = part.openWrite();
      var overflowed = false;
      await for (final chunk in response) {
        received += chunk.length;
        if (maxBytes != null && received > maxBytes) {
          overflowed = true;
          break;
        }
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
      if (overflowed) {
        logger.w('[cache] $name: поток превысил предел $maxBytes байт');
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {}
        return null;
      }
      await part.rename(file.path);
      _markPresent(name, true);
      final known = _cachedSize;
      if (known != null) {
        try {
          _cachedSize = known + await file.length();
        } catch (_) {}
      }
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

  // #***! размер считаем инкрементально
  /// Суммарный размер кэша в байтах.
  ///
  /// Результат держится в памяти и поддерживается инкрементально при
  /// загрузке/очистке/вытеснении — повторные вызовы не пересканируют каталог.
  static Future<int> currentSize() async {
    final cached = _cachedSize;
    if (cached != null) return cached;
    final total = await _scanSize();
    _cachedSize = total;
    return total;
  }

  static Future<int> _scanSize() async {
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
    _cachedSize = 0;
    _present.clear();
    for (final notifier in _presence.values) {
      notifier.value = false;
    }
    return freed;
  }

  // #***! под лимитом выходим сразу, каталог обходим только при превышении
  /// Вытесняет старые файлы (по mtime), пока размер превышает [maxBytes].
  ///
  /// Под лимитом — ранний выход без сканирования каталога (частый случай).
  /// Каталог обходится только когда лимит реально превышен.
  static Future<void> _enforceLimit() async {
    final limit = maxBytes;
    if (limit <= 0) return;

    var total = _cachedSize ?? await _scanSize();
    if (total <= limit) {
      _cachedSize = total;
      return;
    }

    final dir = await _cacheDir();
    // #***! stat снимаем по разу на файл: в компараторе он звался бы
    // синхронно и по два раза на сравнение, то есть тысячи блокирующих
    // сисколлов на изоляте интерфейса
    final entries = <({File file, DateTime modified, int size})>[];
    await for (final entity in dir.list()) {
      if (entity is! File || entity.path.endsWith('.part')) continue;
      if (p.basename(entity.path).startsWith(keptPrefix)) continue;
      try {
        final stat = await entity.stat();
        entries.add((file: entity, modified: stat.modified, size: stat.size));
      } catch (_) {}
    }

    // #***! сортируем по времени доступа и удаляем старое
    entries.sort((a, b) => a.modified.compareTo(b.modified));

    for (final entry in entries) {
      if (total <= limit) break;
      try {
        await entry.file.delete();
        total -= entry.size;
        _markAbsentByBasename(p.basename(entry.file.path));
      } catch (_) {}
    }
    _cachedSize = total;
  }

  // #***! флаг файл скачан для иконки в пузыре
  /// Реактивный флаг наличия файла [name] в кэше (для UI-иконки «скачано»).
  static ValueListenable<bool> presence(String name) {
    final key = _sanitize(name);
    return _presence.putIfAbsent(key, () {
      final notifier = ValueNotifier(_present.contains(key));
      if (!notifier.value) existing(name).ignore();
      return notifier;
    });
  }

  static void _markPresent(String name, bool present) {
    final key = _sanitize(name);
    final changed = present ? _present.add(key) : _present.remove(key);
    if (!changed) return;
    _presence[key]?.value = present;
  }

  static void _markAbsentByBasename(String basename) {
    if (_present.remove(basename)) {
      _presence[basename]?.value = false;
    }
  }

  // #***! запрещённые символы в имени в подчёркивания
  static String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'file' : cleaned;
  }
}
