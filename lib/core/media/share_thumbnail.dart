import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider, MemoryImage;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:image/image.dart' as img;

import '../../models/shared_payload.dart';
import '../utils/logger.dart';
import 'video_transcoder.dart';

// #***! миниатюра для поделиться, 128 px хватает
const int _thumbMaxDimension = 128;
const int _thumbQuality = 70;

// #***! у фото сама картинка, у видео первый кадр
Future<String?> sharedThumbnailDataUri(SharedFile source) async {
  switch (source.kind) {
    case SharedFileKind.photo:
      return _photoThumb(source.file);
    case SharedFileKind.video:
      return _videoThumb(source.file);
    case SharedFileKind.file:
      return null;
  }
}

// #***! декодируем в изоляте иначе список подвисает
Future<String?> _photoThumb(File file) async {
  try {
    final png = await _platformPhotoThumb(file);
    if (png != null) return _asDataUri(png, mime: 'image/png');
  } catch (_) {}
  try {
    final bytes = await file.readAsBytes();
    final jpeg = await compute(_encodeThumbIsolate, bytes);
    return _asDataUri(jpeg);
  } catch (e) {
    logger.w('Поделиться: не создать превью ${file.path}: $e');
    return null;
  }
}

Future<Uint8List?> _platformPhotoThumb(File file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final landscape = descriptor.width >= descriptor.height;
    codec = await descriptor.instantiateCodec(
      targetWidth: landscape && descriptor.width > _thumbMaxDimension
          ? _thumbMaxDimension
          : null,
      targetHeight: !landscape && descriptor.height > _thumbMaxDimension
          ? _thumbMaxDimension
          : null,
    );
    image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

// #***! плагина кадров может не быть, тогда просто без превью
Future<String?> _videoThumb(File file) async {
  try {
    final frames = await VideoTranscoder.frames(file.path, const [
      0,
    ], size: _thumbMaxDimension);
    if (frames.isEmpty) return null;
    return _asDataUri(frames.first);
  } on MissingPluginException {
    return null;
  } catch (e) {
    logger.w('Поделиться: не взять кадр из ${file.path}: $e');
    return null;
  }
}

String? _asDataUri(Uint8List? bytes, {String mime = 'image/jpeg'}) {
  if (bytes == null || bytes.isEmpty) return null;
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

// #***! уважаем EXIF поворот иначе миниатюра на боку
Uint8List? _encodeThumbIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width >= oriented.height
      ? oriented.width
      : oriented.height;
  final scaled = longest > _thumbMaxDimension
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? _thumbMaxDimension : null,
          height: oriented.height > oriented.width ? _thumbMaxDimension : null,
          interpolation: img.Interpolation.average,
        )
      : oriented;
  return img.encodeJpg(scaled, quality: _thumbQuality);
}

// #***! провайдеры кэшируем, иначе base64 декодируется на каждый билд
final Map<String, ImageProvider> _sharedThumbCache = {};

ImageProvider? decodeSharedThumb(String? dataUri) {
  if (dataUri == null || dataUri.isEmpty) return null;
  final cached = _sharedThumbCache[dataUri];
  if (cached != null) return cached;
  final comma = dataUri.indexOf(',');
  if (comma < 0) return null;
  try {
    final provider = MemoryImage(base64Decode(dataUri.substring(comma + 1)));
    if (_sharedThumbCache.length >= 32) {
      _sharedThumbCache.remove(_sharedThumbCache.keys.first);
    }
    _sharedThumbCache[dataUri] = provider;
    return provider;
  } catch (_) {
    return null;
  }
}
