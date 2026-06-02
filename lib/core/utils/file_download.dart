import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileDownloadResult {
  final bool ok;
  final String? path;
  final String? error;

  const FileDownloadResult({required this.ok, this.path, this.error});
}

/// Скачивает файл по [url] во временную папку под именем [fileName]
/// и открывает его системным приложением.
Future<FileDownloadResult> downloadAndOpenFile(
  String url,
  String fileName,
) async {
  try {
    final dir = await getTemporaryDirectory();
    final safeName = _sanitize(fileName);
    final file = File(p.join(dir.path, safeName));

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        return FileDownloadResult(ok: false, error: 'HTTP ${response.statusCode}');
      }
      final sink = file.openWrite();
      await response.pipe(sink);
    } finally {
      client.close();
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

String _sanitize(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return cleaned.isEmpty ? 'file' : cleaned;
}
