import 'dart:typed_data';

import '../protocol/packet.dart';
import '../utils/logger.dart';

/// Буфер входящих данных.
/// Копит сырые байты из сокета, нарезает их на байтовые срезы целых пакетов.
class PacketReceiver {
  Uint8List _buffer = Uint8List(0);
  int _start = 0;
  int _end = 0;

  static const int _maxBufferSize = 2 * 1024 * 1024; // 2 мегабуйта

  /// Добавляет байты в буфер и возвращает все собранные пакеты как сырые срезы.
  /// Полностью синхронный — нарезка не блокируется на распаковке, поэтому
  /// конкурентные вызовы из stream-листенера не могут пересечься на `_buffer`.
  ///
  /// Накопление идёт без перекопирования всего буфера на каждый чанк: целые
  /// пакеты отдаются как `sublistView`, а потреблённый префикс отбрасывается
  /// сдвигом указателя `_start`, а не пересборкой буфера.
  List<Uint8List> feed(Uint8List data) {
    _append(data);

    if (_end - _start > _maxBufferSize) {
      logger.e(
        'PacketReceiver: переполнение буфера (${_end - _start} B), сброс',
      );
      reset();
      return const [];
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
