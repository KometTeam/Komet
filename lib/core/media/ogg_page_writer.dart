import 'dart:typed_data';

// #***! сборка страниц Ogg, в него пакуется записанный опус
class OggPageWriter {
  // #***! в странице не больше 255 сегментов, это формат
  static const int maxSegmentsPerPage = 255;
  static const int continuedPacket = 0x01;
  static const int beginningOfStream = 0x02;
  static const int endOfStream = 0x04;

  // #***! заголовок фиксированный, дальше смещения полей
  static const int headerSize = 27;
  static const int _granuleOffset = 6;
  static const int _serialOffset = 14;
  static const int _sequenceOffset = 18;
  static const int _crcOffset = 22;
  static const int _segmentCountOffset = 26;

  // #***! пакет длиннее 255 байт режется на сегменты
  static int segmentsFor(int length) => (length ~/ 255) + 1;

  static int lengthFor(List<Uint8List> packets) {
    var segments = 0;
    var body = 0;
    for (final packet in packets) {
      segments += segmentsFor(packet.length);
      body += packet.length;
    }
    return headerSize + segments + body;
  }

  // #***! готовая страница одним куском
  static Uint8List page({
    required int headerType,
    required int granulePos,
    required int serial,
    required int sequence,
    required List<Uint8List> packets,
  }) {
    final out = Uint8List(lengthFor(packets));
    writeInto(
      out,
      0,
      headerType: headerType,
      granulePos: granulePos,
      serial: serial,
      sequence: sequence,
      packets: packets,
    );
    return out;
  }

  // #***! пишем в готовый буфер без лишних копий
  static int writeInto(
    Uint8List out,
    int offset, {
    required int headerType,
    required int granulePos,
    required int serial,
    required int sequence,
    required List<Uint8List> packets,
  }) {
    final view = ByteData.sublistView(out);
    out[offset] = 0x4f;
    out[offset + 1] = 0x67;
    out[offset + 2] = 0x67;
    out[offset + 3] = 0x53;
    view.setUint8(offset + 4, 0);
    view.setUint8(offset + 5, headerType);
    view.setInt64(offset + _granuleOffset, granulePos, Endian.little);
    view.setUint32(offset + _serialOffset, serial, Endian.little);
    view.setUint32(offset + _sequenceOffset, sequence, Endian.little);
    view.setUint32(offset + _crcOffset, 0, Endian.little);

    var table = offset + headerSize;
    for (final packet in packets) {
      var remaining = packet.length;
      while (remaining >= 255) {
        out[table++] = 255;
        remaining -= 255;
      }
      out[table++] = remaining;
    }
    view.setUint8(offset + _segmentCountOffset, table - offset - headerSize);

    var cursor = table;
    for (final packet in packets) {
      out.setRange(cursor, cursor + packet.length, packet);
      cursor += packet.length;
    }

    view.setUint32(
      offset + _crcOffset,
      crc32(out, offset, cursor),
      Endian.little,
    );
    return cursor;
  }

  // #***! таблицы CRC считаем один раз
  static final List<Uint32List> _crcTables = _buildCrcTables();

  static List<Uint32List> _buildCrcTables() {
    final base = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var r = (i << 24) & 0xffffffff;
      for (var j = 0; j < 8; j++) {
        if ((r & 0x80000000) != 0) {
          r = ((r << 1) ^ 0x04c11db7) & 0xffffffff;
        } else {
          r = (r << 1) & 0xffffffff;
        }
      }
      base[i] = r;
    }

    final tables = <Uint32List>[base];
    for (var slice = 1; slice < 4; slice++) {
      final previous = tables[slice - 1];
      final next = Uint32List(256);
      for (var i = 0; i < 256; i++) {
        next[i] =
            (((previous[i] << 8) & 0xffffffff) ^
                base[(previous[i] >> 24) & 0xff]) &
            0xffffffff;
      }
      tables.add(next);
    }
    return tables;
  }

  // #***! у Ogg свой CRC32, стандартный не подходит
  static int crc32(Uint8List data, [int start = 0, int? end]) {
    final stop = end ?? data.length;
    final t0 = _crcTables[0];
    final t1 = _crcTables[1];
    final t2 = _crcTables[2];
    final t3 = _crcTables[3];

    var crc = 0;
    var i = start;
    final wordEnd = stop - ((stop - start) & 3);
    while (i < wordEnd) {
      crc ^=
          (data[i] << 24) |
          (data[i + 1] << 16) |
          (data[i + 2] << 8) |
          data[i + 3];
      crc =
          t3[(crc >> 24) & 0xff] ^
          t2[(crc >> 16) & 0xff] ^
          t1[(crc >> 8) & 0xff] ^
          t0[crc & 0xff];
      i += 4;
    }
    while (i < stop) {
      crc =
          (((crc << 8) & 0xffffffff) ^ t0[((crc >> 24) & 0xff) ^ data[i]]) &
          0xffffffff;
      i++;
    }
    return crc & 0xffffffff;
  }
}
