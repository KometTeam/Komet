import 'dart:io';
import 'dart:typed_data';

class EncodedClipHeader {
  const EncodedClipHeader({
    required this.px,
    required this.frameCount,
    required this.frameRate,
    required this.durationMs,
  });

  final int px;
  final int frameCount;
  final double frameRate;
  final int durationMs;
}

class DecodedClip {
  const DecodedClip(this.header, this.frames);

  final EncodedClipHeader header;
  final Uint8List frames;

  Uint8List frame(int index) {
    final size = header.px * header.px * 4;
    return Uint8List.sublistView(frames, index * size, (index + 1) * size);
  }
}

class TlottieCodec {
  static const int _magic = 0x4b544c46;
  static const int _version = 2;
  static const int _headerBytes = 28;

  static Uint8List encode(EncodedClipHeader header, Uint8List frames) {
    final frameBytes = header.px * header.px * 4;
    final payload = Uint8List.fromList(frames);
    for (var i = header.frameCount - 1; i >= 1; i--) {
      final cur = i * frameBytes;
      final prev = (i - 1) * frameBytes;
      for (var b = 0; b < frameBytes; b++) {
        payload[cur + b] ^= payload[prev + b];
      }
    }
    final compressed = GZipCodec(level: 1).encode(payload);
    final head = ByteData(_headerBytes)
      ..setUint32(0, _magic)
      ..setUint8(4, _version)
      ..setUint32(8, header.px)
      ..setUint32(12, header.frameCount)
      ..setFloat64(16, header.frameRate)
      ..setUint32(24, header.durationMs);
    return (BytesBuilder(copy: false)
          ..add(head.buffer.asUint8List())
          ..add(compressed))
        .takeBytes();
  }

  static DecodedClip? decode(Uint8List bytes) {
    if (bytes.length < _headerBytes) return null;
    final head = ByteData.sublistView(bytes, 0, _headerBytes);
    if (head.getUint32(0) != _magic || head.getUint8(4) != _version) {
      return null;
    }
    final header = EncodedClipHeader(
      px: head.getUint32(8),
      frameCount: head.getUint32(12),
      frameRate: head.getFloat64(16),
      durationMs: head.getUint32(24),
    );
    final frameBytes = header.px * header.px * 4;
    final inflated = gzip.decode(Uint8List.sublistView(bytes, _headerBytes));
    if (inflated.length != frameBytes * header.frameCount) return null;
    final payload = inflated is Uint8List
        ? inflated
        : Uint8List.fromList(inflated);
    for (var i = 1; i < header.frameCount; i++) {
      final cur = i * frameBytes;
      final prev = (i - 1) * frameBytes;
      for (var b = 0; b < frameBytes; b++) {
        payload[cur + b] ^= payload[prev + b];
      }
    }
    return DecodedClip(header, payload);
  }
}
