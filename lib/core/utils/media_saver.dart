import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'media_cache.dart';

class MediaSaveResult {
  final bool ok;
  final bool toGallery;
  final String? location;
  final String? error;

  const MediaSaveResult({
    required this.ok,
    this.toGallery = false,
    this.location,
    this.error,
  });
}

Future<MediaSaveResult> saveImageFromUrl(String url) async {
  if (url.isEmpty) {
    return const MediaSaveResult(ok: false, error: 'нет ссылки');
  }
  try {
    final cacheName = 'avatar_${url.hashCode & 0x7fffffff}.jpg';
    final file = await MediaCache.getOrDownload(cacheName, url);
    if (file == null) {
      return const MediaSaveResult(ok: false, error: 'не удалось загрузить');
    }
    final saveName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final state = await PhotoManager.requestPermissionExtend();
      if (!state.isAuth && !state.hasAccess) {
        return const MediaSaveResult(ok: false, error: 'нет доступа к галерее');
      }
      final bytes = await file.readAsBytes();
      await PhotoManager.editor.saveImage(bytes, filename: saveName);
      return const MediaSaveResult(ok: true, toGallery: true);
    }

    final dir = await _targetDirectory();
    final target = File('${dir.path}${Platform.pathSeparator}$saveName');
    await file.copy(target.path);
    return MediaSaveResult(ok: true, location: target.path);
  } catch (e) {
    return MediaSaveResult(ok: false, error: e.toString());
  }
}

enum SaveMediaKind { image, video, file }

Future<MediaSaveResult> saveMediaFile({
  required String cacheName,
  required Future<String?> Function() resolveUrl,
  required String saveName,
  required SaveMediaKind kind,
}) async {
  try {
    var file = await MediaCache.existing(cacheName);
    if (file == null) {
      final url = await resolveUrl();
      if (url == null || url.isEmpty) {
        return const MediaSaveResult(ok: false, error: 'нет ссылки');
      }
      file = await MediaCache.getOrDownload(cacheName, url);
    }
    if (file == null) {
      return const MediaSaveResult(ok: false, error: 'не удалось загрузить');
    }

    final toGallery =
        kind == SaveMediaKind.image || kind == SaveMediaKind.video;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && toGallery) {
      final state = await PhotoManager.requestPermissionExtend();
      if (!state.isAuth && !state.hasAccess) {
        return const MediaSaveResult(ok: false, error: 'нет доступа к галерее');
      }
      if (kind == SaveMediaKind.video) {
        await PhotoManager.editor.saveVideo(file, title: saveName);
      } else {
        final bytes = await file.readAsBytes();
        await PhotoManager.editor.saveImage(bytes, filename: saveName);
      }
      return const MediaSaveResult(ok: true, toGallery: true);
    }

    final dir = await _targetDirectory();
    final target = File('${dir.path}${Platform.pathSeparator}$saveName');
    await file.copy(target.path);
    return MediaSaveResult(ok: true, location: target.path);
  } catch (e) {
    return MediaSaveResult(ok: false, error: e.toString());
  }
}

Future<Directory> _targetDirectory() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}
