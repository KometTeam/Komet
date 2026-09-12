import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'raw_clipboard_media.dart';

const int _cfDib = 8;
const int _cfUnicodeText = 13;
const int _cfHdrop = 15;
const int _cfDibV5 = 17;
const int _pathBufferChars = 32768;
const int _maxFiles = 20;
const int _openAttempts = 8;
// #***! буфер может быть занят другим приложением, повторяем
const Duration _openRetryDelay = Duration(milliseconds: 25);

// #***! сигнатуры WinAPI для FFI
typedef _OpenClipboardC = Int32 Function(IntPtr);
typedef _OpenClipboardDart = int Function(int);
typedef _CloseClipboardC = Int32 Function();
typedef _CloseClipboardDart = int Function();
typedef _FormatAvailableC = Int32 Function(Uint32);
typedef _FormatAvailableDart = int Function(int);
typedef _GetClipboardDataC = IntPtr Function(Uint32);
typedef _GetClipboardDataDart = int Function(int);
typedef _RegisterFormatC = Uint32 Function(Pointer<Utf16>);
typedef _RegisterFormatDart = int Function(Pointer<Utf16>);
typedef _GlobalLockC = Pointer<Uint8> Function(IntPtr);
typedef _GlobalLockDart = Pointer<Uint8> Function(int);
typedef _GlobalUnlockC = Int32 Function(IntPtr);
typedef _GlobalUnlockDart = int Function(int);
typedef _GlobalSizeC = IntPtr Function(IntPtr);
typedef _GlobalSizeDart = int Function(int);
typedef _DragQueryFileC =
    Uint32 Function(IntPtr, Uint32, Pointer<Utf16>, Uint32);
typedef _DragQueryFileDart = int Function(int, int, Pointer<Utf16>, int);

// #***! буфер винды напрямую через WinAPI, флаттер файлы оттуда не отдаёт
class Win32Clipboard {
  Win32Clipboard._() {
    final user32 = DynamicLibrary.open('user32.dll');
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final shell32 = DynamicLibrary.open('shell32.dll');

    _open = user32.lookupFunction<_OpenClipboardC, _OpenClipboardDart>(
      'OpenClipboard',
    );
    _close = user32.lookupFunction<_CloseClipboardC, _CloseClipboardDart>(
      'CloseClipboard',
    );
    _formatAvailable = user32
        .lookupFunction<_FormatAvailableC, _FormatAvailableDart>(
          'IsClipboardFormatAvailable',
        );
    _getData = user32.lookupFunction<_GetClipboardDataC, _GetClipboardDataDart>(
      'GetClipboardData',
    );
    _registerFormat = user32
        .lookupFunction<_RegisterFormatC, _RegisterFormatDart>(
          'RegisterClipboardFormatW',
        );
    _globalLock = kernel32.lookupFunction<_GlobalLockC, _GlobalLockDart>(
      'GlobalLock',
    );
    _globalUnlock = kernel32.lookupFunction<_GlobalUnlockC, _GlobalUnlockDart>(
      'GlobalUnlock',
    );
    _globalSize = kernel32.lookupFunction<_GlobalSizeC, _GlobalSizeDart>(
      'GlobalSize',
    );
    _dragQueryFile = shell32
        .lookupFunction<_DragQueryFileC, _DragQueryFileDart>('DragQueryFileW');
    _pngFormat = _registerNamedFormat('PNG');
  }

  // #***! инстанс один раз, функции не нашлись значит фича выключена
  static Win32Clipboard? _instance;
  static bool _resolved = false;

  static Win32Clipboard? get instance {
    if (!Platform.isWindows) return null;
    if (!_resolved) {
      _resolved = true;
      try {
        _instance = Win32Clipboard._();
      } catch (_) {
        _instance = null;
      }
    }
    return _instance;
  }

  late final _OpenClipboardDart _open;
  late final _CloseClipboardDart _close;
  late final _FormatAvailableDart _formatAvailable;
  late final _GetClipboardDataDart _getData;
  late final _RegisterFormatDart _registerFormat;
  late final _GlobalLockDart _globalLock;
  late final _GlobalUnlockDart _globalUnlock;
  late final _GlobalSizeDart _globalSize;
  late final _DragQueryFileDart _dragQueryFile;
  late final int _pngFormat;

  // #***! в буфере или файлы или картинка
  bool get hasMedia => _has(_cfHdrop) || _hasImage;

  bool get _hasImage =>
      !_has(_cfUnicodeText) &&
      (_has(_pngFormat) || _has(_cfDibV5) || _has(_cfDib));

  // #***! чтение с ретраями, буфер надо открыть забрать и обязательно закрыть
  Future<RawClipboardMedia?> read() async {
    if (!hasMedia) return null;
    for (var attempt = 0; attempt < _openAttempts; attempt++) {
      if (_open(0) != 0) {
        try {
          final raw = _readOpened();
          return raw == null || raw.isEmpty ? null : raw;
        } finally {
          _close();
        }
      }
      await Future<void>.delayed(_openRetryDelay);
    }
    return null;
  }

  // #***! формат PNG не стандартный, регистрируем по имени
  int _registerNamedFormat(String name) {
    final native = name.toNativeUtf16();
    try {
      return _registerFormat(native);
    } finally {
      calloc.free(native);
    }
  }

  bool _has(int format) => format != 0 && _formatAvailable(format) != 0;

  RawClipboardMedia? _readOpened() {
    if (_has(_cfHdrop)) {
      final paths = _readPaths();
      if (paths.isNotEmpty) return RawClipboardMedia(paths: paths);
    }
    if (!_hasImage) return null;
    if (_has(_pngFormat)) {
      final png = _copyGlobal(_getData(_pngFormat));
      if (png != null) return RawClipboardMedia(png: png);
    }
    for (final format in const [_cfDibV5, _cfDib]) {
      if (!_has(format)) continue;
      final dib = _copyGlobal(_getData(format));
      if (dib != null) return RawClipboardMedia(dib: dib);
    }
    return null;
  }

  // #***! пути достаём через DragQueryFile
  List<String> _readPaths() {
    final handle = _getData(_cfHdrop);
    if (handle == 0) return const [];
    final total = _dragQueryFile(handle, 0xFFFFFFFF, nullptr, 0);
    if (total == 0) return const [];
    final limit = total > _maxFiles ? _maxFiles : total;
    final buffer = calloc<Uint16>(_pathBufferChars);
    try {
      final target = buffer.cast<Utf16>();
      final paths = <String>[];
      for (var i = 0; i < limit; i++) {
        if (_dragQueryFile(handle, i, target, _pathBufferChars) == 0) continue;
        final path = target.toDartString();
        if (path.isNotEmpty) paths.add(path);
      }
      return paths;
    } finally {
      calloc.free(buffer);
    }
  }

  // #***! данные надо залочить скопировать и разлочить
  Uint8List? _copyGlobal(int handle) {
    if (handle == 0) return null;
    final size = _globalSize(handle);
    if (size <= 0) return null;
    final block = _globalLock(handle);
    if (block == nullptr) return null;
    try {
      return Uint8List.fromList(block.asTypedList(size));
    } finally {
      _globalUnlock(handle);
    }
  }
}
