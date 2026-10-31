import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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

enum CacheStore { media, images, stickerFrames }

typedef _ListedFile = ({String path, int size, int modified});

class CacheJanitor {
  CacheJanitor._();
  static final CacheJanitor instance = CacheJanitor._();

  static const Duration startupDelay = Duration(seconds: 30);
  static const Duration _debounce = Duration(seconds: 3);
  static const Duration _freshness = Duration(minutes: 2);
  static const Duration _remeasureEvery = Duration(minutes: 15);
  static const List<_Area> _areas = [
    _MediaArea(),
    _ImageArea(),
    _StickerFramesArea(),
  ];

  Timer? _timer;
  Future<void> _queue = Future.value();
  final Map<CacheStore, int> _estimate = {};
  DateTime? _measuredAt;

  void schedule([Duration delay = _debounce]) {
    if (kIsWeb) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(trim());
    });
  }

  void noteWrite(CacheStore store, int bytes) {
    if (kIsWeb) return;
    final measuredAt = _measuredAt;
    final stale =
        measuredAt == null ||
        DateTime.now().difference(measuredAt) > _remeasureEvery;
    if (!stale) {
      _estimate.update(store, (size) => size + bytes, ifAbsent: () => bytes);
      if (!_exceedsLimits()) return;
    }
    if (_timer?.isActive ?? false) return;
    schedule();
  }

  Future<StorageReport?> trim() =>
      _serial<StorageReport?>(_trim).catchError((Object error) {
        logger.w('[cache] не удалось подрезать кэш: $error');
        return null;
      });

  Future<StorageReport> scan() =>
      _serial(() async => _report(await _collect()));

  Future<({int freed, StorageReport report})> clear(
    Set<StorageCategory> categories,
  ) => _serial(() async {
    final entries = await _collect();
    final doomed = {
      for (final entry in entries)
        if (entry.category.clearable && categories.contains(entry.category))
          entry,
    };
    final freed = await _remove(doomed);
    final remaining = _without(entries, doomed);
    _remember(remaining);
    return (freed: freed, report: await _report(remaining));
  });

  @visibleForTesting
  bool get debugPassScheduled => _timer?.isActive ?? false;

  @visibleForTesting
  void debugMeasured(Map<CacheStore, int> estimate) {
    _estimate
      ..clear()
      ..addAll(estimate);
    _measuredAt = DateTime.now();
  }

  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _queue = Future.value();
    _estimate.clear();
    _measuredAt = null;
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  bool _exceedsLimits() {
    for (final area in _areas) {
      final cap = area.capBytes;
      if (cap != null && (_estimate[area.store] ?? 0) > cap) return true;
    }
    final budget = AppCacheLimit.current.value;
    if (budget == AppCacheLimit.unlimited) return false;
    return _estimate.values.fold(0, (sum, size) => sum + size) > budget;
  }

  Future<StorageReport?> _trim() async {
    final entries = await _collect();
    final now = DateTime.now();
    final budget = AppCacheLimit.current.value;
    final pool = <_Entry>[];
    final doomed = <_Entry>{};

    for (final area in _areas) {
      final evictable = [
        for (final entry in entries)
          if (identical(entry.area, area) && entry.category.evictable) entry,
      ]..sort(_oldestFirst);
      final cap = area.capBytes;
      var areaBytes = evictable.fold(0, (sum, entry) => sum + entry.size);
      for (final entry in evictable) {
        if (cap != null && areaBytes > cap && !_isFresh(entry, now)) {
          doomed.add(entry);
          areaBytes -= entry.size;
        } else {
          pool.add(entry);
        }
      }
    }

    if (budget != AppCacheLimit.unlimited) {
      var total = pool.fold(0, (sum, entry) => sum + entry.size);
      pool.sort(_oldestFirst);
      for (final entry in pool) {
        if (total <= budget) break;
        if (_isFresh(entry, now)) continue;
        doomed.add(entry);
        total -= entry.size;
      }
    }

    if (doomed.isNotEmpty) await _remove(doomed);
    final remaining = _without(entries, doomed);
    _remember(remaining);
    return _report(remaining);
  }

  Future<List<_Entry>> _collect() async {
    final directories = await Future.wait([
      for (final area in _areas) _directoryOf(area),
    ]);
    final listed = await _listInBackground(directories);
    final entries = <_Entry>[];
    for (var i = 0; i < _areas.length; i++) {
      final area = _areas[i];
      for (final file in listed[i]) {
        final name = p.basename(file.path);
        if (!area.accepts(name)) continue;
        entries.add(
          _Entry(
            area,
            file.path,
            name,
            file.size,
            DateTime.fromMillisecondsSinceEpoch(file.modified),
            area.categoryOf(name),
          ),
        );
      }
    }
    _remember(entries);
    return entries;
  }

  static Future<String?> _directoryOf(_Area area) async {
    try {
      return await area.directory();
    } catch (error) {
      logger.w('[cache] нет папки ${area.store.name}: $error');
      return null;
    }
  }

  void _remember(List<_Entry> entries) {
    _estimate.clear();
    for (final entry in entries) {
      if (!entry.category.evictable) continue;
      _estimate.update(
        entry.area.store,
        (size) => size + entry.size,
        ifAbsent: () => entry.size,
      );
    }
    _measuredAt = DateTime.now();
  }

  Future<StorageReport> _report(List<_Entry> entries) async {
    final bytes = <StorageCategory, int>{};
    for (final entry in entries) {
      bytes.update(
        entry.category,
        (size) => size + entry.size,
        ifAbsent: () => entry.size,
      );
    }
    bytes[StorageCategory.database] = await AppDatabase.fileBytes();
    return StorageReport(bytes);
  }

  Future<int> _remove(Set<_Entry> doomed) async {
    final media = [
      for (final entry in doomed)
        if (entry.area.store == CacheStore.media) entry.name,
    ];
    final files = [
      for (final entry in doomed)
        if (entry.area.store != CacheStore.media) entry.path,
    ];
    var freed = 0;
    if (media.isNotEmpty) freed += await MediaCache.remove(media);
    if (files.isNotEmpty) freed += await _deleteInBackground(files);
    return freed;
  }

  static List<_Entry> _without(List<_Entry> entries, Set<_Entry> doomed) => [
    for (final entry in entries)
      if (!doomed.contains(entry)) entry,
  ];

  static int _oldestFirst(_Entry a, _Entry b) =>
      a.modified.compareTo(b.modified);

  static bool _isFresh(_Entry entry, DateTime now) =>
      now.difference(entry.modified) < _freshness;

  static Future<List<List<_ListedFile>>> _listInBackground(
    List<String?> directories,
  ) => Isolate.run(() => _listDirectories(directories));

  static Future<int> _deleteInBackground(List<String> paths) =>
      Isolate.run(() => _deleteFiles(paths));
}

