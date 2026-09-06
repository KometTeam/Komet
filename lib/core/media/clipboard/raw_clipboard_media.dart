import 'dart:typed_data';

// #***! сырой ответ натива, пути или байты картинки
class RawClipboardMedia {
  const RawClipboardMedia({
    this.paths = const <String>[],
    this.png,
    this.dib,
    this.imageExtension,
  });

  final List<String> paths;
  final Uint8List? png;
  final Uint8List? dib;
  final String? imageExtension;

  bool get isEmpty => paths.isEmpty && png == null && dib == null;
}
