import 'dart:io';
import 'package:image/image.dart' as img;

const _densities = {
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

void main() {
  final src = img.decodePng(File('assets/meteor.png').readAsBytesSync())!;
  for (final entry in _densities.entries) {
    final canvas =
        img.Image(width: entry.value, height: entry.value, numChannels: 4);
    final scaled = img.copyResize(src,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic);
    img.compositeImage(canvas, scaled);
    final file = File(
        'android/app/src/main/res/drawable-${entry.key}/ic_launcher_minimal_foreground.png');
    file.writeAsBytesSync(img.encodePng(canvas));
    stdout.writeln('wrote ${file.path} (${entry.value}x${entry.value})');
  }
}
