import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class FileLogOutput extends LogOutput {
  FileLogOutput._();

  static final FileLogOutput instance = FileLogOutput._();

  RandomAccessFile? _raf;
  String? _path;
  final List<String> _buffer = [];

  static final RegExp _ansi = RegExp('\x1B\\[[0-9;]*m');

  String? get path => _path;

  Future<void> start() async {
    if (_raf != null) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/komet_calls.log');
      final raf = await file.open(mode: FileMode.write);
      _path = file.path;
      _raf = raf;
      _write('=== komet log ${file.path} ===');
      for (final line in _buffer) {
        _write(line);
      }
      _buffer.clear();
    } catch (_) {}
  }

  void _write(String line) {
    try {
      _raf?.writeStringSync('$line\n');
    } catch (_) {}
  }

  @override
  void output(OutputEvent event) {
    if (_raf == null) {
      for (final line in event.lines) {
        if (_buffer.length < 20000) _buffer.add(line.replaceAll(_ansi, ''));
      }
      return;
    }
    for (final line in event.lines) {
      _write(line.replaceAll(_ansi, ''));
    }
  }

  @override
  Future<void> destroy() async {
    try {
      await _raf?.close();
    } catch (_) {}
    _raf = null;
  }
}
