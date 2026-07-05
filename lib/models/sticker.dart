class StickerSet {
  final int id;
  final String name;
  final String iconUrl;
  final List<int> stickerIds;
  final String? link;

  const StickerSet({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.stickerIds,
    this.link,
  });

  factory StickerSet.fromMap(Map<dynamic, dynamic> map) {
    final rawStickers = map['stickers'];
    final ids = <int>[];
    if (rawStickers is List) {
      for (final e in rawStickers) {
        if (e is int) ids.add(e);
      }
    }
    return StickerSet(
      id: map['id'] as int,
      name: map['name']?.toString() ?? '',
      iconUrl: map['iconUrl']?.toString() ?? '',
      stickerIds: ids,
      link: map['link']?.toString(),
    );
  }
}

class StickerItem {
  final int id;
  final String url;
  final String? lottieUrl;
  final int? setId;
  final int? width;
  final int? height;
  final List<String> tags;

  const StickerItem({
    required this.id,
    required this.url,
    this.lottieUrl,
    this.setId,
    this.width,
    this.height,
    this.tags = const [],
  });

  bool get isAnimated => lottieUrl != null && lottieUrl!.isNotEmpty;

  factory StickerItem.fromMap(Map<dynamic, dynamic> map) => StickerItem(
    id: map['id'] as int,
    url: map['url']?.toString() ?? '',
    lottieUrl: map['lottieUrl']?.toString(),
    setId: map['setId'] as int?,
    width: map['width'] as int?,
    height: map['height'] as int?,
    tags: _parseTags(map['tags']),
  );

  static List<String> _parseTags(dynamic raw) {
    if (raw is! List) return const [];
    final result = <String>[];
    for (final e in raw) {
      final s = e?.toString();
      if (s != null && s.isNotEmpty) result.add(s);
    }
    return result;
  }
}
