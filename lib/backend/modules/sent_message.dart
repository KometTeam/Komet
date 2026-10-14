class SentMessage {
  const SentMessage(this.id, {this.text, this.elements});

  factory SentMessage.fromResponse(Object? payload) {
    final message = payload is Map ? payload['message'] : null;
    if (message is! Map) return const SentMessage('');
    final text = message['text'];
    final elements = message['elements'];
    final echoed = text is String || elements is List;
    return SentMessage(
      message['id']?.toString() ?? '',
      text: text is String ? text : null,
      elements: echoed
          ? [
              if (elements is List)
                for (final element in elements)
                  if (element is Map) Map<String, dynamic>.from(element),
            ]
          : null,
    );
  }

  final String id;
  final String? text;
  final List<Map<String, dynamic>>? elements;

  Map<String, dynamic>? payloadOver(Map<String, dynamic>? local) {
    final accepted = elements;
    if (accepted == null) return local;
    final payload = {...?local}..remove('elements');
    if (accepted.isNotEmpty) payload['elements'] = accepted;
    return payload.isEmpty ? null : payload;
  }
}
