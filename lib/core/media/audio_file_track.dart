class AudioFileTrack {
  const AudioFileTrack({
    required this.cacheName,
    required this.path,
    required this.name,
    required this.sourceName,
    this.chatId,
    this.messageId,
    this.messageTime,
    this.thumbnailUrl,
  });

  final String cacheName;
  final String path;
  final String name;
  final String sourceName;
  final int? chatId;
  final String? messageId;
  final int? messageTime;
  final String? thumbnailUrl;
}
