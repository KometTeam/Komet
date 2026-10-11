import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:photo_manager/photo_manager.dart';

import 'desktop_video_probe.dart';

// #***! доступ к галерее, полный частичный или запрещён
enum GalleryPermission { granted, limited, denied }

// #***! элемент галереи, за ним системный ассет или просто файл
enum GallerySortField { date, name }

class GallerySort {
  final GallerySortField field;
  final bool ascending;

  const GallerySort({required this.field, required this.ascending});

  static const newestFirst = GallerySort(
    field: GallerySortField.date,
    ascending: false,
  );
}
abstract class GalleryItem {
  String get id;
  bool get isVideo;
  Duration? get duration;
  File? get localFile;
  Future<Uint8List?> thumbnail(int size);
  Future<File?> originFile();
  Future<(int, int)?> dimensions();
  Future<Uint8List?> encodeForUpload({
    required int maxDimension,
    required int quality,
  });
  String get name;

  static GalleryItem fromFile(File file) => _FileGalleryItem(file);
}

// #***! страница выдачи
class GalleryPage {
  const GalleryPage({required this.items, required this.hasMore});

  static const empty = GalleryPage(items: <GalleryItem>[], hasMore: false);

  final List<GalleryItem> items;
  final bool hasMore;
}

// #***! выбранное фото плюс результат редактирования
class PickedPhoto {
  final GalleryItem item;
  final File? editedFile;

  const PickedPhoto({required this.item, this.editedFile});
}

// #***! размеры картинки без полного декодирования
class GalleryAlbum {
  final String id;
  final String name;
  final int count;
  final bool isAll;

  const GalleryAlbum({
    required this.id,
    required this.name,
    required this.count,
    required this.isAll,
  });
}
Future<(int, int)?> imageFileDimensions(File file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    final bytes = await file.readAsBytes();
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    return (descriptor.width, descriptor.height);
  } catch (_) {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

// #***! галерея, на мобилках photo_manager на десктопе обход папок
abstract class GallerySource {
  // #***! по 120 штук, столько влезает в несколько экранов сетки
  static const int pageSize = 120;
  static const Duration maxInt32Duration = Duration(milliseconds: 0x7fffffff);

  // #***! фильтр без ограничений, иначе часть видео пропадает
  static FilterOptionGroup mediaFilter(GallerySort sort) => FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    videoOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
      durationConstraint: DurationConstraint(
        max: maxInt32Duration,
        allowNullable: true,
      ),
    ),
    createTimeCond: DateTimeCond.def().copyWith(ignore: true),
    orders: [
      OrderOption(
        type: OrderOptionType.createDate,
        asc: sort.field == GallerySortField.date && sort.ascending,
      ),
    ],
  );

  Future<GalleryPermission> ensurePermission();
  Future<List<GalleryAlbum>> albums();
  void selectAlbum(GalleryAlbum album);
  void setSort(GallerySort sort);
  Future<GalleryPage> load({int offset, int limit});
  Future<void> openSettings();
  Future<void> manageAccess();

  // #***! альбом все спрашиваем один раз, дальше листаем диапазонами
  factory GallerySource.create() {
    if (Platform.isAndroid || Platform.isIOS) {
      return _PhotoManagerSource();
    }
    return _DesktopGallerySource();
  }
}

