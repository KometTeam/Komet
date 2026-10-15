import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';

enum ScreenCodec { vp8, vp9 }

class ScreenFrame {
  const ScreenFrame({
    required this.source,
    required this.codec,
    required this.key,
    required this.timestamp,
    required this.data,
  });

  final int source;
  final ScreenCodec codec;
  final bool key;
  final int timestamp;
  final Uint8List data;
}

// #***! показ экрана у оригинала идёт не дорожкой, а кадрами VP8/VP9 по data channel
// #***! заголовок 11 байт: версия, u16 номер пакета, u32 время, кодек, u16 источник, флаги
class SfuScreenChannel {
  static const String receiveLabel = 'producerScreenShare';

  static const int _headerLength = 11;
  static const int _version = 1;
  static const int _flagFirst = 1;
  static const int _flagLast = 2;
  static const int _flagKey = 4;
  static const int _flagEnd = 8;

  final Map<int, _PendingFrame> _pending = {};
  final _frames = StreamController<ScreenFrame>.broadcast();
  final _ended = StreamController<int>.broadcast();
  bool _badHeaderLogged = false;

  Stream<ScreenFrame> get frames => _frames.stream;
  Stream<int> get ended => _ended.stream;

  void bind(RTCDataChannel channel) {
    channel.onMessage = (message) {
      if (message.isBinary) {
        receive(message.binary);
      } else {
        logger.w('[call][screen] text on ${channel.label}: ${message.text}');
      }
    };
  }

  void receive(Uint8List packet) {
    if (packet.length < _headerLength || packet[0] != _version) {
      if (!_badHeaderLogged) {
        _badHeaderLogged = true;
        logger.w(
          '[call][screen] unknown packet len=${packet.length} '
          'head=${_hex(packet.take(16))}',
        );
      }
      return;
    }
    final header = ByteData.sublistView(packet, 0, _headerLength);
    final timestamp = header.getUint32(3);
    final codec = packet[7] == 1 ? ScreenCodec.vp9 : ScreenCodec.vp8;
    final source = header.getUint16(8);
    final flags = packet[10];

    if (flags & _flagEnd != 0) {
      _pending.remove(source);
      if (!_ended.isClosed) _ended.add(source);
      return;
    }
    if (flags & _flagFirst != 0) {
      _pending[source] = _PendingFrame(codec, timestamp);
    }
    final pending = _pending[source];
    if (pending == null) return;
    if (flags & _flagKey != 0) pending.key = true;
    pending.bytes.add(Uint8List.sublistView(packet, _headerLength));
    if (flags & _flagLast == 0) return;

    _pending.remove(source);
    if (_frames.isClosed) return;
    _frames.add(
      ScreenFrame(
        source: source,
        codec: pending.codec,
        key: pending.key,
        timestamp: pending.timestamp,
        data: pending.bytes.takeBytes(),
      ),
    );
  }

  Future<void> dispose() async {
    _pending.clear();
    if (!_frames.isClosed) await _frames.close();
    if (!_ended.isClosed) await _ended.close();
  }

  static String _hex(Iterable<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
}

// #***! отправка как у оригинала: куски до 8000 байт, флаг ключевого кадра на каждом, источник 0, сервер подменит
class ScreenPacketizer {
  static const String sendLabel = 'consumerScreenShare';
  static const int maxChunk = 8000;
  static const int _ownSource = 0;

  int _sequence = 0;

  List<Uint8List> packetize(ScreenFrame frame, {required int timestamp}) {
    final data = frame.data;
    final packets = <Uint8List>[];
    var offset = 0;
    do {
      final end = min(offset + maxChunk, data.length);
      var flags = 0;
      if (offset == 0) flags |= SfuScreenChannel._flagFirst;
      if (end == data.length) flags |= SfuScreenChannel._flagLast;
      if (frame.key) flags |= SfuScreenChannel._flagKey;
      packets.add(
        _packet(
          codec: frame.codec,
          flags: flags,
          timestamp: timestamp,
          payload: Uint8List.sublistView(data, offset, end),
        ),
      );
      offset = end;
    } while (offset < data.length);
    return packets;
  }

  Uint8List endOfStream({required ScreenCodec codec, required int timestamp}) =>
      _packet(
        codec: codec,
        flags:
            SfuScreenChannel._flagFirst |
            SfuScreenChannel._flagLast |
            SfuScreenChannel._flagEnd,
        timestamp: timestamp,
        payload: Uint8List(0),
      );

  Uint8List _packet({
    required ScreenCodec codec,
    required int flags,
    required int timestamp,
    required Uint8List payload,
  }) {
    _sequence = (_sequence + 1) & 0xFFFF;
    final packet = Uint8List(SfuScreenChannel._headerLength + payload.length);
    ByteData.sublistView(packet)
      ..setUint8(0, SfuScreenChannel._version)
      ..setUint16(1, _sequence)
      ..setUint32(3, timestamp & 0xFFFFFFFF)
      ..setUint8(7, codec == ScreenCodec.vp9 ? 1 : 0)
      ..setUint16(8, _ownSource)
      ..setUint8(10, flags);
    packet.setAll(SfuScreenChannel._headerLength, payload);
    return packet;
  }
}

class _PendingFrame {
  _PendingFrame(this.codec, this.timestamp);

  final ScreenCodec codec;
  final int timestamp;
  final BytesBuilder bytes = BytesBuilder(copy: false);
  bool key = false;
}
