import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/webapp.dart';

void main() {
  group('ExternalCallbackResult', () {
    test('parses callback response fields', () {
      final result = ExternalCallbackResult.fromPayload({
        'botId': '123456',
        'startParam': 'esia-complete',
      });

      expect(result?.botId, 123456);
      expect(result?.startParam, 'esia-complete');
    });

    test('parses a nested protocol response', () {
      final result = ExternalCallbackResult.fromPayload({
        'data': {'bot_id': 42, 'start_param': 'done'},
      });

      expect(result?.botId, 42);
      expect(result?.startParam, 'done');
    });

    test('rejects a response without a bot id', () {
      expect(
        ExternalCallbackResult.fromPayload({
          'data': {'startParam': 'done'},
        }),
        isNull,
      );
    });
  });
}
