import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/ogg_page_writer.dart';
import 'package:komet/core/media/opus_ogg_index.dart';

const int _sampleRate = 48000;
const int _packetSamples = 960;
const int _preSkip = 312;
const int _serial = 0x4b6f6d74;
const int _packetsPerPage = 20;

Uint8List _le16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

Uint8List _le32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

Uint8List _opusHead() {
  final out = BytesBuilder()
    ..add('OpusHead'.codeUnits)
    ..addByte(1)
    ..addByte(1)
    ..add(_le16(_preSkip))
    ..add(_le32(_sampleRate))
    ..add(_le16(0))
    ..addByte(0);
  return out.toBytes();
}

Uint8List _opusTags() {
  const vendor = 'komet-test';
  final out = BytesBuilder()
    ..add('OpusTags'.codeUnits)
    ..add(_le32(vendor.length))
    ..add(vendor.codeUnits)
    ..add(_le32(0));
  return out.toBytes();
}

Uint8List _audioPacket(int index) {
  final out = Uint8List(40);
  out[0] = 0x08;
  out[1] = index & 0xff;
  for (var i = 2; i < out.length; i++) {
    out[i] = (index + i) & 0xff;
  }
  return out;
}

Uint8List _buildStream(int packetCount, {int endTrim = 0}) {
  final pages = <Uint8List>[];
  var sequence = 0;
  pages.add(
    OggPageWriter.page(
      headerType: OggPageWriter.beginningOfStream,
      granulePos: 0,
      serial: _serial,
      sequence: sequence++,
      packets: [_opusHead()],
    ),
  );
  pages.add(
    OggPageWriter.page(
      headerType: 0,
      granulePos: 0,
      serial: _serial,
      sequence: sequence++,
      packets: [_opusTags()],
    ),
  );

  for (var start = 0; start < packetCount; start += _packetsPerPage) {
    final end = (start + _packetsPerPage).clamp(0, packetCount);
    final last = end == packetCount;
    final packets = [
      for (var i = start; i < end; i++) _audioPacket(i),
    ];
    pages.add(
      OggPageWriter.page(
        headerType: last ? OggPageWriter.endOfStream : 0,
        granulePos: end * _packetSamples - (last ? endTrim : 0),
        serial: _serial,
        sequence: sequence++,
        packets: packets,
      ),
    );
  }

  final builder = BytesBuilder();
  for (final page in pages) {
    builder.add(page);
  }
  return builder.toBytes();
}

int _referenceCrc(Uint8List data) {
  var crc = 0;
  for (final byte in data) {
    crc ^= (byte << 24) & 0xffffffff;
    for (var bit = 0; bit < 8; bit++) {
      if ((crc & 0x80000000) != 0) {
        crc = ((crc << 1) ^ 0x04c11db7) & 0xffffffff;
      } else {
        crc = (crc << 1) & 0xffffffff;
      }
    }
  }
  return crc;
}

class _Page {
  _Page({required this.headerType, required this.granulePos});

  final int headerType;
  final int granulePos;
}

List<_Page> _verifyPages(Uint8List bytes) {
  final pages = <_Page>[];
  var offset = 0;
  while (offset + 27 <= bytes.length) {
    expect(
      String.fromCharCodes(bytes, offset, offset + 4),
      'OggS',
      reason: 'страница на смещении $offset',
    );
    final view = ByteData.sublistView(bytes, offset);
    final segmentCount = bytes[offset + 26];
    final tableStart = offset + 27;
    var bodyLength = 0;
    for (var i = 0; i < segmentCount; i++) {
      bodyLength += bytes[tableStart + i];
    }
    final pageEnd = tableStart + segmentCount + bodyLength;
    expect(pageEnd <= bytes.length, isTrue);

    final stored = view.getUint32(22, Endian.little);
    final page = Uint8List.fromList(bytes.sublist(offset, pageEnd));
    ByteData.sublistView(page).setUint32(22, 0, Endian.little);
    expect(_referenceCrc(page), stored, reason: 'CRC страницы $offset');

    pages.add(
      _Page(
        headerType: bytes[offset + 5],
        granulePos: view.getInt64(6, Endian.little),
      ),
    );
    offset = pageEnd;
  }
  expect(offset, bytes.length);
  return pages;
}

