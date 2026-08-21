import 'dart:convert';
import 'dart:typed_data';

class MaxWebFrame {
  final int cmd;
  final int seq;
  final int opcode;
  final Object? payload;

  const MaxWebFrame({
    required this.cmd,
    required this.seq,
    required this.opcode,
    this.payload,
  });

  bool get isOk => cmd == MaxWebCmd.ok;
  bool get isError => cmd != MaxWebCmd.ok && cmd != MaxWebCmd.request;
}

abstract class MaxWebCmd {
  static const int request = 0;
  static const int ok = 1;
  static const int notFound = 2;
  static const int error = 3;
}

abstract class MaxWebFraming {
  static const int protocolVersion = 10;
  static const int headerSize = 10;

  static Uint8List encode({
    required int cmd,
    required int seq,
    required int opcode,
    Object? payload,
  }) {
    final body = payload == null
        ? Uint8List(0)
        : MaxMsgpack.encode(payload);
    final frame = Uint8List(headerSize + body.length);
    final view = ByteData.view(frame.buffer);

    view.setUint8(0, protocolVersion);
    view.setUint8(1, cmd);
    view.setInt16(2, seq);
    view.setInt16(4, opcode);
    view.setUint8(6, 0);
    view.setUint8(7, (body.length >> 16) & 0xFF);
    view.setUint8(8, (body.length >> 8) & 0xFF);
    view.setUint8(9, body.length & 0xFF);

    frame.setRange(headerSize, frame.length, body);
    return frame;
  }

  static MaxWebFrame decode(Uint8List frame) {
    if (frame.length < headerSize) {
      throw const FormatException('MaxWebFraming: кадр короче заголовка');
    }
    final view = ByteData.view(frame.buffer, frame.offsetInBytes, frame.length);

    final cmd = view.getUint8(1);
    final seq = view.getInt16(2);
    final opcode = view.getInt16(4);
    final compressionRatio = view.getUint8(6);
    final length =
        (view.getUint8(7) << 16) | (view.getUint8(8) << 8) | view.getUint8(9);

    if (length <= 0) {
      return MaxWebFrame(cmd: cmd, seq: seq, opcode: opcode);
    }

    var body = Uint8List.sublistView(frame, headerSize, headerSize + length);
    if (compressionRatio > 0) {
      body = Lz4Block.decompress(body, length * compressionRatio * 16);
    }

    return MaxWebFrame(
      cmd: cmd,
      seq: seq,
      opcode: opcode,
      payload: MaxMsgpack.decode(body),
    );
  }
}

abstract class Lz4Block {
  static Uint8List decompress(Uint8List source, int maxOutputSize) {
    final output = Uint8List(maxOutputSize);
    var input = 0;
    var written = 0;

    while (input < source.length) {
      final token = source[input++];

      var literalLength = token >> 4;
      if (literalLength == 15) {
        literalLength += _readLengthExtension(source, () => input, (v) => input = v);
      }

      if (written + literalLength > output.length) {
        throw const FormatException('Lz4Block: литералы не помещаются');
      }
      output.setRange(written, written + literalLength,
          Uint8List.sublistView(source, input, input + literalLength));
      written += literalLength;
      input += literalLength;

      if (input >= source.length) break;

      final offset = source[input] | (source[input + 1] << 8);
      input += 2;
      if (offset == 0 || offset > written) {
        throw const FormatException('Lz4Block: неверное смещение совпадения');
      }

      var matchLength = token & 0x0F;
      if (matchLength == 15) {
        matchLength += _readLengthExtension(source, () => input, (v) => input = v);
      }
      matchLength += 4;

      if (written + matchLength > output.length) {
        throw const FormatException('Lz4Block: совпадение не помещается');
      }

      var from = written - offset;
      for (var i = 0; i < matchLength; i++) {
        output[written++] = output[from++];
      }
    }

    return Uint8List.sublistView(output, 0, written);
  }

  static int _readLengthExtension(
    Uint8List source,
    int Function() get,
    void Function(int) set,
  ) {
    var cursor = get();
    var extra = 0;
    while (true) {
      if (cursor >= source.length) {
        throw const FormatException('Lz4Block: обрыв в расширении длины');
      }
      final byte = source[cursor++];
      extra += byte;
      if (byte != 255) break;
    }
    set(cursor);
    return extra;
  }
}

