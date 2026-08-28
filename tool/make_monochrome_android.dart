import 'dart:io';
import 'package:image/image.dart' as img;

const _densities = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

const _layers = {
  'assets/komet.png': 'ic_launcher_monochrome',
  'assets/meteor.png': 'ic_launcher_minimal_monochrome',
};

void main() {
  for (final layer in _layers.entries) {
    final src = img.decodePng(File(layer.key).readAsBytesSync())!;
    for (final density in _densities.entries) {
      final scaled = img.copyResize(src,
          width: density.value,
          height: density.value,
          interpolation: img.Interpolation.cubic);
      final canvas = img.Image(
          width: density.value, height: density.value, numChannels: 4);
      for (final pixel in scaled) {
        canvas.setPixelRgba(pixel.x, pixel.y, 0, 0, 0, pixel.a);
      }
      final file = File('android/app/src/main/res/'
          'drawable-${density.key}/${layer.value}.png');
      file.writeAsBytesSync(img.encodePng(canvas));
      stdout.writeln('wrote ${file.path} (${density.value}x${density.value})');
    }
  }
}
