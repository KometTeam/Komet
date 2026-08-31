import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// #***! аватарка до 1024 px и примерно 900 КБ
const int _avatarMaxDimension = 1024;
const int _avatarTargetBytes = 900 * 1024;

// #***! обои ужимаем под экран, иначе полный кадр декодится при каждом открытии чата
const int _wallpaperMaxDimension = 1440;
const int _wallpaperQuality = 88;

/// Maximum accepted size for a user-picked avatar before compression.
const int kMaxAvatarBytes = 8 * 1024 * 1024;

/// Maximum accepted size for a user-picked chat wallpaper before compression.
const int kMaxWallpaperBytes = 16 * 1024 * 1024;

// #***! сжимаем в изоляте иначе кадры пропадают, файл читаем тоже там:
// главный изолят не должен держать полный кадр
Future<Uint8List?> compressAvatarFile(String path) =>
    compute(_encodeAvatarFile, path);

Future<Uint8List?> compressWallpaperFile(String path) =>
    compute(_encodeWallpaperFile, path);

Future<Uint8List?> encodeRgbaToJpeg(Uint8List rgba, int width, int height) =>
    compute(_encodeRgba, (rgba, width, height));

Uint8List? _encodeRgba((Uint8List, int, int) args) {
  final (rgba, width, height) = args;
  if (width <= 0 || height <= 0) return null;
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 90);
}

img.Image? _decodeFitted(Uint8List input, int maxDimension) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  if (oriented.width <= maxDimension && oriented.height <= maxDimension) {
    return oriented;
  }
  return img.copyResize(
    oriented,
    width: oriented.width >= oriented.height ? maxDimension : null,
    height: oriented.height > oriented.width ? maxDimension : null,
    interpolation: img.Interpolation.average,
  );
}

Uint8List? _encodeAvatarFile(String path) =>
    _encodeAvatar(File(path).readAsBytesSync());

Uint8List? _encodeWallpaperFile(String path) {
  final image = _decodeFitted(
    File(path).readAsBytesSync(),
    _wallpaperMaxDimension,
  );
  if (image == null) return null;
  return img.encodeJpg(image, quality: _wallpaperQuality);
}

// #***! качество снижаем шагами пока не влезем
Uint8List? _encodeAvatar(Uint8List input) {
  final image = _decodeFitted(input, _avatarMaxDimension);
  if (image == null) return null;
  var quality = 88;
  var out = img.encodeJpg(image, quality: quality);
  while (out.lengthInBytes > _avatarTargetBytes && quality > 35) {
    quality -= 12;
    out = img.encodeJpg(image, quality: quality);
  }
  return out;
}