void main() {
  test('crc32 совпадает с побитовой реализацией на любой длине', () {
    for (var length = 0; length <= 260; length++) {
      final data = Uint8List.fromList(
        List.generate(length, (i) => (i * 31 + length) & 0xff),
      );
      expect(
        OggPageWriter.crc32(data),
        _referenceCrc(data),
        reason: 'длина $length',
      );
    }
  });

  test('crc32 по диапазону не зависит от окружающих байт', () {
    final payload = Uint8List.fromList(
      List.generate(1021, (i) => (i * 7) & 0xff),
    );
    final padded = Uint8List(payload.length + 9)
      ..fillRange(0, 5, 0xab)
      ..setRange(5, 5 + payload.length, payload)
      ..fillRange(5 + payload.length, payload.length + 9, 0xcd);

    expect(
      OggPageWriter.crc32(padded, 5, 5 + payload.length),
      _referenceCrc(payload),
    );
  });

  test('разбирает длительность из TOC-байтов', () {
    final index = OpusOggIndex.parse(_buildStream(250))!;
    expect(
      index.duration,
      closeTo((250 * _packetSamples - _preSkip) / _sampleRate, 1e-9),
    );
  });

  test('не разбирает мусор', () {
    expect(OpusOggIndex.parse(Uint8List(0)), isNull);
    expect(
      OpusOggIndex.parse(Uint8List.fromList(List.filled(512, 7))),
      isNull,
    );
  });

  test('срез укорачивает поток ровно на запрошенную позицию', () {
    final index = OpusOggIndex.parse(_buildStream(500))!;
    final total = index.duration;

    for (final seconds in [0.02, 0.5, 1.0, 3.3, 7.75]) {
      final sliced = index.sliceFrom(seconds);
      expect(sliced, isNotNull, reason: 'срез с $seconds с');
      final reparsed = OpusOggIndex.parse(sliced!)!;
      expect(
        reparsed.duration,
        closeTo(total - seconds, 1e-6),
        reason: 'длительность среза с $seconds с',
      );
    }
  });

  test('срез остаётся валидным Ogg с EOS на последней странице', () {
    final index = OpusOggIndex.parse(_buildStream(500))!;
    final sliced = index.sliceFrom(4.0)!;
    final pages = _verifyPages(sliced);

    expect(pages.length, greaterThan(2));
    expect(pages.first.headerType & OggPageWriter.beginningOfStream, isNot(0));
    expect(pages.first.granulePos, 0);
    expect(pages[1].granulePos, 0);
    expect(pages.last.headerType & OggPageWriter.endOfStream, isNot(0));

    var previous = -1;
    for (final page in pages) {
      expect(page.granulePos, greaterThanOrEqualTo(previous));
      previous = page.granulePos;
    }
  });

  test('учитывает обрезку хвоста в финальной granule', () {
    const trim = 700;
    final index = OpusOggIndex.parse(_buildStream(300, endTrim: trim))!;
    expect(
      index.duration,
      closeTo((300 * _packetSamples - _preSkip - trim) / _sampleRate, 1e-9),
    );

    final sliced = index.sliceFrom(2.0);
    final reparsed = OpusOggIndex.parse(sliced!)!;
    expect(reparsed.duration, closeTo(index.duration - 2.0, 1e-6));
  });

  test('срез за пределами длительности не строится', () {
    final index = OpusOggIndex.parse(_buildStream(100))!;
    expect(index.sliceFrom(0), isNull);
    expect(index.sliceFrom(-1), isNull);
    expect(index.sliceFrom(index.duration + 1), isNull);
  });
}
