import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/foundation.dart';

import 'desktop_video_probe.dart';

// #***! доступ к галерее, полный частичный или запрещён
enum GalleryPermission { granted, limited, denied }

// #***! элемент галереи, за ним системный ассет или просто файл
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
  static FilterOptionGroup mediaFilter() => FilterOptionGroup(
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
    orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  Future<GalleryPermission> ensurePermission();
  Future<GalleryPage> load({int offset, int limit});
  Future<void> openSettings();
  Future<void> manageAccess();

  // #***! альбом все спрашиваем один раз, дальше листаем диапазонами
  @visibleForTesting
  factory GallerySource.desktopForTesting(
    List<Directory> directories, {
    Duration refreshInterval = const Duration(seconds: 30),
  }) => _DesktopGallerySource(
    directories: directories,
    refreshInterval: refreshInterval,
  );

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

  AssetPathEntity? _album;
  int _total = 0;

  @override
  Future<GalleryPage> load({
    int offset = 0,
    int limit = GallerySource.pageSize,
  }) async {
    if (offset == 0 || _album == null) {
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
        filterOption: GallerySource.mediaFilter(),
      );
      if (paths.isEmpty) {
        _album = null;
        _total = 0;
        return GalleryPage.empty;
      }
      _album = paths.first;
      _total = await paths.first.assetCountAsync;
    }
    final album = _album;
    if (album == null || offset >= _total) return GalleryPage.empty;
    final end = offset + limit < _total ? offset + limit : _total;
    final assets = await album.getAssetListRange(start: offset, end: end);
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

bool isVideoPath(String path) =>
    kGalleryVideoExtensions.contains(_fileExtension(path));

bool isImagePath(String path) =>
    kGalleryImageExtensions.contains(_fileExtension(path));

// #***! на десктопе галереи нет, сканируем стандартные папки
class _DesktopGallerySource implements GallerySource {
  _DesktopGallerySource({
    this.directories,
    this.refreshInterval = const Duration(seconds: 30),
  });
  final List<Directory>? directories;
  final Duration refreshInterval;
  @override
  Future<GalleryPermission> ensurePermission() async =>
      GalleryPermission.granted;

  List<_FileGalleryItem> _all = const [];
  Future<void>? _loading;
  DateTime? _scannedAt;

  Future<void> _ensureIndex(int offset) async {
    final scannedAt = _scannedAt;
    if (scannedAt != null &&
        (offset != 0 ||
            DateTime.now().difference(scannedAt) < refreshInterval)) {
      return;
    }
    await (_loading ??= () async {
      final paths = await compute(
        _scanDesktopGallery,
        _candidateDirs().map((dir) => dir.path).toList(),
      );
      _all = paths.map((path) => _FileGalleryItem(File(path))).toList();
      _scannedAt = DateTime.now();
    }().whenComplete(() => _loading = null));
  }

  @override
  Future<GalleryPage> load({
    int offset = 0,
    int limit = GallerySource.pageSize,
  }) async {
    await _ensureIndex(offset);
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

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> manageAccess() async {}

  List<Directory> _candidateDirs() {
    if (directories != null) return directories!;
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
}

List<String> _scanDesktopGallery(List<String> directories) {
  final entries = <({String path, DateTime modified})>[];
  for (final path in directories) {
    try {
      final directory = Directory(path);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(followLinks: false)) {
        if (entity is! File ||
            (!isImagePath(entity.path) && !isVideoPath(entity.path))) {
          continue;
        }
        try {
          entries.add((
            path: entity.path,
            modified: entity.statSync().modified,
          ));
        } on FileSystemException {
          continue;
        }
      }
    } on FileSystemException {
      continue;
    }
  }
  entries.sort((a, b) => b.modified.compareTo(a.modified));
  return entries.map((entry) => entry.path).toList();
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
