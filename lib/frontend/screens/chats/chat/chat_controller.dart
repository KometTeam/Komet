import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../core/cache/message_session_cache.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../core/utils/logger.dart';
import '../../../../main.dart';

class ChatController extends ChangeNotifier {
  static const int historyPageSize = 30;
  static const int historyInitialLimit = 50;

  int chatId = 0;
  int myId = 0;

  List<CachedMessage> messages = [];
  final ValueNotifier<int> messagesRev = ValueNotifier(0);

  bool hasMoreHistory = true;
  bool isLoadingMore = false;
  bool historyKickedOff = false;

  bool Function() isMounted = () => true;

  void bump() {
    messagesRev.value++;
  }

  int prependOlder(List<CachedMessage> olderDesc) {
    if (olderDesc.isEmpty) return 0;
    final existing = messages.map((m) => m.id).toSet();
    final toAdd = <CachedMessage>[];
    for (final m in olderDesc.reversed) {
      if (existing.add(m.id)) toAdd.add(m);
    }
    if (toAdd.isEmpty) return 0;
    messages = [...toAdd, ...messages];
    messagesRev.value++;
    return toAdd.length;
  }

  bool mergeMessages(List<CachedMessage> decodedDesc) {
    final byId = <String, CachedMessage>{for (final m in messages) m.id: m};
    var changed = false;
    for (final fresh in decodedDesc) {
      final old = byId[fresh.id];
      if (old == null) {
        byId[fresh.id] = fresh;
        changed = true;
      } else if (!_sameMessage(old, fresh)) {
        byId[fresh.id] = fresh;
        changed = true;
      }
    }

    if (!changed) return false;

    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    messages = merged;
    messagesRev.value++;
    return true;
  }

  bool _sameMessage(CachedMessage a, CachedMessage b) {
    return a.id == b.id &&
        a.time == b.time &&
        a.status == b.status &&
        a.text == b.text &&
        a.senderId == b.senderId &&
        a.deleted == b.deleted;
  }

  Future<List<CachedMessage>> loadInitialFromDb({
    required bool onlyVisible,
  }) async {
    final rows = await AppDatabase.loadMessages(
      myId,
      chatId,
      limit: historyInitialLimit,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<List<CachedMessage>> loadOlderFromDb(
    int beforeTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesBefore(
      myId,
      chatId,
      beforeTime: beforeTime,
      limit: historyPageSize,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  void persistSessionCache() {
    if (myId == 0 || messages.isEmpty) return;
    MessageSessionCache.save(
      myId,
      chatId,
      messages,
      reachedStart: !hasMoreHistory,
    );
  }

  Future<void> loadMoreHistory({
    required void Function() onLoadingStarted,
    required void Function(int added) onLoaded,
    required void Function(Object error) onError,
  }) async {
    if (isLoadingMore || !hasMoreHistory || messages.isEmpty) return;
    isLoadingMore = true;
    onLoadingStarted();

    final oldest = messages.first;
    final onlyVisible = !KometSettings.viewDeleted.value;

    try {
      var older = await loadOlderFromDb(oldest.time, onlyVisible);

      if (older.length < historyPageSize) {
        final fetched = await messagesModule.fetchHistory(
          myId,
          chatId,
          fromTime: oldest.time,
          count: historyPageSize,
        );
        if (fetched.isNotEmpty) {
          if (KometSettings.viewDeleted.value) {
            await chats.reconcileDeletedFromFetch(myId, chatId, fetched);
          }
          older = await loadOlderFromDb(oldest.time, onlyVisible);
        }
      }

      if (!isMounted()) return;
      final added = prependOlder(older);
      isLoadingMore = false;
      if (added == 0) hasMoreHistory = false;
      persistSessionCache();
      onLoaded(added);
    } catch (e) {
      logger.e('Error loading more history: $e');
      onError(e);
    }
  }

  Future<void> loadRemainingHistory({
    required void Function(List<CachedMessage> decoded, {bool markLoaded})
    onApplyMerged,
    required void Function() onLoadingFinished,
    required void Function() onPreview,
    required void Function() onSenderNames,
  }) async {
    final onlyVisible = !KometSettings.viewDeleted.value;
    final fullDecoded = await loadInitialFromDb(onlyVisible: onlyVisible);
    if (isMounted()) {
      onApplyMerged(fullDecoded);
    }

    if (fullDecoded.isNotEmpty && chats.wasHistoryFetched(chatId)) {
      if (isMounted()) {
        onLoadingFinished();
      }
      onSenderNames();
      return;
    }

    try {
      final cachedRows = await AppDatabase.loadChat(myId, chatId);
      if (cachedRows.isEmpty) {
        onPreview();
        await chats.ensureChatCached(api, myId, chatId);
        await chats.subscribeChat(api, chatId);
      }
      final serverMessages = await messagesModule.fetchHistory(myId, chatId);
      chats.markHistoryFetched(chatId);
      if (KometSettings.viewDeleted.value) {
        await chats.reconcileDeletedFromFetch(myId, chatId, serverMessages);
      }
      final updatedDecoded = await loadInitialFromDb(onlyVisible: onlyVisible);
      if (isMounted()) {
        onApplyMerged(updatedDecoded, markLoaded: true);
      }
      unawaited(chats.reconcileLastMessageIfPlaceholder(myId, chatId));
      onSenderNames();
    } catch (e) {
      logger.e('Error fetching history: $e');
      if (isMounted()) {
        onLoadingFinished();
      }
    }
  }

  @override
  void dispose() {
    messagesRev.dispose();
    super.dispose();
  }
}
