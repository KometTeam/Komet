import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// #***! шифрованное фото едет как валидный RGB8 PNG из шума, пиксели = байты блоба
const int _channels = 3;
const int _maxDimension = 16384;
// #***! zlib раздувает без предела, распаковываем порциями по бюджету из IHDR
const int _inflateChunk = 1 << 16;
const List<int> _signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

void _writeChunk(BytesBuilder out, String type, List<int> data) {
  final typeBytes = type.codeUnits;
  out.add(_be32(data.length));
  out.add(typeBytes);
  out.add(data);
  out.add(_be32(_crc32([...typeBytes, ...data])));
}

Uint8List _be32(int value) => Uint8List(4)
  ..[0] = (value >> 24) & 0xFF
  ..[1] = (value >> 16) & 0xFF
  ..[2] = (value >> 8) & 0xFF
  ..[3] = value & 0xFF;

int _readBe32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

Uint8List? wrapNoisePng(Uint8List blob, {Random? random}) {
  final rng = random ?? Random.secure();
  final pixels = (blob.length + _channels - 1) ~/ _channels;
  final width = max(1, sqrt(pixels).ceil());
  if (width > _maxDimension) return null;
  final height = max(1, (pixels + width - 1) ~/ width);
  final stride = width * _channels;
  final raw = Uint8List((stride + 1) * height);
  var source = 0;
  for (var row = 0; row < height; row++) {
    final start = row * (stride + 1) + 1;
    for (var column = 0; column < stride; column++) {
      raw[start + column] = source < blob.length
          ? blob[source]
          : rng.nextInt(256);
      source++;
    }
  }
  final out = BytesBuilder(copy: false);
  out.add(_signature);
  _writeChunk(out, 'IHDR', [
    ..._be32(width),
    ..._be32(height),
    8,
    2,
    0,
    0,
    0,
  ]);
  _writeChunk(out, 'IDAT', ZLibEncoder(level: 1).convert(raw));
  _writeChunk(out, 'IEND', const []);
  return out.toBytes();
}

// #***! обратно из PNG в байты, null если это не наш RGB8 без interlace
Uint8List? unwrapNoisePng(Uint8List png) {
  if (png.length < _signature.length + 8) return null;
  for (var i = 0; i < _signature.length; i++) {
    if (png[i] != _signature[i]) return null;
  }
  var offset = _signature.length;
  int? width;
  int? height;
  final idat = BytesBuilder(copy: false);
  while (offset + 8 <= png.length) {
    final length = _readBe32(png, offset);
    final type = String.fromCharCodes(png, offset + 4, offset + 8);
    final dataStart = offset + 8;
    final dataEnd = dataStart + length;
    if (length < 0 || dataEnd + 4 > png.length) return null;
    if (type == 'IHDR') {
      if (length != 13) return null;
      width = _readBe32(png, dataStart);
      height = _readBe32(png, dataStart + 4);
      final depth = png[dataStart + 8];
      final color = png[dataStart + 9];
      final interlace = png[dataStart + 12];
      if (depth != 8 || color != 2 || interlace != 0) return null;
      if (width <= 0 || height <= 0) return null;
      if (width > _maxDimension || height > _maxDimension) return null;
    } else if (type == 'IDAT') {
      idat.add(Uint8List.sublistView(png, dataStart, dataEnd));
    } else if (type == 'IEND') {
      break;
    }
    offset = dataEnd + 4;
  }
  if (width == null || height == null) return null;
  final stride = width * _channels;
  final expected = (stride + 1) * height;
  final Uint8List? inflated;
  try {
    inflated = _inflateBounded(idat.toBytes(), expected);
  } catch (_) {
    return null;
  }
  if (inflated == null) return null;
  final out = Uint8List(stride * height);
  final previous = Uint8List(stride);
  final current = Uint8List(stride);
  for (var row = 0; row < height; row++) {
    final start = row * (stride + 1);
    final filter = inflated[start];
    current.setRange(0, stride, inflated, start + 1);
    for (var i = 0; i < stride; i++) {
      final left = i >= _channels ? current[i - _channels] : 0;
      final up = previous[i];
      final upLeft = i >= _channels ? previous[i - _channels] : 0;
      final int predictor;
      switch (filter) {
        case 0:
          predictor = 0;
        case 1:
          predictor = left;
        case 2:
          predictor = up;
        case 3:
          predictor = (left + up) >> 1;
        case 4:
          predictor = _paeth(left, up, upLeft);
        default:
          return null;
      }
      current[i] = (current[i] + predictor) & 0xFF;
    }
    out.setRange(row * stride, (row + 1) * stride, current);
    previous.setAll(0, current);
  }
  return out;
}

// #***! ровно обещанный объём, больше заголовка нам всё равно не нужно
Uint8List? _inflateBounded(Uint8List input, int limit) {
  final out = BytesBuilder(copy: false);
  final sink = _BoundedSink(out, limit);
  final converter = ZLibDecoder().startChunkedConversion(sink);
  try {
    for (var offset = 0; offset < input.length; offset += _inflateChunk) {
      final end = offset + _inflateChunk < input.length
          ? offset + _inflateChunk
          : input.length;
      converter.add(Uint8List.sublistView(input, offset, end));
      if (sink.full) break;
    }
    if (!sink.full) converter.close();
  } catch (_) {
    return null;
  }
  final bytes = out.toBytes();
  return bytes.length < limit ? null : Uint8List.sublistView(bytes, 0, limit);
}

class _BoundedSink implements Sink<List<int>> {
  _BoundedSink(this._out, this._limit);

  final BytesBuilder _out;
  final int _limit;

  bool get full => _out.length >= _limit;

  @override
  void add(List<int> data) {
    if (full) return;
    final room = _limit - _out.length;
    _out.add(data.length <= room ? data : data.sublist(0, room));
  }

  @override
  void close() {}
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}
