import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// #***! сигнатуры нативной rlottie для FFI
typedef _InitNative = Void Function();
typedef _VoidFn = void Function();

typedef _FromDataNative = Pointer<Void> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef _SizeGetterNative = Size Function(Pointer<Void>);
typedef _SizeGetter = int Function(Pointer<Void>);

typedef _DoubleGetterNative = Double Function(Pointer<Void>);
typedef _DoubleGetter = double Function(Pointer<Void>);

typedef _RenderNative = Void Function(
    Pointer<Void>, Size, Pointer<Uint32>, Size, Size, Size);
typedef _Render = void Function(
    Pointer<Void>, int, Pointer<Uint32>, int, int, int);

typedef _DestroyNative = Void Function(Pointer<Void>);
typedef _Destroy = void Function(Pointer<Void>);

typedef _CacheSizeNative = Void Function(Size);
typedef _CacheSize = void Function(int);

// #***! обёртка над librlottie, стикеры рисует си а не дарт
class RlottieBindings {
  RlottieBindings._(this._lib) {
    _init = _lib.lookupFunction<_InitNative, _VoidFn>('lottie_init');
    _shutdown = _lib.lookupFunction<_InitNative, _VoidFn>('lottie_shutdown');
    _fromData = _lib.lookupFunction<_FromDataNative, _FromDataNative>(
        'lottie_animation_from_data');
    _totalFrame = _lib.lookupFunction<_SizeGetterNative, _SizeGetter>(
        'lottie_animation_get_totalframe');
    _frameRate = _lib.lookupFunction<_DoubleGetterNative, _DoubleGetter>(
        'lottie_animation_get_framerate');
    _duration = _lib.lookupFunction<_DoubleGetterNative, _DoubleGetter>(
        'lottie_animation_get_duration');
    _render =
        _lib.lookupFunction<_RenderNative, _Render>('lottie_animation_render');
    _destroy = _lib
        .lookupFunction<_DestroyNative, _Destroy>('lottie_animation_destroy');
    _cacheSize = _lib.lookupFunction<_CacheSizeNative, _CacheSize>(
        'lottie_configure_model_cache_size');
    _init();
  }

  final DynamicLibrary _lib;
  late final _VoidFn _init;
  late final _VoidFn _shutdown;
  late final _FromDataNative _fromData;
  late final _SizeGetter _totalFrame;
  late final _DoubleGetter _frameRate;
  late final _DoubleGetter _duration;
  late final _Render _render;
  late final _Destroy _destroy;
  late final _CacheSize _cacheSize;

  // #***! библиотеки может не быть, тогда стикеры просто не играют
  static RlottieBindings? open({String? path}) {
    try {
      final lib = _openLibrary(path);
      return lib == null ? null : RlottieBindings._(lib);
    } catch (_) {
      return null;
    }
  }

  // #***! на эпле библиотека в самом процессе, на остальных файлом
  static DynamicLibrary? _openLibrary(String? path) {
    if (path != null) return DynamicLibrary.open(path);
    if (Platform.isMacOS || Platform.isIOS) return DynamicLibrary.process();
    try {
      return DynamicLibrary.open(rlottieLibraryName);
    } catch (_) {
      return null;
    }
  }

  // #***! строки в си руками и обязательно освободить
  Pointer<Void>? loadFromData(String data, String key) {
    final dataC = data.toNativeUtf8();
    final keyC = key.toNativeUtf8();
    final resC = ''.toNativeUtf8();
    try {
      final anim = _fromData(dataC, keyC, resC);
      return anim == nullptr ? null : anim;
    } finally {
      calloc.free(dataC);
      calloc.free(keyC);
      calloc.free(resC);
    }
  }

  int totalFrame(Pointer<Void> anim) => _totalFrame(anim);
  double frameRate(Pointer<Void> anim) => _frameRate(anim);
  double duration(Pointer<Void> anim) => _duration(anim);

  // #***! кадр рендерим прямо в буфер, так отдаём в текстуру без копий
  void render(Pointer<Void> anim, int frameNo, Pointer<Uint32> buffer, int px) {
    _render(anim, frameNo, buffer, px, px, px * 4);
  }

  void destroy(Pointer<Void> anim) => _destroy(anim);

  void configureModelCache(int bytes) => _cacheSize(bytes);

  void shutdown() => _shutdown();
}

// #***! имя библиотеки на каждой платформе своё
String get rlottieLibraryName {
  if (Platform.isWindows) return 'rlottie.dll';
  return 'librlottie.so';
}
