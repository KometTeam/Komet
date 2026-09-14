import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/profile/avatar_carousel.dart';

void main() {
  const historyUrls = ['https://example.test/new', 'https://example.test/old'];
  const historyIds = <int?>[22, 11];

  test('history already holding the main photo is shown as is', () {
    final photos = buildAvatarPhotos(
      urls: historyUrls,
      ids: historyIds,
      baseUrl: 'https://example.test/main-link',
      mainPhotoId: 22,
    );

    expect(photos.length, 2);
    expect(indexOfMainAvatar(photos, 22), 0);
  });

  test('a main photo missing from history is added, not dropped', () {
    final photos = buildAvatarPhotos(
      urls: historyUrls,
      ids: historyIds,
      baseUrl: 'https://example.test/fresh',
      mainPhotoId: 33,
    );

    expect(photos.length, 3);
    expect(photos.first, const AvatarPhoto('https://example.test/fresh', 33));
    expect(indexOfMainAvatar(photos, 33), 0);
    expect(photos.last.id, 11);
  });

  test('an older main photo keeps its place in the list', () {
    final photos = buildAvatarPhotos(
      urls: historyUrls,
      ids: historyIds,
      baseUrl: 'https://example.test/main-link',
      mainPhotoId: 11,
    );

    expect(photos.length, 2);
    expect(indexOfMainAvatar(photos, 11), 1);
  });

  test('without ids the photo is matched by url instead of duplicated', () {
    final photos = buildAvatarPhotos(
      urls: historyUrls,
      ids: const [],
      baseUrl: historyUrls.first,
      mainPhotoId: null,
    );

    expect(photos.length, 2);
    expect(photos.every((p) => p.id == null), isTrue);
  });

  test('an empty history still shows the current avatar', () {
    final photos = buildAvatarPhotos(
      urls: const [],
      ids: const [],
      baseUrl: 'https://example.test/only',
      mainPhotoId: 7,
    );

    expect(photos, [const AvatarPhoto('https://example.test/only', 7)]);
    expect(indexOfMainAvatar(photos, 7), 0);
  });

  test('no avatar at all gives an empty carousel', () {
    expect(
      buildAvatarPhotos(urls: const [], ids: const [], baseUrl: ''),
      isEmpty,
    );
  });
}
