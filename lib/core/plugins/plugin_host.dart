import 'dart:typed_data';

abstract interface class PluginHost {
  String get args;
  Map<String, dynamic> get arguments;
  Map<String, dynamic>? get replyMessage;
  bool get isOnline;
  bool get isActive;

  Future<String> sendText(String text);
  Future<void> editText(String messageId, String text);
  Future<void> sendPhoto(
    Uint8List bytes, {
    required String filename,
    required String caption,
  });
  Future<void> sendFile(Uint8List bytes, {required String filename});
  Future<void> notify(String message);
  Future<Map<String, dynamic>?> getPeer();
}
