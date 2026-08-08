import 'dart:typed_data';

import 'ogg_page_writer.dart';

class OpusOggIndex {
  static const int sampleRate = 48000;

  static const int _prerollSamples = 3840;
  static const int _maxPreSkip = 65535;
  static const int _maxPacketSamples = 5760;
  static const int _preSkipOffset = 10;
  static const int _opusHeadMinLength = 19;
  static const int _pageHeaderSize = 27;

  OpusOggIndex._({
    required Uint8List head,
    required Uint8List tags,
    required List<Uint8List> packets,
    required List<int> packetStarts,
    required int preSkip,
    required int serial,
    required int endGranule,
  }) : _head = head,
       _tags = tags,
       _packets = packets,
       _packetStarts = packetStarts,
       _preSkip = preSkip,
       _serial = serial,
       _endGranule = endGranule;

  final Uint8List _head;
  final Uint8List _tags;
  final List<Uint8List> _packets;
  final List<int> _packetStarts;
  final int _preSkip;
  final int _serial;
  final int _endGranule;

  double get duration {
    final playable = _endGranule - _preSkip;
    return playable <= 0 ? 0 : playable / sampleRate;
  }

  static OpusOggIndex? parse(Uint8List bytes) {
    Uint8List? head;
    Uint8List? tags;
    int? serial;
    var lastGranule = 0;
    final packets = <Uint8List>[];
    final pendingParts = <Uint8List>[];
    var pendingStart = -1;
    var pendingLength = 0;
    var pendingContiguous = true;
    var offset = 0;

    while (offset + _pageHeaderSize <= bytes.length) {
      if (!_hasCapture(bytes, offset)) {
        final resync = _findCapture(bytes, offset + 1);
        if (resync < 0) break;
        offset = resync;
        continue;
      }

      final view = ByteData.sublistView(bytes, offset);
      final headerType = bytes[offset + 5];
      final pageSerial = view.getUint32(14, Endian.little);
      final segmentCount = bytes[offset + 26];
      final tableStart = offset + _pageHeaderSize;
      final bodyStart = tableStart + segmentCount;
      if (bodyStart > bytes.length) break;

      var bodyLength = 0;
      for (var i = 0; i < segmentCount; i++) {
        bodyLength += bytes[tableStart + i];
      }
      final bodyEnd = bodyStart + bodyLength;
      if (bodyEnd > bytes.length) break;

      serial ??= pageSerial;
      if (pageSerial != serial) {
        offset = bodyEnd;
        continue;
      }

      final granule = view.getInt64(6, Endian.little);
      if (granule > lastGranule) lastGranule = granule;

      if ((headerType & OggPageWriter.continuedPacket) == 0) {
        pendingParts.clear();
        pendingStart = -1;
        pendingLength = 0;
        pendingContiguous = true;
      } else if (pendingLength > 0 && pendingContiguous) {
        pendingParts.add(
          Uint8List.sublistView(bytes, pendingStart, pendingStart + pendingLength),
        );
        pendingContiguous = false;
      }

      var cursor = bodyStart;
      for (var i = 0; i < segmentCount; i++) {
        final length = bytes[tableStart + i];
        if (length > 0) {
          if (pendingContiguous) {
            if (pendingLength == 0) pendingStart = cursor;
          } else {
            pendingParts.add(
              Uint8List.sublistView(bytes, cursor, cursor + length),
            );
          }
          pendingLength += length;
        }
        cursor += length;
        if (length == 255) continue;

        final Uint8List packet;
        if (pendingContiguous) {
          packet = pendingLength == 0
              ? _empty
              : Uint8List.sublistView(
                  bytes,
                  pendingStart,
                  pendingStart + pendingLength,
                );
        } else {
          packet = _join(pendingParts);
        }
        pendingParts.clear();
        pendingStart = -1;
        pendingLength = 0;
        pendingContiguous = true;
        if (packet.isEmpty) continue;
        if (head == null) {
          if (!_startsWith(packet, 'OpusHead')) return null;
          head = packet;
        } else if (tags == null) {
          tags = packet;
        } else {
          packets.add(packet);
        }
      }
      offset = bodyEnd;
    }

    if (head == null || tags == null || packets.isEmpty || serial == null) {
      return null;
    }
    if (head.length < _opusHeadMinLength) return null;

    final starts = <int>[];
    var total = 0;
    for (final packet in packets) {
      final samples = _packetDuration(packet);
      if (samples <= 0) return null;
      starts.add(total);
      total += samples;
    }

    final preSkip = ByteData.sublistView(
      head,
    ).getUint16(_preSkipOffset, Endian.little);
    if (preSkip >= total) return null;

    final endGranule = lastGranule > preSkip && lastGranule <= total
        ? lastGranule
        : total;

    return OpusOggIndex._(
      head: head,
      tags: tags,
      packets: packets,
      packetStarts: starts,
      preSkip: preSkip,
      serial: serial,
      endGranule: endGranule,
    );
  }

