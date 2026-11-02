import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/channel_stats.dart';
import 'package:komet/backend/modules/channel_suggestions.dart';
import 'package:komet/core/utils/format.dart';

const int _channelId = -900601;

Map<String, Object?> _channel(int id, {String type = 'CHANNEL'}) => {
  'id': id,
  'type': type,
  'title': 'Синтетический канал $id',
  'baseIconUrl': 'https://example.test/icon/$id.png',
  'link': 'https://example.test/channel_$id',
  'participantsCount': 3663,
};

void main() {
  group('views', () {
    test('ask with numeric ids the way the server validates them', () {
      final payload = ChannelStats.requestPayload(_channelId, [
        '115000000000000001',
        'temp_1_1700000000000',
        '900701',
      ], countView: true);

      expect(payload, {
        'chatId': _channelId,
        'messageIds': [115000000000000001, 900701],
      });
    });

    test('only read the counters when the view must not count', () {
      final payload = ChannelStats.requestPayload(_channelId, [
        '900701',
      ], countView: false);

      expect(payload['readOnly'], isTrue);
    });

    test('never ask for more than the server accepts at once', () {
      final payload = ChannelStats.requestPayload(_channelId, [
        for (var i = 0; i < ChannelStats.maxBatch + 20; i++) '${900000 + i}',
      ], countView: true);

      expect(payload['messageIds'], hasLength(ChannelStats.maxBatch));
    });

    test('are read per message id from the stats map', () {
      expect(
        ChannelStats.parseViews({
          'stats': {
            '900701': {'views': 8948},
            '900702': {'views': 0},
            '900703': {'reactions': 4},
          },
        }),
        {'900701': 8948, '900702': 0},
      );
    });

    test('an unexpected answer gives no views', () {
      expect(ChannelStats.parseViews(null), isEmpty);
      expect(ChannelStats.parseViews({'stats': 'nope'}), isEmpty);
    });
  });

  group('recommendations', () {
    test('keep channels with a link and drop the current one', () {
      final channels = ChannelSuggestions.parse({
        'chats': [
          _channel(_channelId),
          _channel(-900602),
          _channel(-900603, type: 'CHAT'),
          {..._channel(-900604), 'link': null},
          _channel(-900605),
        ],
        'recomId': 'synthetic',
      }, exclude: _channelId);

      expect(channels.map((c) => c.id), [-900602, -900605]);
      expect(channels.first.title, 'Синтетический канал -900602');
      expect(channels.first.subscribers, 3663);
      expect(channels.first.iconUrl, 'https://example.test/icon/-900602.png');
    });

    test('an unexpected answer gives no channels', () {
      expect(ChannelSuggestions.parse(null, exclude: _channelId), isEmpty);
    });
  });

  test('counts are shortened the way MAX shows them', () {
    expect(formatCompactCount(623), '623');
    expect(formatCompactCount(1000), '1K');
    expect(formatCompactCount(3663), '3,7K');
    expect(formatCompactCount(8948), '8,9K');
    expect(formatCompactCount(129812), '129,8K');
    expect(formatCompactCount(175155), '175,2K');
    expect(formatCompactCount(999950), '1M');
    expect(formatCompactCount(2450000), '2,5M');
  });
}
