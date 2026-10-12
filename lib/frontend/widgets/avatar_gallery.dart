import 'dart:math' as math;

import '../../backend/api.dart';
import '../../backend/modules/contacts.dart';
import '../../main.dart';
import '../screens/profile/avatar_carousel.dart';

class AvatarGallery {
  final int contactId;
  final String name;
  final String currentUrl;
  final int? mainPhotoId;
  final String? initialUrl;
  final int? initialPhotoId;
  final void Function(int photoId)? onDelete;

  const AvatarGallery({
    required this.contactId,
    required this.name,
    required this.currentUrl,
    this.mainPhotoId,
    this.initialUrl,
    this.initialPhotoId,
    this.onDelete,
  });

  bool get hasHistory => contactId > 0;
}

class AvatarFeed {
  static const int pageSize = 50;

  final AvatarGallery gallery;
  final Api _api;
  final List<String> _urls = [];
  final List<int?> _ids = [];
  final Set<String> _seen = {};
  int _historyTotal = 0;
  bool _exhausted = false;
  List<AvatarPhoto> _photos = const [];
  int _total = 0;

  AvatarFeed(this.gallery, {Api? client}) : _api = client ?? api {
    final cached = gallery.hasHistory
        ? ContactsModule.cachedPhotos(gallery.contactId)
        : null;
    if (cached != null) _merge(cached);
    _rebuild();
  }

  List<AvatarPhoto> get photos => _photos;

  int get total => _total;

  bool get reachedEnd =>
      !gallery.hasHistory || _exhausted || _urls.length >= _historyTotal;

  int get initialIndex {
    final id = gallery.initialPhotoId;
    if (id != null) {
      final at = _photos.indexWhere((p) => p.id == id);
      if (at >= 0) return at;
    }
    final url = gallery.initialUrl ?? gallery.currentUrl;
    final at = _photos.indexWhere((p) => p.url == url);
    return at < 0 ? 0 : at;
  }

  Future<void> load() => _fetch(from: 0);

  Future<void> loadMore() async {
    if (reachedEnd) return;
    final before = _urls.length;
    await _fetch(from: before);
    if (_urls.length == before) _exhausted = true;
  }

  Future<void> _fetch({required int from}) async {
    if (!gallery.hasHistory) return;
    _merge(
      await ContactsModule.fetchPhotos(
        _api,
        gallery.contactId,
        from: from,
        count: pageSize,
      ),
    );
    _rebuild();
  }

  void _merge(ContactPhotos photos) {
    for (var i = 0; i < photos.urls.length; i++) {
      final url = photos.urls[i];
      if (url.isEmpty || !_seen.add(url)) continue;
      _urls.add(url);
      _ids.add(photos.idAt(i));
    }
    _historyTotal = math.max(_historyTotal, photos.total);
  }

  void _rebuild() {
    _photos = buildAvatarPhotos(
      urls: _urls,
      ids: _ids,
      baseUrl: gallery.currentUrl,
      mainPhotoId: gallery.mainPhotoId,
    );
    final extra = _photos.length - _urls.length;
    _total = math.max(_historyTotal + extra, _photos.length);
  }
}
