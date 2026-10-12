import 'dart:convert';
import 'dart:typed_data';

abstract final class FontFileInfo {
  static const int _collectionTag = 0x74746366;
  static const int _typographicFamily = 16;
  static const int _family = 1;
  static const int _platformUnicode = 0;
  static const int _platformMac = 1;
  static const int _platformWindows = 3;
  static const int _englishUs = 0x0409;

  static String? familyName(Uint8List bytes) {
    try {
      final data = ByteData.sublistView(bytes);
      if (bytes.length < 12) return null;
      final fontOffset = data.getUint32(0) == _collectionTag
          ? data.getUint32(12)
          : 0;
      final nameTable = _tableOffset(bytes, data, fontOffset, 'name');
      if (nameTable == null) return null;
      return _pick(bytes, data, nameTable, _typographicFamily) ??
          _pick(bytes, data, nameTable, _family);
    } catch (_) {
      return null;
    }
  }

  static int? _tableOffset(
    Uint8List bytes,
    ByteData data,
    int fontOffset,
    String tag,
  ) {
    final numTables = data.getUint16(fontOffset + 4);
    for (var i = 0; i < numTables; i++) {
      final record = fontOffset + 12 + i * 16;
      if (record + 16 > bytes.length) return null;
      if (String.fromCharCodes(bytes, record, record + 4) == tag) {
        return data.getUint32(record + 8);
      }
    }
    return null;
  }

  static String? _pick(Uint8List bytes, ByteData data, int table, int nameId) {
    final count = data.getUint16(table + 2);
    final storage = table + data.getUint16(table + 4);
    String? fallback;
    for (var i = 0; i < count; i++) {
      final record = table + 6 + i * 12;
      if (record + 12 > bytes.length) break;
      if (data.getUint16(record + 6) != nameId) continue;
      final platform = data.getUint16(record);
      final language = data.getUint16(record + 4);
      final length = data.getUint16(record + 8);
      final start = storage + data.getUint16(record + 10);
      if (start + length > bytes.length) continue;
      final raw = bytes.sublist(start, start + length);
      final value = switch (platform) {
        _platformUnicode || _platformWindows => _utf16be(raw),
        _platformMac => latin1.decode(raw, allowInvalid: true),
        _ => null,
      }?.trim();
      if (value == null || value.isEmpty) continue;
      if (platform == _platformWindows && language == _englishUs) {
        return value;
      }
      fallback ??= value;
    }
    return fallback;
  }

  static String _utf16be(Uint8List raw) {
    final units = <int>[
      for (var i = 0; i + 1 < raw.length; i += 2) (raw[i] << 8) | raw[i + 1],
    ];
    return String.fromCharCodes(units);
  }

  static String familyFromFileName(String fileName) {
    final base = fileName.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final cleaned = stem
        .replaceAll(
          RegExp(
            r'[-_ ]?(Regular|Bold|Italic|Medium|Light|Thin|Black|'
            r'SemiBold|ExtraBold|ExtraLight|VariableFont.*|Variable)$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .trim();
    return cleaned.isEmpty ? stem : cleaned;
  }
}
