class SuggestedChannel {
  final int id;
  final String title;
  final String? iconUrl;
  final String link;
  final int? subscribers;

  const SuggestedChannel({
    required this.id,
    required this.title,
    required this.link,
    this.iconUrl,
    this.subscribers,
  });

  static SuggestedChannel? fromServer(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final link = raw['link'];
    if (id is! int || link is! String || link.isEmpty) return null;
    if (raw['type'] != 'CHANNEL') return null;
    final title = (raw['title'] as String?)?.trim() ?? '';
    final icon = raw['baseIconUrl'];
    final count = raw['participantsCount'];
    return SuggestedChannel(
      id: id,
      title: title,
      link: link,
      iconUrl: icon is String && icon.isNotEmpty ? icon : null,
      subscribers: count is int ? count : null,
    );
  }
}
