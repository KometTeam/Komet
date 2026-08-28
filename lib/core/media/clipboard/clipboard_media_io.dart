import 'dart:io';

import 'package:flutter/foundation.dart';

import 'clipboard_channel.dart';
import 'clipboard_media_types.dart';
import 'dib_image.dart';
import 'raw_clipboard_media.dart';
import 'win32_clipboard.dart';

class ClipboardMedia {
  const ClipboardMedia._();

  static bool get supported {
    if (Platform.isWindows) return Win32Clipboard.instance != null;
    return Platform.isMacOS || Platform.isLinux;
  }

  static Future<bool> hasMedia() async {
    if (Platform.isWindows) {
      return Win32Clipboard.instance?.hasMedia ?? false;
    }
    if (!supported) return false;
    return ClipboardChannel.hasMedia();
  }

  static Future<ClipboardMediaPayload?> read() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return null;

    if (raw.paths.isNotEmpty) {
      final files = <ClipboardFileRef>[];
      for (final path in raw.paths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        files.add(
          ClipboardFileRef(
            path: path,
            name: _basename(path),
            size: file.lengthSync(),
          ),
        );
      }
      if (files.isNotEmpty) return ClipboardMediaPayload(files: files);
    }

    final png = raw.png;
    if (png != null && png.isNotEmpty) {
      return ClipboardMediaPayload(
        image: ClipboardImageData(bytes: png, extension: '.png'),
      );
    }

    final dib = raw.dib;
    if (dib != null && dib.isNotEmpty) {
      final decoded = await compute(dibToPng, dib);
      if (decoded != null && decoded.isNotEmpty) {
        return ClipboardMediaPayload(
          image: ClipboardImageData(bytes: decoded, extension: '.png'),
        );
      }
    }
    return null;
  }

  static Future<RawClipboardMedia?> _readRaw() {
    if (Platform.isWindows) {
      final clipboard = Win32Clipboard.instance;
      if (clipboard == null) return Future.value();
      return clipboard.read();
    }
    if (!supported) return Future.value();
    return ClipboardChannel.read();
  }
}

String _basename(String path) {
  final separator = path.lastIndexOf(RegExp(r'[\\/]'));
  return separator < 0 ? path : path.substring(separator + 1);
}
