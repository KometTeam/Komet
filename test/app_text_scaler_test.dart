import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_fonts.dart';

void main() {
  test(
    'the slider multiplies the system font size instead of replacing it',
    () {
      const system = TextScaler.linear(1.3);
      expect(const AppTextScaler(system, 1.0).scale(10), closeTo(13, 1e-9));
      expect(const AppTextScaler(system, 1.1).scale(10), closeTo(14.3, 1e-9));
      expect(const AppTextScaler(system, 0.9).scale(10), closeTo(11.7, 1e-9));
    },
  );

  test('a bigger slider value always means bigger text', () {
    const system = TextScaler.linear(1.3);
    final sizes = [
      for (var f = AppFonts.minScale; f <= AppFonts.maxScale; f += 0.05)
        AppTextScaler(system, f).scale(16),
    ];
    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], greaterThan(sizes[i - 1]));
    }
  });

  test('equal settings compare equal so cached layouts survive rebuilds', () {
    const a = AppTextScaler(TextScaler.linear(1.2), 1.05);
    const b = AppTextScaler(TextScaler.linear(1.2), 1.05);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == const AppTextScaler(TextScaler.linear(1.2), 1.1), isFalse);
  });
}
