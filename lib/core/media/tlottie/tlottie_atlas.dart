import 'dart:typed_data';

class AtlasLayout {
  const AtlasLayout({required this.px, required this.frameCount});

  static const int columns = 4;
  static const int framesPerPage = columns * columns;
  static const int gap = 2;

  final int px;
  final int frameCount;

  int get pageCount => (frameCount + framesPerPage - 1) ~/ framesPerPage;

  int pageOf(int frame) => frame ~/ framesPerPage;

  int framesOn(int page) {
    final rest = frameCount - page * framesPerPage;
    return rest < framesPerPage ? rest : framesPerPage;
  }

  int _span(int cells) => cells * px + (cells - 1) * gap;

  int widthOf(int page) =>
      _span(framesOn(page) < columns ? framesOn(page) : columns);

  int heightOf(int page) => _span((framesOn(page) + columns - 1) ~/ columns);

  int bytesOf(int page) => widthOf(page) * heightOf(page) * 4;

  int leftOf(int frame) => (frame % framesPerPage % columns) * (px + gap);

  int topOf(int frame) => (frame % framesPerPage ~/ columns) * (px + gap);

  Uint8List allocate(int page) => Uint8List(bytesOf(page));

  void blit(Uint8List page, int frame, Uint8List bgra) {
    final rowBytes = px * 4;
    final stride = widthOf(pageOf(frame)) * 4;
    var dst = topOf(frame) * stride + leftOf(frame) * 4;
    var src = 0;
    for (var y = 0; y < px; y++) {
      page.setRange(dst, dst + rowBytes, bgra, src);
      dst += stride;
      src += rowBytes;
    }
  }
}
