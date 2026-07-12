import 'dart:typed_data';

import '../protocol/packet.dart';

class ReceiverOverflowException implements Exception {
  final int size;
  const ReceiverOverflowException(this.size);
  @override
  String toString() => 'PacketReceiver: переполнение буфера ($size B)';
}

class PacketReceiver {
  Uint8List _buffer = Uint8List(0);
  int _start = 0;
  int _end = 0;

  static const int _maxBufferSize = 16 * 1024 * 1024;

  List<Uint8List> feed(Uint8List data) {
    _append(data);

    if (_end - _start > _maxBufferSize) {
      final overflow = _end - _start;
      reset();
      throw ReceiverOverflowException(overflow);
    }

    final packets = <Uint8List>[];
    while (_end - _start >= headerSize) {
      final bd = ByteData.view(
        _buffer.buffer,
        _buffer.offsetInBytes + _start,
        headerSize,
      );
      final packedLen = bd.getUint32(6, Endian.big);
      final payloadLength = packedLen & 0xFFFFFF;
      final totalLength = headerSize + payloadLength;

      if (_end - _start < totalLength) break;

      packets.add(Uint8List.sublistView(_buffer, _start, _start + totalLength));
      _start += totalLength;
    }

    if (_start == _end) {
      _start = 0;
      _end = 0;
    }
    return packets;
  }

  void _append(Uint8List data) {
    final pending = _end - _start;
    if (pending == 0) {
      _buffer = Uint8List.fromList(data);
      _start = 0;
      _end = data.length;
      return;
    }
    final total = pending + data.length;
    final newBuffer = Uint8List(total);
    newBuffer.setRange(0, pending, _buffer, _start);
    newBuffer.setRange(pending, total, data);
    _buffer = newBuffer;
    _start = 0;
    _end = total;
  }

  void reset() {
    _buffer = Uint8List(0);
    _start = 0;
    _end = 0;
  }
}
