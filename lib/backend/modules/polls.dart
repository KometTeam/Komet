import 'package:flutter/foundation.dart';

import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/utils/logger.dart';
import '../../models/poll.dart';

class PollsModule extends ChangeNotifier {
  final Api _api;

  PollsModule(this._api);

  final Map<int, Poll> _cache = {};
  final Set<int> _inFlight = {};

  Poll? get(int pollId) => _cache[pollId];

  Future<void> fetch(
    int chatId,
    String messageId,
    int pollId, {
    bool force = false,
  }) async {
    if (pollId == 0) return;
    if (!force && (_cache.containsKey(pollId) || _inFlight.contains(pollId))) {
      return;
    }
    _inFlight.add(pollId);
    try {
      final mid = int.tryParse(messageId) ?? 0;
      final response = await _api.sendRequest(Opcode.getPollUpdates, {
        'chatId': chatId,
        'polls': [
          {'messageId': mid, 'pollId': pollId},
        ],
      });
      if (!response.isOk) return;

      final data = response.payload;
      if (data is! Map) return;

      final polls = data['polls'];
      if (polls is! List) return;

      var changed = false;
      for (final p in polls) {
        if (p is Map) {
          final poll = Poll.fromServerMap(p);
          if (poll.pollId != 0) {
            _cache[poll.pollId] = poll;
            changed = true;
          }
        }
      }
      if (changed) notifyListeners();
    } catch (e) {
      logger.w('PollsModule.fetch: pollId=$pollId chatId=$chatId $e');
    } finally {
      _inFlight.remove(pollId);
    }
  }

  Future<bool> vote(
    int chatId,
    String messageId,
    int pollId,
    List<int> answersIds,
  ) async {
    try {
      final response = await _api.sendRequest(Opcode.sendVote, {
        'messageId': int.tryParse(messageId) ?? 0,
        'chatId': chatId,
        'pollId': pollId,
        'answersIds': answersIds,
      });
      if (!response.isOk) return false;

      final data = response.payload;
      final state = data is Map ? data['state'] : null;
      final cached = _cache[pollId];
      if (state is Map && cached != null) {
        _cache[pollId] = cached.withStateMap(state);
        notifyListeners();
      } else {
        await fetch(chatId, messageId, pollId, force: true);
      }
      return true;
    } catch (e) {
      logger.w('PollsModule.vote: pollId=$pollId chatId=$chatId $e');
      return false;
    }
  }
}
