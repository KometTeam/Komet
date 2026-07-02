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
  final int? setId;
  final int? width;
  final int? height;

  const StickerItem({
    required this.id,
    required this.url,
    this.setId,
    this.width,
    this.height,
  });

  factory StickerItem.fromMap(Map<dynamic, dynamic> map) => StickerItem(
    id: map['id'] as int,
    url: map['url']?.toString() ?? '',
    setId: map['setId'] as int?,
    width: map['width'] as int?,
    height: map['height'] as int?,
  );
}
