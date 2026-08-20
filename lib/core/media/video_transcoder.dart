import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';
import 'desktop_video_probe.dart';

class VideoInfo {
  final int width;
  final int height;
  final int durationMs;
  final double fps;
  final bool hasAudio;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fps,
    required this.hasAudio,
  });
}

class VideoExportSpec {
  final String input;
  final String output;
  final int? startMs;
  final int? endMs;
  final bool removeAudio;

  final double rotationDegrees;
  final bool flipH;

  final Rect? crop;
  final int outWidth;
  final int outHeight;

  final List<double>? rgbMatrix;
  final String? overlayPath;
  final int? bitrate;

  const VideoExportSpec({
    required this.input,
    required this.output,
    required this.outWidth,
    required this.outHeight,
    this.startMs,
    this.endMs,
    this.removeAudio = false,
    this.rotationDegrees = 0,
    this.flipH = false,
    this.crop,
    this.rgbMatrix,
    this.overlayPath,
    this.bitrate,
  });

  bool get hasGeometry =>
      rotationDegrees.abs() > 0.01 ||
      flipH ||
      (crop != null && crop != const Rect.fromLTRB(0, 0, 1, 1));
}

class VideoTranscoder {
  static const _channel = MethodChannel('ru.komet.app/video');

  static bool get _native => Platform.isAndroid || Platform.isIOS;

  static Process? _desktopProcess;
  static bool _desktopCancelled = false;

  static bool get supported =>
      _native || (DesktopVideoProbe.supported && _ffmpegReady);

  static bool _ffmpegReady = false;

  static Future<bool> ensureAvailable() async {
    if (_native) return true;
    if (!DesktopVideoProbe.supported) return false;
    _ffmpegReady = await DesktopVideoProbe.toolsAvailable();
    return _ffmpegReady;
  }

  static Future<VideoInfo?> probe(String path) async {
    if (_native) {
      try {
        final res = await _channel.invokeMapMethod<String, dynamic>('probe', {
          'input': path,
        });
        if (res == null) return null;
        return VideoInfo(
          width: (res['width'] as num?)?.toInt() ?? 0,
          height: (res['height'] as num?)?.toInt() ?? 0,
          durationMs: (res['durationMs'] as num?)?.toInt() ?? 0,
          fps: (res['fps'] as num?)?.toDouble() ?? 30,
          hasAudio: res['hasAudio'] == true,
        );
      } catch (e) {
        logger.w('VideoTranscoder.probe: $e');
        return null;
      }
    }
    if (!await ensureAvailable()) return null;
    return DesktopVideoProbe.info(path);
  }

  static Future<List<Uint8List?>> frames(
    String path,
    List<int> timesMs, {
    int size = 256,
    bool precise = false,
  }) async {
    if (timesMs.isEmpty) return const [];
    if (_native) {
      try {
        final res = await _channel.invokeListMethod<Object?>('frames', {
          'input': path,
          'times': timesMs,
          'size': size,
          'precise': precise,
        });
        if (res == null) return List.filled(timesMs.length, null);
        return res.map((e) => e as Uint8List?).toList();
      } catch (e) {
        logger.w('VideoTranscoder.frames: $e');
        return List.filled(timesMs.length, null);
      }
    }
    if (!await ensureAvailable()) return List.filled(timesMs.length, null);
    final out = <Uint8List?>[];
    for (final t in timesMs) {
      out.add(await DesktopVideoProbe.frameAt(path, t, size));
    }
    return out;
  }

  static Future<File?> outputFile(String prefix) async {
    final dir = await getTemporaryDirectory();
    return File(
      p.join(
        dir.path,
        'komet_${prefix}_${DateTime.now().microsecondsSinceEpoch}.mp4',
      ),
    );
  }

  static Future<bool> export(
    VideoExportSpec spec, {
    void Function(double progress)? onProgress,
  }) async {
    if (_native) return _exportNative(spec, onProgress);
    if (!await ensureAvailable()) return false;
    return _exportFfmpeg(spec, onProgress);
  }

  static Future<void> cancel() async {
    if (_native) {
      try {
        await _channel.invokeMethod<void>('editCancel');
      } catch (_) {}
      return;
    }
    _desktopCancelled = true;
    _desktopProcess?.kill();
  }

