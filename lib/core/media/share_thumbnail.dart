import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider, MemoryImage;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:image/image.dart' as img;

import '../../models/shared_payload.dart';
import '../utils/logger.dart';
import 'video_transcoder.dart';

const int _thumbMaxDimension = 128;
const int _thumbQuality = 70;

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

Future<String?> _photoThumb(File file) async {
  Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (e) {
    logger.w('Поделиться: не прочитать ${file.path}: $e');
    return null;
  }
  final jpeg = await compute(_encodeThumbIsolate, bytes);
  return _asDataUri(jpeg);
}

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

String? _asDataUri(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

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
