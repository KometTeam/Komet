import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';
import 'screen_decoder.dart';
import 'sfu_screen_channel.dart';

sealed class RemoteScreen {
  const RemoteScreen();

  double get aspectRatio;
}

final class RemoteScreenPicture extends RemoteScreen {
  const RemoteScreenPicture(this.image);

  final ui.Image image;

  @override
  double get aspectRatio => image.width / image.height;
}

final class RemoteScreenTexture extends RemoteScreen {
  const RemoteScreenTexture({
    required this.textureId,
    required this.width,
    required this.height,
  });

  final int textureId;
  final int width;
  final int height;

  @override
  double get aspectRatio => width / height;
}

// #***! чужие экраны: на десктопе libvpx в изоляте и ui.Image, на Android MediaCodec рисует прямо в текстуру Flutter
class RemoteScreens {
  RemoteScreens()
    : _backend = defaultTargetPlatform == TargetPlatform.android
          ? _TextureBackend()
          : _PictureBackend();

  final _Backend _backend;
  final Map<int, ValueNotifier<RemoteScreen?>> _screens = {};
  final Map<int, int> _owners = {};

  ValueListenable<RemoteScreen?> of(int participantId) =>
      _notifier(participantId);

  void push(ScreenFrame frame, int participantId) {
    final previous = _owners[frame.source];
    if (previous != null && previous != participantId) _clear(previous);
    _owners[frame.source] = participantId;
    _backend.push(frame, (screen) => _show(participantId, screen));
  }

  void end(int source) {
    _backend.drop(source);
    final id = _owners.remove(source);
    if (id != null) _clear(id);
  }

  void reset() {
    for (final source in _owners.keys.toList()) {
      end(source);
    }
  }

  Future<void> dispose() async {
    _owners.clear();
    await _backend.dispose();
    for (final notifier in _screens.values) {
      _release(notifier.value);
      notifier.dispose();
    }
    _screens.clear();
  }

  ValueNotifier<RemoteScreen?> _notifier(int id) =>
      _screens.putIfAbsent(id, () => ValueNotifier(null));

  void _show(int id, RemoteScreen screen) {
    if (!_owners.containsValue(id)) {
      _release(screen);
      return;
    }
    final notifier = _notifier(id);
    final previous = notifier.value;
    notifier.value = screen;
    if (!identical(previous, screen)) _release(previous);
  }

  void _clear(int id) {
    final notifier = _screens[id];
    final previous = notifier?.value;
    notifier?.value = null;
    _release(previous);
  }

  static void _release(RemoteScreen? screen) {
    if (screen is RemoteScreenPicture) screen.image.dispose();
  }
}

typedef _ScreenSink = void Function(RemoteScreen screen);

abstract class _Backend {
  void push(ScreenFrame frame, _ScreenSink sink);

  void drop(int source);

  Future<void> dispose();
}

class _PictureBackend implements _Backend {
  static const int _maxFramesBeforeDecoder = 120;

  Future<ScreenDecoder?>? _starting;
  ScreenDecoder? _decoder;
  bool _missing = false;
  bool _disposed = false;
  StreamSubscription<DecodedScreen>? _decodedSub;
  final List<ScreenFrame> _early = [];
  final Map<int, _ScreenSink> _sinks = {};
  final Map<int, DecodedScreen> _pending = {};
  final Set<int> _uploading = {};

  @override
  void push(ScreenFrame frame, _ScreenSink sink) {
    if (_missing || _disposed) return;
    _sinks[frame.source] = sink;
    final decoder = _decoder;
    if (decoder != null) {
      decoder.push(frame);
      return;
    }
    if (_early.length < _maxFramesBeforeDecoder) _early.add(frame);
    _starting ??= _start();
  }

  @override
  void drop(int source) {
    _decoder?.drop(source);
    _sinks.remove(source);
    _pending.remove(source);
    _early.removeWhere((frame) => frame.source == source);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _decodedSub?.cancel();
    final decoder = _decoder ?? await _starting;
    _decoder = null;
    await decoder?.dispose();
    _sinks.clear();
    _pending.clear();
    _early.clear();
  }

