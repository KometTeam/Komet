import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const _dir = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

const _sizes = {
  'app_icon_16.png': 16,
  'app_icon_32.png': 32,
  'app_icon_64.png': 64,
  'app_icon_128.png': 128,
  'app_icon_256.png': 256,
  'app_icon_512.png': 512,
  'app_icon_1024.png': 1024,
};

void main() {
  final source = img.decodePng(File('assets/meteor_icon.png').readAsBytesSync()) ??
      img.decodePng(File('$_dir/app_icon_1024.png').readAsBytesSync())!;

  const canvas = 1024;
  const content = 824;
  const margin = (canvas - content) / 2;
  const radius = 184.0;

  final body = img.copyResize(source,
      width: content, height: content, interpolation: img.Interpolation.cubic);

  final master = img.Image(width: canvas, height: canvas, numChannels: 4);
  img.compositeImage(master, body, dstX: margin.toInt(), dstY: margin.toInt());

  _applyRoundedMask(master, margin, margin, margin + content, margin + content, radius);

  for (final entry in _sizes.entries) {
    final out = img.copyResize(master,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.cubic);
    File('$_dir/${entry.key}').writeAsBytesSync(img.encodePng(out));
    stdout.writeln('wrote ${entry.key} (${entry.value}x${entry.value})');
  }
}

void _applyRoundedMask(
    img.Image im, double x0, double y0, double x1, double y1, double r) {
  final cx = (x0 + x1) / 2;
  final cy = (y0 + y1) / 2;
  final hw = (x1 - x0) / 2;
  final hh = (y1 - y0) / 2;
  for (final p in im) {
    final qx = (p.x + 0.5 - cx).abs() - (hw - r);
    final qy = (p.y + 0.5 - cy).abs() - (hh - r);
    final dx = math.max(qx, 0.0);
    final dy = math.max(qy, 0.0);
    final dist =
        math.sqrt(dx * dx + dy * dy) + math.min(math.max(qx, qy), 0.0) - r;
    final coverage = (0.5 - dist).clamp(0.0, 1.0);
    if (coverage < 1.0) {
      p.a = (p.a * coverage).round().clamp(0, 255);
    }
  }
}
