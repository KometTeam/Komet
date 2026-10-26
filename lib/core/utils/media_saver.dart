import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../l10n/app_localizations.dart';
import '../config/device_profile.dart';
import 'download_history.dart';
import 'download_progress.dart';
import 'format.dart';
import 'image_format.dart';
import 'media_cache.dart';
import 'save_file_as.dart';

enum MediaSaveFailure {
  noLink,
  downloadFailed,
  fileNotFound,
  noGalleryAccess,
  noStorageAccess,
}

// #***! итог сохранения, в галерею или в папку
class MediaSaveResult {
  final bool ok;
  final bool toGallery;
  final String? location;
  final MediaSaveFailure? failure;
  final String? error;

  const MediaSaveResult({
    required this.ok,
    this.toGallery = false,
    this.location,
    this.failure,
    this.error,
  });

  String errorText(AppLocalizations l10n) => switch (failure) {
    MediaSaveFailure.noLink => l10n.photoViewerErrorNoLink,
    MediaSaveFailure.downloadFailed => l10n.fileBubbleDownloadFailedReason,
    MediaSaveFailure.fileNotFound => l10n.mediaSaveFileNotFound,
    MediaSaveFailure.noGalleryAccess => l10n.mediaSaveNoGalleryAccess,
    MediaSaveFailure.noStorageAccess => l10n.mediaSaveNoStorageAccess,
    null => error ?? '',
  };
}

// #***! аватарка, качаем в кэш и в галерею
Future<MediaSaveResult> saveImageFromUrl(String url) async {
  if (url.isEmpty) {
    return const MediaSaveResult(ok: false, failure: MediaSaveFailure.noLink);
  }
  try {
    final cacheName = 'avatar_${url.hashCode & 0x7fffffff}.jpg';
    final file = await MediaCache.getOrDownload(cacheName, url);
    if (file == null) {
      return const MediaSaveResult(
        ok: false,
        failure: MediaSaveFailure.downloadFailed,
      );
    }
    return await _persist(
      file,
      saveName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      kind: SaveMediaKind.image,
    );
  } catch (e) {
    return MediaSaveResult(ok: false, error: e.toString());
  }
}

// #***! фото и видео в галерею, аудио в медиатеку, остальное в папку
enum SaveMediaKind { image, video, audio, file }

bool get savesToGallery => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

bool get _isIOS => !kIsWeb && Platform.isIOS;

const _scopedStorageSdk = 29;

// #***! сохранение вложения с записью в историю
Future<MediaSaveResult> saveMediaFile({
  required String cacheName,
  required Future<String?> Function() resolveUrl,
  required String saveName,
  required SaveMediaKind kind,
  DownloadMetadata? download,
  void Function(double progress)? onProgress,
}) async {
  try {
    var file = await MediaCache.existing(cacheName);
    if (file == null) {
      onProgress?.call(0);
      final url = await resolveUrl();
      if (url == null || url.isEmpty) {
        return const MediaSaveResult(
          ok: false,
          failure: MediaSaveFailure.noLink,
        );
      }
      file = await MediaCache.getOrDownload(
        cacheName,
        url,
        onProgress: onProgress,
      );
    }
    if (file == null) {
      return const MediaSaveResult(
        ok: false,
        failure: MediaSaveFailure.downloadFailed,
      );
    }
    final result = await _persist(file, saveName: saveName, kind: kind);
    if (result.ok && download != null) {
      try {
        await DownloadHistory.record(download, file);
      } catch (_) {}
    }
    return result;
  } catch (e) {
    return MediaSaveResult(ok: false, error: e.toString());
  }
}

// #***! голосовое как обычный аудиофайл, докачку видно на кнопке пузыря
Future<MediaSaveResult> saveVoiceMessage({
  required String cacheName,
  required String url,
  required int messageTime,
  DownloadMetadata? download,
}) async {
  final stamp = formatFileStamp(
    DateTime.fromMillisecondsSinceEpoch(messageTime),
  );
  try {
    return await saveMediaFile(
      cacheName: cacheName,
      resolveUrl: () async => url,
      saveName: 'VOICE_$stamp.ogg',
      kind: SaveMediaKind.audio,
      download: download,
      onProgress: (value) => MediaDownloadProgress.set(cacheName, value),
    );
  } finally {
    MediaDownloadProgress.set(cacheName, null);
  }
}

