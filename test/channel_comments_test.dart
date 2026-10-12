import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/channel_comments.dart';

void main() {
  group('commentsInfoBatches', () {
    test('splits long histories into bounded requests', () {
      final ids = [for (var i = 0; i < 120; i++) '$i'];
      final batches = commentsInfoBatches(ids);
      expect(batches.map((b) => b.length), [50, 50, 20]);
      expect(batches.expand((b) => b).toList(), ids);
    });

    test('short lists stay in one request', () {
      expect(commentsInfoBatches(['1', '2']), [
        ['1', '2'],
      ]);
      expect(commentsInfoBatches(const []), isEmpty);
    });
  });
}
