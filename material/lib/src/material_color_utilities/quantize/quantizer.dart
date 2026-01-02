import 'quantizer_result.dart';

abstract interface class Quantizer {
  QuantizerResult quantize(List<int> pixels, int maxColors);
}
