import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../backend/modules/upload_service.dart';
import '../../../../core/media/gallery_source.dart';
import '../../../../main.dart' show api;
import '../../../../models/attachment.dart';

class EditMediaItem {
  EditMediaItem._({this.kept, this.file, this.source, this.temporary = false});

  final PhotoAttachment? kept;
  final File? file;
  final GalleryItem? source;
  final bool temporary;
  final ValueNotifier<List<UploadBytes>> progress = ValueNotifier(const [
    UploadBytes.none,
  ]);
  final Completer<void> _cancel = Completer<void>();
  Future<void>? _upload;
  String? _token;
  bool _failed = false;

  bool get uploading => kept == null && _token == null && !_failed;
  bool get failed => _failed;
  String? get token => kept?.photoToken ?? _token;

  void _report(int sent, int total) {
    if (!_cancel.isCompleted) progress.value = [UploadBytes(sent, total)];
  }

  void _release() {
    if (!_cancel.isCompleted) _cancel.complete();
    progress.dispose();
    final local = file;
    if (temporary && local != null) {
      local.delete().then((_) {}, onError: (_) {});
    }
  }
}

class MessageMediaDraft extends ChangeNotifier {
  MessageMediaDraft(List<PhotoAttachment> photos)
    : _original = photos,
      _items = [for (final photo in photos) EditMediaItem._(kept: photo)];

  static List<PhotoAttachment>? editablePhotos(CachedMessage message) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) return null;
    final photos = attachments.whereType<PhotoAttachment>().toList();
    if (photos.length != attachments.length) return null;
    if (photos.any((photo) => (photo.photoToken ?? '').isEmpty)) return null;
    return photos;
  }

  final List<PhotoAttachment> _original;
  final List<EditMediaItem> _items;
  final List<EditMediaItem> _dropped = [];
  final Object? _session = api.session;
  bool _disposed = false;

  List<EditMediaItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get changed {
    if (_items.length != _original.length) return true;
    for (var i = 0; i < _items.length; i++) {
      if (!identical(_items[i].kept, _original[i])) return true;
    }
    return false;
  }

  void add(File file, {GalleryItem? source, bool temporary = false}) {
    final item = EditMediaItem._(
      file: file,
      source: source,
      temporary: temporary,
    );
    _items.add(item);
    item._upload = _upload(item);
    notifyListeners();
  }

  void replace(
    EditMediaItem current,
    File file, {
    GalleryItem? source,
    bool temporary = false,
  }) {
    final index = _items.indexOf(current);
    if (index == -1) {
      if (temporary) file.delete().then((_) {}, onError: (_) {});
      return;
    }
    final item = EditMediaItem._(
      file: file,
      source: source,
      temporary: temporary,
    );
    _items[index] = item;
    _drop(current);
    item._upload = _upload(item);
    notifyListeners();
  }

  void remove(EditMediaItem item) {
    if (!_items.remove(item)) return;
    _drop(item);
    notifyListeners();
  }

  void retry(EditMediaItem item) {
    if (!item._failed || !_items.contains(item)) return;
    item._failed = false;
    item._upload = _upload(item);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>?> settle() async {
    await Future.wait([for (final item in _items) ?item._upload]);
    if (_disposed || _items.any((item) => item.token == null)) return null;
    return [
      for (final item in _items) {'_type': 'PHOTO', 'photoToken': item.token},
    ];
  }

  Future<void> _upload(EditMediaItem item) async {
    String? token;
    try {
      token = await UploadService.instance.uploadPhoto(
        item.file!,
        item: item.source,
        cancel: item._cancel.future,
        onProgress: item._report,
        onRetry: () => item._report(0, item.progress.value.first.total),
        beforeSend: _ensureSameSession,
      );
    } catch (_) {}
    if (_disposed || item._cancel.isCompleted) return;
    item._token = token;
    item._failed = token == null;
    notifyListeners();
  }

  void _ensureSameSession() {
    if (!identical(api.session, _session)) {
      throw const UploadFailure('account_changed');
    }
  }

  void _drop(EditMediaItem item) {
    if (!item._cancel.isCompleted) item._cancel.complete();
    _dropped.add(item);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final item in [..._items, ..._dropped]) {
      item._release();
    }
    super.dispose();
  }
}
