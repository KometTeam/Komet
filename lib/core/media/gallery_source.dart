import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:photo_manager/photo_manager.dart';

enum GalleryPermission { granted, limited, denied }

abstract class GalleryItem {
  String get id;
  bool get isVideo;
  Duration? get duration;
  File? get localFile;
  Future<Uint8List?> thumbnail(int size);
  Future<File?> originFile();
  Future<(int, int)?> dimensions();
}

class PickedPhoto {
  final GalleryItem item;
  final File? editedFile;

  const PickedPhoto({required this.item, this.editedFile});
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

abstract class GallerySource {
  Future<GalleryPermission> ensurePermission();
  Future<List<GalleryItem>> load({int limit});
  Future<void> openSettings();
  Future<void> manageAccess();

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

  @override
  Future<List<GalleryItem>> load({int limit = 120}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (paths.isEmpty) return const [];
    final assets = await paths.first.getAssetListRange(start: 0, end: limit);
    return assets.map((a) => _AssetGalleryItem(a)).toList();
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> manageAccess() => PhotoManager.presentLimited();
}

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
  Future<(int, int)?> dimensions() async {
    if (asset.width > 0 && asset.height > 0) {
      return (asset.width, asset.height);
    }
    return null;
  }
}

class _DesktopGallerySource implements GallerySource {
  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
  };

  @override
  Future<GalleryPermission> ensurePermission() async =>
      GalleryPermission.granted;

  @override
  Future<List<GalleryItem>> load({int limit = 120}) async {
    final entries = <({File file, DateTime modified})>[];
    for (final dir in _candidateDirs()) {
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is! File || !_isImage(entity.path)) continue;
          entries.add((file: entity, modified: entity.statSync().modified));
        }
      } catch (_) {}
    }
    entries.sort((a, b) => b.modified.compareTo(a.modified));
    return entries.take(limit).map((e) => _FileGalleryItem(e.file)).toList();
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
    ];
  }

  bool _isImage(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return false;
    return _imageExtensions.contains(path.substring(dot).toLowerCase());
  }
}

class _FileGalleryItem implements GalleryItem {
  final File file;

  _FileGalleryItem(this.file);

  @override
  String get id => file.path;

  @override
  bool get isVideo => false;

  @override
  Duration? get duration => null;

  @override
  File? get localFile => file;

  @override
  Future<Uint8List?> thumbnail(int size) async => null;

  @override
  Future<File?> originFile() async => file;

  @override
  Future<(int, int)?> dimensions() => imageFileDimensions(file);
}
