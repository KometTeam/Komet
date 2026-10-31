import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/app_cache_limit.dart';
import '../media/tlottie/tlottie_disk_cache.dart';
import '../storage/app_database.dart';
import '../utils/logger.dart';
import '../utils/media_cache.dart';
import '../utils/media_cache_names.dart';

enum StorageCategory {
  photos,
  videos,
  files,
  voice,
  stickers,
  keptMedia,
  database,
}

extension StorageCategoryRole on StorageCategory {
  bool get clearable => this != StorageCategory.database;

  bool get evictable => clearable && this != StorageCategory.keptMedia;
}

class StorageReport {
  const StorageReport(this.bytes);

  final Map<StorageCategory, int> bytes;

  int of(StorageCategory category) => bytes[category] ?? 0;

  int get total => bytes.values.fold(0, (sum, size) => sum + size);
}

class CacheJanitor {
  CacheJanitor._();
  static final CacheJanitor instance = CacheJanitor._();

  static const Duration startupDelay = Duration(seconds: 30);
  static const Duration _debounce = Duration(seconds: 3);
  static const Duration _freshness = Duration(minutes: 2);
  static const List<_Area> _areas = [
    _MediaArea(),
    _ImageArea(),
    _StickerFramesArea(),
  ];

  Timer? _timer;
  Future<void> _queue = Future.value();

  void schedule([Duration delay = _debounce]) {
    if (kIsWeb) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(trim());
    });
  }

  Future<void> trim() => _serial(_trim).catchError((Object error) {
    logger.w('[cache] не удалось подрезать кэш: $error');
  });

  Future<StorageReport> scan() => _serial(() async {
    final bytes = <StorageCategory, int>{};
    for (final area in _areas) {
      for (final entry in await area.entries()) {
        bytes.update(
          entry.category,
          (size) => size + entry.size,
          ifAbsent: () => entry.size,
        );
      }
    }
    bytes[StorageCategory.database] = await AppDatabase.fileBytes();
    return StorageReport(bytes);
  });

  Future<int> clear(Set<StorageCategory> categories) => _serial(() async {
    var freed = 0;
    for (final area in _areas) {
      final ids = {
        for (final entry in await area.entries())
          if (entry.category.clearable && categories.contains(entry.category))
            entry.id,
      };
      if (ids.isNotEmpty) freed += await area.remove(ids);
    }
    return freed;
  });

  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _queue = Future.value();
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _trim() async {
    final now = DateTime.now();
    final budget = AppCacheLimit.current.value;
    final pool = <(_Area, _Entry)>[];
    final doomed = <_Area, Set<String>>{};

    for (final area in _areas) {
      final entries = [
        for (final entry in await area.entries())
          if (entry.category.evictable) entry,
      ]..sort(_oldestFirst);
      final cap = area.capBytes;
      var areaBytes = entries.fold(0, (sum, entry) => sum + entry.size);
      for (final entry in entries) {
        if (cap != null && areaBytes > cap && !_isFresh(entry, now)) {
          doomed.putIfAbsent(area, () => {}).add(entry.id);
          areaBytes -= entry.size;
        } else {
          pool.add((area, entry));
        }
      }
    }

    if (budget != AppCacheLimit.unlimited) {
      var total = pool.fold(0, (sum, item) => sum + item.$2.size);
      pool.sort((a, b) => _oldestFirst(a.$2, b.$2));
      for (final (area, entry) in pool) {
        if (total <= budget) break;
        if (_isFresh(entry, now)) continue;
        doomed.putIfAbsent(area, () => {}).add(entry.id);
        total -= entry.size;
      }
    }

    for (final MapEntry(key: area, value: ids) in doomed.entries) {
      await area.remove(ids);
    }
  }

  static int _oldestFirst(_Entry a, _Entry b) =>
      a.modified.compareTo(b.modified);

  static bool _isFresh(_Entry entry, DateTime now) =>
      now.difference(entry.modified) < _freshness;
}

class _Entry {
  const _Entry(this.id, this.size, this.modified, this.category);

  final String id;
  final int size;
  final DateTime modified;
  final StorageCategory category;
}

abstract class _Area {
  const _Area();

  int? get capBytes => null;

  Future<List<_Entry>> entries();

  Future<int> remove(Set<String> ids);
}

class _MediaArea extends _Area {
  const _MediaArea();

  static StorageCategory _categoryOf(String name) =>
      switch (mediaCacheKindOf(name)) {
        MediaCacheKind.photo => StorageCategory.photos,
        MediaCacheKind.video => StorageCategory.videos,
        MediaCacheKind.voice => StorageCategory.voice,
        MediaCacheKind.file => StorageCategory.files,
        MediaCacheKind.kept => StorageCategory.keptMedia,
      };

  @override
  Future<List<_Entry>> entries() async => [
    for (final entry in await MediaCache.entries())
      _Entry(entry.name, entry.size, entry.modified, _categoryOf(entry.name)),
  ];

  @override
  Future<int> remove(Set<String> ids) => MediaCache.removeWhere(ids.contains);
}

abstract class _FileArea extends _Area {
  const _FileArea();

  Future<List<File>> files();

  StorageCategory categoryOf(File file);

  @override
  Future<List<_Entry>> entries() async {
    final result = <_Entry>[];
    for (final file in await files()) {
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) continue;
        result.add(
          _Entry(file.path, stat.size, stat.modified, categoryOf(file)),
        );
      } catch (_) {}
    }
    return result;
  }

  @override
  Future<int> remove(Set<String> ids) async {
    var freed = 0;
    for (final path in ids) {
      final file = File(path);
      try {
        final size = await file.length();
        await file.delete();
        freed += size;
      } catch (_) {}
    }
    return freed;
  }
}

class _ImageArea extends _FileArea {
  const _ImageArea();

  static const Set<String> _animationExtensions = {'.json', '.tgs', '.lottie'};

  @override
  Future<List<File>> files() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, DefaultCacheManager.key));
    if (!await dir.exists()) return const [];
    return dir.list().where((e) => e is File).cast<File>().toList();
  }

  @override
  StorageCategory categoryOf(File file) =>
      _animationExtensions.contains(p.extension(file.path).toLowerCase())
      ? StorageCategory.stickers
      : StorageCategory.photos;
}

class _StickerFramesArea extends _FileArea {
  const _StickerFramesArea();

  @override
  int? get capBytes => TlottieDiskCache.maxBytes;

  @override
  Future<List<File>> files() => TlottieDiskCache.instance.files();

  @override
  StorageCategory categoryOf(File file) => StorageCategory.stickers;
}
