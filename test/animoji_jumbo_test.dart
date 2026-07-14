import 'package:flutter_test/flutter_test.dart';

import 'package:komet/core/utils/text_format.dart';

FormatRange _animoji(int start, int length, String url) => FormatRange(
  format: TextFormat.animoji,
  start: start,
  length: length,
  attributes: {'animojiLottieUrl': url},
);

void main() {
  test('single animoji-only message is jumbo', () {
    expect(animojiOnlyLottieUrls('❤️', [_animoji(0, 2, 'L1')]), ['L1']);
  });

  test('several animoji with no other text are jumbo, in order', () {
    final urls = animojiOnlyLottieUrls('❤️🔥', [
      _animoji(2, 2, 'L2'),
      _animoji(0, 2, 'L1'),
    ]);
    expect(urls, ['L1', 'L2']);
  });

  test('animoji mixed with real text is NOT jumbo', () {
    expect(
      animojiOnlyLottieUrls('animoji message🤣', [_animoji(15, 2, 'L1')]),
      isNull,
    );
  });

  test('plain emoji without an ANIMOJI element is NOT jumbo', () {
    expect(animojiOnlyLottieUrls('😀', const []), isNull);
  });

  test('more than the limit is NOT jumbo', () {
    final ranges = [
      for (var i = 0; i < 5; i++) _animoji(i * 2, 2, 'L$i'),
    ];
    expect(animojiOnlyLottieUrls('❤️❤️❤️❤️❤️', ranges), isNull);
  });

  test('whitespace between animoji is allowed', () {
    expect(
      animojiOnlyLottieUrls('❤️ ❤️', [_animoji(0, 2, 'L1'), _animoji(3, 2, 'L2')]),
      ['L1', 'L2'],
    );
  });
}
