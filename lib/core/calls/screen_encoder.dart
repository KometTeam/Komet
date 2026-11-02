import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../utils/logger.dart';
import 'sfu_screen_channel.dart';
import 'vpx_library.dart';

class RawScreenFrame {
  const RawScreenFrame({
    required this.width,
    required this.height,
    required this.i420,
  });

  final int width;
  final int height;
  final Uint8List i420;

  static int i420Length(int width, int height) =>
      width * height + 2 * ((width + 1) >> 1) * ((height + 1) >> 1);
}

// #***! наш экран кодирует libvpx VP8 в отдельном изоляте, на выходе кадры для consumerScreenShare
class ScreenEncoder {
  ScreenEncoder._(this._isolate, this._commands, this._replies);

  static const int defaultBitrateKbps = 2000;
  static const int _maxInFlight = 2;

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _replies;
  final _encoded = StreamController<ScreenFrame>.broadcast();
  int _inFlight = 0;
  bool _keyWanted = true;

  Stream<ScreenFrame> get encoded => _encoded.stream;

  static Future<ScreenEncoder?> start({
    int bitrateKbps = defaultBitrateKbps,
  }) async {
    final replies = ReceivePort();
    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(_encoderMain, [
        replies.sendPort,
        bitrateKbps,
      ], debugName: 'screen-encoder');
    } catch (e) {
      replies.close();
      logger.w('[call][screen] encoder isolate failed: $e');
      return null;
    }

    final ready = Completer<SendPort?>();
    ScreenEncoder? encoder;
    replies.listen((message) {
      if (!ready.isCompleted) {
        ready.complete(message is SendPort ? message : null);
        return;
      }
      encoder?._onReply(message);
    });

    final commands = await ready.future;
    if (commands == null) {
      replies.close();
      isolate.kill(priority: Isolate.immediate);
      logger.i('[call][screen] libvpx encoder is not available');
      return null;
    }
    return encoder = ScreenEncoder._(isolate, commands, replies);
  }

  void requestKeyFrame() => _keyWanted = true;

  bool push(RawScreenFrame frame) {
    if (_inFlight >= _maxInFlight || _encoded.isClosed) return false;
    if (frame.i420.length <
        RawScreenFrame.i420Length(frame.width, frame.height)) {
      return false;
    }
    _inFlight++;
    final key = _keyWanted;
    _keyWanted = false;
    _commands.send({
      'width': frame.width,
      'height': frame.height,
      'key': key,
      'data': TransferableTypedData.fromList([frame.i420]),
    });
    return true;
  }

  void _onReply(Object? message) {
    if (message is! Map || _encoded.isClosed) return;
    _inFlight = max(0, _inFlight - 1);
    final error = message['error'];
    if (error != null) {
      logger.w('[call][screen] encoder: $error');
      _keyWanted = true;
      return;
    }
    final frames = message['frames'] as List;
    for (final frame in frames.cast<Map>()) {
      _encoded.add(
        ScreenFrame(
          source: 0,
          codec: ScreenCodec.vp8,
          key: frame['key'] as bool,
          timestamp: frame['pts'] as int,
          data: (frame['data'] as TransferableTypedData)
              .materialize()
              .asUint8List(),
        ),
      );
    }
  }

  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
    _replies.close();
    if (!_encoded.isClosed) await _encoded.close();
  }
}

void _encoderMain(List<Object> args) {
  final replies = args[0] as SendPort;
  final bitrateKbps = args[1] as int;
  final api = _VpxEncoderApi.open();
  if (api == null) {
    replies.send(null);
    return;
  }
  final commands = ReceivePort();
  replies.send(commands.sendPort);

  _VpxEncoder? encoder;
  final started = DateTime.now();
  commands.listen((message) {
    if (message is! Map) return;
    final width = message['width'] as int;
    final height = message['height'] as int;
    final data = (message['data'] as TransferableTypedData)
        .materialize()
        .asUint8List();

    var current = encoder;
    var fresh = false;
    if (current == null || current.width != width || current.height != height) {
      current?.dispose();
      current = encoder = _VpxEncoder.create(api, width, height, bitrateKbps);
      fresh = true;
    }
    if (current == null) {
      replies.send({'error': 'init failed for ${width}x$height'});
      return;
    }

    final pts = DateTime.now().difference(started).inMilliseconds;
    final result = current.encode(
      data,
      pts,
      forceKey: fresh || message['key'] == true,
    );
    if (result.error != null) {
      encoder?.dispose();
      encoder = null;
      replies.send({'error': result.error});
      return;
    }
    replies.send({
      'frames': [
        for (final frame in result.frames)
          {
            'key': frame.key,
            'pts': pts,
            'data': TransferableTypedData.fromList([frame.data]),
          },
      ],
    });
  });
}

