import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../utils/logger.dart';
import 'sfu_screen_channel.dart';
import 'vpx_library.dart';

class DecodedScreen {
  const DecodedScreen({
    required this.source,
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int source;
  final int width;
  final int height;
  final Uint8List rgba;
}

// #***! VP8/VP9 из data channel декодирует libvpx в отдельном изоляте, наружу отдаёт RGBA
class ScreenDecoder {
  ScreenDecoder._(this._isolate, this._commands, this._replies);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final _decoded = StreamController<DecodedScreen>.broadcast();

  Stream<DecodedScreen> get decoded => _decoded.stream;

  static Future<ScreenDecoder?> start() async {
    final replies = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _decoderMain,
        replies.sendPort,
        debugName: 'screen-decoder',
      );
    } catch (e) {
      replies.close();
      logger.w('[call][screen] decoder isolate failed: $e');
      return null;
    }

    final ready = Completer<SendPort?>();
    ScreenDecoder? decoder;
    replies.listen((message) {
      if (!ready.isCompleted) {
        ready.complete(message is SendPort ? message : null);
        return;
      }
      decoder?._onReply(message);
    });

    final commands = await ready.future;
    if (commands == null) {
      replies.close();
      isolate.kill(priority: Isolate.immediate);
      logger.i('[call][screen] libvpx is not available, screens stay hidden');
      return null;
    }
    return decoder = ScreenDecoder._(isolate, commands, replies);
  }

  void push(ScreenFrame frame) {
    _commands.send({
      'source': frame.source,
      'codec': frame.codec.index,
      'key': frame.key,
      'data': TransferableTypedData.fromList([frame.data]),
    });
  }

  void drop(int source) => _commands.send({'source': source, 'drop': true});

  void _onReply(Object? message) {
    if (message is! Map || _decoded.isClosed) return;
    final error = message['error'];
    if (error != null) {
      logger.w('[call][screen] source ${message['source']}: $error');
      return;
    }
    final rgba = message['rgba'] as TransferableTypedData;
    _decoded.add(
      DecodedScreen(
        source: message['source'] as int,
        width: message['width'] as int,
        height: message['height'] as int,
        rgba: rgba.materialize().asUint8List(),
      ),
    );
  }

  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
    _replies.close();
    if (!_decoded.isClosed) await _decoded.close();
  }
}

void _decoderMain(SendPort replies) {
  final vpx = _Vpx.open();
  if (vpx == null) {
    replies.send(null);
    return;
  }
  final commands = ReceivePort();
  replies.send(commands.sendPort);

  final decoders = <int, _VpxDecoder>{};
  commands.listen((message) {
    if (message is! Map) return;
    final source = message['source'] as int;
    if (message['drop'] == true) {
      decoders.remove(source)?.dispose();
      return;
    }

    final codec = message['codec'] as int;
    final key = message['key'] as bool;
    final data = (message['data'] as TransferableTypedData)
        .materialize()
        .asUint8List();

    var decoder = decoders[source];
    if (decoder != null && decoder.codec != codec) {
      decoders.remove(source)?.dispose();
      decoder = null;
    }
    if (decoder == null) {
      if (!key) return;
      decoder = _VpxDecoder.create(vpx, codec);
      if (decoder == null) {
        replies.send({'source': source, 'error': 'decoder init failed'});
        return;
      }
      decoders[source] = decoder;
    }

    final result = decoder.decode(data);
    if (!result.ok) {
      replies.send({'source': source, 'error': result.error});
      decoders.remove(source)?.dispose();
      return;
    }
    final image = result.image;
    if (image == null) return;
    replies.send({
      'source': source,
      'width': image.width,
      'height': image.height,
      'rgba': TransferableTypedData.fromList([image.rgba]),
    });
  });
}

typedef _IfaceNative = Pointer<Void> Function();
typedef _DecodeNative =
    Int32 Function(
      Pointer<Void> ctx,
      Pointer<Uint8> data,
      Uint32 size,
      Pointer<Void> userPriv,
      Long deadline,
    );
typedef _DecodeDart =
    int Function(Pointer<Void>, Pointer<Uint8>, int, Pointer<Void>, int);
typedef _GetFrameNative =
    Pointer<_VpxImage> Function(Pointer<Void> ctx, Pointer<Pointer<Void>> iter);
typedef _CtxNative = Int32 Function(Pointer<Void> ctx);
typedef _CtxDart = int Function(Pointer<Void>);
typedef _ErrorNative = Pointer<Utf8> Function(Pointer<Void> ctx);

final class _VpxImage extends Struct {
  @Int32()
  external int format;
  @Int32()
  external int colorSpace;
  @Int32()
  external int colorRange;
  @Uint32()
  external int width;
  @Uint32()
  external int height;
  @Uint32()
  external int bitDepth;
  @Uint32()
  external int displayWidth;
  @Uint32()
  external int displayHeight;
  @Uint32()
  external int renderWidth;
  @Uint32()
  external int renderHeight;
  @Uint32()
  external int xChromaShift;
  @Uint32()
  external int yChromaShift;
  @Array(4)
  external Array<Pointer<Uint8>> planes;
  @Array(4)
  external Array<Int32> stride;
}