class _PhotoManagerSource implements GallerySource {
  @override
  Future<GalleryPermission> ensurePermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    if (state.isAuth) return GalleryPermission.granted;
    if (state.hasAccess) return GalleryPermission.limited;
    return GalleryPermission.denied;
  }

  List<AssetPathEntity> _paths = const [];
  String? _albumId;
  AssetPathEntity? _album;
  int _total = 0;
  GallerySort _sort = GallerySort.newestFirst;
  List<AssetEntity>? _nameOrder;
  String? _nameOrderKey;
  DateTime _nameOrderAt = DateTime.fromMillisecondsSinceEpoch(0);
  static List<GalleryAlbum>? _albumsCache;
  static DateTime _albumsCachedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _fetchPaths() async {
    _paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: false,
      filterOption: GallerySource.mediaFilter(_sort),
    );
  }

  AssetPathEntity? _pathFor(String? id) {
    for (final path in _paths) {
      if (path.id == id) return path;
    }
    for (final path in _paths) {
      if (path.isAll) return path;
    }
    return _paths.isEmpty ? null : _paths.first;
  }

  @override
  Future<List<GalleryAlbum>> albums() async {
    final cached = _albumsCache;
    if (cached != null &&
        DateTime.now().difference(_albumsCachedAt) < const Duration(minutes: 1)) {
      return cached;
    }
    await _fetchPaths();
    final result = <GalleryAlbum>[];
    for (final path in _paths) {
      final count = await path.assetCountAsync;
      if (count == 0) continue;
      result.add(
        GalleryAlbum(
          id: path.id,
          name: path.name,
          count: count,
          isAll: path.isAll,
        ),
      );
    }
    result.sort((a, b) => (b.isAll ? 1 : 0).compareTo(a.isAll ? 1 : 0));
    _albumsCache = result;
    _albumsCachedAt = DateTime.now();
    return result;
  }

  @override
  void selectAlbum(GalleryAlbum album) {
    _albumId = album.id;
    _album = null;
    _total = 0;
    _nameOrder = null;
  }

  @override
  void setSort(GallerySort sort) {
    _sort = sort;
    _album = null;
    _total = 0;
    _nameOrder = null;
  }

  Future<List<AssetEntity>> _assetsByName(AssetPathEntity album) async {
    final key = '${album.id}:${_sort.ascending}';
    final cached = _nameOrder;
    if (cached != null &&
        _nameOrderKey == key &&
        DateTime.now().difference(_nameOrderAt) < const Duration(minutes: 1)) {
      return cached;
    }
    final assets = await album.getAssetListRange(start: 0, end: _total);
    int compare(AssetEntity a, AssetEntity b) =>
        (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase());
    assets.sort(_sort.ascending ? compare : (a, b) => compare(b, a));
    _nameOrder = assets;
    _nameOrderKey = key;
    _nameOrderAt = DateTime.now();
    return assets;
  }

  @override
  Future<GalleryPage> load({
    int offset = 0,
    int limit = GallerySource.pageSize,
  }) async {
    if (offset == 0 || _album == null) {
      await _fetchPaths();
      final album = _pathFor(_albumId);
      _album = album;
      if (album == null) {
        _total = 0;
        return GalleryPage.empty;
      }
      _total = await album.assetCountAsync;
    }
    final album = _album;
    if (album == null || offset >= _total) return GalleryPage.empty;
    final end = offset + limit < _total ? offset + limit : _total;
    final List<AssetEntity> assets;
    if (_sort.field == GallerySortField.name) {
      assets = (await _assetsByName(album)).sublist(offset, end);
    } else {
      assets = await album.getAssetListRange(start: offset, end: end);
    }
    return GalleryPage(
      items: assets.map((a) => _AssetGalleryItem(a)).toList(),
      hasMore: end < _total,
    );
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> manageAccess() => PhotoManager.presentLimited();
}

// #***! обёртка над системным ассетом
class _AssetGalleryItem implements GalleryItem {
  final AssetEntity asset;

  _AssetGalleryItem(this.asset);

  @override
  String get id => asset.id;

  @override
  String get name => asset.title ?? '';

  @override
  bool get isVideo => asset.type == AssetType.video;

  @override
  Duration? get duration => isVideo ? Duration(seconds: asset.duration) : null;

  @override
  File? get localFile => null;

  @override
  Future<Uint8List?> thumbnail(int size) =>
      asset.thumbnailDataWithSize(ThumbnailSize.square(size));

  @override
  Future<File?> originFile() => asset.file;

  @override
  Future<Uint8List?> encodeForUpload({
    required int maxDimension,
    required int quality,
  }) => asset.thumbnailDataWithSize(
    ThumbnailSize(maxDimension, maxDimension),
    format: ThumbnailFormat.jpeg,
    quality: quality,
  );

  @override
  Future<(int, int)?> dimensions() async {
    if (asset.width > 0 && asset.height > 0) {
      return (asset.width, asset.height);
    }
    return null;
  }
}

const Set<String> kGalleryImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
  '.heic',
  '.heif',
};

const Set<String> kGalleryVideoExtensions = {
  '.mp4',
  '.mov',
  '.m4v',
  '.mkv',
  '.webm',
  '.avi',
  '.3gp',
};

