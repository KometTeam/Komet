import 'quantizer.dart';
import 'quantizer_result.dart';
import 'quantizer_wsmeans.dart';
import 'quantizer_wu.dart';

final class QuantizerCelebi implements Quantizer {
  const QuantizerCelebi();

  @override
  QuantizerResult quantize(List<int> pixels, int maxColors) {
    final wu = QuantizerWu();
    final wuResult = wu.quantize(pixels, maxColors);
    final wuClusters = wuResult.colorToCount.keys.toList();
    const wsmeans = QuantizerWsmeans();
    return wsmeans.quantize(pixels, maxColors, startingClusters: wuClusters);
  }
}
