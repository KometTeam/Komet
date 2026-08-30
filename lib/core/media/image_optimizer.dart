import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'gallery_source.dart';

// #***! сервер не берёт фото больше 5 МБ
const int kPhotoUploadLimitBytes = 5 * 1024 * 1024;

const int _photoMaxDimension = 2560;
const int _photoJpegQuality = 85;
const int _photoTargetBytes = 4700 * 1024;

// #***! HEIC перекодируем всегда, сервер его не понимает
const Set<String> _heicExtensions = {'.heic', '.heif'};

bool isHeicPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return _heicExtensions.contains(path.substring(dot).toLowerCase());
}

// #***! влезает в лимит отдаём как есть чтоб не терять качество
Future<File> optimizePhotoForUpload(File source, {GalleryItem? item}) async {
  final heic = isHeicPath(source.path);
  var length = 0;
  try {
    length = await source.length();
  } catch (_) {}

  if (!heic && length > 0 && length <= kPhotoUploadLimitBytes) {
    return source;
  }

  // #***! сначала нативный кодек галереи, он быстрее и качественнее
  if (item != null) {
    final native = await item.encodeForUpload(
      maxDimension: _photoMaxDimension,
      quality: _photoJpegQuality,
    );
    if (native != null) return writePhotoJpeg(native);
  }

  final fallback = await _encodeWithImagePackage(source);
  return fallback ?? source;
}

Future<File?> _encodeWithImagePackage(File source) async {
  Uint8List bytes;
  try {
    bytes = await source.readAsBytes();
  } catch (_) {
    return null;
  }
  final jpeg = await compute(_encodePhotoIsolate, (
    bytes,
    _photoMaxDimension,
    _photoJpegQuality,
    _photoTargetBytes,
  ));
  if (jpeg == null) return null;
  return writePhotoJpeg(jpeg);
}

// #***! качество снижаем шагами пока не влезем
Uint8List? _encodePhotoIsolate((Uint8List, int, int, int) args) {
  final (bytes, maxDim, quality, target) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final scaled = oriented.width > maxDim || oriented.height > maxDim
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? maxDim : null,
          height: oriented.height > oriented.width ? maxDim : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  var quality0 = quality;
  var out = img.encodeJpg(scaled, quality: quality0);
  while (out.lengthInBytes > target && quality0 > 40) {
    quality0 -= 10;
    out = img.encodeJpg(scaled, quality: quality0);
  }
  return out;
}

Future<File> writePhotoJpeg(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File(
    p.join(
      dir.path,
      'komet_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
    ),
  );
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
