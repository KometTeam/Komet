import 'dart:io';
import 'package:image/image.dart' as img;

const _pairs = {
  'assets/komet.png': 'assets/komet_icon.png',
  'assets/meteor.png': 'assets/meteor_icon.png',
};

void main() {
  for (final entry in _pairs.entries) {
    final src = img.decodePng(File(entry.key).readAsBytesSync())!;
    final size = src.width > src.height ? src.width : src.height;
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(canvas, src,
        dstX: (size - src.width) ~/ 2, dstY: (size - src.height) ~/ 2);
    File(entry.value).writeAsBytesSync(img.encodePng(canvas));
    stdout.writeln('wrote ${entry.value} (${size}x$size)');
  }
}
