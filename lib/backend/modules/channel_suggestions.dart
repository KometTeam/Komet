import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/utils/logger.dart';
import '../../models/suggested_channel.dart';

class ChannelSuggestions {
  const ChannelSuggestions._();

  static const int _ownChannelsLimit = 20;
  static const Duration _freshFor = Duration(minutes: 30);
  static final Map<
    ({int account, int chat}),
    ({DateTime at, List<SuggestedChannel> channels})
  >
  _recent = {};

  static Future<List<SuggestedChannel>> forChannel(
    Api api,
    int chatId, {
    required int accountId,
    required Iterable<int> ownChannelIds,
  }) async {
    final own = {...ownChannelIds}..remove(chatId);
    final key = (account: accountId, chat: chatId);
    final now = DateTime.now();
    _recent.removeWhere((_, entry) => now.difference(entry.at) >= _freshFor);
    final channels =
        _recent[key]?.channels ?? await _request(api, chatId, own, key);
    return [
      for (final channel in channels)
        if (!own.contains(channel.id)) channel,
    ];
  }

  static Future<List<SuggestedChannel>> _request(
    Api api,
    int chatId,
    Set<int> own,
    ({int account, int chat}) key,
  ) async {
    try {
      final packet = await api.sendRequest(Opcode.chatSuggest, {
        'chatId': chatId,
        'userChatIds': [chatId, ...own.take(_ownChannelsLimit)],
      }, silent: true);
      final channels = parse(
        packet.isOk ? packet.payload : null,
        exclude: chatId,
      );
      if (channels.isNotEmpty) {
        _recent[key] = (at: DateTime.now(), channels: channels);
      }
      return channels;
    } catch (e) {
      logger.w('ChannelSuggestions.forChannel: $e');
      return const [];
    }
  }

  static List<SuggestedChannel> parse(Object? payload, {required int exclude}) {
    final chats = payload is Map ? payload['chats'] : null;
    if (chats is! List) return const [];
    return [
      for (final raw in chats)
        if (SuggestedChannel.fromServer(raw) case final channel?
            when channel.id != exclude)
          channel,
    ];
  }
}
