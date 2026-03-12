import 'dart:typed_data';
import 'package:dart_lz4/dart_lz4.dart';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

import '../utils/logger.dart';

final int apiVersion = 10;
int seq = 1;

/*
  Базовый класс пакета

  api - версия API (по умолчанию 10 для сокета)
  cmd - от кого был прислан пакет (
  0 - клиент (если отправляется серверу)
  1 - сервер
  3 - отправляется вместе с ошибкой)
  seq - счёт пакетов (начинается с 1)
  opcode - показывает, для чего отправляется пакет (подробнее в /lib/core/protocol/opcode_map.dart)
  payload - содержимое пакета (отправляется с сервера ввиде msgpack)
*/
class Packet {
  int api;
  int cmd;
  int seq;
  int opcode;
  Map<dynamic, dynamic> payload;

  Packet({
    this.api = 10,
    this.cmd = 0,
    this.seq = 1,
    this.opcode = 0,
    this.payload = const {},
  });

  /// Выводит пакет в консоль
  void printPacket() {
    logger.i(
      "Api: $api\nCmd: $cmd\nSeq: $seq\nOPCode: $opcode\nPayload: $payload",
    );
  }
}

/// Функция запаковки пакета
/// Принимает только opcode и payload, так как api и cmd
/// константы (10 и 0 соответственно), а seq считается менеджером сокета
/// Возращает запакованный пакет
Uint8List packPacket(int opcode, Map<dynamic, dynamic> payload) {
  // Объяснение каждой переменной смотри в классе Packet

  final apiVerB = Uint8List(1)..[0] = apiVersion;
  final cmdB = Uint8List(1)..[0] = 0;
  final seqB = Uint8List(2)..buffer.asByteData().setUint16(0, seq, Endian.big);
  final opcodeB = Uint8List(2)
    ..buffer.asByteData().setUint16(0, opcode, Endian.big);

  // Перед получением длины пакуем в msgpack
  final payloadBytes = msgpack.serialize(payload);
  final payloadLen = payloadBytes.length & 0xFFFFFF;

  final payloadLenB = Uint8List(4)
    ..buffer.asByteData().setUint32(0, payloadLen, Endian.big);

  return Uint8List.fromList(
    apiVerB + cmdB + seqB + opcodeB + payloadLenB + payloadBytes,
  );
}

/// Функция распаковки пакета
/// Принимает байты пакета, которые отправляет сервер
/// Возращает Packet
Packet unpackPacket(Uint8List packet) {
  // Для удобства расшифровки пакета переводим в ByteData
  ByteData packetData = ByteData.view(packet.buffer);

  // Объяснение каждой переменной смотри в классе Packet

  // API версия и cmd представляют из себя 8 битные числа
  var apiVer = packetData.getUint8(0) & 0xFF;
  var cmd = packetData.getUint8(1) & 0xFF;

  // Sequence и OPCode представляют из себя 16 битные числа
  var seq = packetData.getUint16(2) & 0xFFFF;
  var opcode = packetData.getUint16(4) & 0xFFFF;

  // После базовых переменных идет длина пакета, является 32 битным числом
  var packedLen = packetData.getUint32(6);

  // Compression flag показывает, сжат ли payload
  var compFlag = packedLen >> 24;

  // Длина payload'а
  var payloadLength = packedLen & 0xFFFFFF;

  // Байты payload'а, могут быть сжаты LZ4
  var payloadBytes = packet.buffer.asUint8List(10, payloadLength);

  var payload = {};

  // Если payload пустой, ничего не делаем (так может быть при получении пинга)
  if (payloadBytes.buffer.lengthInBytes > 0) {
    // Если пакет сжат, используем LZ4
    if (compFlag != 0) {
      try {
        final decompressedBytes = lz4Decompress(
          payloadBytes,
          decompressedSize: 99999,
        );

        payloadBytes = decompressedBytes;
      } catch (e) {
        logger.e("Ошибка при декомпрессировании: $e", error: e);
      }
    }

    // Пробуем десериализовать msgpack
    try {
      payload = msgpack.deserialize(payloadBytes);
    } catch (e) {
      logger.e("Ошибка при десериализации msgpack: $e", error: e);
    }
  }

  // Собираем целый пакет и возращаем его
  final fullPacket = Packet(
    api: apiVer,
    cmd: cmd,
    seq: seq,
    opcode: opcode,
    payload: payload,
  );

  return fullPacket;
}
