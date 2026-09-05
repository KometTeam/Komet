import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

const _dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _size = 1024;

const _variants = {
  'dark': 'Icon-App-Dark-1024x1024@1x.png',
  'tinted': 'Icon-App-Tinted-1024x1024@1x.png',
};

void main() {
  final src = img.decodePng(File('assets/komet.png').readAsBytesSync())!;
  final dark = img.copyResize(src,
      width: _size, height: _size, interpolation: img.Interpolation.cubic);
  _write(_variants['dark']!, dark);
  _write(_variants['tinted']!, _normalized(img.grayscale(dark)));
  _registerVariants();
}

img.Image _normalized(img.Image src) {
  var peak = 0;
  for (final pixel in src) {
    if (pixel.a < 8) continue;
    if (pixel.r > peak) peak = pixel.r.toInt();
  }
  if (peak == 0 || peak == 255) return src;
  final gain = 255 / peak;
  for (final pixel in src) {
    final value = (pixel.r * gain).round().clamp(0, 255);
    pixel.setRgb(value, value, value);
  }
  return src;
}

void _write(String name, img.Image image) {
  File('$_dir/$name').writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote $_dir/$name (${image.width}x${image.height})');
}

void _registerVariants() {
  final file = File('$_dir/Contents.json');
  final contents = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final images = (contents['images'] as List).cast<Map<String, dynamic>>();
  images.removeWhere((entry) => entry.containsKey('appearances'));
  for (final variant in _variants.entries) {
    images.add({
      'size': '${_size}x$_size',
      'idiom': 'universal',
      'platform': 'ios',
      'filename': variant.value,
      'appearances': [
        {'appearance': 'luminosity', 'value': variant.key},
      ],
    });
  }
  file.writeAsStringSync(jsonEncode(contents));
  stdout.writeln('registered ${_variants.length} appearances in ${file.path}');
}