typedef _IfaceNative = Pointer<Void> Function();
typedef _ConfigNative =
    Int32 Function(Pointer<Void> iface, Pointer<Uint8> cfg, Uint32 usage);
typedef _ConfigDart = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _EncodeNative =
    Int32 Function(
      Pointer<Void> ctx,
      Pointer<Void> image,
      Int64 pts,
      UnsignedLong duration,
      Long flags,
      UnsignedLong deadline,
    );
typedef _EncodeDart =
    int Function(Pointer<Void>, Pointer<Void>, int, int, int, int);
typedef _PacketNative =
    Pointer<Uint8> Function(Pointer<Void> ctx, Pointer<Pointer<Void>> iter);
typedef _ControlNative =
    Int32 Function(Pointer<Void> ctx, Int32 id, VarArgs<(Int32,)>);
typedef _ControlDart = int Function(Pointer<Void>, int, int);
typedef _WrapNative =
    Pointer<Void> Function(
      Pointer<Void> image,
      Int32 format,
      Uint32 width,
      Uint32 height,
      Uint32 align,
      Pointer<Uint8> data,
    );
typedef _WrapDart =
    Pointer<Void> Function(Pointer<Void>, int, int, int, int, Pointer<Uint8>);
typedef _CtxNative = Int32 Function(Pointer<Void> ctx);
typedef _CtxDart = int Function(Pointer<Void>);
typedef _ErrorNative = Pointer<Utf8> Function(Pointer<Void> ctx);

class _VpxEncoderApi {
  _VpxEncoderApi(VpxLibrary vpx, DynamicLibrary lib)
    : vp8 = lib.lookupFunction<_IfaceNative, _IfaceNative>('vpx_codec_vp8_cx'),
      configDefault = lib.lookupFunction<_ConfigNative, _ConfigDart>(
        'vpx_codec_enc_config_default',
      ),
      init = vpx.lookupInit('vpx_codec_enc_init_ver'),
      encode = lib.lookupFunction<_EncodeNative, _EncodeDart>(
        'vpx_codec_encode',
      ),
      packet = lib.lookupFunction<_PacketNative, _PacketNative>(
        'vpx_codec_get_cx_data',
      ),
      control = lib.lookupFunction<_ControlNative, _ControlDart>(
        'vpx_codec_control_',
      ),
      wrap = lib.lookupFunction<_WrapNative, _WrapDart>('vpx_img_wrap'),
      destroy = lib.lookupFunction<_CtxNative, _CtxDart>('vpx_codec_destroy'),
      error = lib.lookupFunction<_ErrorNative, _ErrorNative>('vpx_codec_error');

  final _IfaceNative vp8;
  final _ConfigDart configDefault;
  final VpxInit init;
  final _EncodeDart encode;
  final _PacketNative packet;
  final _ControlDart control;
  final _WrapDart wrap;
  final _CtxDart destroy;
  final _ErrorNative error;

  static _VpxEncoderApi? open() {
    final vpx = VpxLibrary.open();
    if (vpx == null) return null;
    try {
      return _VpxEncoderApi(vpx, vpx.library);
    } catch (_) {
      return null;
    }
  }
}

class _EncodedPart {
  const _EncodedPart(this.data, this.key);

  final Uint8List data;
  final bool key;
}

// #***! смещения полей vpx_codec_enc_cfg_t и vpx_codec_cx_pkt_t сняты с libvpx 1.17, начало структур не менялось с 1.6
class _VpxEncoder {
  _VpxEncoder._(this._api, this.width, this.height, this._ctx, this._image)
    : _input = calloc<Uint8>(RawScreenFrame.i420Length(width, height));

  static const int _encoderAbiVersion = 39;
  static const int _contextBytes = 256;
  static const int _configBytes = 4096;
  static const int _imageBytes = 512;
  static const int _formatI420 = 0x102;

  static const int _cfgThreads = 4;
  static const int _cfgWidth = 12;
  static const int _cfgHeight = 16;
  static const int _cfgTimebaseNum = 28;
  static const int _cfgTimebaseDen = 32;
  static const int _cfgErrorResilient = 36;
  static const int _cfgLagInFrames = 44;
  static const int _cfgDropFrameThreshold = 48;
  static const int _cfgEndUsage = 72;
  static const int _cfgTargetBitrate = 112;
  static const int _cfgMinQuantizer = 116;
  static const int _cfgMaxQuantizer = 120;
  static const int _cfgKeyFrameMode = 160;
  static const int _cfgKeyFrameMaxDistance = 168;

  static const int _endUsageCbr = 1;
  static const int _keyFrameAuto = 1;
  static const int _keyFrameEvery = 100;
  static const int _minQuantizer = 2;
  static const int _maxQuantizer = 52;

