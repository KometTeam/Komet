import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:komet/core/media/video_transcoder.dart';
import 'package:komet/frontend/widgets/attachment/editor_common.dart';
import 'package:komet/frontend/widgets/attachment/video_edit.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

VideoCropEdit _cropEdit({
  required Size viewport,
  required Rect crop,
  int quarterTurns = 0,
  bool flipH = false,
  double straightenDeg = 0,
}) => VideoCropEdit(
  viewport: viewport,
  state: CropState(
    quarterTurns: quarterTurns,
    flipH: flipH,
    straightenDeg: straightenDeg,
    cropNorm: Rect.fromLTRB(
      crop.left / viewport.width,
      crop.top / viewport.height,
      crop.right / viewport.width,
      crop.bottom / viewport.height,
    ),
  ),
);

Future<bool> _hasFfmpeg() async {
  try {
    final probe = await Process.run('ffprobe', const ['-version']);
    return probe.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<(int, int, double, bool)> _describe(String path) async {
  final out = await Process.run('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'stream=codec_type,width,height:format=duration',
    '-of',
    'default=noprint_wrappers=1',
    path,
  ]);
  var width = 0;
  var height = 0;
  var duration = 0.0;
  var hasAudio = false;
  for (final line in '${out.stdout}'.split('\n')) {
    final parts = line.trim().split('=');
    if (parts.length != 2) continue;
    switch (parts[0]) {
      case 'width':
        width = int.tryParse(parts[1]) ?? width;
      case 'height':
        height = int.tryParse(parts[1]) ?? height;
      case 'duration':
        duration = double.tryParse(parts[1]) ?? duration;
      case 'codec_type':
        if (parts[1] == 'audio') hasAudio = true;
    }
  }
  return (width, height, duration, hasAudio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoGeometry', () {
    const source = Size(720, 1280);

    test('без правок кадр остаётся исходным', () {
      final geometry = VideoGeometry.resolve(null, source);
      expect(geometry.rotationDegrees, 0);
      expect(geometry.cropNorm, const Rect.fromLTRB(0, 0, 1, 1));
      expect(geometry.naturalOutput, source);
    });

    test('рамка во весь кадр даёт полные доли', () {
      const viewport = Size(400, 800);
      final fitted = const CropGeometry(source: source).fittedRect(viewport);
      final geometry = VideoGeometry.resolve(
        _cropEdit(viewport: viewport, crop: fitted),
        source,
      );
      expect(geometry.cropNorm.left, closeTo(0, 0.001));
      expect(geometry.cropNorm.top, closeTo(0, 0.001));
      expect(geometry.cropNorm.right, closeTo(1, 0.001));
      expect(geometry.cropNorm.bottom, closeTo(1, 0.001));
      expect(geometry.naturalOutput.width, closeTo(720, 0.5));
      expect(geometry.naturalOutput.height, closeTo(1280, 0.5));
    });

    test('половина рамки кадрирует ровно половину', () {
      const viewport = Size(400, 800);
      final fitted = const CropGeometry(source: source).fittedRect(viewport);
      final half = Rect.fromLTRB(
        fitted.left,
        fitted.top,
        fitted.center.dx,
        fitted.bottom,
      );
      final geometry = VideoGeometry.resolve(
        _cropEdit(viewport: viewport, crop: half),
        source,
      );
      expect(geometry.cropNorm.right, closeTo(0.5, 0.001));
      expect(geometry.naturalOutput.width, closeTo(360, 1));
      expect(geometry.naturalOutput.height, closeTo(1280, 1));
    });

    test('поворот на четверть меняет стороны местами', () {
      const viewport = Size(400, 800);
      const geometryBase = CropGeometry(source: source, quarterTurns: 1);
      final fitted = geometryBase.fittedRect(viewport);
      final geometry = VideoGeometry.resolve(
        _cropEdit(viewport: viewport, crop: fitted, quarterTurns: 1),
        source,
      );
      expect(geometry.rotationDegrees, closeTo(90, 0.001));
      expect(geometry.rotatedSize.width, closeTo(1280, 0.5));
      expect(geometry.rotatedSize.height, closeTo(720, 0.5));
    });

    test('отражение переворачивает знак поворота', () {
      const viewport = Size(400, 800);
      const geometryBase = CropGeometry(
        source: source,
        quarterTurns: 1,
        flipH: true,
      );
      final fitted = geometryBase.fittedRect(viewport);
      final geometry = VideoGeometry.resolve(
        _cropEdit(
          viewport: viewport,
          crop: fitted,
          quarterTurns: 1,
          flipH: true,
        ),
        source,
      );
      expect(geometry.flipH, isTrue);
      expect(geometry.rotationDegrees, closeTo(-90, 0.001));
    });

    test('качество ограничивает короткую сторону и держит её чётной', () {
      final geometry = VideoGeometry.resolve(null, source);
      expect(geometry.outputSize(480), const Size(480, 854));
      expect(geometry.outputSize(null), source);
      expect(geometry.outputSize(2000), source);
    });

    test('матрица цвета переносит сдвиги в четвёртый столбец', () {
      final adjust = ColorAdjust(warmth: 0.5);
      final gl = glColorMatrix(adjust)!;
      final base = adjust.matrix();
      expect(gl.length, 16);
      expect(gl[0], closeTo(base[0], 1e-9));
      expect(gl[12], closeTo(base[4] / 255, 1e-9));
      expect(gl[14], closeTo(base[14] / 255, 1e-9));
      expect(gl[15], 1);
      expect(glColorMatrix(ColorAdjust()), isNull);
    });
  });

  group('экспорт видео', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('komet_video_test');
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('обрезает, кадрирует, масштабирует и убирает звук', () async {
      if (!await _hasFfmpeg()) {
        markTestSkipped('ffmpeg недоступен');
        return;
      }
      final input = File('${tmp.path}/source.mp4');
      final make = await Process.run('ffmpeg', [
        '-y',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=640x480:rate=30:duration=4',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=4',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        input.path,
      ]);
      expect(make.exitCode, 0, reason: '${make.stderr}');

      final info = await VideoTranscoder.probe(input.path);
      expect(info, isNotNull);
      expect(info!.width, 640);
      expect(info.height, 480);
      expect(info.hasAudio, isTrue);
      expect(info.durationMs, greaterThan(3500));

      final source = Size(info.width.toDouble(), info.height.toDouble());
      final edit = VideoEditState()
        ..sourceDuration = Duration(milliseconds: info.durationMs)
        ..start = const Duration(milliseconds: 500)
        ..end = const Duration(milliseconds: 2500)
        ..muted = true
        ..maxShortSide = 240
        ..adjust = ColorAdjust(contrast: 0.3, vignette: 0.4);
      final viewport = const Size(400, 300);
      final fitted = CropGeometry(source: source).fittedRect(viewport);
      edit.crop = _cropEdit(
        viewport: viewport,
        crop: Rect.fromLTRB(
          fitted.left,
          fitted.top,
          fitted.center.dx,
          fitted.bottom,
        ),
      );

      final spec = await buildVideoExportSpec(
        edit,
        input.path,
        source,
        info.fps,
      );
      expect(spec, isNotNull);
      expect(spec!.overlayPath, isNotNull);
      expect(File(spec.overlayPath!).existsSync(), isTrue);

      final ok = await VideoTranscoder.export(spec);
      expect(ok, isTrue);

      final (width, height, duration, hasAudio) = await _describe(spec.output);
      expect(width, spec.outWidth);
      expect(height, spec.outHeight);
      expect(width, 240);
      expect(hasAudio, isFalse);
      expect(duration, closeTo(2.0, 0.35));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('поворачивает и отражает кадр', () async {
      if (!await _hasFfmpeg()) {
        markTestSkipped('ffmpeg недоступен');
        return;
      }
      final input = File('${tmp.path}/rotate.mp4');
      final make = await Process.run('ffmpeg', [
        '-y',
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=640x480:rate=30:duration=2',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        input.path,
      ]);
      expect(make.exitCode, 0, reason: '${make.stderr}');

      const source = Size(640, 480);
      const viewport = Size(400, 800);
      const base = CropGeometry(source: source, quarterTurns: 1, flipH: true);
      final edit = VideoEditState()
        ..sourceDuration = const Duration(seconds: 2)
        ..end = const Duration(seconds: 2)
        ..crop = _cropEdit(
          viewport: viewport,
          crop: base.fittedRect(viewport),
          quarterTurns: 1,
          flipH: true,
        );

      final spec = await buildVideoExportSpec(edit, input.path, source, 30);
      expect(spec, isNotNull);
      expect(spec!.rotationDegrees, closeTo(-90, 0.001));
      expect(spec.flipH, isTrue);
      expect(spec.outWidth, 480);
      expect(spec.outHeight, 640);

      final ok = await VideoTranscoder.export(spec);
      expect(ok, isTrue);

      final (width, height, _, _) = await _describe(spec.output);
      expect(width, 480);
      expect(height, 640);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
