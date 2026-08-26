import 'dart:typed_data';

abstract class FontMetrics {
  static const double referenceXHeight = 0.528;
  static const double minScale = 0.85;
  static const double maxScale = 1.15;

  static double scaleForXHeight(double xHeightRatio) {
    if (xHeightRatio <= 0) return 1.0;
    return (referenceXHeight / xHeightRatio)
        .clamp(minScale, maxScale)
        .toDouble();
  }

  static double? xHeightRatio(Uint8List bytes) {
    try {
      if (bytes.length < 12) return null;
      final data = ByteData.sublistView(bytes);
      if (data.getUint32(0) == 0x74746366) return null;
      final numTables = data.getUint16(4);
      int? headOffset;
      int? os2Offset;
      for (var i = 0; i < numTables; i++) {
        final record = 12 + i * 16;
        if (record + 16 > bytes.length) return null;
        final tag = String.fromCharCodes(bytes, record, record + 4);
        if (tag == 'head') headOffset = data.getUint32(record + 8);
        if (tag == 'OS/2') os2Offset = data.getUint32(record + 8);
      }
      if (headOffset == null || os2Offset == null) return null;
      if (headOffset + 20 > bytes.length || os2Offset + 88 > bytes.length) {
        return null;
      }
      final unitsPerEm = data.getUint16(headOffset + 18);
      if (unitsPerEm == 0) return null;
      if (data.getUint16(os2Offset) < 2) return null;
      final xHeight = data.getInt16(os2Offset + 86);
      if (xHeight <= 0) return null;
      return xHeight / unitsPerEm;
    } catch (_) {
      return null;
    }
  }
}
