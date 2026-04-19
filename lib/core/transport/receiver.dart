import 'dart:typed_data';

import '../protocol/packet.dart';
import '../utils/logger.dart';

/// Буфер входящих данных.
/// Копит сырые байты из сокета, собирает из них целые пакеты.
class PacketReceiver {
  Uint8List _buffer = Uint8List(0);

  static const int _maxBufferSize = 2 * 1024 * 1024; // 2 мегабуйта

  /// Добавляет байты в буфер, возвращает поток собранных пакетов.
  /// Неполные данные остаются в буфере до следующего вызова.
  Stream<Packet> feed(Uint8List data) async* {
    final newBuffer = Uint8List(_buffer.length + data.length);
    newBuffer.setAll(0, _buffer);
    newBuffer.setAll(_buffer.length, data);
    _buffer = newBuffer;

    if (_buffer.length > _maxBufferSize) {
      logger.e(
        'PacketReceiver: переполнение буфера (${_buffer.length} B), сброс',
      );
      reset();
      return;
    }

    while (_buffer.length >= headerSize) {
      final bd = ByteData.view(
        _buffer.buffer,
        _buffer.offsetInBytes,
        headerSize,
      );
      final packedLen = bd.getUint32(6, Endian.big);
      final payloadLength = packedLen & 0xFFFFFF;
      final totalLength = headerSize + payloadLength;

      if (_buffer.length < totalLength) break;

      final packetBytes = Uint8List.sublistView(_buffer, 0, totalLength);
      _buffer = _buffer.sublist(totalLength);

      try {
        yield await unpackPacket(packetBytes);
      } catch (e) {
        logger.e('PacketReceiver: ошибка распаковки: $e');
      }
    }
  }

  void reset() {
    _buffer = Uint8List(0);
  }
}
