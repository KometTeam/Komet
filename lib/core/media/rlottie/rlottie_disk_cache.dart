import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';

class DiskClip {
  DiskClip({
    required this.px,
    required this.frameCount,
    required this.frameRate,
    required this.durationMs,
    required this.frames,
  });

  final int px;
  final int frameCount;
  final double frameRate;
  final int durationMs;
  final List<Uint8List> frames;
}

class RlottieDiskCache {
  RlottieDiskCache._();
  static final RlottieDiskCache instance = RlottieDiskCache._();

  static const _magic = 0x4b524c46;
  static const _version = 2;
  static const int _maxBytes = 256 * 1024 * 1024;

  Directory? _dir;
  Future<Directory>? _dirFuture;

  Future<Directory> _directory() {
    return _dirFuture ??= () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/rlottie_frames');
      if (!await dir.exists()) await dir.create(recursive: true);
      _dir = dir;
      return dir;
    }();
  }

  String _key(String url, int px) {
    final digest = sha1.convert(url.codeUnits).toString().substring(0, 20);
    return '${digest}_$px.krlf';
  }

  Future<File> _file(String url, int px) async {
    final dir = await _directory();
    return File('${dir.path}/${_key(url, px)}');
  }

  Future<DiskClip?> load(String url, int px) async {
    try {
      final file = await _file(url, px);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final clip = await _decode(bytes);
      if (clip != null) {
        unawaited(file.setLastModified(DateTime.now()).catchError((_) {}));
      }
      return clip;
    } catch (e) {
      logger.w('RlottieDiskCache.load failed: $e');
      return null;
    }
  }

  Future<void> store({
    required String url,
    required int px,
    required int frameCount,
    required double frameRate,
    required int durationMs,
    required List<Uint8List> frames,
  }) async {
    if (frames.isEmpty || frames.length != frameCount) return;
    try {
      final bytes = await _encode(px, frameCount, frameRate, durationMs, frames);
      final file = await _file(url, px);
      await file.writeAsBytes(bytes, flush: false);
      unawaited(_evict());
    } catch (e) {
      logger.w('RlottieDiskCache.store failed: $e');
    }
  }

  static Future<Uint8List> _encode(
    int px,
    int frameCount,
    double frameRate,
    int durationMs,
    List<Uint8List> frames,
  ) {
    return Isolate.run(() {
      final frameBytes = px * px * 4;
      final payload = Uint8List(frameBytes * frameCount);
      for (var i = 0; i < frameCount; i++) {
        payload.setRange(i * frameBytes, (i + 1) * frameBytes, frames[i]);
      }
      for (var i = frameCount - 1; i >= 1; i--) {
        final cur = i * frameBytes;
        final prev = (i - 1) * frameBytes;
        for (var b = 0; b < frameBytes; b++) {
          payload[cur + b] ^= payload[prev + b];
        }
      }
      final compressed = gzip.encode(payload);
      final header = ByteData(28);
      header.setUint32(0, _magic);
      header.setUint8(4, _version);
      header.setUint32(8, px);
      header.setUint32(12, frameCount);
      header.setFloat64(16, frameRate);
      header.setUint32(24, durationMs);
      final out = BytesBuilder();
      out.add(header.buffer.asUint8List());
      out.add(compressed);
      return out.toBytes();
    });
  }

  static Future<DiskClip?> _decode(Uint8List bytes) {
    return Isolate.run(() {
      if (bytes.length < 28) return null;
      final header = ByteData.sublistView(bytes, 0, 28);
      if (header.getUint32(0) != _magic) return null;
      if (header.getUint8(4) != _version) return null;
      final px = header.getUint32(8);
      final frameCount = header.getUint32(12);
      final frameRate = header.getFloat64(16);
      final durationMs = header.getUint32(24);
      final frameBytes = px * px * 4;
      final payload = Uint8List.fromList(gzip.decode(bytes.sublist(28)));
      if (payload.length != frameBytes * frameCount) return null;
      for (var i = 1; i < frameCount; i++) {
        final cur = i * frameBytes;
        final prev = (i - 1) * frameBytes;
        for (var b = 0; b < frameBytes; b++) {
          payload[cur + b] ^= payload[prev + b];
        }
      }
      final frames = <Uint8List>[];
      for (var i = 0; i < frameCount; i++) {
        frames.add(Uint8List.sublistView(
            payload, i * frameBytes, (i + 1) * frameBytes));
      }
      return DiskClip(
        px: px,
        frameCount: frameCount,
        frameRate: frameRate,
        durationMs: durationMs,
        frames: frames,
      );
    });
  }

  Future<void> _evict() async {
    try {
      final dir = _dir ?? await _directory();
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.krlf'))
          .cast<File>()
          .toList();
      var total = 0;
      final stats = <(File, FileStat)>[];
      for (final f in files) {
        final st = await f.stat();
        total += st.size;
        stats.add((f, st));
      }
      if (total <= _maxBytes) return;
      stats.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
      for (final (file, st) in stats) {
        if (total <= _maxBytes) break;
        total -= st.size;
        await file.delete().catchError((_) => file);
      }
    } catch (e) {
      logger.w('RlottieDiskCache.evict failed: $e');
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      _dir = null;
      _dirFuture = null;
    } catch (_) {}
  }
}
