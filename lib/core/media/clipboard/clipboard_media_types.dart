import 'dart:typed_data';

// #***! файл из буфера
class ClipboardFileRef {
  const ClipboardFileRef({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}

// #***! картинка из буфера с расширением
class ClipboardImageData {
  const ClipboardImageData({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

// #***! что реально достали из буфера
class ClipboardMediaPayload {
  const ClipboardMediaPayload({
    this.files = const <ClipboardFileRef>[],
    this.image,
  });

  final List<ClipboardFileRef> files;
  final ClipboardImageData? image;

  bool get isEmpty => files.isEmpty && image == null;
}
