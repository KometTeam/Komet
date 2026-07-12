import 'dart:typed_data';
import 'dart:isolate';
import 'package:dart_lz4/dart_lz4.dart';
import 'package:libcompress/libcompress.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;
import 'lz4_block.dart';

/// ver(1) + cmd(1) + seq(2) + opcode(2) + packedLen(4) = 10
const int headerSize = 10;

/// Потолок распаковки payload (анти-бомба); буфер растёт динамически до него.
const int _maxDecompressedSize = 32 * 1024 * 1024; // 32 MB

/// Типы команд в протоколе
abstract class CmdType {
  static const int request =
      0; // запрос клиента / пуш от сервера (направление определяет смысл)
  static const int push = 0; // пуш от сервера (имеет смысл только для incoming)

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

class PacketError implements Exception {
  final String message;
  final String? errorKey;
  const PacketError(this.message, {this.errorKey});
  @override
  String toString() => message;
}

class SessionExpiredException extends PacketError {
  const SessionExpiredException(super.message);
}

String messageFromErrorPayload(dynamic payload) {
  if (payload is Map) {
    final msg = payload['message'];
    if (msg == 'FAIL_WRONG_PASSWORD' || msg == 'FAIL_LOGIN_TOKEN') {
      return 'Ваш токен был отклонён сервером, хм... Попробуйте войти ещё раз.';
    }
    for (final key in ['localizedMessage', 'message', 'title']) {
      final v = payload[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return 'Неизвестная ошибка';
  }
  if (payload == null) return 'Неизвестная ошибка';
  final s = payload.toString();
  return s.isNotEmpty ? s : 'Неизвестная ошибка';
}

bool isSessionExpiredPayload(dynamic payload) {
  return payload is Map &&
      (payload['message'] == 'FAIL_LOGIN_TOKEN' ||
          payload['message'] == 'FAIL_WRONG_PASSWORD');
}

void throwIfPacketError(Packet packet) {
  if (!packet.isError) return;
  final payload = packet.payload;
  if (isSessionExpiredPayload(payload)) {
    throw SessionExpiredException(messageFromErrorPayload(payload));
  }
  throw PacketError(messageFromErrorPayload(payload));
}

bool isSessionStateError(Object error) {
  if (error is SessionExpiredException) return true;
  final text = error.toString().toLowerCase();
  return text.contains('состояние сессии') ||
      text.contains('сессия не найдена') ||
      text.contains('авторизационная сессия') ||
      text.contains('сессия не онлайн');
}

/// Payload меньше этого размера отправляется без сжатия (как в оригинале).
const int _compressionThreshold = 32;

/// Упаковка пакета для отправки на сервер.
///
/// Payload сериализуется в MsgPack и при размере >= [_compressionThreshold]
/// сжимается LZ4-block. Старший байт поля packedLen — флаг сжатия:
/// `0` — без сжатия, иначе `(rawLen ~/ compLen) + 1` (множитель размера, по
/// которому получатель выделяет буфер под распаковку).
Uint8List packPacket(int opcode, Map<dynamic, dynamic> payload, {int seq = 0}) {
  final Uint8List raw = msgpack.serialize(payload);

  final List<int> body;
  final int flag;
  if (raw.length < _compressionThreshold) {
    body = raw;
    flag = 0;
  } else {
    body = lz4Compress(raw);
    flag = (raw.length ~/ body.length) + 1;
  }

  final out = Uint8List(headerSize + body.length);
  final header = ByteData.view(out.buffer, out.offsetInBytes, headerSize);
  header.setUint8(0, 10);
  header.setUint8(1, CmdType.request);
  header.setUint16(2, seq, Endian.big);
  header.setUint16(4, opcode, Endian.big);
  header.setUint32(
    6,
    ((flag & 0xFF) << 24) | (body.length & 0xFFFFFF),
    Endian.big,
  );
  out.setRange(headerSize, out.length, body);
  return out;
}

const int _isolateDecodeThreshold = 4096;

Future<Packet> unpackPacket(Uint8List packet) async {
  final header = ByteData.sublistView(packet);

  final apiVer = header.getUint8(0) & 0xFF;
  final cmd = header.getUint8(1) & 0xFF;
  final seq = header.getUint16(2) & 0xFFFF;
  final opcode = header.getUint16(4) & 0xFFFF;
  final packedLen = header.getUint32(6);
  final compFlag = packedLen >> 24;
  final payloadLength = packedLen & 0xFFFFFF;

  if (payloadLength == 0) {
    return Packet(api: apiVer, cmd: cmd, seq: seq, opcode: opcode);
  }

  final end = headerSize + payloadLength;
  if (end > packet.length) {
    throw Exception('Packet payload length $payloadLength exceeds buffer');
  }
  final slice = Uint8List.sublistView(packet, headerSize, end);

  dynamic payload;
  if (compFlag == 0 && slice.length < _isolateDecodeThreshold) {
    payload = _deserializePayload(slice, compFlag);
  } else {
    final owned = Uint8List.fromList(slice);
    payload = await Isolate.run(() => _deserializePayload(owned, compFlag));
  }

  return Packet(
    api: apiVer,
    cmd: cmd,
    seq: seq,
    opcode: opcode,
    payload: payload,
  );
}

dynamic _deserializePayload(Uint8List payloadBytes, int compFlag) {
  var bytes = payloadBytes;
  if (compFlag != 0) {
    bytes = _decompressPayload(bytes);
  }
  if (bytes.isEmpty) return null;
  try {
    return msgpack.deserialize(bytes);
  } catch (e) {
    throw Exception('MsgPack deserialization error: $e');
  }
}

/// Определяет формат сжатия по magic-number и распаковывает payload.
/// Сервер может присылать LZ4 block ИЛИ Zstandard в зависимости от ответа.
Uint8List _decompressPayload(Uint8List src) {
  // Zstandard: magic 28 B5 2F FD (little-endian)
  if (src.length >= 4 &&
      src[0] == 0x28 &&
      src[1] == 0xB5 &&
      src[2] == 0x2F &&
      src[3] == 0xFD) {
    try {
      return ZstdCodec(
        maxDecompressedSize: _maxDecompressedSize,
      ).decompress(src);
    } catch (e) {
      throw Exception('Zstd decompression error: $e');
    }
  }

  // LZ4 frame: magic 04 22 4D 18
  if (src.length >= 4 &&
      src[0] == 0x04 &&
      src[1] == 0x22 &&
      src[2] == 0x4D &&
      src[3] == 0x18) {
    try {
      return lz4Decompress(src, decompressedSize: _maxDecompressedSize);
    } catch (e) {
      throw Exception('LZ4 frame decompression error: $e');
    }
  }

  // По умолчанию — LZ4 block (без magic)
  try {
    return lz4BlockDecompress(src, _maxDecompressedSize);
  } catch (e) {
    throw Exception('LZ4 block decompression error: $e');
  }
}