  static const int _controlCpuUsed = 13;
  static const int _controlStaticThreshold = 17;
  static const int _controlScreenContent = 31;
  static const int _cpuUsed = -8;
  static const int _staticThreshold = 100;
  static const int _screenContentOn = 1;

  static const int _frameDurationMs = 100;
  static const int _flagForceKey = 1;
  static const int _deadlineRealtime = 1;
  static const int _packetFrame = 0;
  static const int _frameIsKey = 1;

  final _VpxEncoderApi _api;
  final int width;
  final int height;
  final Pointer<Void> _ctx;
  final Pointer<Void> _image;
  final Pointer<Uint8> _input;

  static _VpxEncoder? create(
    _VpxEncoderApi api,
    int width,
    int height,
    int bitrateKbps,
  ) {
    if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) return null;
    final iface = api.vp8();
    final cfg = calloc<Uint8>(_configBytes);
    final ctx = calloc<Uint8>(_contextBytes).cast<Void>();
    try {
      if (api.configDefault(iface, cfg, 0) != 0) {
        calloc.free(ctx);
        return null;
      }
      ByteData.sublistView(cfg.asTypedList(_configBytes))
        ..setUint32(
          _cfgThreads,
          width * height > 1280 * 720 ? 4 : 2,
          Endian.host,
        )
        ..setUint32(_cfgWidth, width, Endian.host)
        ..setUint32(_cfgHeight, height, Endian.host)
        ..setInt32(_cfgTimebaseNum, 1, Endian.host)
        ..setInt32(_cfgTimebaseDen, 1000, Endian.host)
        ..setUint32(_cfgErrorResilient, 0, Endian.host)
        ..setUint32(_cfgLagInFrames, 0, Endian.host)
        ..setUint32(_cfgDropFrameThreshold, 0, Endian.host)
        ..setUint32(_cfgEndUsage, _endUsageCbr, Endian.host)
        ..setUint32(_cfgTargetBitrate, bitrateKbps, Endian.host)
        ..setUint32(_cfgMinQuantizer, _minQuantizer, Endian.host)
        ..setUint32(_cfgMaxQuantizer, _maxQuantizer, Endian.host)
        ..setUint32(_cfgKeyFrameMode, _keyFrameAuto, Endian.host)
        ..setUint32(_cfgKeyFrameMaxDistance, _keyFrameEvery, Endian.host);
      final status = VpxLibrary.initWithAnyAbi(
        api.init,
        ctx,
        iface,
        cfg.cast<Void>(),
        preferred: _encoderAbiVersion,
      );
      if (status != 0) {
        calloc.free(ctx);
        return null;
      }
    } finally {
      calloc.free(cfg);
    }
    api
      ..control(ctx, _controlCpuUsed, _cpuUsed)
      ..control(ctx, _controlStaticThreshold, _staticThreshold)
      ..control(ctx, _controlScreenContent, _screenContentOn);
    return _VpxEncoder._(
      api,
      width,
      height,
      ctx,
      calloc<Uint8>(_imageBytes).cast<Void>(),
    );
  }

  ({List<_EncodedPart> frames, String? error}) encode(
    Uint8List i420,
    int pts, {
    required bool forceKey,
  }) {
    final length = RawScreenFrame.i420Length(width, height);
    _input
        .asTypedList(length)
        .setAll(0, Uint8List.sublistView(i420, 0, length));
    if (_api.wrap(_image, _formatI420, width, height, 1, _input) == nullptr) {
      return (frames: const [], error: 'vpx_img_wrap failed');
    }
    final status = _api.encode(
      _ctx,
      _image,
      pts,
      _frameDurationMs,
      forceKey ? _flagForceKey : 0,
      _deadlineRealtime,
    );
    if (status != 0) {
      return (frames: const [], error: _api.error(_ctx).toDartString());
    }

    final frames = <_EncodedPart>[];
    final iterator = calloc<Pointer<Void>>();
    final flagsOffset = 32 + sizeOf<UnsignedLong>();
    try {
      while (true) {
        final packet = _api.packet(_ctx, iterator);
        if (packet == nullptr) break;
        if (packet.cast<Int32>().value != _packetFrame) continue;
        final buffer = (packet + 8).cast<Pointer<Uint8>>().value;
        final size = (packet + 16).cast<Size>().value;
        final flags = (packet + flagsOffset).cast<Uint32>().value;
        frames.add(
          _EncodedPart(
            Uint8List.fromList(buffer.asTypedList(size)),
            flags & _frameIsKey != 0,
          ),
        );
      }
    } finally {
      calloc.free(iterator);
    }
    return (frames: frames, error: null);
  }

  void dispose() {
    _api.destroy(_ctx);
    calloc.free(_ctx);
    calloc.free(_image);
    calloc.free(_input);
  }
}
