import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const w = 1280;
  const h = 800;
  final bg = img.Image(width: w, height: h, numChannels: 4);

  final topR = 251, topG = 251, topB = 253;
  final botR = 233, botG = 233, botB = 237;
  for (var y = 0; y < h; y++) {
    final t = y / (h - 1);
    final r = (topR + (botR - topR) * t).round();
    final g = (topG + (botG - topG) * t).round();
    final b = (topB + (botB - topB) * t).round();
    img.fillRect(bg, x1: 0, y1: y, x2: w - 1, y2: y, color: img.ColorRgb8(r, g, b));
  }

  final green = img.ColorRgb8(124, 191, 64);
  const ay = 380;
  img.fillRect(bg, x1: 548, y1: ay - 9, x2: 704, y2: ay + 9, color: green);
  img.fillPolygon(bg, vertices: [
    img.Point(700, ay - 30),
    img.Point(700, ay + 30),
    img.Point(752, ay),
  ], color: green);

  final outDir = Directory('scripts/dmg');
  outDir.createSync(recursive: true);
  File('scripts/dmg/background.png').writeAsBytesSync(img.encodePng(bg));
  stdout.writeln('wrote scripts/dmg/background.png (${w}x$h)');
}
