import 'package:flutter/services.dart';

import 'raw_clipboard_media.dart';

class ClipboardChannel {
  const ClipboardChannel._();

  static const MethodChannel _channel = MethodChannel('ru.komet.app/clipboard');

  static Future<bool> hasMedia() async {
    try {
      return await _channel.invokeMethod<bool>('hasMedia') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<RawClipboardMedia?> read() async {
    Map<Object?, Object?>? raw;
    try {
      raw = await _channel.invokeMapMethod<Object?, Object?>('read');
    } catch (_) {
      return null;
    }
    if (raw == null) return null;

    final paths = (raw['files'] as List<Object?>?)?.whereType<String>().toList(
      growable: false,
    );
    if (paths != null && paths.isNotEmpty) {
      return RawClipboardMedia(paths: paths);
    }

    final image = raw['image'];
    if (image is Uint8List && image.isNotEmpty) {
      return RawClipboardMedia(png: image);
    }
    return null;
  }
}
