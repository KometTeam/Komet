import 'package:flutter/foundation.dart';

import '../../../../core/config/komet_settings.dart';
import '../../../../models/suggested_channel.dart';

enum SuggestedChannelState { idle, joining, joined }

class ChannelRecommendations extends ChangeNotifier {
  ChannelRecommendations({
    required this.chatId,
    required Future<List<SuggestedChannel>> Function() fetch,
    required Future<void> Function(SuggestedChannel channel) join,
  }) : _fetch = fetch,
       _join = join {
    KometSettings.hideChannelRecommendations.addListener(notifyListeners);
    KometSettings.recommendationsHiddenIn.addListener(notifyListeners);
  }

  final int chatId;
  final Future<List<SuggestedChannel>> Function() _fetch;
  final Future<void> Function(SuggestedChannel channel) _join;
  final Map<int, SuggestedChannelState> _states = {};
  List<SuggestedChannel> _channels = const [];
  bool _requested = false;
  bool _disposed = false;

  List<SuggestedChannel> get channels => _channels;

  bool get allowed =>
      !KometSettings.hideChannelRecommendations.value &&
      !KometSettings.recommendationsHiddenIn.value.contains(chatId);

  bool get visible => allowed && _channels.isNotEmpty;

  SuggestedChannelState stateOf(SuggestedChannel channel) =>
      _states[channel.id] ?? SuggestedChannelState.idle;

  Future<void> load() async {
    if (_requested || !allowed) return;
    _requested = true;
    final channels = await _fetch();
    if (_disposed || channels.isEmpty) return;
    _channels = channels;
    notifyListeners();
  }

  Future<void> hide() => KometSettings.hideRecommendationsIn(chatId);

  Future<void> join(SuggestedChannel channel) async {
    if (stateOf(channel) != SuggestedChannelState.idle) return;
    _setState(channel, SuggestedChannelState.joining);
    try {
      await _join(channel);
      _setState(channel, SuggestedChannelState.joined);
    } catch (_) {
      _setState(channel, SuggestedChannelState.idle);
      rethrow;
    }
  }

  void _setState(SuggestedChannel channel, SuggestedChannelState state) {
    if (_disposed) return;
    _states[channel.id] = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    KometSettings.hideChannelRecommendations.removeListener(notifyListeners);
    KometSettings.recommendationsHiddenIn.removeListener(notifyListeners);
    super.dispose();
  }
}
