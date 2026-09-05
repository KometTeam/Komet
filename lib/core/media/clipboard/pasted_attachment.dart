import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../gallery_source.dart';
import 'clipboard_media.dart';

// #***! вставленные картинки лежат сутки
const Duration _pasteRetention = Duration(hours: 24);

// #***! как показать вставленное
enum PastedAttachmentKind { image, video, file }

// #***! файл из буфера готовый к отправке
class PastedAttachment {
  const PastedAttachment({
    required this.file,
    required this.name,
    required this.size,
    required this.kind,
  });

  final File file;
  final String name;
  final int size;
  final PastedAttachmentKind kind;

  bool get isMedia => kind != PastedAttachmentKind.file;
}

// #***! содержимое буфера в файлы на диске
Future<List<PastedAttachment>> materializeClipboardMedia(
  ClipboardMediaPayload payload,
) async {
  final result = <PastedAttachment>[];

  final image = payload.image;
  if (image != null) {
    final stored = await _storePastedImage(image);
    if (stored != null) result.add(stored);
  }

  for (final ref in payload.files) {
    final file = File(ref.path);
    if (!await file.exists()) continue;
    result.add(
      PastedAttachment(
        file: file,
        name: ref.name,
        size: ref.size,
        kind: _kindOf(ref.path),
      ),
    );
  }
  return result;
}

// #***! картинку сначала сохраняем иначе её не отправить
Future<PastedAttachment?> _storePastedImage(ClipboardImageData image) async {
  try {
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}/komet_paste',
    );
    await dir.create(recursive: true);
    await _prune(dir);
    final name =
        'paste_${DateTime.now().millisecondsSinceEpoch}'
        '${image.extension}';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(image.bytes, flush: true);
    return PastedAttachment(
      file: file,
      name: name,
      size: image.bytes.length,
      kind: PastedAttachmentKind.image,
    );
  } catch (_) {
    return null;
  }
}

// #***! тип по расширению
PastedAttachmentKind _kindOf(String path) {
  if (isVideoPath(path)) return PastedAttachmentKind.video;
  if (isImagePath(path)) return PastedAttachmentKind.image;
  return PastedAttachmentKind.file;
}

// #***! старые вставки чистим иначе папка растёт
Future<void> _prune(Directory dir) async {
  final cutoff = DateTime.now().subtract(_pasteRetention);
  try {
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      if ((await entry.stat()).modified.isBefore(cutoff)) await entry.delete();
    }
  } catch (_) {}
}
