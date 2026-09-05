class PluginOutgoingText {
  const PluginOutgoingText({required this.plaintext, required this.wireText});

  final String plaintext;
  final String wireText;

  bool get encrypted => plaintext != wireText;
}

class PluginOutgoingTextException implements Exception {
  const PluginOutgoingTextException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<PluginOutgoingText> preparePluginOutgoingText(
  String plaintext,
  Future<String?> Function(String plaintext) encrypt,
) async {
  final wireText = await encrypt(plaintext);
  if (wireText == null) {
    throw const PluginOutgoingTextException(
      'Не удалось зашифровать сообщение плагина',
    );
  }
  return PluginOutgoingText(plaintext: plaintext, wireText: wireText);
}
