class SentMessage {
  const SentMessage(this.id, {this.text, this.elements, this.attaches});

  factory SentMessage.fromResponse(Object? payload) {
    final message = payload is Map ? payload['message'] : null;
    if (message is! Map) return const SentMessage('');
    final text = message['text'];
    final elements = message['elements'];
    final attaches = message['attaches'];
    final echoed = text is String || elements is List;
    return SentMessage(
      message['id']?.toString() ?? '',
      text: text is String ? text : null,
      elements: echoed ? _maps(elements) : null,
      attaches: attaches is List ? _maps(attaches) : null,
    );
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
  ];

  final String id;
  final String? text;
  final List<Map<String, dynamic>>? elements;
  final List<Map<String, dynamic>>? attaches;

  Map<String, dynamic>? payloadOver(Map<String, dynamic>? local) {
    final accepted = elements;
    if (accepted == null) return local;
    final payload = {...?local}..remove('elements');
    if (accepted.isNotEmpty) payload['elements'] = accepted;
    return payload.isEmpty ? null : payload;
  }
}
