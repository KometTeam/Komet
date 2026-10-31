import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../cache/cache_janitor.dart';
import '../config/app_cache_limit.dart';
import 'logger.dart';
import '../storage/app_instance.dart';

// #***! дисковый кэш медиа, имя детерминированное поэтому повторно не качаем
/// Постоянный дисковый кэш скачанных медиа (файлы, видео).
///
/// Хранит файлы в `<appSupport>/media_cache/` под детерминированным именем
/// (обычно по id вложения), чтобы повторные открытия не качали заново.
class MediaCache {
  /// Общий лимит кэша из настроек памяти: файл крупнее него не скачиваем,
  /// а вытеснение старых файлов (LRU) ведёт [CacheJanitor].
  static int get maxBytes => AppCacheLimit.current.value;

  static const String keptPrefix = 'keep_';
  static const int maxSingleFileBytes = 128 * 1024 * 1024;
  static const int maxPinnedBytes = 128 * 1024 * 1024;
  static int _generation = 0;
  static Future<void> _mutations = Future.value();

  static Future<T> _mutate<T>(Future<T> Function() action) {
    final next = _mutations.then((_) => action());
    _mutations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  static Directory? _dir;
  static final Map<String, Future<File?>> _inFlight = {};
  static final Set<String> _present = {};
  static final Map<String, ValueNotifier<bool>> _presence = {};

  @visibleForTesting
  static void resetForTesting() {
    _generation++;
    _mutations = Future.value();
    _dir = null;
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
        final generation = _generation;
        final dir = await _cacheDir();
        final staging = await dir.createTemp('writing_');
        try {
          final length = await source.length();
          if (length <= 0 || length > maxSingleFileBytes) return null;
          final part = await source.copy(p.join(staging.path, 'content.part'));
          return await _mutate(() async {
            if (generation != _generation ||
                !await _pinnedFits(pinned, await part.length())) {
              return null;
            }
            final target = await part.rename((await fileFor(pinned)).path);
            _markPresent(pinned, true);
            return target;
          });
        } finally {
          if (await staging.exists()) await staging.delete(recursive: true);
        }
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

  static Future<String> directoryPath() async => (await _cacheDir()).path;

  static Future<int> remove(Iterable<String> names) => _mutate(() async {
    final dir = await _cacheDir();
    var freed = 0;
    for (final name in names) {
      if (_isInFlight(name)) continue;
      final file = File(p.join(dir.path, name));
      try {
        final size = await file.length();
        await file.delete();
        freed += size;
        _markAbsentByBasename(name);
      } catch (_) {}
    }
    return freed;
  });

  static bool _isInFlight(String name) =>
      _inFlight.keys.any((key) => _sanitize(key) == name);

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

  static Future<void> discard(String name) => _mutate(() async {
    final file = await fileFor(name);
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      logger.w('[cache] не удалил $name: $e');
    }
    _markPresent(name, false);
  });

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
    Map<String, String> headers = const {},
  }) async {
    name = _sanitize(name);
    final existingFile = await existing(name);
    if (existingFile != null) return existingFile;

    final running = _inFlight[name];
    if (running != null) return running;

    final future = _download(name, url, onProgress, maxBytes, headers);
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
    Map<String, String> headers,
  ) async {
    final generation = _generation;
    final file = await fileFor(name);
    final part = File('${file.path}.part');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? sink;
    final pinned = _sanitize(name).startsWith(keptPrefix);
    final quota = MediaCache.maxBytes;
    final requestedCap = maxBytes ?? maxSingleFileBytes;
    final hardCap = requestedCap < maxSingleFileBytes
        ? requestedCap
        : maxSingleFileBytes;
    final cap = !pinned && quota > 0 && quota < hardCap ? quota : hardCap;
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) return null;

      final total = response.contentLength;
      // #***! сервер врёт и в обещанном размере, и в потоке
      if (total > cap) {
        logger.w('[cache] $name: обещано $total байт, предел $cap');
        return null;
      }
      var received = 0;
      sink = part.openWrite();
      var overflowed = false;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        received += chunk.length;
        if (received > cap) {
          overflowed = true;
          break;
        }
        sink.add(chunk);
        if (onProgress != null && total > 0) {
          onProgress(received / total);
        }
      }
      await sink.close();
      sink = null;
      if (total >= 0 && received != total) {
        throw const FormatException('Incomplete download');
      }
      if (overflowed) {
        logger.w('[cache] $name: поток превысил предел $cap байт');
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {}
        return null;
      }
      if (received == 0) return null;
      return await _mutate(() async {
        if (generation != _generation ||
            (pinned && !await _pinnedFits(name, received))) {
          return null;
        }
        await part.rename(file.path);
        _markPresent(name, true);
        if (!pinned) {
          CacheJanitor.instance.noteWrite(CacheStore.media, received);
        }
        return await file.exists() ? file : null;
      });
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      sink = null;
      if (await part.exists()) {
        try {
          await part.delete();
        } catch (_) {}
      }
      return null;
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      client.close(force: true);
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
    }
  }

  /// Полностью очищает кэш. Возвращает число удалённых байт.
  static Future<int> clear() {
    _generation++;
    return _mutate(() async {
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
      _present.clear();
      for (final notifier in _presence.values) {
        notifier.value = false;
      }
      return freed;
    });
  }

  static Future<bool> _pinnedFits(String name, int incoming) async {
    var total = incoming;
    for (final file in await files()) {
      final basename = p.basename(file.path);
      if (basename != _sanitize(name) && basename.startsWith(keptPrefix)) {
        total += await file.length();
      }
    }
    return total <= maxPinnedBytes;
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
