import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class TlottieAnimation extends Opaque {}

typedef _NewNative = Pointer<TlottieAnimation> Function(
    Pointer<Uint8>, Size, Uint32, Pointer<Void>, Size, Pointer<Void>, Size, Uint32);
typedef _New = Pointer<TlottieAnimation> Function(
    Pointer<Uint8>, int, int, Pointer<Void>, int, Pointer<Void>, int, int);

typedef _DropNative = Void Function(Pointer<TlottieAnimation>);
typedef _Drop = void Function(Pointer<TlottieAnimation>);

typedef _FrameCountNative = Uint32 Function(Pointer<TlottieAnimation>);
typedef _FrameCount = int Function(Pointer<TlottieAnimation>);

typedef _FrameRateNative = Float Function(Pointer<TlottieAnimation>);
typedef _FrameRate = double Function(Pointer<TlottieAnimation>);

typedef _RenderNative = Int32 Function(
    Pointer<TlottieAnimation>, Float, Uint32, Uint32, Pointer<Uint32>, Size, Uint32);
typedef _Render = int Function(
    Pointer<TlottieAnimation>, double, int, int, Pointer<Uint32>, int, int);

class TlottieBindings {
  TlottieBindings._(DynamicLibrary lib)
      : _new = lib.lookupFunction<_NewNative, _New>('tlottie_new_with_options'),
        _drop = lib.lookupFunction<_DropNative, _Drop>('tlottie_drop'),
        _frameCount =
            lib.lookupFunction<_FrameCountNative, _FrameCount>('tlottie_frame_count'),
        _frameRate =
            lib.lookupFunction<_FrameRateNative, _FrameRate>('tlottie_frame_rate'),
        _render = lib.lookupFunction<_RenderNative, _Render>('tlottie_render');

  static const int _fitzNone = 0;
  static const int _channelBgra = 1;
  static const int _statusOk = 0;

  final _New _new;
  final _Drop _drop;
  final _FrameCount _frameCount;
  final _FrameRate _frameRate;
  final _Render _render;

  static TlottieBindings? open({String? path}) {
    try {
      return TlottieBindings._(_openLibrary(path));
    } catch (_) {
      return null;
    }
  }

  static DynamicLibrary _openLibrary(String? path) {
    if (path != null) return DynamicLibrary.open(path);
    if (Platform.isIOS || Platform.isMacOS) {
      final process = DynamicLibrary.process();
      if (process.providesSymbol('tlottie_new_with_options')) return process;
      return DynamicLibrary.open('komet_tlottie.framework/komet_tlottie');
    }
    if (Platform.isWindows) return DynamicLibrary.open('komet_tlottie.dll');
    return DynamicLibrary.open('libkomet_tlottie.so');
  }

  Pointer<TlottieAnimation>? parse(Uint8List json) {
    if (json.isEmpty) return null;
    final data = malloc<Uint8>(json.length);
    try {
      data.asTypedList(json.length).setAll(0, json);
      final anim = _new(data, json.length, _fitzNone, nullptr, 0, nullptr, 0,
          _channelBgra);
      return anim == nullptr ? null : anim;
    } finally {
      malloc.free(data);
    }
  }

  int frameCount(Pointer<TlottieAnimation> anim) => _frameCount(anim);

  double frameRate(Pointer<TlottieAnimation> anim) => _frameRate(anim);

  bool render(Pointer<TlottieAnimation> anim, int frame, Pointer<Uint32> buffer,
      int px) {
    return _render(anim, frame.toDouble(), px, px, buffer, px * px, 1) ==
        _statusOk;
  }

  void drop(Pointer<TlottieAnimation> anim) => _drop(anim);
}