// #***! подсказываем где искать сохранённое голосовое
String voiceSaveNotice(AppLocalizations l10n, MediaSaveResult result) {
  if (!result.ok) return l10n.notificationsSaveFailed(result.errorText(l10n));
  if (_isIOS) return l10n.voiceSavedToFiles;
  final location = result.location;
  return location == null ? l10n.voiceSaved : l10n.voiceSavedTo(location);
}

// #***! медиа уже на диске, просто копируем
Future<MediaSaveResult> saveLocalMedia(
  File file, {
  required String saveName,
  required SaveMediaKind kind,
}) async {
  try {
    if (!await file.exists()) {
      return const MediaSaveResult(
        ok: false,
        failure: MediaSaveFailure.fileNotFound,
      );
    }
    return await _persist(file, saveName: saveName, kind: kind);
  } catch (e) {
    return MediaSaveResult(ok: false, error: e.toString());
  }
}

// #***! на мобилках просим доступ и в галерею, на десктопе в загрузки
Future<MediaSaveResult> _persist(
  File file, {
  required String saveName,
  required SaveMediaKind kind,
}) async {
  if (kind != SaveMediaKind.image) {
    return _write(file, saveName: saveName, kind: kind);
  }
  final image = await prepareImageForSave(file);
  if (image == null) return _write(file, saveName: saveName, kind: kind);
  try {
    return await _write(
      image.file,
      saveName: withImageExtension(saveName, image.extension),
      kind: kind,
    );
  } finally {
    await image.discard();
  }
}

Future<MediaSaveResult> _write(
  File file, {
  required String saveName,
  required SaveMediaKind kind,
}) async {
  final toGallery = kind == SaveMediaKind.image || kind == SaveMediaKind.video;
  if (savesToGallery && toGallery) {
    if (!await _mayWriteGallery()) {
      return const MediaSaveResult(
        ok: false,
        failure: MediaSaveFailure.noGalleryAccess,
      );
    }
    if (kind == SaveMediaKind.video) {
      await PhotoManager.editor.saveVideo(file, title: saveName);
    } else {
      final bytes = await file.readAsBytes();
      await PhotoManager.editor.saveImage(bytes, filename: saveName);
    }
    return const MediaSaveResult(ok: true, toGallery: true);
  }
  if (kind == SaveMediaKind.audio && _isAndroid) {
    return _publishAudio(file, saveName);
  }

  final dir = await _targetDirectory();
  final target = await availableSaveTarget(dir.path, p.basename(saveName));
  await file.copy(target.path);
  return MediaSaveResult(ok: true, location: target.path);
}

// #***! в MediaStore, файл видят плееры и проводник
Future<MediaSaveResult> _publishAudio(File file, String saveName) async {
  if (!await _mayWriteSharedStorage()) {
    return const MediaSaveResult(
      ok: false,
      failure: MediaSaveFailure.noStorageAccess,
    );
  }
  try {
    final folder = await mediaExportChannel.invokeMethod<String>(
      'publishAudio',
      {'path': file.path, 'name': saveName},
    );
    return MediaSaveResult(ok: true, location: folder);
  } on PlatformException catch (e) {
    return MediaSaveResult(ok: false, error: e.message ?? e.code);
  }
}

Future<bool> _hasScopedStorage() async =>
    _isAndroid &&
    ((await DeviceProfile.load()).sdkInt ?? 0) >= _scopedStorageSdk;

Future<bool> _mayWriteGallery() async {
  if (await _hasScopedStorage()) return true;
  final state = await PhotoManager.requestPermissionExtend();
  return state.isAuth || state.hasAccess;
}

Future<bool> _mayWriteSharedStorage() async {
  if (await _hasScopedStorage()) return true;
  return (await Permission.storage.request()).isGranted;
}

// #***! на айфоне Documents виден в «Файлах», загрузок нет на всех платформах
Future<Directory> _targetDirectory() async {
  if (_isIOS) return getApplicationDocumentsDirectory();
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}
