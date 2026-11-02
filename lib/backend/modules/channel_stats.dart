import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/utils/logger.dart';

class ChannelStats {
  const ChannelStats._();

  static const int maxBatch = 100;

  static Future<Map<String, int>?> views(
    Api api,
    int chatId,
    List<String> messageIds, {
    required bool countView,
  }) async {
    final payload = requestPayload(chatId, messageIds, countView: countView);
    if ((payload['messageIds'] as List).isEmpty) return const {};
    try {
      final packet = await api.sendRequest(
        Opcode.msgGetStat,
        payload,
        silent: true,
      );
      return packet.isOk ? parseViews(packet.payload) : null;
    } on PacketError catch (e) {
      logger.w('ChannelStats.views refused: $e');
      return null;
    } catch (e) {
      logger.w('ChannelStats.views: $e');
      return const {};
    }
  }

  static Map<String, Object> requestPayload(
    int chatId,
    List<String> messageIds, {
    required bool countView,
  }) => {
    'chatId': chatId,
    'messageIds': [
      for (final id in messageIds) ?int.tryParse(id),
    ].take(maxBatch).toList(),
    if (!countView) 'readOnly': true,
  };

  static Map<String, int> parseViews(Object? payload) {
    final stats = payload is Map ? payload['stats'] : null;
    if (stats is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in stats.entries)
        if (value is Map && value['views'] is int)
          key.toString(): value['views'] as int,
    };
  }
}
