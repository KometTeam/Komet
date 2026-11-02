import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';
import 'sfu_screen_channel.dart';

// #***! наш экран уходит кадрами в consumerScreenShare, сервер в ответ просит ключевой кадр 4 байтами с единицей во втором
class SfuScreenSender {
  SfuScreenSender(this._channel, {required this.onKeyFrameRequest}) {
    _channel.onMessage = _onMessage;
  }

  static const int _dropDeltaAbove = 4000000;
  static const int _keyRequestMarker = 1;

  final RTCDataChannel _channel;
  final void Function() onKeyFrameRequest;
  final ScreenPacketizer _packetizer = ScreenPacketizer();
  ScreenCodec? _codec;
  Future<void> _tail = Future.value();

  bool get open => _channel.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<bool> send(ScreenFrame frame) {
    final sent = Completer<bool>();
    _tail = _tail.then((_) async => sent.complete(await _send(frame)));
    return sent.future;
  }

  Future<void> end() {
    final codec = _codec;
    _codec = null;
    if (codec == null) return _tail;
    return _tail = _tail.then((_) async {
      if (!open) return;
      await _write(_packetizer.endOfStream(codec: codec, timestamp: _now()));
    });
  }

  Future<bool> _send(ScreenFrame frame) async {
    if (!open) return false;
    if (!frame.key && await _buffered() > _dropDeltaAbove) return false;
    _codec = frame.codec;
    for (final packet in _packetizer.packetize(frame, timestamp: _now())) {
      if (!await _write(packet)) return false;
    }
    return true;
  }

  Future<int> _buffered() async {
    try {
      return await _channel.getBufferedAmount();
    } catch (_) {
      return _channel.bufferedAmount ?? 0;
    }
  }

  Future<bool> _write(Uint8List packet) async {
    try {
      await _channel.send(RTCDataChannelMessage.fromBinary(packet));
      return true;
    } catch (e) {
      logger.w('[call][screen] send failed: $e');
      return false;
    }
  }

  void _onMessage(RTCDataChannelMessage message) {
    if (!message.isBinary) return;
    final bytes = message.binary;
    if (bytes.length >= 2 && bytes[1] == _keyRequestMarker) {
      onKeyFrameRequest();
    }
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch;
}
