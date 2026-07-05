import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart';

import '../utils/logger.dart';

/// Кодирует PCM в Ogg/Opus через libopus (FFI) на платформах, где у системы нет
/// своего Opus-энкодера (Windows). Сырые Opus-пакеты выдаёт [opus_dart], а
/// Ogg-контейнер (страницы, лейсинг, CRC32, OpusHead/OpusTags) собирается здесь.
///
/// Формат совпадает с тем, что шлёт оригинальный клиент: моно, 48000 Hz,
/// pre-skip 312, vendor «libopus unknown».
class OpusOggEncoder {
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _preSkip = 312;
  static const int _frameSamples = 960; // 20 мс @ 48 кГц
  static const int _serial = 0x4b6f6d74; // 'Komt'
  static const String _vendor = 'libopus unknown';

  static bool _initialized = false;
  static bool _available = false;

  /// Лениво загружает libopus и инициализирует opus_dart: на Windows —
  /// вендоренную `opus.dll` рядом с exe, на Android — через
  /// `opus_flutter_android`. Возвращает `false`, если кодек недоступен.
  static Future<bool> ensureAvailable() async {
    if (_initialized) return _available;
    _initialized = true;
    try {
      // libopus.so на Android бандлится плагином opus_flutter_android,
      // opus.dll — вендоренная рядом с exe на Windows.
      final String libName;
      if (Platform.isWindows) {
        libName = 'opus.dll';
      } else if (Platform.isAndroid) {
        libName = 'libopus.so';
      } else {
        return false;
      }
      initOpus(DynamicLibrary.open(libName) as dynamic);
      _available = true;
    } catch (e) {
      logger.w('OpusOggEncoder: libopus недоступна: $e');
      _available = false;
    }
    return _available;
  }

  /// Парсит WAV (16-bit PCM моно 48 кГц) и кодирует его в Ogg/Opus.
  /// Возвращает `null`, если кодек недоступен или WAV не распознан.
  static Future<Uint8List?> wavToOggOpus(Uint8List wav) async {
    if (!await ensureAvailable()) return null;
    final pcm = _pcmFromWav(wav);
    if (pcm == null || pcm.isEmpty) return null;
    try {
      return _encodePcm(pcm);
    } catch (e) {
      logger.w('OpusOggEncoder: ошибка кодирования: $e');
      return null;
    }
  }

  static Uint8List _encodePcm(Int16List pcm) {
    final encoder = SimpleOpusEncoder(
      sampleRate: _sampleRate,
      channels: _channels,
      application: Application.audio,
    );
    final packets = <Uint8List>[];
    try {
      for (var off = 0; off < pcm.length; off += _frameSamples) {
        final end = off + _frameSamples;
        final Int16List frame;
        if (end <= pcm.length) {
          frame = Int16List.sublistView(pcm, off, end);
        } else {
          frame = Int16List(_frameSamples)
            ..setRange(0, pcm.length - off, pcm, off);
        }
        packets.add(encoder.encode(input: frame));
      }
    } finally {
      encoder.destroy();
    }
    return _buildOgg(packets, totalSamples: pcm.length);
  }

  static Uint8List _buildOgg(
    List<Uint8List> packets, {
    required int totalSamples,
  }) {
    final out = BytesBuilder();
    var seq = 0;

    out.add(
      _page(
        headerType: 0x02,
        granulePos: 0,
        seq: seq++,
        packets: [_opusHead()],
      ),
    );
    out.add(
      _page(
        headerType: 0x00,
        granulePos: 0,
        seq: seq++,
        packets: [_opusTags()],
      ),
    );

    var pagePackets = <Uint8List>[];
    var pageSegments = 0;
    var samples = 0;

    void flush({required bool last}) {
      final granule = last ? totalSamples + _preSkip : samples + _preSkip;
      out.add(
        _page(
          headerType: last ? 0x04 : 0x00,
          granulePos: granule,
          seq: seq++,
          packets: pagePackets,
        ),
      );
      pagePackets = <Uint8List>[];
      pageSegments = 0;
    }

    for (var i = 0; i < packets.length; i++) {
      final p = packets[i];
      final segs = (p.length ~/ 255) + 1;
      if (pagePackets.isNotEmpty && pageSegments + segs > 255) {
        flush(last: false);
      }
      pagePackets.add(p);
      pageSegments += segs;
      samples += _frameSamples;
    }
    flush(last: true);

    return out.toBytes();
  }

