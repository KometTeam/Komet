import 'dart:io';
import 'dart:typed_data';

import '../utils/logger.dart';
import 'sfu_screen_channel.dart';

// #***! пока нет декодера: считаем принятые кадры, а под --calldebug пишем их в .ivf для ffplay
class ScreenFrameProbe {
  ScreenFrameProbe({required this.dump});

  static const Duration _reportEvery = Duration(seconds: 5);

  final bool dump;
  final Map<int, _SourceProbe> _sources = {};

  void onFrame(ScreenFrame frame, String? owner) {
    final probe = _sources.putIfAbsent(frame.source, () {
      logger.i(
        '[call][screen] source ${frame.source} owner=${owner ?? '?'} '
        'codec=${frame.codec.name} first key=${frame.key}',
      );
      return _SourceProbe(frame.source);
    });
    probe.add(frame);
    if (dump && frame.key) probe.writer ??= _IvfWriter.open(frame);
    probe.writer?.write(frame);
    probe.reportIfDue(_reportEvery);
  }

  void onEnded(int source) {
    final probe = _sources.remove(source);
    logger.i('[call][screen] source $source ended');
    probe?.close();
  }

  void close() {
    for (final probe in _sources.values) {
      probe.close();
    }
    _sources.clear();
  }
}

class _SourceProbe {
  _SourceProbe(this.source);

  final int source;
  _IvfWriter? writer;
  DateTime _windowStart = DateTime.now();
  int _frames = 0;
  int _keys = 0;
  int _bytes = 0;

  void add(ScreenFrame frame) {
    _frames++;
    if (frame.key) _keys++;
    _bytes += frame.data.length;
  }

  void reportIfDue(Duration every) {
    final elapsed = DateTime.now().difference(_windowStart);
    if (elapsed < every) return;
    final seconds = elapsed.inMilliseconds / 1000;
    logger.i(
      '[call][screen] source $source: ${_frames / seconds ~/ 1} fps, '
      '${_bytes * 8 / seconds ~/ 1000} kbit/s, keyframes=$_keys',
    );
    _windowStart = DateTime.now();
    _frames = 0;
    _keys = 0;
    _bytes = 0;
  }

  void close() => writer?.close();
}

class _IvfWriter {
  _IvfWriter._(this._path, this._file);

  static const int _headerLength = 32;
  static const int _frameCountOffset = 24;

  final String _path;
  final RandomAccessFile _file;
  int _frames = 0;
  int? _firstTimestamp;

  static _IvfWriter? open(ScreenFrame frame) {
    try {
      final dir = Directory('${Directory.systemTemp.path}/komet-screen')
        ..createSync(recursive: true);
      final path =
          '${dir.path}/screen-${frame.source}-'
          '${DateTime.now().millisecondsSinceEpoch}.ivf';
      final file = File(path).openSync(mode: FileMode.write)
        ..writeFromSync(_header(frame.codec));
      logger.i('[call][screen] dumping source ${frame.source} to $path');
      return _IvfWriter._(path, file);
    } catch (e) {
      logger.w('[call][screen] dump failed: $e');
      return null;
    }
  }

  void write(ScreenFrame frame) {
    final first = _firstTimestamp ??= frame.timestamp;
    final pts = (frame.timestamp - first) & 0xFFFFFFFF;
    final head = ByteData(12)
      ..setUint32(0, frame.data.length, Endian.little)
      ..setUint64(4, pts, Endian.little);
    _file
      ..writeFromSync(head.buffer.asUint8List())
      ..writeFromSync(frame.data);
    _frames++;
  }

  void close() {
    final count = ByteData(4)..setUint32(0, _frames, Endian.little);
    _file
      ..setPositionSync(_frameCountOffset)
      ..writeFromSync(count.buffer.asUint8List())
      ..closeSync();
    logger.i('[call][screen] dump saved: $_path ($_frames frames)');
  }

  static Uint8List _header(ScreenCodec codec) {
    final header = ByteData(_headerLength)
      ..setUint16(4, 0, Endian.little)
      ..setUint16(6, _headerLength, Endian.little)
      ..setUint32(16, 1000, Endian.little)
      ..setUint32(20, 1, Endian.little);
    final bytes = header.buffer.asUint8List()
      ..setAll(0, 'DKIF'.codeUnits)
      ..setAll(8, (codec == ScreenCodec.vp9 ? 'VP90' : 'VP80').codeUnits);
    return bytes;
  }
}