abstract class MaxMsgpack {
  static Uint8List encode(Object? value) {
    final sink = BytesBuilder(copy: false);
    _write(sink, value);
    return sink.takeBytes();
  }

  static Object? decode(Uint8List bytes) => _Reader(bytes).read();

  static void _write(BytesBuilder sink, Object? value) {
    if (value == null) {
      sink.addByte(0xC0);
    } else if (value is bool) {
      sink.addByte(value ? 0xC3 : 0xC2);
    } else if (value is int) {
      _writeInt(sink, value);
    } else if (value is double) {
      final buffer = ByteData(9)
        ..setUint8(0, 0xCB)
        ..setFloat64(1, value);
      sink.add(buffer.buffer.asUint8List());
    } else if (value is String) {
      _writeString(sink, value);
    } else if (value is Uint8List) {
      _writeBinary(sink, value);
    } else if (value is List) {
      _writePrefix(sink, value.length, 0x90, 0xDC, 0xDD);
      for (final item in value) {
        _write(sink, item);
      }
    } else if (value is Map) {
      _writePrefix(sink, value.length, 0x80, 0xDE, 0xDF);
      value.forEach((key, item) {
        _write(sink, key);
        _write(sink, item);
      });
    } else {
      throw ArgumentError('MaxMsgpack: неподдерживаемый тип ${value.runtimeType}');
    }
  }

  static void _writePrefix(
    BytesBuilder sink,
    int length,
    int fixBase,
    int wide16,
    int wide32,
  ) {
    if (length < 16) {
      sink.addByte(fixBase | length);
    } else if (length < 0x10000) {
      sink.addByte(wide16);
      sink.add([(length >> 8) & 0xFF, length & 0xFF]);
    } else {
      sink.addByte(wide32);
      sink.add([
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]);
    }
  }

  static void _writeString(BytesBuilder sink, String value) {
    final utf8Bytes = utf8.encode(value);
    final length = utf8Bytes.length;
    if (length < 32) {
      sink.addByte(0xA0 | length);
    } else if (length < 0x100) {
      sink.add([0xD9, length]);
    } else if (length < 0x10000) {
      sink.add([0xDA, (length >> 8) & 0xFF, length & 0xFF]);
    } else {
      sink.add([
        0xDB,
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]);
    }
    sink.add(utf8Bytes);
  }

  static void _writeBinary(BytesBuilder sink, Uint8List value) {
    final length = value.length;
    if (length < 0x100) {
      sink.add([0xC4, length]);
    } else if (length < 0x10000) {
      sink.add([0xC5, (length >> 8) & 0xFF, length & 0xFF]);
    } else {
      sink.add([
        0xC6,
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]);
    }
    sink.add(value);
  }

  static void _writeInt(BytesBuilder sink, int value) {
    if (value >= 0) {
      if (value < 0x80) {
        sink.addByte(value);
      } else if (value < 0x100) {
        sink.add([0xCC, value]);
      } else if (value < 0x10000) {
        sink.add([0xCD, (value >> 8) & 0xFF, value & 0xFF]);
      } else if (value < 0x100000000) {
        sink.add([
          0xCE,
          (value >> 24) & 0xFF,
          (value >> 16) & 0xFF,
          (value >> 8) & 0xFF,
          value & 0xFF,
        ]);
      } else {
        final buffer = ByteData(9)
          ..setUint8(0, 0xCF)
          ..setUint64(1, value);
        sink.add(buffer.buffer.asUint8List());
      }
    } else if (value >= -32) {
      sink.addByte(0xE0 | (value + 32));
    } else if (value >= -128) {
      final buffer = ByteData(2)
        ..setUint8(0, 0xD0)
        ..setInt8(1, value);
      sink.add(buffer.buffer.asUint8List());
    } else if (value >= -32768) {
      final buffer = ByteData(3)
        ..setUint8(0, 0xD1)
        ..setInt16(1, value);
      sink.add(buffer.buffer.asUint8List());
    } else if (value >= -2147483648) {
      final buffer = ByteData(5)
        ..setUint8(0, 0xD2)
        ..setInt32(1, value);
      sink.add(buffer.buffer.asUint8List());
    } else {
      final buffer = ByteData(9)
        ..setUint8(0, 0xD3)
        ..setInt64(1, value);
      sink.add(buffer.buffer.asUint8List());
    }
  }
}