// #***! тип по расширению
String _fileExtension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return '';
  return path.substring(dot).toLowerCase();
}

String _baseName(String path) => path.split(RegExp(r'[\\/]')).last;

bool isVideoPath(String path) =>
    kGalleryVideoExtensions.contains(_fileExtension(path));

bool isImagePath(String path) =>
    kGalleryImageExtensions.contains(_fileExtension(path));

// #***! на десктопе галереи нет, сканируем стандартные папки
class _DesktopGallerySource implements GallerySource {
  @override
  Future<GalleryPermission> ensurePermission() async =>
      GalleryPermission.granted;

  @override
  Future<List<GalleryAlbum>> albums() async => const [
    GalleryAlbum(id: 'desktop', name: '', count: 0, isAll: true),
  ];

  @override
  void selectAlbum(GalleryAlbum album) {}

  GallerySort _sort = GallerySort.newestFirst;

  @override
  void setSort(GallerySort sort) {
    _sort = sort;
    _all = const [];
  }

  List<_FileGalleryItem> _all = const [];

  @override
  Future<GalleryPage> load({
    int offset = 0,
    int limit = GallerySource.pageSize,
  }) async {
    if (offset == 0 || _all.isEmpty) _all = _scan();
    if (offset >= _all.length) return GalleryPage.empty;
    final end = offset + limit < _all.length ? offset + limit : _all.length;
    final items = _all.sublist(offset, end);
    const batch = 8;
    const eager = 24;

    Future<void> probeRange(int from, int to) async {
      for (var i = from; i < to; i += batch) {
        final stop = i + batch > to ? to : i + batch;
        await Future.wait(items.sublist(i, stop).map((it) => it.probe()));
      }
    }

    final head = items.length < eager ? items.length : eager;
    await probeRange(0, head);
    if (head < items.length) unawaited(probeRange(head, items.length));
    return GalleryPage(items: items, hasMore: end < _all.length);
  }

  List<_FileGalleryItem> _scan() {
    final entries = <({File file, DateTime modified})>[];
    for (final dir in _candidateDirs()) {
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is! File || !_isMedia(entity.path)) continue;
          entries.add((file: entity, modified: entity.statSync().modified));
        }
      } catch (_) {}
    }
    entries.sort((a, b) {
      final order = switch (_sort.field) {
        GallerySortField.date => a.modified.compareTo(b.modified),
        GallerySortField.name => _baseName(
          a.file.path,
        ).toLowerCase().compareTo(_baseName(b.file.path).toLowerCase()),
      };
      return _sort.ascending ? order : -order;
    });
    return entries.map((e) => _FileGalleryItem(e.file)).toList();
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> manageAccess() async {}

  List<Directory> _candidateDirs() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return const [];
    return [
      Directory('$home/Pictures'),
      Directory('$home/Изображения'),
      Directory('$home/Images'),
      Directory('$home/Videos'),
      Directory('$home/Видео'),
      Directory('$home/Movies'),
    ];
  }

  bool _isMedia(String path) {
    final ext = _fileExtension(path);
    return kGalleryImageExtensions.contains(ext) ||
        kGalleryVideoExtensions.contains(ext);
  }
}

// #***! обёртка над обычным файлом
class _FileGalleryItem implements GalleryItem {
  final File file;
  Duration? _duration;

  _FileGalleryItem(this.file, {Duration? duration}) : _duration = duration;

  Future<void> probe() async {
    if (!isVideo || _duration != null) return;
    _duration = await DesktopVideoProbe.duration(file.path);
  }

  @override
  String get id => file.path;

  @override
  String get name => _baseName(file.path);

  @override
  bool get isVideo => isVideoPath(file.path);

  @override
  Duration? get duration => _duration;

  @override
  File? get localFile => file;

  @override
  Future<Uint8List?> thumbnail(int size) async =>
      isVideo ? DesktopVideoProbe.thumbnail(file.path, size) : null;

  @override
  Future<File?> originFile() async => file;

  @override
  Future<Uint8List?> encodeForUpload({
    required int maxDimension,
    required int quality,
  }) async => null;

  @override
  Future<(int, int)?> dimensions() => isVideo
      ? DesktopVideoProbe.dimensions(file.path)
      : imageFileDimensions(file);
}
