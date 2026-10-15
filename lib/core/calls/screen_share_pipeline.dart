import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';
import 'screen_encoder.dart';
import 'sfu_screen_channel.dart';
import 'sfu_screen_sender.dart';

// #***! наш экран идёт кадрами по data channel: на десктопе VP8 кодирует наш libvpx, на Android MediaCodec внутри плагина
class ScreenSharePipeline {
  ScreenSharePipeline._(this._tap, this._encoder, this._sender);

  static const int maxFps = 10;
  static const int maxWidth = 1920;
  static const int maxHeight = 1080;
  static const int bitrateKbps = 2000;
  static const Duration _statsEvery = Duration(seconds: 5);

  final VideoFrameTap _tap;
  final ScreenEncoder? _encoder;
  final SfuScreenSender? Function() _sender;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _statsTimer;
  bool _needKey = true;
  bool _stopped = false;
  int _frames = 0;
  int _bytes = 0;
  int _dropped = 0;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool get _encodesNatively =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<ScreenSharePipeline?> start(
    MediaStreamTrack track,
    SfuScreenSender? Function() sender,
  ) async {
    if (!supported) return null;
    ScreenEncoder? encoder;
    if (!_encodesNatively) {
      encoder = await ScreenEncoder.start(bitrateKbps: bitrateKbps);
      if (encoder == null) return null;
    }
    final VideoFrameTap tap;
    try {
      tap = await VideoFrameTap.start(
        track,
        format: _encodesNatively
            ? VideoFrameTapFormat.vp8
            : VideoFrameTapFormat.i420,
        maxFps: maxFps,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        bitrateKbps: bitrateKbps,
      );
    } catch (e) {
      logger.w('[call][screen] frame tap failed: $e');
      await encoder?.dispose();
      return null;
    }
    return ScreenSharePipeline._(tap, encoder, sender).._listen();
  }

  void requestKeyFrame() {
    if (_stopped) return;
    _needKey = true;
    final encoder = _encoder;
    if (encoder != null) {
      encoder.requestKeyFrame();
    } else {
      unawaited(_tap.requestKeyFrame());
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _statsTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _tap.stop();
    await _encoder?.dispose();
    await _sender()?.end();
    _logStats();
  }

  void _listen() {
    final encoder = _encoder;
    if (encoder == null) {
      _subscriptions.add(
        _tap.frames.listen(
          (frame) => unawaited(
            _send(
              ScreenFrame(
                source: 0,
                codec: ScreenCodec.vp8,
                key: frame.keyFrame,
                timestamp: 0,
                data: frame.data,
              ),
            ),
          ),
        ),
      );
    } else {
      _subscriptions
        ..add(
          _tap.frames.listen((frame) {
            final pushed = encoder.push(
              RawScreenFrame(
                width: frame.width,
                height: frame.height,
                i420: frame.data,
              ),
            );
            if (!pushed) _dropped++;
          }),
        )
        ..add(encoder.encoded.listen((frame) => unawaited(_send(frame))));
    }
    _statsTimer = Timer.periodic(_statsEvery, (_) => _logStats());
  }

  Future<void> _send(ScreenFrame frame) async {
    if (_stopped) return;
    final sender = _sender();
    if (sender == null || !sender.open) {
      _dropped++;
      _needKey = true;
      return;
    }
    if (_needKey && !frame.key) {
      _dropped++;
      requestKeyFrame();
      return;
    }
    _needKey = false;
    if (await sender.send(frame)) {
      _frames++;
      _bytes += frame.data.length;
    } else {
      _dropped++;
      requestKeyFrame();
    }
  }

  void _logStats() {
    if (_frames == 0 && _dropped == 0) return;
    final seconds = _statsEvery.inSeconds;
    logger.i(
      '[call][screen] sending: ${(_frames / seconds).toStringAsFixed(1)} fps, '
      '${_bytes * 8 ~/ 1000 ~/ seconds} kbit/s, dropped=$_dropped',
    );
    _frames = 0;
    _bytes = 0;
    _dropped = 0;
  }
}
