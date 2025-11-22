import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:es_compression/lz4.dart';

final lz4Codec = Lz4Codec();

Uint8List packPacket({
  required int ver,
  required int cmd,
  required int seq,
  required int opcode,
  required Map<String, dynamic> payload,
}) {
  Uint8List payloadBytes = serialize(payload);
  bool isCompressed = false;

  if (payloadBytes.length >= 32) {
    final uncompressedSize = ByteData(4)
      ..setUint32(0, payloadBytes.length, Endian.big);

    final compressedData = lz4Codec.encode(payloadBytes);

    final builder = BytesBuilder();
    builder.add(uncompressedSize.buffer.asUint8List());
    builder.add(compressedData);
    payloadBytes = builder.toBytes();
    isCompressed = true;
  }

  final header = ByteData(10);
  header.setUint8(0, ver);
  header.setUint16(1, cmd, Endian.big);
  header.setUint8(3, seq);
  header.setUint16(4, opcode, Endian.big);

  int packedLen = payloadBytes.length;
  if (isCompressed) {
    packedLen |= (1 << 24);
  }
  header.setUint32(6, packedLen, Endian.big);

  final builder = BytesBuilder();
  builder.add(header.buffer.asUint8List());
  builder.add(payloadBytes);

  return builder.toBytes();
}

Map<String, dynamic>? unpackPacket(Uint8List data) {
  if (data.length < 10) {
    print("Ошибка распаковки: Пакет слишком короткий для заголовка.");
    return null;
  }

  final byteData = data.buffer.asByteData(
    data.offsetInBytes,
    data.lengthInBytes,
  );

  final ver = byteData.getUint8(0);
  final cmd = byteData.getUint16(1, Endian.big);
  final seq = byteData.getUint8(3);
  final opcode = byteData.getUint16(4, Endian.big);
  final packedLen = byteData.getUint32(6, Endian.big);

  final compFlag = packedLen >> 24;
  final payloadLength = packedLen & 0x00FFFFFF;

  if (data.length < 10 + payloadLength) {
    print(
      "Ошибка распаковки: Фактическая длина пакета (${data.length}) меньше заявленной (${10 + payloadLength}).",
    );
    return null;
  }

  Uint8List payloadBytes = data.sublist(10, 10 + payloadLength);

  if (compFlag != 0) {
    try {
      final compressedData = payloadBytes.sublist(4);

      payloadBytes = Uint8List.fromList(lz4Codec.decode(compressedData));
    } catch (e) {
      print("Ошибка распаковки LZ4: $e");
      return null;
    }
  }

  final dynamic payload = deserialize(payloadBytes);

  return {
    "ver": ver,
    "cmd": cmd,
    "seq": seq,
    "opcode": opcode,
    "payload": payload,
  };
}