List<List<_ListedFile>> _listDirectories(List<String?> directories) => [
  for (final directory in directories)
    directory == null ? const <_ListedFile>[] : _listDirectory(directory),
];

List<_ListedFile> _listDirectory(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) return const [];
  final files = <_ListedFile>[];
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is! File) continue;
    try {
      final stat = entity.statSync();
      files.add((
        path: entity.path,
        size: stat.size,
        modified: stat.modified.millisecondsSinceEpoch,
      ));
    } catch (_) {}
  }
  return files;
}

int _deleteFiles(List<String> paths) {
  var freed = 0;
  for (final path in paths) {
    final file = File(path);
    try {
      final size = file.lengthSync();
      file.deleteSync();
      freed += size;
    } catch (_) {}
  }
  return freed;
}

class _Entry {
  const _Entry(
    this.area,
    this.path,
    this.name,
    this.size,
    this.modified,
    this.category,
  );

  final _Area area;
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final StorageCategory category;
}

abstract class _Area {
  const _Area(this.store);

  final CacheStore store;

  int? get capBytes => null;

  Future<String?> directory();

  bool accepts(String name) => true;

  StorageCategory categoryOf(String name);
}

class _MediaArea extends _Area {
  const _MediaArea() : super(CacheStore.media);

  @override
  Future<String?> directory() => MediaCache.directoryPath();

  @override
  bool accepts(String name) => !name.endsWith('.part');

  @override
  StorageCategory categoryOf(String name) => switch (mediaCacheKindOf(name)) {
    MediaCacheKind.photo => StorageCategory.photos,
    MediaCacheKind.video => StorageCategory.videos,
    MediaCacheKind.voice => StorageCategory.voice,
    MediaCacheKind.file => StorageCategory.files,
    MediaCacheKind.kept => StorageCategory.keptMedia,
  };
}

class _ImageArea extends _Area {
  const _ImageArea() : super(CacheStore.images);

  static const Set<String> _animationExtensions = {'.json', '.tgs', '.lottie'};
  static Future<String>? _path;

  @override
  Future<String?> directory() => _path ??= getTemporaryDirectory().then(
    (base) => p.join(base.path, DefaultCacheManager.key),
  );

  @override
  StorageCategory categoryOf(String name) =>
      _animationExtensions.contains(p.extension(name).toLowerCase())
      ? StorageCategory.stickers
      : StorageCategory.photos;
}

class _StickerFramesArea extends _Area {
  const _StickerFramesArea() : super(CacheStore.stickerFrames);

  @override
  int? get capBytes => TlottieDiskCache.maxBytes;

  @override
  Future<String?> directory() => TlottieDiskCache.instance.directoryPath();

  @override
  bool accepts(String name) => TlottieDiskCache.holds(name);

  @override
  StorageCategory categoryOf(String name) => StorageCategory.stickers;
}
