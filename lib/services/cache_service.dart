import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:es_compression/lz4.dart';
import 'package:gwid/utils/fresh_mode_helper.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  static const Duration _defaultTTL = Duration(hours: 24);
  static const int _maxMemoryCacheSize = 1000;

  SharedPreferences? _prefs;

  Directory? _cacheDirectory;

  Lz4Codec? _lz4Codec;
  bool _lz4Available = false;

  static final _clearLock = Object();

  Future<T> _synchronized<T>(
    Object lock,
    Future<T> Function() operation,
  ) async {
    return operation();
  }

  Future<void> initialize() async {
    _prefs = await FreshModeHelper.getSharedPreferences();
    if (FreshModeHelper.isEnabled) {
      _cacheDirectory = null;
      return;
    }
    _cacheDirectory = await getApplicationCacheDirectory();

    await _createCacheDirectories();

    try {
      _lz4Codec = Lz4Codec();
      _lz4Available = true;
      print('✅ CacheService: LZ4 compression доступна');
    } catch (e) {
      _lz4Codec = null;
      _lz4Available = false;
      print(
        '⚠️ CacheService: LZ4 compression недоступна, используется обычное кэширование: $e',
      );
    }

    print('CacheService инициализирован');
  }

  Future<void> _createCacheDirectories() async {
    if (_cacheDirectory == null) return;

    final directories = [
      'avatars',
      'images',
      'files',
      'chats',
      'contacts',
      'audio',
      'stickers',
    ];

    for (final dir in directories) {
      final directory = Directory('${_cacheDirectory!.path}/$dir');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  Future<T?> get<T>(String key, {Duration? ttl}) async {
    if (FreshModeHelper.shouldSkipLoad()) return null;

    if (_memoryCache.containsKey(key)) {
      final timestamp = _cacheTimestamps[key];
      if (timestamp != null && !_isExpired(timestamp, ttl ?? _defaultTTL)) {
        return _memoryCache[key] as T?;
      } else {
        _memoryCache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }

    if (_prefs != null) {
      try {
        final cacheKey = 'cache_$key';
        final cachedData = _prefs!.getString(cacheKey);

        if (cachedData != null) {
          final Map<String, dynamic> data = jsonDecode(cachedData);
          final timestamp = DateTime.fromMillisecondsSinceEpoch(
            data['timestamp'],
          );
          final value = data['value'];

          if (!_isExpired(timestamp, ttl ?? _defaultTTL)) {
            _memoryCache[key] = value;
            _cacheTimestamps[key] = timestamp;
            return value as T?;
          }
        }
      } catch (e) {
        print('Ошибка получения данных из кэша: $e');
      }
    }

    return null;
  }

  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    if (FreshModeHelper.shouldSkipSave()) return;

    final timestamp = DateTime.now();

    _memoryCache[key] = value;
    _cacheTimestamps[key] = timestamp;

    if (_memoryCache.length > _maxMemoryCacheSize) {
      await _evictOldestMemoryCache();
    }

    if (_prefs != null) {
      try {
        final cacheKey = 'cache_$key';
        final data = {
          'value': value,
          'timestamp': timestamp.millisecondsSinceEpoch,
          'ttl': (ttl ?? _defaultTTL).inMilliseconds,
        };

        await _prefs!.setString(cacheKey, jsonEncode(data));
      } catch (e) {
        print('Ошибка сохранения данных в кэш: $e');
      }
    }
  }

  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);

    if (_prefs != null) {
      try {
        final cacheKey = 'cache_$key';
        await _prefs!.remove(cacheKey);
      } catch (e) {
        print('Ошибка удаления данных из кэша: $e');
      }
    }
  }

  Future<void> clear() async {
    return _synchronized(_clearLock, () async {
      _memoryCache.clear();
      _cacheTimestamps.clear();

      if (_prefs != null) {
        try {
          final keys = _prefs!.getKeys().where(
            (key) => key.startsWith('cache_'),
          );
          for (final key in keys) {
            await _prefs!.remove(key);
          }
        } catch (e) {
          print('Ошибка очистки кэша: $e');
        }
      }

      if (_cacheDirectory != null) {
        try {
          for (final dir in [
            'avatars',
            'images',
            'files',
            'chats',
            'contacts',
            'audio',
          ]) {
            final directory = Directory('${_cacheDirectory!.path}/$dir');
            if (await directory.exists()) {
              await _clearDirectoryContents(directory);
            }
          }
        } catch (e) {
          print('Ошибка очистки файлового кэша: $e');
        }
      }
    });
  }

  bool _isExpired(DateTime timestamp, Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  Future<void> _evictOldestMemoryCache() async {
    if (_memoryCache.isEmpty) return;

    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final toRemove = (sortedEntries.length * 0.2).ceil();
    for (int i = 0; i < toRemove && i < sortedEntries.length; i++) {
      final key = sortedEntries[i].key;
      _memoryCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  Future<Map<String, int>> getCacheSize() async {
    final memorySize = _memoryCache.length;

    int filesSize = 0;
    if (_cacheDirectory != null) {
      try {
        await for (final entity in _cacheDirectory!.list(recursive: true)) {
          if (entity is File) {
            filesSize += await entity.length();
          }
        }
      } catch (e) {
        print('Ошибка подсчета размера файлового кэша: $e');
      }
    }

    return {
      'memory': memorySize,
      'database': 0,
      'files': filesSize,
      'total': filesSize,
    };
  }

  Future<String?> cacheFile(String url, {String? customKey}) async {
    if (_cacheDirectory == null) return null;

    try {
      final fileName = _generateFileName(url, customKey);
      final filePath = '${_cacheDirectory!.path}/images/$fileName';

      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        return filePath;
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (_lz4Available && _lz4Codec != null) {
          try {
            final compressedData = _lz4Codec!.encode(response.bodyBytes);
            await existingFile.writeAsBytes(compressedData);
          } catch (e) {
            print('⚠️ Ошибка сжатия файла $url, сохраняем без сжатия: $e');
            await existingFile.writeAsBytes(response.bodyBytes);
          }
        } else {
          await existingFile.writeAsBytes(response.bodyBytes);
        }
        return filePath;
      }
    } catch (e) {
      print('Ошибка кэширования файла $url: $e');

      return null;
    }

    return null;
  }

  Future<File?> getCachedFile(String url, {String? customKey}) async {
    if (_cacheDirectory == null) return null;

    try {
      final fileName = _generateFileName(url, customKey);
      final filePath = '${_cacheDirectory!.path}/images/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Ошибка получения кэшированного файла: $e');
    }

    return null;
  }

  String _generateFileName(String url, String? customKey) {
    final key = customKey ?? url;
    final hashString = key.hashCode.abs().toString();
    final hash = hashString.length >= 16
        ? hashString.substring(0, 16)
        : hashString.padRight(16, '0');
    final extension = _getFileExtension(url);
    return '$hash$extension';
  }

  String _getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final extension = path.substring(path.lastIndexOf('.'));
      if (extension.isNotEmpty && extension.length < 10) {
        return extension;
      }
      if (url.contains('audio') ||
          url.contains('voice') ||
          url.contains('.mp3') ||
          url.contains('.ogg') ||
          url.contains('.m4a')) {
        return '.mp3';
      }
      return '.jpg';
    } catch (e) {
      return '.jpg';
    }
  }

  Future<bool> hasCachedFile(String url, {String? customKey}) async {
    final file = await getCachedFile(url, customKey: customKey);
    return file != null;
  }

  Future<Uint8List?> getCachedFileBytes(String url, {String? customKey}) async {
    final file = await getCachedFile(url, customKey: customKey);
    if (file != null && await file.exists()) {
      final fileData = await file.readAsBytes();

      if (_lz4Available && _lz4Codec != null) {
        try {
          final decompressedData = _lz4Codec!.decode(fileData);
          return Uint8List.fromList(decompressedData);
        } catch (e) {
          print(
            '⚠️ Ошибка декомпрессии файла $url, пробуем прочитать как обычный файл: $e',
          );
          return fileData;
        }
      } else {
        return fileData;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> getDetailedCacheStats() async {
    final memorySize = _memoryCache.length;
    final cacheSize = await getCacheSize();

    return {
      'memory': {'items': memorySize, 'max_items': _maxMemoryCacheSize},
      'filesystem': {
        'total_size': cacheSize['total'],
        'files_size': cacheSize['files'],
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> removeCachedFile(String url, {String? customKey}) async {}

  Future<void> _clearDirectoryContents(Directory directory) async {
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          try {
            await entity.delete();

            await Future.delayed(const Duration(milliseconds: 5));
          } catch (fileError) {
            print('Не удалось удалить файл ${entity.path}: $fileError');
          }
        } else if (entity is Directory) {
          try {
            await _clearDirectoryContents(entity);
            try {
              await entity.delete();
            } catch (dirError) {
              print(
                'Не удалось удалить поддиректорию ${entity.path}: $dirError',
              );
            }
          } catch (subDirError) {
            print('Ошибка очистки поддиректории ${entity.path}: $subDirError');
          }
        }
      }
      print('Содержимое директории ${directory.path} очищено');
    } catch (e) {
      print('Ошибка очистки содержимого директории ${directory.path}: $e');
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    final sizes = await getCacheSize();
    final memoryEntries = _memoryCache.length;
    final diskEntries =
        _prefs?.getKeys().where((key) => key.startsWith('cache_')).length ?? 0;

    return {
      'memoryEntries': memoryEntries,
      'diskEntries': diskEntries,
      'memorySize': sizes['memory'],
      'filesSizeMB': (sizes['files']! / (1024 * 1024)).toStringAsFixed(2),
      'maxMemorySize': _maxMemoryCacheSize,
      'compression_enabled': _lz4Available,
      'compression_algorithm': _lz4Available ? 'LZ4' : 'none',
    };
  }

  Future<String?> cacheAudioFile(String url, {String? customKey}) async {
    if (_cacheDirectory == null) {
      print('CacheService: _cacheDirectory is null, initializing...');
      await initialize();
      if (_cacheDirectory == null) {
        print('CacheService: Failed to initialize cache directory');
        return null;
      }
    }

    try {
      final fileName = _generateFileName(url, customKey);
      final filePath = '${_cacheDirectory!.path}/audio/$fileName';

      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        print('CacheService: Audio file already cached: $filePath');
        return filePath;
      }

      print('CacheService: Downloading audio from: $url');
      print('CacheService: Target file path: $filePath');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('CacheService: Request timeout');
              throw TimeoutException('Request timeout');
            },
          );

      print(
        'CacheService: Response status: ${response.statusCode}, content-length: ${response.contentLength}',
      );

      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) {
          print('CacheService: Response body is empty');
          return null;
        }

        final audioDir = Directory('${_cacheDirectory!.path}/audio');
        if (!await audioDir.exists()) {
          await audioDir.create(recursive: true);
        }

        if (_lz4Available && _lz4Codec != null) {
          try {
            final compressedData = _lz4Codec!.encode(response.bodyBytes);
            await existingFile.writeAsBytes(compressedData);
          } catch (e) {
            print(
              '⚠️ Ошибка сжатия аудио файла $url, сохраняем без сжатия: $e',
            );
            await existingFile.writeAsBytes(response.bodyBytes);
          }
        } else {
          await existingFile.writeAsBytes(response.bodyBytes);
        }
        final fileSize = await existingFile.length();
        print(
          'CacheService: Audio cached successfully: $filePath (compressed size: $fileSize bytes)',
        );
        return filePath;
      } else {
        print(
          'CacheService: Failed to download audio, status code: ${response.statusCode}',
        );
        print(
          'CacheService: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
        );
      }
    } catch (e, stackTrace) {
      print('Ошибка кэширования аудио файла $url: $e');
      print('Stack trace: $stackTrace');
      if (e is TimeoutException) {
        print('CacheService: Request timed out');
      } else if (e is SocketException) {
        print('CacheService: Network error - ${e.message}');
      } else if (e is HttpException) {
        print('CacheService: HTTP error - ${e.message}');
      }
    }

    return null;
  }

  Future<File?> getCachedAudioFile(String url, {String? customKey}) async {
    if (_cacheDirectory == null) return null;

    try {
      final fileName = _generateFileName(url, customKey);
      final filePath = '${_cacheDirectory!.path}/audio/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Ошибка получения кэшированного аудио файла: $e');
    }

    return null;
  }

  Future<bool> hasCachedAudioFile(String url, {String? customKey}) async {
    final file = await getCachedAudioFile(url, customKey: customKey);
    return file != null;
  }

  Future<Uint8List?> getCachedAudioFileBytes(
    String url, {
    String? customKey,
  }) async {
    final file = await getCachedAudioFile(url, customKey: customKey);
    if (file != null && await file.exists()) {
      final fileData = await file.readAsBytes();

      if (_lz4Available && _lz4Codec != null) {
        try {
          final decompressedData = _lz4Codec!.decode(fileData);
          return Uint8List.fromList(decompressedData);
        } catch (e) {
          print(
            '⚠️ Ошибка декомпрессии аудио файла $url, пробуем прочитать как обычный файл: $e',
          );
          return fileData;
        }
      } else {
        return fileData;
      }
    }
    return null;
  }

  Future<String?> cacheStickerFile(String url, int stickerId) async {
    if (_cacheDirectory == null) {
      print('CacheService: _cacheDirectory is null, initializing...');
      await initialize();
      if (_cacheDirectory == null) {
        print('CacheService: Failed to initialize cache directory');
        return null;
      }
    }

    try {
      final customKey = 'sticker_$stickerId';
      final fileName = _generateFileName(url, customKey);
      final filePath = '${_cacheDirectory!.path}/stickers/$fileName';

      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        print('CacheService: Sticker already cached: $filePath');
        return filePath;
      }

      print('CacheService: Downloading sticker from: $url');
      print('CacheService: Target file path: $filePath');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('CacheService: Request timeout');
              throw TimeoutException('Request timeout');
            },
          );

      print(
        'CacheService: Response status: ${response.statusCode}, content-length: ${response.contentLength}',
      );

      if (response.statusCode == 200) {
        if (response.bodyBytes.isEmpty) {
          print('CacheService: Response body is empty');
          return null;
        }

        final stickerDir = Directory('${_cacheDirectory!.path}/stickers');
        if (!await stickerDir.exists()) {
          await stickerDir.create(recursive: true);
        }

        if (_lz4Available && _lz4Codec != null) {
          try {
            final compressedData = _lz4Codec!.encode(response.bodyBytes);
            await existingFile.writeAsBytes(compressedData);
          } catch (e) {
            print('⚠️ Ошибка сжатия стикера $url, сохраняем без сжатия: $e');
            await existingFile.writeAsBytes(response.bodyBytes);
          }
        } else {
          await existingFile.writeAsBytes(response.bodyBytes);
        }
        final fileSize = await existingFile.length();
        print(
          'CacheService: Sticker cached successfully: $filePath (compressed size: $fileSize bytes)',
        );
        return filePath;
      } else {
        print(
          'CacheService: Failed to download sticker, status code: ${response.statusCode}',
        );
        print(
          'CacheService: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
        );
      }
    } catch (e, stackTrace) {
      print('Ошибка кэширования стикера $url: $e');
      print('Stack trace: $stackTrace');
      if (e is TimeoutException) {
        print('CacheService: Request timed out');
      } else if (e is SocketException) {
        print('CacheService: Network error - ${e.message}');
      } else if (e is HttpException) {
        print('CacheService: HTTP error - ${e.message}');
      }
    }

    return null;
  }

  Future<File?> getCachedStickerFile(int stickerId, {String? url}) async {
    if (_cacheDirectory == null) return null;

    try {
      final customKey = 'sticker_$stickerId';
      final fileName = _generateFileName(url ?? customKey, customKey);
      final filePath = '${_cacheDirectory!.path}/stickers/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Ошибка получения кэшированного стикера: $e');
    }

    return null;
  }

  Future<bool> hasCachedStickerFile(int stickerId, {String? url}) async {
    final file = await getCachedStickerFile(stickerId, url: url);
    return file != null;
  }

  Future<Uint8List?> getCachedStickerFileBytes(
    int stickerId, {
    String? url,
  }) async {
    final file = await getCachedStickerFile(stickerId, url: url);
    if (file != null && await file.exists()) {
      final fileData = await file.readAsBytes();

      if (_lz4Available && _lz4Codec != null) {
        try {
          final decompressedData = _lz4Codec!.decode(fileData);
          return Uint8List.fromList(decompressedData);
        } catch (e) {
          print(
            '⚠️ Ошибка декомпрессии стикера, пробуем прочитать как обычный файл: $e',
          );
          return fileData;
        }
      } else {
        return fileData;
      }
    }
    return null;
  }
}
