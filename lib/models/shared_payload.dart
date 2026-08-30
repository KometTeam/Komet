import 'dart:io';

// #***! как показать файл, фото видео или документ
enum SharedFileKind { photo, video, file }

// #***! файл прилетевший через системное поделиться
class SharedFile {
  final String path;
  final String name;
  final String mime;
  final int size;

  const SharedFile({
    required this.path,
    required this.name,
    required this.mime,
    required this.size,
  });

  // #***! путь обязателен, остальное добираем
  static SharedFile? fromMap(Map<dynamic, dynamic> map) {
    final path = map['path'];
    if (path is! String || path.isEmpty) return null;
    final name = map['name'];
    final mime = map['mime'];
    final size = map['size'];
    return SharedFile(
      path: path,
      name: name is String && name.isNotEmpty ? name : _basename(path),
      mime: mime is String && mime.isNotEmpty
          ? mime
          : 'application/octet-stream',
      size: size is int ? size : 0,
    );
  }

  File get file => File(path);

  // #***! тип по mime, svg это документ
  SharedFileKind get kind {
    if (mime.startsWith('image/') && !mime.contains('svg')) {
      return SharedFileKind.photo;
    }
    if (mime.startsWith('video/')) return SharedFileKind.video;
    return SharedFileKind.file;
  }

  static String _basename(String path) {
    final idx = path.lastIndexOf(Platform.pathSeparator);
    return idx < 0 ? path : path.substring(idx + 1);
  }
}

// #***! весь пакет шаринга, файлы и текст
class SharedPayload {
  final List<SharedFile> files;
  final String? text;
  final String? subject;

  const SharedPayload({this.files = const [], this.text, this.subject});

  // #***! нет файла на диске выкидываем, иначе упадём позже
  static SharedPayload? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final rawFiles = raw['files'];
    final files = <SharedFile>[];
    if (rawFiles is List) {
      for (final entry in rawFiles) {
        if (entry is! Map) continue;
        final file = SharedFile.fromMap(entry);
        if (file != null && file.file.existsSync()) files.add(file);
      }
    }
    final text = raw['text'];
    final subject = raw['subject'];
    final payload = SharedPayload(
      files: files,
      text: text is String && text.trim().isNotEmpty ? text.trim() : null,
      subject: subject is String && subject.trim().isNotEmpty
          ? subject.trim()
          : null,
    );
    return payload.isEmpty ? null : payload;
  }

  // #***! пустой пакет юишке не нужен
  bool get isEmpty => files.isEmpty && text == null;

  bool get isTextOnly => files.isEmpty && text != null;

  List<SharedFile> get photos =>
      files.where((f) => f.kind == SharedFileKind.photo).toList();

  List<SharedFile> get videos =>
      files.where((f) => f.kind == SharedFileKind.video).toList();

  List<SharedFile> get documents =>
      files.where((f) => f.kind == SharedFileKind.file).toList();

  // #***! по главному типу выбираем экран
  SharedFileKind? get dominantKind {
    if (files.isEmpty) return null;
    if (documents.isNotEmpty) return SharedFileKind.file;
    if (videos.isNotEmpty && photos.isEmpty) return SharedFileKind.video;
    if (photos.isNotEmpty && videos.isEmpty) return SharedFileKind.photo;
    return SharedFileKind.photo;
  }
}
