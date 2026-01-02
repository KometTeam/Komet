import 'quantizer.dart';
import 'quantizer_result.dart';

final class QuantizerMap implements Quantizer {
  const QuantizerMap();

  @override
  QuantizerResult quantize(List<int> pixels, int maxColors) {
    final pixelByCount = <int, int>{};
    for (final pixel in pixels) {
      pixelByCount.update(
        pixel,
        (currentPixelCount) => currentPixelCount + 1,
        ifAbsent: () => 1,
      );
    }
    return QuantizerResult(colorToCount: pixelByCount);
  }
}
