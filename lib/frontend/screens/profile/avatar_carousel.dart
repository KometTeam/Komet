// #***! одна аватарка из истории: ссылка и её photoId
class AvatarPhoto {
  const AvatarPhoto(this.url, this.id);

  final String url;
  final int? id;

  @override
  bool operator ==(Object other) =>
      other is AvatarPhoto && other.url == url && other.id == id;

  @override
  int get hashCode => Object.hash(url, id);

  @override
  String toString() => 'AvatarPhoto($url, $id)';
}

// #***! у истории и профиля ссылки на одно фото разные, сверяем по id;
// самой свежей аватарки в истории может ещё не быть, добавляем её сами
List<AvatarPhoto> buildAvatarPhotos({
  required List<String> urls,
  required List<int?> ids,
  String? baseUrl,
  int? mainPhotoId,
}) {
  final photos = [
    for (var i = 0; i < urls.length; i++)
      AvatarPhoto(urls[i], i < ids.length ? ids[i] : null),
  ];
  final base = baseUrl ?? '';
  if (base.isEmpty) return photos;
  final known =
      (mainPhotoId != null && ids.contains(mainPhotoId)) || urls.contains(base);
  if (!known) photos.insert(0, AvatarPhoto(base, mainPhotoId));
  return photos;
}

int indexOfMainAvatar(List<AvatarPhoto> photos, int? mainPhotoId) {
  if (mainPhotoId == null) return 0;
  final at = photos.indexWhere((p) => p.id == mainPhotoId);
  return at < 0 ? 0 : at;
}
