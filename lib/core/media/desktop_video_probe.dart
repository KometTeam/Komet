import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'video_transcoder.dart' show VideoInfo;

// #***! на десктопе метаданные берём у ffprobe, плагина там нет
class DesktopVideoProbe {
  static const Duration _timeout = Duration(seconds: 6);
  // #***! кэшируем, ffprobe это запуск процесса и это дорого
  static const int _maxCache = 60;

  // #***! наличие утилит проверяем один раз
  static bool get supported =>
      !Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia;

  static bool? _hasTools;
  static final Map<String, Duration?> _durations = {};
  static final Map<String, Uint8List?> _thumbs = {};

  static Future<bool> toolsAvailable() => _toolsAvailable();

  static Future<bool> _toolsAvailable() async {
    if (_hasTools != null) return _hasTools!;
    if (!supported) return _hasTools = false;
    try {
      final probe = await Process.run('ffprobe', const [
        '-version',
      ]).timeout(_timeout);
      _hasTools = probe.exitCode == 0;
    } catch (_) {
      _hasTools = false;
    }
    return _hasTools!;
  }

  // #***! длительность
  static Future<Duration?> duration(String path) async {
    if (_durations.containsKey(path)) return _durations[path];
    if (!await _toolsAvailable()) return null;
    Duration? result;
    try {
      final out = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'default=noprint_wrappers=1:nokey=1',
        path,
      ]).timeout(_timeout);
      final seconds = double.tryParse('${out.stdout}'.trim());
      if (seconds != null && seconds > 0) {
        result = Duration(milliseconds: (seconds * 1000).round());
      }
    } catch (_) {}
    _remember(_durations, path, result);
    return result;
  }

  static final Map<String, (int, int)?> _sizes = {};

  // #***! размеры кадра
  static Future<(int, int)?> dimensions(String path) async {
    if (_sizes.containsKey(path)) return _sizes[path];
    if (!await _toolsAvailable()) return null;
    (int, int)? result;
    try {
      final out = await Process.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=width,height',
        '-of',
        'csv=s=x:p=0',
        path,
      ]).timeout(_timeout);
      final parts = '${out.stdout}'.trim().split('x');
      if (parts.length >= 2) {
        final w = int.tryParse(parts[0].trim());
        final h = int.tryParse(parts[1].trim());
        if (w != null && h != null && w > 0 && h > 0) result = (w, h);
      }
    } catch (_) {}
    _remember(_sizes, path, result);
    return result;
  }

  // #***! полная инфа, размеры длительность фпс
  static Future<VideoInfo?> info(String path) async {
    if (!await _toolsAvailable()) return null;
    try {
      final out = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'stream=codec_type,width,height,r_frame_rate:format=duration',
        '-of',
        'json',
        path,
      ]).timeout(_timeout);
      final root = jsonDecode('${out.stdout}') as Map<String, dynamic>;
      final streams = (root['streams'] as List?) ?? const [];
      Map<String, dynamic>? video;
      var hasAudio = false;
      for (final raw in streams) {
        final s = raw as Map<String, dynamic>;
        if (s['codec_type'] == 'video') {
          video ??= s;
        } else if (s['codec_type'] == 'audio') {
          hasAudio = true;
        }
      }
      if (video == null) return null;
      final seconds =
          double.tryParse('${(root['format'] as Map?)?['duration']}') ?? 0;
      return VideoInfo(
        width: (video['width'] as num?)?.toInt() ?? 0,
        height: (video['height'] as num?)?.toInt() ?? 0,
        durationMs: (seconds * 1000).round(),
        fps: _parseRate('${video['r_frame_rate']}'),
        hasAudio: hasAudio,
      );
    } catch (_) {
      return null;
    }
  }

  static double _parseRate(String value) {
    final parts = value.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]);
      final den = double.tryParse(parts[1]);
      if (num != null && den != null && den > 0) return num / den;
    }
    return double.tryParse(value) ?? 30;
  }

  // #***! кадр в нужный момент для превью
  static Future<Uint8List?> frameAt(String path, int timeMs, int size) async {
    if (!await _toolsAvailable()) return null;
    return _grabFrame(path, size, (timeMs / 1000).toStringAsFixed(3));
  }

  static Future<Uint8List?> thumbnail(String path, int size) async {
    final key = '$path@$size';
    if (_thumbs.containsKey(key)) return _thumbs[key];
    if (!await _toolsAvailable()) return null;
    var bytes = await _grabFrame(path, size, '1');
    bytes ??= await _grabFrame(path, size, '0');
    _remember(_thumbs, key, bytes);
    return bytes;
  }

  static Future<Uint8List?> _grabFrame(
    String path,
    int size,
    String seek,
  ) async {
    try {
      final out = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-ss',
        seek,
        '-i',
        path,
        '-frames:v',
        '1',
        '-vf',
        'scale=$size:-2:force_original_aspect_ratio=decrease',
        '-f',
        'image2',
        '-vcodec',
        'mjpeg',
        'pipe:1',
      ], stdoutEncoding: null).timeout(_timeout);
      final data = out.stdout;
      if (data is List<int> && data.isNotEmpty) {
        return Uint8List.fromList(data);
      }
    } catch (_) {}
    return null;
  }

  // #***! кэш ограничен, старое выкидываем
  static void _remember<T>(Map<String, T> cache, String key, T value) {
    if (cache.length > _maxCache) cache.clear();
    cache[key] = value;
  }
}
