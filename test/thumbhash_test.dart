import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:komet/core/media/thumbhash.dart';

List<int> _flatHash() => [
  0x3F,
  0x08,
  0x02,
  0x05,
  0x00,
  ...List<int>.filled(20, 0x77),
];

void main() {
  test('a hash without detail decodes to one flat colour', () {
    final decoded = thumbHashToRgba(_flatHash())!;
    expect(decoded.width, 23);
    expect(decoded.height, 32);
    for (var i = 0; i < decoded.rgba.length; i += 4) {
      expect(decoded.rgba.sublist(i, i + 4), [255, 254, 252, 255]);
    }
  });

  test('the png keeps the decoded size and pixels', () {
    final png = thumbHashToPng(_flatHash())!;
    final image = img.decodePng(png)!;
    expect(image.width, 23);
    expect(image.height, 32);
    final pixel = image.getPixel(11, 20);
    expect([pixel.r, pixel.g, pixel.b, pixel.a], [255, 254, 252, 255]);
  });

  test('truncated hashes are rejected instead of throwing', () {
    expect(thumbHashToRgba(const [0x3F, 0x08]), isNull);
    expect(thumbHashToRgba(_flatHash().sublist(0, 9)), isNull);
  });
}
