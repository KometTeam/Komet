import 'dart:typed_data';

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

class ClipboardImageData {
  const ClipboardImageData({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

class ClipboardMediaPayload {
  const ClipboardMediaPayload({
    this.files = const <ClipboardFileRef>[],
    this.image,
  });

  final List<ClipboardFileRef> files;
  final ClipboardImageData? image;

  bool get isEmpty => files.isEmpty && image == null;
}
