import 'dart:typed_data';

import 'package:image/image.dart' as img;

// #***! константы BMP
const int _biBitfields = 3;
const int _biAlphaBitfields = 6;
const int _fileHeaderSize = 14;
const int _coreHeaderSize = 12;
const int _infoHeaderSize = 40;

// #***! винда отдаёт картинку как DIB, это BMP без файлового заголовка
Uint8List? dibToPng(Uint8List dib) {
  final bmp = _wrapDibAsBmp(dib);
  if (bmp == null) return null;
  try {
    final decoded = img.decodeBmp(bmp);
    if (decoded == null) return null;
    return img.encodePng(decoded);
  } catch (_) {
    return null;
  }
}

// #***! дописываем 14 байт заголовка, смещение пикселей считаем по палитре и маскам
Uint8List? _wrapDibAsBmp(Uint8List dib) {
  if (dib.length < _coreHeaderSize) return null;
  final source = ByteData.sublistView(dib);
  final headerSize = source.getUint32(0, Endian.little);
  if (headerSize != _coreHeaderSize && headerSize < _infoHeaderSize) {
    return null;
  }
  if (dib.length < headerSize) return null;

  final int bitCount;
  final int compression;
  final int paletteEntries;
  if (headerSize == _coreHeaderSize) {
    bitCount = source.getUint16(10, Endian.little);
    compression = 0;
    paletteEntries = bitCount <= 8 ? 1 << bitCount : 0;
  } else {
    bitCount = source.getUint16(14, Endian.little);
    compression = source.getUint32(16, Endian.little);
    final declared = source.getUint32(32, Endian.little);
    paletteEntries = bitCount <= 8
        ? (declared != 0 ? declared : 1 << bitCount)
        : declared;
  }

  var extra = paletteEntries * (headerSize == _coreHeaderSize ? 3 : 4);
  if (headerSize == _infoHeaderSize) {
    if (compression == _biBitfields) extra += 12;
    if (compression == _biAlphaBitfields) extra += 16;
  }

  final pixelOffset = _fileHeaderSize + headerSize + extra;
  if (pixelOffset >= _fileHeaderSize + dib.length) return null;

  final bmp = Uint8List(_fileHeaderSize + dib.length);
  final header = ByteData.sublistView(bmp, 0, _fileHeaderSize);
  header.setUint8(0, 0x42);
  header.setUint8(1, 0x4D);
  header.setUint32(2, bmp.length, Endian.little);
  header.setUint32(10, pixelOffset, Endian.little);
  bmp.setRange(_fileHeaderSize, bmp.length, dib);
  return bmp;
}
