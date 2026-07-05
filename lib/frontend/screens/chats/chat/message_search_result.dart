class MessageSearchResult {
  final String id;
  final int time;
  final int senderId;
  final String text;
  final List<String> highlights;

  const MessageSearchResult({
    required this.id,
    required this.time,
    required this.senderId,
    required this.text,
    required this.highlights,
  });

  static MessageSearchResult? fromRaw(Map<dynamic, dynamic> raw) {
    final message = raw['message'];
    if (message is! Map) return null;
    final id = message['id']?.toString();
    if (id == null) return null;
    final rawHighlights = raw['highlights'];
    final highlights = rawHighlights is List
        ? rawHighlights.whereType<String>().toList()
        : const <String>[];
    final time = message['time'];
    final sender = message['sender'];
    return MessageSearchResult(
      id: id,
      time: time is int ? time : int.tryParse('${time ?? 0}') ?? 0,
      senderId: sender is int ? sender : int.tryParse('${sender ?? 0}') ?? 0,
      text: message['text']?.toString() ?? '',
      highlights: highlights,
    );
  }
}
