import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List? thumbHashToPng(List<int> hash) {
  final decoded = thumbHashToRgba(hash);
  if (decoded == null) return null;
  final image = img.Image.fromBytes(
    width: decoded.width,
    height: decoded.height,
    bytes: decoded.rgba.buffer,
    numChannels: 4,
  );
  return img.encodePng(image);
}

({int width, int height, Uint8List rgba})? thumbHashToRgba(List<int> hash) {
  if (hash.length < 5) return null;
  final header24 = hash[0] | (hash[1] << 8) | (hash[2] << 16);
  final header16 = hash[3] | (hash[4] << 8);
  final lDc = (header24 & 63) / 63;
  final pDc = ((header24 >> 6) & 63) / 31.5 - 1;
  final qDc = ((header24 >> 12) & 63) / 31.5 - 1;
  final lScale = ((header24 >> 18) & 31) / 31;
  final hasAlpha = (header24 >> 23) != 0;
  final pScale = ((header16 >> 3) & 63) / 63;
  final qScale = ((header16 >> 9) & 63) / 63;
  final isLandscape = (header16 >> 15) != 0;
  final lx = math.max(3, isLandscape ? (hasAlpha ? 5 : 7) : header16 & 7);
  final ly = math.max(3, isLandscape ? header16 & 7 : (hasAlpha ? 5 : 7));
  if (hasAlpha && hash.length < 6) return null;
  final aDc = hasAlpha ? (hash[5] & 15) / 15 : 1.0;
  final aScale = hasAlpha ? (hash[5] >> 4) / 15 : 0.0;

  final acStart = hasAlpha ? 6 : 5;
  var acIndex = 0;
  List<double>? channel(int nx, int ny, double scale) {
    final ac = <double>[];
    for (var cy = 0; cy < ny; cy++) {
      for (var cx = cy > 0 ? 0 : 1; cx * ny < nx * (ny - cy); cx++) {
        final at = acStart + (acIndex >> 1);
        if (at >= hash.length) return null;
        final nibble = (hash[at] >> ((acIndex & 1) << 2)) & 15;
        acIndex++;
        ac.add((nibble / 7.5 - 1) * scale);
      }
    }
    return ac;
  }

  final lAc = channel(lx, ly, lScale);
  final pAc = channel(3, 3, pScale * 1.25);
  final qAc = channel(3, 3, qScale * 1.25);
  final aAc = hasAlpha ? channel(5, 5, aScale) : const <double>[];
  if (lAc == null || pAc == null || qAc == null || aAc == null) return null;

  final ratio = _approximateAspect(hash);
  final width = (ratio > 1 ? 32 : 32 * ratio).round();
  final height = (ratio > 1 ? 32 / ratio : 32).round();
  if (width <= 0 || height <= 0) return null;

  final rgba = Uint8List(width * height * 4);
  final fx = List<double>.filled(math.max(lx, hasAlpha ? 5 : 3), 0);
  final fy = List<double>.filled(math.max(ly, hasAlpha ? 5 : 3), 0);
  var i = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++, i += 4) {
      var l = lDc;
      var p = pDc;
      var q = qDc;
      var a = aDc;
      for (var cx = 0; cx < fx.length; cx++) {
        fx[cx] = math.cos(math.pi / width * (x + 0.5) * cx);
      }
      for (var cy = 0; cy < fy.length; cy++) {
        fy[cy] = math.cos(math.pi / height * (y + 0.5) * cy);
      }
      var j = 0;
      for (var cy = 0; cy < ly; cy++) {
        final fy2 = fy[cy] * 2;
        for (var cx = cy > 0 ? 0 : 1; cx * ly < lx * (ly - cy); cx++, j++) {
          l += lAc[j] * fx[cx] * fy2;
        }
      }
      j = 0;
      for (var cy = 0; cy < 3; cy++) {
        final fy2 = fy[cy] * 2;
        for (var cx = cy > 0 ? 0 : 1; cx < 3 - cy; cx++, j++) {
          final f = fx[cx] * fy2;
          p += pAc[j] * f;
          q += qAc[j] * f;
        }
      }
      if (hasAlpha) {
        j = 0;
        for (var cy = 0; cy < 5; cy++) {
          final fy2 = fy[cy] * 2;
          for (var cx = cy > 0 ? 0 : 1; cx < 5 - cy; cx++, j++) {
            a += aAc[j] * fx[cx] * fy2;
          }
        }
      }
      final b = l - 2 / 3 * p;
      final r = (3 * l - b + q) / 2;
      final g = r - q;
      rgba[i] = _channel(r);
      rgba[i + 1] = _channel(g);
      rgba[i + 2] = _channel(b);
      rgba[i + 3] = _channel(a);
    }
  }
  return (width: width, height: height, rgba: rgba);
}

int _channel(double value) => (255 * value.clamp(0.0, 1.0)).toInt();

double _approximateAspect(List<int> hash) {
  final header = hash[3];
  final hasAlpha = hash[2] & 0x80 != 0;
  final isLandscape = hash[4] & 0x80 != 0;
  final lx = isLandscape ? (hasAlpha ? 5 : 7) : header & 7;
  final ly = isLandscape ? header & 7 : (hasAlpha ? 5 : 7);
  return ly == 0 ? 0 : lx / ly;
}