class _Vpx {
  _Vpx(VpxLibrary vpx, DynamicLibrary lib)
    : vp8 = lib.lookupFunction<_IfaceNative, _IfaceNative>('vpx_codec_vp8_dx'),
      vp9 = lib.lookupFunction<_IfaceNative, _IfaceNative>('vpx_codec_vp9_dx'),
      init = vpx.lookupInit('vpx_codec_dec_init_ver'),
      decode = lib.lookupFunction<_DecodeNative, _DecodeDart>(
        'vpx_codec_decode',
      ),
      getFrame = lib.lookupFunction<_GetFrameNative, _GetFrameNative>(
        'vpx_codec_get_frame',
      ),
      destroy = lib.lookupFunction<_CtxNative, _CtxDart>('vpx_codec_destroy'),
      error = lib.lookupFunction<_ErrorNative, _ErrorNative>('vpx_codec_error');

  final _IfaceNative vp8;
  final _IfaceNative vp9;
  final VpxInit init;
  final _DecodeDart decode;
  final _GetFrameNative getFrame;
  final _CtxDart destroy;
  final _ErrorNative error;

  static _Vpx? open() {
    final vpx = VpxLibrary.open();
    if (vpx == null) return null;
    try {
      return _Vpx(vpx, vpx.library);
    } catch (_) {
      return null;
    }
  }
}

class _Rgba {
  const _Rgba(this.width, this.height, this.rgba);

  final int width;
  final int height;
  final Uint8List rgba;
}

class _VpxDecoder {
  _VpxDecoder._(this._vpx, this.codec, this._ctx);

  static const int _decoderAbiVersion = 12;
  static const int _contextBytes = 256;
  static const int _formatI420 = 0x102;

  final _Vpx _vpx;
  final int codec;
  final Pointer<Void> _ctx;
  Pointer<Uint8> _input = nullptr;
  int _inputCapacity = 0;

  static _VpxDecoder? create(_Vpx vpx, int codec) {
    final ctx = calloc<Uint8>(_contextBytes).cast<Void>();
    final iface = codec == ScreenCodec.vp9.index ? vpx.vp9() : vpx.vp8();
    final status = VpxLibrary.initWithAnyAbi(
      vpx.init,
      ctx,
      iface,
      nullptr,
      preferred: _decoderAbiVersion,
    );
    if (status != 0) {
      calloc.free(ctx);
      return null;
    }
    return _VpxDecoder._(vpx, codec, ctx);
  }

  ({bool ok, String? error, _Rgba? image}) decode(Uint8List data) {
    if (data.length > _inputCapacity) {
      if (_input != nullptr) calloc.free(_input);
      _inputCapacity = data.length;
      _input = calloc<Uint8>(_inputCapacity);
    }
    _input.asTypedList(data.length).setAll(0, data);
    if (_vpx.decode(_ctx, _input, data.length, nullptr, 0) != 0) {
      return (ok: false, error: _vpx.error(_ctx).toDartString(), image: null);
    }

    final iterator = calloc<Pointer<Void>>();
    try {
      _Rgba? latest;
      while (true) {
        final frame = _vpx.getFrame(_ctx, iterator);
        if (frame == nullptr) break;
        latest = _toRgba(frame.ref) ?? latest;
      }
      return (ok: true, error: null, image: latest);
    } finally {
      calloc.free(iterator);
    }
  }

  // #***! BT.601 с ограниченным диапазоном, как пишут VP8 и VP9 по умолчанию
  static _Rgba? _toRgba(_VpxImage frame) {
    if (frame.format != _formatI420) return null;
    final width = frame.displayWidth;
    final height = frame.displayHeight;
    final yStride = frame.stride[0];
    final uStride = frame.stride[1];
    final vStride = frame.stride[2];
    final chromaRows = (height + 1) >> 1;
    final yPlane = frame.planes[0].asTypedList(yStride * height);
    final uPlane = frame.planes[1].asTypedList(uStride * chromaRows);
    final vPlane = frame.planes[2].asTypedList(vStride * chromaRows);

    final out = Uint8ClampedList(width * height * 4);
    var o = 0;
    for (var row = 0; row < height; row++) {
      final yRow = row * yStride;
      final uRow = (row >> 1) * uStride;
      final vRow = (row >> 1) * vStride;
      for (var col = 0; col < width; col++) {
        final luma = (yPlane[yRow + col] - 16) * 298 + 128;
        final u = uPlane[uRow + (col >> 1)] - 128;
        final v = vPlane[vRow + (col >> 1)] - 128;
        out[o] = (luma + 409 * v) >> 8;
        out[o + 1] = (luma - 100 * u - 208 * v) >> 8;
        out[o + 2] = (luma + 516 * u) >> 8;
        out[o + 3] = 255;
        o += 4;
      }
    }
    return _Rgba(width, height, Uint8List.view(out.buffer));
  }

  void dispose() {
    _vpx.destroy(_ctx);
    calloc.free(_ctx);
    if (_input != nullptr) calloc.free(_input);
    _input = nullptr;
    _inputCapacity = 0;
  }
}
