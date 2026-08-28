import 'dart:typed_data';

class RawClipboardMedia {
  const RawClipboardMedia({this.paths = const <String>[], this.png, this.dib});

  final List<String> paths;
  final Uint8List? png;
  final Uint8List? dib;

  bool get isEmpty => paths.isEmpty && png == null && dib == null;
}