class _Reader {
  _Reader(this._bytes) : _view = ByteData.view(
          _bytes.buffer,
          _bytes.offsetInBytes,
          _bytes.length,
        );

  final Uint8List _bytes;
  final ByteData _view;
  int _cursor = 0;

  Object? read() {
    final byte = _u8();

    if (byte <= 0x7F) return byte;
    if (byte >= 0xE0) return byte - 256;
    if (byte >= 0x80 && byte <= 0x8F) return _map(byte & 0x0F);
    if (byte >= 0x90 && byte <= 0x9F) return _list(byte & 0x0F);
    if (byte >= 0xA0 && byte <= 0xBF) return _string(byte & 0x1F);

    switch (byte) {
      case 0xC0:
        return null;
      case 0xC2:
        return false;
      case 0xC3:
        return true;
      case 0xC4:
        return _binary(_u8());
      case 0xC5:
        return _binary(_u16());
      case 0xC6:
        return _binary(_u32());
      case 0xCA:
        final value = _view.getFloat32(_cursor);
        _cursor += 4;
        return value;
      case 0xCB:
        final value = _view.getFloat64(_cursor);
        _cursor += 8;
        return value;
      case 0xCC:
        return _u8();
      case 0xCD:
        return _u16();
      case 0xCE:
        return _u32();
      case 0xCF:
        final value = _view.getUint64(_cursor);
        _cursor += 8;
        return value;
      case 0xD0:
        final value = _view.getInt8(_cursor);
        _cursor += 1;
        return value;
      case 0xD1:
        final value = _view.getInt16(_cursor);
        _cursor += 2;
        return value;
      case 0xD2:
        final value = _view.getInt32(_cursor);
        _cursor += 4;
        return value;
      case 0xD3:
        final value = _view.getInt64(_cursor);
        _cursor += 8;
        return value;
      case 0xD9:
        return _string(_u8());
      case 0xDA:
        return _string(_u16());
      case 0xDB:
        return _string(_u32());
      case 0xDC:
        return _list(_u16());
      case 0xDD:
        return _list(_u32());
      case 0xDE:
        return _map(_u16());
      case 0xDF:
        return _map(_u32());
    }

    if (byte >= 0xD4 && byte <= 0xD8) return _ext(1 << (byte - 0xD4));
    if (byte == 0xC7) return _ext(_u8());
    if (byte == 0xC8) return _ext(_u16());
    if (byte == 0xC9) return _ext(_u32());

    throw FormatException('MaxMsgpack: неизвестный маркер 0x${byte.toRadixString(16)}');
  }

  static const int _numberExtType = 1;

  Object? _ext(int length) {
    final type = _u8();
    final data = Uint8List.fromList(
      Uint8List.sublistView(_bytes, _cursor, _cursor + length),
    );
    _cursor += length;
    if (type != _numberExtType) return null;
    return _Reader(data).read();
  }

  int _u8() => _bytes[_cursor++];

  int _u16() {
    final value = _view.getUint16(_cursor);
    _cursor += 2;
    return value;
  }

  int _u32() {
    final value = _view.getUint32(_cursor);
    _cursor += 4;
    return value;
  }

  String _string(int length) {
    final value = utf8.decode(
      Uint8List.sublistView(_bytes, _cursor, _cursor + length),
      allowMalformed: true,
    );
    _cursor += length;
    return value;
  }

  Uint8List _binary(int length) {
    final value = Uint8List.fromList(
      Uint8List.sublistView(_bytes, _cursor, _cursor + length),
    );
    _cursor += length;
    return value;
  }

  List<Object?> _list(int length) =>
      List<Object?>.generate(length, (_) => read(), growable: false);

  Map<Object?, Object?> _map(int length) {
    final map = <Object?, Object?>{};
    for (var i = 0; i < length; i++) {
      final key = read();
      map[key] = read();
    }
    return map;
  }
}
