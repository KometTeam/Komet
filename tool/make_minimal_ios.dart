import 'dart:io';
import 'package:image/image.dart' as img;

const _sizes = {
  'ios/Runner/MinimalIcon@2x.png': 120,
  'ios/Runner/MinimalIcon@3x.png': 180,
  'ios/Runner/MinimalIcon-76@2x.png': 152,
  'ios/Runner/MinimalIcon-83.5@2x.png': 167,
};

void main() {
  final src = img.decodePng(File('assets/meteor_icon.png').readAsBytesSync())!;
  for (final entry in _sizes.entries) {
    final resized = img.copyResize(src,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
    stdout.writeln('wrote ${entry.key} (${entry.value}x${entry.value})');
  }
}
