import 'dart:typed_data';
import 'dart:isolate';
import 'package:dart_lz4/dart_lz4.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../utils/logger.dart';

/// ver(1) + cmd(1) + seq(2) + opcode(2) + packedLen(4) = 10
const int headerSize = 10;
const int _maxDecompressedSize = 1048576; // 1 MB

/// Типы команд в протоколе
abstract class CmdType {
  static const int request = 0; // запрос клиента
  static const int push = 1; // пуш от сервера

  static const int ok = 1; // ответ: ок
  static const int notFound = 2; // ответ: не найдено
  static const int error = 3; // ответ: ошибка
}

/// Распакованный бинарный пакет
///
/// Формат заголовка (10 байт):
/// ```
/// [0]      ver       — версия протокола (uint8) (по умолчанию 10)
/// [1]   cmd       — тип команды (uint8) (при отправке от клиента равно 0)
/// [2..3]      seq       — порядковый номер (uint16 BE)
/// [4..5]   opcode    — код операции (uint16 BE)
/// [6..9]   packedLen — флаг сжатия [6] + длина payload [7..9] (uint32 BE)
/// [10..]   payload   — данные в MsgPack, опционально сжатые LZ4
/// ```
class Packet {
  int api;
  int cmd;
  int seq;
  int opcode;
  dynamic payload;

  Packet({
    this.api = 10,
    this.cmd = 0,
    this.seq = 0,
    this.opcode = 0,
    this.payload,
  });

  bool get isOk => cmd == CmdType.ok;
  bool get isError => cmd == CmdType.error;
  bool get isPush => cmd == CmdType.push;

  @override
  String toString() =>
      'Packet(ver=$api cmd=$cmd seq=$seq opcode=$opcode payload=$payload)';
}

/// Упаковка пакета для отправки на сервер
Uint8List packPacket(int opcode, Map<dynamic, dynamic> payload, {int seq = 0}) {
  final header = ByteData(headerSize);
  header.setUint8(0, 10);
  header.setUint8(1, CmdType.request);
  header.setUint16(2, seq, Endian.big);
  header.setUint16(4, opcode, Endian.big);

  final payloadBytes = msgpack.serialize(payload);
  final payloadLen = payloadBytes.length & 0xFFFFFF;
  header.setUint32(6, payloadLen, Endian.big);

  return Uint8List.fromList(header.buffer.asUint8List() + payloadBytes);
}

/// Распаковка пакета от сервера
Future<Packet> unpackPacket(Uint8List packet) async {
  return Isolate.run(() {
    // Для удобства расшифровки пакета переводим в ByteData
    ByteData packetData = ByteData.view(
      packet.buffer,
      packet.offsetInBytes,
      packet.lengthInBytes,
    );

    // API версия и cmd представляют из себя 8 битные числа
    final apiVer = packetData.getUint8(0) & 0xFF;
    final cmd = packetData.getUint8(1) & 0xFF;

    // Sequence и OPCode представляют из себя 16 битные числа
    final seq = packetData.getUint16(2) & 0xFFFF;
    final opcode = packetData.getUint16(4) & 0xFFFF;

    // После базовых переменных идет длина пакета, является 32 битным числом
    final packedLen = packetData.getUint32(6);

    // Compression flag показывает, сжат ли payload
    final compFlag = packedLen >> 24;

    // Длина payload'а
    final payloadLength = packedLen & 0xFFFFFF;

    // Байты payload'а, могут быть сжаты LZ4
    var payloadBytes = packet.buffer.asUint8List(10, payloadLength);

    dynamic payload;

    if (payloadBytes.isNotEmpty) {
      if (compFlag != 0) {
        try {
          payloadBytes = lz4Decompress(
            payloadBytes,
            decompressedSize: _maxDecompressedSize,
          );
        } catch (_) {
          try {
            payloadBytes = _lz4BlockDecompress(
              payloadBytes,
              _maxDecompressedSize,
            );
          } catch (e) {
            // В изоляте нельзя использовать логгер, который пишет в терминал через зависимости Flutter,
            // но простой print или throw сработает
            print("LZ4 decompression error: $e");
          }
        }
      }

      try {
        payload = msgpack.deserialize(payloadBytes);
      } catch (e) {
        if (payloadBytes.isNotEmpty) {
          print("MsgPack deserialization error: $e");
        }
      }
    }

    return Packet(
      api: apiVer,
      cmd: cmd,
      seq: seq,
      opcode: opcode,
      payload: payload,
    );
  });
}

/// LZ4 block декомпрессия (без frame-заголовка).
/// Сервер шлёт именно block-формат, dart_lz4 его не поддерживает.
Uint8List _lz4BlockDecompress(Uint8List src, int maxSize) {
  final dst = BytesBuilder(copy: false);
  int pos = 0;

  while (pos < src.length) {
    final token = src[pos++];
    var litLen = token >> 4;

    if (litLen == 15) {
      while (pos < src.length) {
        final b = src[pos++];
        litLen += b;
        if (b != 255) break;
      }
    }

    if (litLen > 0) {
      dst.add(src.sublist(pos, pos + litLen));
      pos += litLen;
    }

    if (pos >= src.length) break;

    final offset = src[pos] | (src[pos + 1] << 8);
    pos += 2;
    if (offset == 0) throw StateError('LZ4: offset = 0');

    var matchLen = (token & 0x0F) + 4;
    if ((token & 0x0F) == 0x0F) {
      while (pos < src.length) {
        final b = src[pos++];
        matchLen += b;
        if (b != 255) break;
      }
    }

    final out = dst.toBytes();
    final start = out.length - offset;
    dst.add(List<int>.generate(matchLen, (i) => out[start + (i % offset)]));

    if (dst.length > maxSize) throw StateError('LZ4: превышен лимит');
  }

  return dst.toBytes();
}
