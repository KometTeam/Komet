import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/app_instance.dart';
import 'media_cache.dart';

// #***! тип файла для группировки в списке
enum DownloadKind { photo, video, gif, audio, file }

// #***! тип по расширению
DownloadKind downloadKindForName(
  String name, {
  DownloadKind fallback = DownloadKind.file,
}) {
  final extension = p.extension(name).toLowerCase();
  if (extension == '.gif') return DownloadKind.gif;
  if (const {
    '.mp4',
    '.mkv',
    '.mov',
    '.webm',
    '.avi',
    '.m4v',
  }.contains(extension)) {
    return DownloadKind.video;
  }
  if (const {
    '.mp3',
    '.ogg',
    '.opus',
    '.wav',
    '.m4a',
    '.flac',
  }.contains(extension)) {
    return DownloadKind.audio;
  }
  if (const {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.bmp',
  }.contains(extension)) {
    return DownloadKind.photo;
  }
  return fallback;
}

// #***! что писать в историю, заполняется на месте скачивания
class DownloadMetadata {
  final String cacheName;
  final String name;
  final DownloadKind kind;
  final String sourceName;
  final String? thumbnailUrl;
  final int expectedSize;
  final int? chatId;
  final String? messageId;
  final int? messageTime;

  const DownloadMetadata({
    required this.cacheName,
    this.name = '',
    required this.kind,
    this.sourceName = '',
    this.thumbnailUrl,
    this.expectedSize = 0,
    this.chatId,
    this.messageId,
    this.messageTime,
  });
}

// #***! запись в истории
class DownloadRecord {
  final String cacheName;
  final String name;
  final DownloadKind kind;
  final String sourceName;
  final String? thumbnailUrl;
  final int size;
  final int downloadedAt;
  final int? chatId;
  final String? messageId;
  final int? messageTime;

  const DownloadRecord({
    required this.cacheName,
    required this.name,
    required this.kind,
    required this.sourceName,
    required this.thumbnailUrl,
    required this.size,
    required this.downloadedAt,
    required this.chatId,
    required this.messageId,
    required this.messageTime,
  });

