import 'clipboard_media_types.dart';

class ClipboardMedia {
  const ClipboardMedia._();

  static bool get supported => false;

  static Future<bool> hasMedia() async => false;

  static Future<ClipboardMediaPayload?> read() async => null;
}