  Uint8List? sliceFrom(double seconds) {
    if (seconds <= 0) return null;
    final target = (seconds * sampleRate).round() + _preSkip;
    if (target >= _endGranule) return null;

    final floor = target - _prerollSamples;
    var first = 0;
    for (var i = 0; i < _packetStarts.length; i++) {
      if (_packetStarts[i] > floor) break;
      first = i;
    }

    final base = _packetStarts[first];
    final preSkip = target - base;
    if (preSkip < 0 || preSkip > _maxPreSkip) return null;

    final head = _headWithPreSkip(preSkip);
    final plans = <_PagePlan>[];
    var pageStart = first;
    var pageSegments = 0;
    var pageBytes = 0;

    for (var i = first; i < _packets.length; i++) {
      final packet = _packets[i];
      final segments = OggPageWriter.segmentsFor(packet.length);
      if (segments > OggPageWriter.maxSegmentsPerPage) return null;
      if (i > pageStart &&
          pageSegments + segments > OggPageWriter.maxSegmentsPerPage) {
        plans.add(
          _PagePlan(
            start: pageStart,
            end: i,
            granulePos: _packetStarts[i] - base,
            bytes: OggPageWriter.headerSize + pageSegments + pageBytes,
          ),
        );
        pageStart = i;
        pageSegments = 0;
        pageBytes = 0;
      }
      pageSegments += segments;
      pageBytes += packet.length;
    }
    plans.add(
      _PagePlan(
        start: pageStart,
        end: _packets.length,
        granulePos: _endGranule - base,
        bytes: OggPageWriter.headerSize + pageSegments + pageBytes,
        last: true,
      ),
    );

    var total =
        OggPageWriter.lengthFor([head]) + OggPageWriter.lengthFor([_tags]);
    for (final plan in plans) {
      total += plan.bytes;
    }

    final out = Uint8List(total);
    var sequence = 0;
    var offset = OggPageWriter.writeInto(
      out,
      0,
      headerType: OggPageWriter.beginningOfStream,
      granulePos: 0,
      serial: _serial,
      sequence: sequence++,
      packets: [head],
    );
    offset = OggPageWriter.writeInto(
      out,
      offset,
      headerType: 0,
      granulePos: 0,
      serial: _serial,
      sequence: sequence++,
      packets: [_tags],
    );
    for (final plan in plans) {
      offset = OggPageWriter.writeInto(
        out,
        offset,
        headerType: plan.last ? OggPageWriter.endOfStream : 0,
        granulePos: plan.granulePos,
        serial: _serial,
        sequence: sequence++,
        packets: _packets.sublist(plan.start, plan.end),
      );
    }
    return out;
  }

  Uint8List _headWithPreSkip(int preSkip) {
    final head = Uint8List.fromList(_head);
    ByteData.sublistView(
      head,
    ).setUint16(_preSkipOffset, preSkip, Endian.little);
    return head;
  }

  static bool _hasCapture(Uint8List bytes, int offset) =>
      bytes[offset] == 0x4f &&
      bytes[offset + 1] == 0x67 &&
      bytes[offset + 2] == 0x67 &&
      bytes[offset + 3] == 0x53;

  static int _findCapture(Uint8List bytes, int from) {
    for (var i = from; i + 4 <= bytes.length; i++) {
      if (_hasCapture(bytes, i)) return i;
    }
    return -1;
  }

  static final Uint8List _empty = Uint8List(0);

  static Uint8List _join(List<Uint8List> parts) {
    if (parts.isEmpty) return _empty;
    if (parts.length == 1) return parts.first;
    var length = 0;
    for (final part in parts) {
      length += part.length;
    }
    final out = Uint8List(length);
    var offset = 0;
    for (final part in parts) {
      out.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return out;
  }

  static bool _startsWith(Uint8List bytes, String magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic.codeUnitAt(i)) return false;
    }
    return true;
  }

  static int _packetDuration(Uint8List packet) {
    if (packet.isEmpty) return 0;
    final toc = packet[0];
    final frameSamples = _frameSamples(toc >> 3);
    final int frames;
    switch (toc & 0x03) {
      case 0:
        frames = 1;
      case 1:
      case 2:
        frames = 2;
      default:
        if (packet.length < 2) return 0;
        frames = packet[1] & 0x3f;
    }
    if (frames <= 0) return 0;
    final total = frameSamples * frames;
    return total > _maxPacketSamples ? 0 : total;
  }

  static int _frameSamples(int config) {
    const silkOrHybrid = [480, 960, 1920, 2880];
    const celt = [120, 240, 480, 960];
    if (config < 12) return silkOrHybrid[config & 0x03];
    if (config < 16) return (config & 0x01) == 0 ? 480 : 960;
    return celt[config & 0x03];
  }
}

class _PagePlan {
  const _PagePlan({
    required this.start,
    required this.end,
    required this.granulePos,
    required this.bytes,
    this.last = false,
  });

  final int start;
  final int end;
  final int granulePos;
  final int bytes;
  final bool last;
}
