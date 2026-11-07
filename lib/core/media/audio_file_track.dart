enum AudioFileOrigin { message, downloads }

typedef AudioFileEnricher =
    Future<AudioFileTrack> Function(AudioFileTrack track);

typedef AudioFileActivator =
    Future<void> Function(
      AudioFileTrack track, {
      required String notificationChannelName,
    });

// #***! аудиофайл в плеере плюс откуда он взялся
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
    this.origin = AudioFileOrigin.message,
  });

  final String cacheName;
  final String path;
  final String name;
  final String sourceName;
  final int? chatId;
  final String? messageId;
  final int? messageTime;
  final String? thumbnailUrl;
  final AudioFileOrigin origin;

  AudioFileTrack copyWith({
    String? name,
    String? sourceName,
    String? thumbnailUrl,
  }) => AudioFileTrack(
    cacheName: cacheName,
    path: path,
    name: name ?? this.name,
    sourceName: sourceName ?? this.sourceName,
    chatId: chatId,
    messageId: messageId,
    messageTime: messageTime,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    origin: origin,
  );
}
