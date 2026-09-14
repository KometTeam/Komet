import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ImageByteFormat { jpeg, png, gif, webp, bmp, heic, unknown }

const Map<ImageByteFormat, String> _extensionByFormat = {
  ImageByteFormat.jpeg: '.jpg',
  ImageByteFormat.png: '.png',
  ImageByteFormat.gif: '.gif',
  ImageByteFormat.webp: '.webp',
  ImageByteFormat.bmp: '.bmp',
  ImageByteFormat.heic: '.heic',
};

const Set<String> _heicBrands = {
  'heic',
  'heix',
  'heim',
  'heis',
  'hevc',
  'hevx',
  'hevm',
  'hevs',
  'mif1',
  'msf1',
};

const int _webpAnimationFlag = 0x02;

const int _transcodeJpegQuality = 95;

const int _headerBytes = 32;

bool _startsWith(Uint8List bytes, int offset, List<int> signature) {
  if (bytes.length < offset + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}

String _fourcc(Uint8List bytes, int offset, [int length = 4]) {
  if (bytes.length < offset + length) return '';
  return String.fromCharCodes(bytes, offset, offset + length);
}

ImageByteFormat sniffImageFormat(Uint8List bytes) {
  if (_startsWith(bytes, 0, const [0xFF, 0xD8, 0xFF])) {
    return ImageByteFormat.jpeg;
  }
  if (_startsWith(bytes, 0, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return ImageByteFormat.png;
  }
  if (_fourcc(bytes, 0) == 'GIF8') return ImageByteFormat.gif;
  if (_fourcc(bytes, 0) == 'RIFF' && _fourcc(bytes, 8) == 'WEBP') {
    return ImageByteFormat.webp;
  }
  if (_fourcc(bytes, 0, 2) == 'BM') return ImageByteFormat.bmp;
  if (_fourcc(bytes, 4) == 'ftyp' && _heicBrands.contains(_fourcc(bytes, 8))) {
    return ImageByteFormat.heic;
  }
  return ImageByteFormat.unknown;
}

bool isAnimatedWebp(Uint8List bytes) {
  if (sniffImageFormat(bytes) != ImageByteFormat.webp) return false;
  if (_fourcc(bytes, 12) != 'VP8X' || bytes.length < 21) return false;
  return (bytes[20] & _webpAnimationFlag) != 0;
}

String? extensionForImageFormat(ImageByteFormat format) =>
    _extensionByFormat[format];

String withImageExtension(String name, String extension) {
  if (extension.isEmpty) return name;
  return '${p.basenameWithoutExtension(name)}$extension';
}

class SaveReadyImage {
  final File file;
  final String extension;
  final bool temporary;

  const SaveReadyImage({
    required this.file,
    required this.extension,
    required this.temporary,
  });

  Future<void> discard() async {
    if (!temporary) return;
    try {
      await file.delete();
    } catch (_) {}
  }
}

Future<SaveReadyImage?> prepareImageForSave(File source) async {
  final head = await _readHeader(source);
  if (head == null) return null;

  final format = sniffImageFormat(head);
  final asIs = SaveReadyImage(
    file: source,
    extension:
        extensionForImageFormat(format) ??
        p.extension(source.path).toLowerCase(),
    temporary: false,
  );
  if (format != ImageByteFormat.webp || isAnimatedWebp(head)) return asIs;

  Uint8List bytes;
  try {
    bytes = await source.readAsBytes();
  } catch (_) {
    return asIs;
  }

  final converted = await compute(_transcodeWebp, bytes);
  if (converted == null) return asIs;

  final (data, extension) = converted;
  try {
    final directory = await getTemporaryDirectory();
    final target = File(
      p.join(
        directory.path,
        '${p.basenameWithoutExtension(source.path)}_save$extension',
      ),
    );
    await target.writeAsBytes(data, flush: true);
    return SaveReadyImage(
      file: target,
      extension: extension,
      temporary: true,
    );
  } catch (_) {
    return asIs;
  }
}

Future<Uint8List?> _readHeader(File source) async {
  RandomAccessFile? handle;
  try {
    handle = await source.open();
    return await handle.read(_headerBytes);
  } catch (_) {
    return null;
  } finally {
    await handle?.close();
  }
}

(Uint8List, String)? _transcodeWebp(Uint8List bytes) {
  final decoded = img.decodeWebP(bytes);
  if (decoded == null) return null;
  if (!_isOpaque(decoded)) return (img.encodePng(decoded), '.png');
  return (img.encodeJpg(decoded, quality: _transcodeJpegQuality), '.jpg');
}

bool _isOpaque(img.Image image) {
  final data = image.data;
  if (data is! img.ImageDataUint8 || data.numChannels != 4) {
    return !image.hasAlpha;
  }
  final raw = data.toUint8List();
  for (var i = 3; i < raw.length; i += 4) {
    if (raw[i] != 255) return false;
  }
  return true;
}
