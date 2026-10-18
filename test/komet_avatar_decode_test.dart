import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';

void main() {
  test('размер декодирования аватарки идёт ступенями и не меньше нужного', () {
    var previous = 0;
    var changes = 0;
    for (var size = 20.0; size <= 200; size += 0.5) {
      final decode = KometAvatar.decodeSizeFor(size);
      expect(decode, greaterThanOrEqualTo((size * 3).round()));
      expect(decode, greaterThanOrEqualTo(previous));
      if (decode != previous) changes++;
      previous = decode;
    }
    expect(changes, lessThan(10));
  });
}
