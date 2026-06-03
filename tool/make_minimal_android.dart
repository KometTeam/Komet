import 'dart:io';
import 'package:image/image.dart' as img;

const _densities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

void main() {
  final src = img.decodePng(File('assets/meteor_icon.png').readAsBytesSync())!;
  for (final entry in _densities.entries) {
    final resized = img.copyResize(src,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.average);
    final dir =
        Directory('android/app/src/main/res/mipmap-${entry.key}');
    final file = File('${dir.path}/ic_launcher_minimal.png');
    file.writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('wrote ${file.path} (${entry.value}x${entry.value})');
  }
}