  // #***! незнакомый тип из старой версии превращаем в файл
  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind']?.toString();
    final kind = DownloadKind.values.firstWhere(
      (value) => value.name == rawKind,
      orElse: () => DownloadKind.file,
    );
    return DownloadRecord(
      cacheName: json['cacheName']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: kind,
      sourceName: json['sourceName']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadedAt: (json['downloadedAt'] as num?)?.toInt() ?? 0,
      chatId: switch (json['chatId']) {
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
      messageId: json['messageId']?.toString(),
      messageTime: switch (json['messageTime']) {
        final num value => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'cacheName': cacheName,
    'name': name,
    'kind': kind.name,
    'sourceName': sourceName,
    'thumbnailUrl': thumbnailUrl,
    'size': size,
    'downloadedAt': downloadedAt,
    'chatId': chatId,
    'messageId': messageId,
    'messageTime': messageTime,
  };

  // #***! размер обновляем если на диске другой
  DownloadRecord withSize(int value) => DownloadRecord(
    cacheName: cacheName,
    name: name,
    kind: kind,
    sourceName: sourceName,
    thumbnailUrl: thumbnailUrl,
    size: value,
    downloadedAt: downloadedAt,
    chatId: chatId,
    messageId: messageId,
    messageTime: messageTime,
  );
}

// #***! последние 200 загрузок, они же экран загрузок
class DownloadHistory {
  static const int maxEntries = 200;
  // #***! records для экрана, менять только через _enqueue
  static final ValueNotifier<List<DownloadRecord>> records = ValueNotifier(
    const [],
  );

  static Future<void>? _loading;
  // #***! _mutations строит очередь, параллельная запись затёрла бы список
  static Future<void> _mutations = Future.value();

  static String get _key => 'recent_downloads_v1${AppInstance.suffix}';

  @visibleForTesting
  static void resetForTesting() {
    _loading = null;
    _mutations = Future.value();
    records.value = const [];
  }

  // #***! грузится один раз
  static Future<void> load() => _loading ??= _load();

  // #***! сверка с диском, удалённые руками уходят из истории
  static Future<void> refresh() => _enqueue(() async {
    await load();
    final available = await _available(records.value);
    if (listEquals(available, records.value)) return;
    records.value = List.unmodifiable(available);
    await _save();
  });

  // #***! новая запись в начало, дубль заменяется
  static Future<void> record(DownloadMetadata metadata, File file) =>
      _enqueue(() async {
        await load();
        if (!await file.exists()) return;
        final actualSize = await file.length();
        final entry = DownloadRecord(
          cacheName: metadata.cacheName,
          name: metadata.name,
          kind: metadata.kind,
          sourceName: metadata.sourceName,
          thumbnailUrl: metadata.thumbnailUrl,
          size: actualSize > 0 ? actualSize : metadata.expectedSize,
          downloadedAt: DateTime.now().millisecondsSinceEpoch,
          chatId: metadata.chatId,
          messageId: metadata.messageId,
          messageTime: metadata.messageTime,
        );
        final next = <DownloadRecord>[
          entry,
          ...records.value.where((item) => item.cacheName != entry.cacheName),
        ];
        if (next.length > maxEntries) next.removeRange(maxEntries, next.length);
        records.value = List.unmodifiable(next);
        await _save();
      });

  static Future<void> remove(String cacheName) => _enqueue(() async {
    await load();
    final next = records.value
        .where((item) => item.cacheName != cacheName)
        .toList(growable: false);
    if (next.length == records.value.length) return;
    records.value = List.unmodifiable(next);
    await _save();
  });

  static Future<void> clear() => _enqueue(() async {
    await load();
    records.value = const [];
    await _save();
  });

  // #***! touch false чтоб не двигать mtime, иначе просмотр списка ломает LRU
  static Future<File?> fileFor(
    DownloadRecord record, {
    bool touch = true,
  }) async {
    if (touch) return MediaCache.existing(record.cacheName);
    final file = await MediaCache.fileFor(record.cacheName);
    return await file.exists() && await file.length() > 0 ? file : null;
  }

  // #***! истории нет, собираем из того что в кэше
  static Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<DownloadRecord> loaded;
    if (raw == null) {
      loaded = await _migrateCache();
    } else {
      loaded = _decode(raw);
    }
    loaded = await _available(loaded);
    loaded.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    if (loaded.length > maxEntries) {
      loaded = loaded.sublist(0, maxEntries);
    }
    records.value = List.unmodifiable(loaded);
    await _save();
  }

  static List<DownloadRecord> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => DownloadRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.cacheName.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // #***! оставляем только те у кого файл на месте
  static Future<List<DownloadRecord>> _available(
    List<DownloadRecord> source,
  ) async {
    final available = <DownloadRecord>[];
    for (final record in source) {
      final file = await fileFor(record, touch: false);
      if (file == null) continue;
      final size = await file.length();
      available.add(size == record.size ? record : record.withSize(size));
    }
    return available;
  }

  // #***! разовая миграция, служебные файлы кэша не берём
  static Future<List<DownloadRecord>> _migrateCache() async {
    final files = await MediaCache.files();
    final migrated = <DownloadRecord>[];
    for (final file in files) {
      final cacheName = p.basename(file.path);
      if (cacheName.startsWith('avatar_') ||
          cacheName.startsWith('decrypted_') ||
          cacheName.startsWith('download_thumb_')) {
        continue;
      }
      final stat = await file.stat();
      final kind = cacheName.startsWith('photo_')
          ? DownloadKind.photo
          : cacheName.startsWith('video_')
          ? DownloadKind.video
          : downloadKindForName(cacheName);
      migrated.add(
        DownloadRecord(
          cacheName: cacheName,
          name: kind == DownloadKind.file ? _fileName(cacheName) : '',
          kind: kind,
          sourceName: '',
          thumbnailUrl: null,
          size: stat.size,
          downloadedAt: stat.modified.millisecondsSinceEpoch,
          chatId: null,
          messageId: null,
          messageTime: null,
        ),
      );
    }
    return migrated;
  }

  // #***! в имени кэша префикс из id, для показа отрезаем
  static String _fileName(String cacheName) {
    final separator = cacheName.indexOf('_');
    if (separator <= 0) return cacheName;
    final prefix = cacheName.substring(0, separator);
    return int.tryParse(prefix) == null
        ? cacheName
        : cacheName.substring(separator + 1);
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(records.value.map((item) => item.toJson()).toList()),
    );
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final next = _mutations.then((_) => operation());
    _mutations = next.catchError((_) {});
    return next;
  }
}
