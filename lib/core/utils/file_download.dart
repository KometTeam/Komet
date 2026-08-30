import 'package:open_filex/open_filex.dart';

import 'download_history.dart';
import 'media_cache.dart';

// #***! итог скачивания, путь или ошибка
class FileDownloadResult {
  final bool ok;
  final String? path;
  final String? error;

  const FileDownloadResult({required this.ok, this.path, this.error});
}

// #***! открыть файл, скачав если надо
/// Открывает файл из кэша, скачивая его при отсутствии.
///
/// [cacheName] — стабильное имя в кэше (например, `<fileId>_имя.ext`).
/// [resolveUrl] вызывается лениво — только если файла ещё нет в кэше,
/// чтобы не дёргать сервер за временной ссылкой повторно.
/// [onReady] вызывается как только файл лежит на диске — до открытия во
/// внешнем приложении, которое может не возвращать управление, пока его не
/// закроют. Без этого индикатор загрузки висел бы всё это время.
Future<FileDownloadResult> openCachedFile(
  String cacheName,
  Future<String?> Function() resolveUrl, {
  void Function(double progress)? onProgress,
  void Function()? onReady,
  DownloadMetadata? download,
}) async {
  final result = await ensureCachedFile(
    cacheName,
    resolveUrl,
    onProgress: onProgress,
    onReady: onReady,
    download: download,
  );
  if (!result.ok || result.path == null) return result;
  try {
    final opened = await OpenFilex.open(result.path!);
    return FileDownloadResult(
      ok: opened.type == ResultType.done,
      path: result.path,
      error: opened.type == ResultType.done ? null : opened.message,
    );
  } catch (e) {
    return FileDownloadResult(
      ok: false,
      path: result.path,
      error: e.toString(),
    );
  }
}

// #***! скачивание в кэш, onReady зовётся как только файл на диске
Future<FileDownloadResult> ensureCachedFile(
  String cacheName,
  Future<String?> Function() resolveUrl, {
  void Function(double progress)? onProgress,
  void Function()? onReady,
  DownloadMetadata? download,
}) async {
  // #***! ready зовётся из разных веток, защита от повтора
  var readyFired = false;
  void ready() {
    if (readyFired) return;
    readyFired = true;
    onReady?.call();
  }

  try {
    var file = await MediaCache.existing(cacheName);

    if (file == null) {
      final url = await resolveUrl();
      if (url == null || url.isEmpty) {
        ready();
        return const FileDownloadResult(ok: false, error: 'нет ссылки');
      }
      file = await MediaCache.getOrDownload(
        cacheName,
        url,
        onProgress: onProgress,
      );
      if (file == null) {
        ready();
        return const FileDownloadResult(ok: false, error: 'ошибка загрузки');
      }
    }

    ready();
    if (download != null) {
      try {
        await DownloadHistory.record(download, file);
      } catch (_) {}
    }
    return FileDownloadResult(ok: true, path: file.path);
  } catch (e) {
    ready();
    return FileDownloadResult(ok: false, error: e.toString());
  }
}