  static Uint8List _opusHead() {
    final b = BytesBuilder();
    b.add(_ascii('OpusHead'));
    final d = ByteData(11);
    d.setUint8(0, 1); // version
    d.setUint8(1, _channels);
    d.setUint16(2, _preSkip, Endian.little);
    d.setUint32(4, _sampleRate, Endian.little);
    d.setUint16(8, 0, Endian.little); // output gain
    d.setUint8(10, 0); // channel mapping family
    b.add(d.buffer.asUint8List());
    return b.toBytes();
  }

  static Uint8List _opusTags() {
    final vendor = _ascii(_vendor);
    final b = BytesBuilder();
    b.add(_ascii('OpusTags'));
    final len = ByteData(4)..setUint32(0, vendor.length, Endian.little);
    b.add(len.buffer.asUint8List());
    b.add(vendor);
    final count = ByteData(4)..setUint32(0, 0, Endian.little);
    b.add(count.buffer.asUint8List());
    return b.toBytes();
  }

  static Uint8List _page({
    required int headerType,
    required int granulePos,
    required int seq,
    required List<Uint8List> packets,
  }) {
    final segs = <int>[];
    for (final p in packets) {
      var len = p.length;
      while (len >= 255) {
        segs.add(255);
        len -= 255;
      }
      segs.add(len);
    }

    final header = Uint8List(27 + segs.length);
    final hd = ByteData.sublistView(header);
    header.setRange(0, 4, _ascii('OggS'));
    hd.setUint8(4, 0); // stream structure version
    hd.setUint8(5, headerType);
    hd.setUint64(6, granulePos, Endian.little);
    hd.setUint32(14, _serial, Endian.little);
    hd.setUint32(18, seq, Endian.little);
    hd.setUint32(22, 0, Endian.little); // CRC placeholder
    hd.setUint8(26, segs.length);
    header.setRange(27, 27 + segs.length, segs);

    final body = BytesBuilder();
    body.add(header);
    for (final p in packets) {
      body.add(p);
    }
    final page = body.toBytes();

    final crc = _crc32(page);
    ByteData.sublistView(page).setUint32(22, crc, Endian.little);
    return page;
  }

  static Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);

  static final Uint32List _crcTable = _buildCrcTable();

  static Uint32List _buildCrcTable() {
    final t = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var r = (i << 24) & 0xffffffff;
      for (var j = 0; j < 8; j++) {
        if ((r & 0x80000000) != 0) {
          r = ((r << 1) ^ 0x04c11db7) & 0xffffffff;
        } else {
          r = (r << 1) & 0xffffffff;
        }
      }
      t[i] = r;
    }
    return t;
  }

  static int _crc32(Uint8List data) {
    var crc = 0;
    for (final b in data) {
      crc =
          (((crc << 8) & 0xffffffff) ^ _crcTable[((crc >> 24) & 0xff) ^ b]) &
          0xffffffff;
    }
    return crc & 0xffffffff;
  }

  static Int16List? _pcmFromWav(Uint8List bytes) {
    if (bytes.length < 12) return null;
    if (String.fromCharCodes(bytes, 0, 4) != 'RIFF' ||
        String.fromCharCodes(bytes, 8, 12) != 'WAVE') {
      return null;
    }
    final bd = ByteData.sublistView(bytes);
    var off = 12;
    while (off + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes, off, off + 4);
      final size = bd.getUint32(off + 4, Endian.little);
      final body = off + 8;
      if (id == 'data') {
        final end = (body + size) <= bytes.length ? body + size : bytes.length;
        final n = (end - body) ~/ 2;
        final pcm = Int16List(n);
        for (var i = 0; i < n; i++) {
          pcm[i] = bd.getInt16(body + i * 2, Endian.little);
        }
        return pcm;
      }
      off = body + size + (size & 1);
    }
    return null;
  }
}
