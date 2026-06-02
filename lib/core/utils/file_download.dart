import 'package:open_filex/open_filex.dart';

import 'media_cache.dart';

class FileDownloadResult {
  final bool ok;
  final String? path;
  final String? error;

  const FileDownloadResult({required this.ok, this.path, this.error});
}

/// Открывает файл из кэша, скачивая его при отсутствии.
///
/// [cacheName] — стабильное имя в кэше (например, `<fileId>_имя.ext`).
/// [resolveUrl] вызывается лениво — только если файла ещё нет в кэше,
/// чтобы не дёргать сервер за временной ссылкой повторно.
Future<FileDownloadResult> openCachedFile(
  String cacheName,
  Future<String?> Function() resolveUrl, {
  void Function(double progress)? onProgress,
}) async {
  try {
    var file = await MediaCache.existing(cacheName);

    if (file == null) {
      final url = await resolveUrl();
      if (url == null || url.isEmpty) {
        return const FileDownloadResult(ok: false, error: 'нет ссылки');
      }
      file = await MediaCache.getOrDownload(
        cacheName,
        url,
        onProgress: onProgress,
      );
      if (file == null) {
        return const FileDownloadResult(ok: false, error: 'ошибка загрузки');
      }
    }

    final opened = await OpenFilex.open(file.path);
    return FileDownloadResult(
      ok: opened.type == ResultType.done,
      path: file.path,
      error: opened.type == ResultType.done ? null : opened.message,
    );
  } catch (e) {
    return FileDownloadResult(ok: false, error: e.toString());
  }
}
