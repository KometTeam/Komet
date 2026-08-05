import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class DesktopVideoProbe {
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxCache = 60;

  static bool get supported =>
      !Platform.isAndroid && !Platform.isIOS && !Platform.isFuchsia;

  static bool? _hasTools;
  static final Map<String, Duration?> _durations = {};
  static final Map<String, Uint8List?> _thumbs = {};

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

  static void _remember<T>(Map<String, T> cache, String key, T value) {
    if (cache.length > _maxCache) cache.clear();
    cache[key] = value;
  }
}
