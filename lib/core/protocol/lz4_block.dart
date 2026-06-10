import 'dart:typed_data';

/// LZ4 block декомпрессия (без frame-заголовка).
///
/// Сервер шлёт block-формат как в транспорте (payload пакетов), так и в
/// `vcp`-параметрах звонка. dart_lz4 поддерживает только frame-формат, поэтому
/// block распаковывается вручную.
Uint8List lz4BlockDecompress(Uint8List src, int maxSize) {
  var out = Uint8List(1024);
  int outLen = 0;
  int pos = 0;

  void ensure(int extra) {
    if (outLen + extra > maxSize) throw StateError('LZ4: превышен лимит');
    if (outLen + extra <= out.length) return;
    var newCap = out.length * 2;
    while (newCap < outLen + extra) {
      newCap *= 2;
    }
    if (newCap > maxSize) newCap = maxSize;
    final grown = Uint8List(newCap);
    grown.setRange(0, outLen, out);
    out = grown;
  }

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
      ensure(litLen);
      out.setRange(outLen, outLen + litLen, src, pos);
      outLen += litLen;
      pos += litLen;
    }

    if (pos >= src.length) break;

    if (pos + 1 >= src.length) throw StateError('LZ4: unexpected end of input');
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

    ensure(matchLen);
    final start = outLen - offset;
    if (start < 0) throw StateError('LZ4: offset за пределами вывода');
    for (var i = 0; i < matchLen; i++) {
      out[outLen + i] = out[start + i];
    }
    outLen += matchLen;
  }

  return Uint8List.sublistView(out, 0, outLen);
}