  Future<ScreenDecoder?> _start() async {
    final decoder = await ScreenDecoder.start();
    if (decoder == null || _disposed) {
      await decoder?.dispose();
      _missing = decoder == null;
      _early.clear();
      return null;
    }
    _decoder = decoder;
    _decodedSub = decoder.decoded.listen(_onDecoded);
    for (final frame in _early) {
      decoder.push(frame);
    }
    _early.clear();
    return decoder;
  }

  void _onDecoded(DecodedScreen frame) {
    if (!_sinks.containsKey(frame.source)) return;
    _pending[frame.source] = frame;
    if (_uploading.add(frame.source)) unawaited(_upload(frame.source));
  }

  // #***! в картинку грузим только свежий кадр, промежуточные пропускаем
  Future<void> _upload(int source) async {
    try {
      while (!_disposed) {
        final frame = _pending.remove(source);
        if (frame == null) return;
        final image = await _imageFromRgba(frame);
        final sink = _sinks[source];
        if (_disposed || sink == null) {
          image.dispose();
          return;
        }
        sink(RemoteScreenPicture(image));
      }
    } finally {
      _uploading.remove(source);
    }
  }

  static Future<ui.Image> _imageFromRgba(DecodedScreen frame) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      frame.rgba,
      frame.width,
      frame.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

class _TextureBackend implements _Backend {
  static const MethodChannel _channel = MethodChannel(
    'ru.komet.app/screen_decoder',
  );
  static const int _maxQueued = 3;

  final Map<int, _TextureDecoder> _decoders = {};
  bool _disposed = false;

  @override
  void push(ScreenFrame frame, _ScreenSink sink) {
    if (_disposed) return;
    final current = _decoders[frame.source];
    if (current != null && current.codec == frame.codec) {
      current.push(frame, sink);
      return;
    }
    if (!frame.key) return;
    if (current != null) unawaited(current.release());
    final decoder = _TextureDecoder(frame.codec);
    _decoders[frame.source] = decoder;
    decoder.push(frame, sink);
  }

  @override
  void drop(int source) {
    final decoder = _decoders.remove(source);
    if (decoder != null) unawaited(decoder.release());
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    final decoders = _decoders.values.toList();
    _decoders.clear();
    for (final decoder in decoders) {
      await decoder.release();
    }
  }
}

class _TextureDecoder {
  _TextureDecoder(this.codec) : _id = _create(codec);

  final ScreenCodec codec;
  final Future<int?> _id;
  Future<void> _tail = Future.value();
  int _queued = 0;
  bool _waitingKey = false;
  bool _released = false;
  int _width = 0;
  int _height = 0;

  static Future<int?> _create(ScreenCodec codec) async {
    try {
      return await _TextureBackend._channel.invokeMethod<int>('create', {
        'codec': codec.name,
      });
    } catch (e) {
      logger.w('[call][screen] texture decoder failed: $e');
      return null;
    }
  }

  void push(ScreenFrame frame, _ScreenSink sink) {
    if (_released) return;
    if (_waitingKey && !frame.key) return;
    if (_queued >= _TextureBackend._maxQueued && !frame.key) {
      _waitingKey = true;
      return;
    }
    _waitingKey = false;
    _queued++;
    _tail = _tail.then((_) => _decode(frame, sink));
  }

  Future<void> _decode(ScreenFrame frame, _ScreenSink sink) async {
    try {
      final id = await _id;
      if (id == null || _released) return;
      final reply = await _TextureBackend._channel.invokeMethod<Map>('decode', {
        'id': id,
        'data': frame.data,
        'key': frame.key,
      });
      if (reply == null || _released) return;
      if (reply['needKey'] != null) {
        _waitingKey = true;
        return;
      }
      final width = reply['width'] as int?;
      final height = reply['height'] as int?;
      if (width == null || height == null) return;
      if (width == _width && height == _height) return;
      _width = width;
      _height = height;
      sink(RemoteScreenTexture(textureId: id, width: width, height: height));
    } catch (e) {
      logger.w('[call][screen] texture decode failed: $e');
    } finally {
      _queued--;
    }
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _tail;
    final id = await _id;
    if (id == null) return;
    try {
      await _TextureBackend._channel.invokeMethod<void>('release', {'id': id});
    } catch (_) {}
  }
}