  static Future<bool> _exportNative(
    VideoExportSpec spec,
    void Function(double)? onProgress,
  ) async {
    final poll = onProgress == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 250), (_) async {
            try {
              final value = await _channel.invokeMethod<int>('editProgress');
              if (value != null && value >= 0) onProgress(value / 100);
            } catch (_) {}
          });
    try {
      final ok = await _channel.invokeMethod<bool>('edit', _nativeArgs(spec));
      return ok == true;
    } catch (e) {
      logger.w('VideoTranscoder.export: $e');
      return false;
    } finally {
      poll?.cancel();
    }
  }

  static Map<String, dynamic> _nativeArgs(VideoExportSpec spec) {
    final crop = spec.crop;
    return {
      'input': spec.input,
      'output': spec.output,
      'startMs': spec.startMs,
      'endMs': spec.endMs,
      'removeAudio': spec.removeAudio,
      'rotationDegrees': spec.rotationDegrees,
      'flipH': spec.flipH,
      'crop': crop == null
          ? null
          : <double>[
              crop.left * 2 - 1,
              crop.right * 2 - 1,
              1 - crop.bottom * 2,
              1 - crop.top * 2,
            ],
      'outWidth': spec.outWidth,
      'outHeight': spec.outHeight,
      'rgbMatrix': spec.rgbMatrix,
      'overlay': spec.overlayPath,
      'bitrate': spec.bitrate,
    };
  }

  static Future<bool> _exportFfmpeg(
    VideoExportSpec spec,
    void Function(double)? onProgress,
  ) async {
    _desktopCancelled = false;
    File? lut;
    try {
      final args = <String>[
        '-y',
        '-v',
        'error',
        '-progress',
        'pipe:1',
        '-nostats',
      ];
      final startMs = spec.startMs ?? 0;
      if (startMs > 0) {
        args.addAll(['-ss', (startMs / 1000).toStringAsFixed(3)]);
      }
      args.addAll(['-i', spec.input]);
      final overlay = spec.overlayPath;
      if (overlay != null) args.addAll(['-i', overlay]);
      final endMs = spec.endMs;
      if (endMs != null && endMs > startMs) {
        args.addAll(['-t', ((endMs - startMs) / 1000).toStringAsFixed(3)]);
      }

      final matrix = spec.rgbMatrix;
      if (matrix != null) lut = await _writeCubeLut(matrix);

      final chain = <String>[];
      if (spec.flipH) chain.add('hflip');
      final rotation = spec.rotationDegrees;
      if (rotation.abs() > 0.01) {
        final radians = -rotation * math.pi / 180;
        chain.add(
          'rotate=${radians.toStringAsFixed(6)}:'
          "ow='rotw(${radians.toStringAsFixed(6)})':"
          "oh='roth(${radians.toStringAsFixed(6)})':c=black",
        );
      }
      final crop = spec.crop;
      if (crop != null && crop != const Rect.fromLTRB(0, 0, 1, 1)) {
        chain.add(
          'crop=iw*${crop.width.toStringAsFixed(6)}:'
          'ih*${crop.height.toStringAsFixed(6)}:'
          'iw*${crop.left.toStringAsFixed(6)}:'
          'ih*${crop.top.toStringAsFixed(6)}',
        );
      }
      chain.add('scale=${spec.outWidth}:${spec.outHeight}');
      if (lut != null) {
        chain.add("lut3d=file='${lut.path.replaceAll("'", r"\'")}'");
      }
      chain.add('format=yuv420p');

      if (overlay != null) {
        args.addAll([
          '-filter_complex',
          '[0:v]${chain.join(',')}[base];[base][1:v]overlay=0:0',
        ]);
      } else {
        args.addAll(['-vf', chain.join(',')]);
      }

      args.addAll([
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-pix_fmt',
        'yuv420p',
      ]);
      final bitrate = spec.bitrate;
      if (bitrate != null) {
        args.addAll(['-b:v', '$bitrate', '-maxrate', '$bitrate']);
      }
      if (spec.removeAudio) {
        args.add('-an');
      } else {
        args.addAll(['-c:a', 'aac', '-b:a', '128k']);
      }
      args.addAll(['-movflags', '+faststart', spec.output]);

      final process = await Process.start('ffmpeg', args);
      _desktopProcess = process;
      final totalMs = (endMs ?? 0) - startMs;
      final progress = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (onProgress == null || totalMs <= 0) return;
            if (!line.startsWith('out_time_ms=')) return;
            final us = int.tryParse(line.substring(12).trim());
            if (us == null) return;
            onProgress((us / 1000 / totalMs).clamp(0.0, 1.0));
          });
      final stderr = process.stderr.transform(utf8.decoder).join();
      final code = await process.exitCode;
      await progress.cancel();
      if (code != 0 && !_desktopCancelled) {
        logger.w('ffmpeg exited $code: ${await stderr}');
      }
      return code == 0;
    } catch (e) {
      logger.w('VideoTranscoder ffmpeg: $e');
      return false;
    } finally {
      _desktopProcess = null;
      lut?.delete().then((_) {}, onError: (_) {});
    }
  }

  static Future<File> _writeCubeLut(List<double> m) async {
    const n = 17;
    final buffer = StringBuffer('LUT_3D_SIZE $n\n');
    double apply(int row, double r, double g, double b) =>
        (m[row] * r + m[4 + row] * g + m[8 + row] * b + m[12 + row]).clamp(
          0.0,
          1.0,
        );
    for (var bi = 0; bi < n; bi++) {
      for (var gi = 0; gi < n; gi++) {
        for (var ri = 0; ri < n; ri++) {
          final r = ri / (n - 1);
          final g = gi / (n - 1);
          final b = bi / (n - 1);
          buffer.writeln(
            '${apply(0, r, g, b).toStringAsFixed(6)} '
            '${apply(1, r, g, b).toStringAsFixed(6)} '
            '${apply(2, r, g, b).toStringAsFixed(6)}',
          );
        }
      }
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'komet_lut_${DateTime.now().microsecondsSinceEpoch}.cube',
      ),
    );
    await file.writeAsString(buffer.toString());
    return file;
  }
}
