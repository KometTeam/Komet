import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../core/cache/message_session_cache.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../core/utils/logger.dart';
import '../../../../main.dart';

class HistoryGap {
  HistoryGap({
    required this.edgeId,
    required this.edgeTime,
    required this.tailTime,
  });

  String edgeId;
  int edgeTime;
  final int tailTime;
}

class ChatController extends ChangeNotifier {
  static const int historyPageSize = 30;
  static const int historyInitialLimit = 50;
  static const int jumpWindowBefore = 40;
  static const int jumpWindowAfter = 20;
  static const int historyWalkPageSize = 200;
  static const int gapPageSize = 60;

  int chatId = 0;
  int myId = 0;

  List<CachedMessage> _messages = [];
  final Map<String, int> _indexById = {};

  List<CachedMessage> get messages => _messages;
  set messages(List<CachedMessage> v) {
    _messages = v;
    _reindexAll();
  }

  final ValueNotifier<int> messagesRev = ValueNotifier(0);

  void _reindexAll() {
    _indexById.clear();
    for (var i = 0; i < _messages.length; i++) {
      _indexById[_messages[i].id] = i;
    }
  }

  void _reindexFrom(int start) {
    for (var i = start; i < _messages.length; i++) {
      _indexById[_messages[i].id] = i;
    }
  }

  // #***! O(1) поиск вместо линейного скана по списку сообщений
  int indexOfId(String id) => _indexById[id] ?? -1;
  bool containsId(String id) => _indexById.containsKey(id);
  CachedMessage? byId(String id) {
    final i = _indexById[id];
    return i == null ? null : _messages[i];
  }

  void addMessage(CachedMessage msg) {
    _indexById[msg.id] = _messages.length;
    _messages.add(msg);
  }

  void removeMessageAt(int index) {
    final removedId = _messages[index].id;
    _messages.removeAt(index);
    _indexById.remove(removedId);
    _reindexFrom(index);
  }

  void setMessageAt(int index, CachedMessage msg) {
    final old = _messages[index];
    _messages[index] = msg;
    if (old.id != msg.id) _indexById.remove(old.id);
    _indexById[msg.id] = index;
  }

  bool hasMoreHistory = true;
  bool isLoadingMore = false;
  bool historyKickedOff = false;
  bool loadingGap = false;

  final List<HistoryGap> gaps = [];

  bool get hasGap => gaps.isNotEmpty;

  static bool gapFillLeavesViewportInPlace(
    HistoryGap gap,
    int? oldestRenderedTime,
  ) => oldestRenderedTime != null && oldestRenderedTime >= gap.tailTime;

  bool Function() isMounted = () => true;

  void bump() {
    messagesRev.value++;
  }

  int _tempIdCounter = 0;
  String nextTempId() =>
      'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> persistOutgoing(CachedMessage msg, {String? removeId}) async {
    try {
      if (removeId != null && removeId != msg.id) {
        await AppDatabase.deleteMessage(myId, chatId, removeId);
      }
      await AppDatabase.saveMessages([msg.toDbRow()]);
    } catch (_) {}
  }

  int prependOlder(List<CachedMessage> olderDesc) {
    if (olderDesc.isEmpty) return 0;
    final toAdd = <CachedMessage>[];
    final seenInBatch = <String>{};
    for (final m in olderDesc.reversed) {
      if (containsId(m.id) || !seenInBatch.add(m.id)) continue;
      toAdd.add(m);
    }
    if (toAdd.isEmpty) return 0;
    messages = [...toAdd, ...messages];
    messagesRev.value++;
    return toAdd.length;
  }

  bool mergeMessages(List<CachedMessage> decodedDesc) {
    final updates = <String, CachedMessage>{};
    for (final fresh in decodedDesc) {
      final old = byId(fresh.id);
      if (old == null || !_sameMessage(old, fresh)) {
        updates[fresh.id] = fresh;
      }
    }

    if (updates.isEmpty) return false;

    final merged = <CachedMessage>[
      for (final m in messages) updates[m.id] ?? m,
      for (final entry in updates.entries)
        if (!containsId(entry.key)) entry.value,
    ]..sort((a, b) {
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
    bool onlyVisible, {
    int? limit,
  }) async {
    final rows = await AppDatabase.loadMessagesBefore(
      myId,
      chatId,
      beforeTime: beforeTime,
      limit: limit ?? historyPageSize,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<List<CachedMessage>> loadGapSliceFromDb(
    int afterTime,
    int beforeTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesBetween(
      myId,
      chatId,
      afterTime: afterTime,
      beforeTime: beforeTime,
      limit: gapPageSize,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<List<CachedMessage>> loadWindowFromDb(
    int centerTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesAround(
      myId,
      chatId,
      centerTime: centerTime,
      before: jumpWindowBefore,
      after: jumpWindowAfter,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  Future<bool> loadMessageWindow({
    required String targetId,
    required int targetTime,
  }) async {
    if (myId == 0 || targetTime <= 0) return false;
    final onlyVisible = !KometSettings.viewDeleted.value;

    var window = await loadWindowFromDb(targetTime, onlyVisible);
    if (!isMounted()) return false;

    if (!window.any((m) => m.id == targetId)) {
      final fetched = await messagesModule.fetchHistory(
        myId,
        chatId,
        fromTime: targetTime + 1,
        forward: jumpWindowAfter,
        backward: jumpWindowBefore + 1,
      );
      if (!isMounted()) return false;
      if (fetched.isNotEmpty && KometSettings.viewDeleted.value) {
        await chats.reconcileDeletedFromFetch(myId, chatId, fetched);
      }
      window = await loadWindowFromDb(targetTime, onlyVisible);
      if (!isMounted()) return false;
    }

    if (window.isEmpty) return false;

    final oldestLoaded = messages.isEmpty ? 0 : messages.first.time;
    final reachesLoaded =
        messages.isEmpty || window.any((m) => m.time >= oldestLoaded);

    mergeMessages(window);

    if (reachesLoaded) {
      persistSessionCache();
    } else {
      _markGapAfterWindow(window);
    }
    return containsId(targetId);
  }

  void _markGapAfterWindow(List<CachedMessage> window) {
    var edge = window.first;
    for (final m in window) {
      if (m.time > edge.time) edge = m;
    }
    final idx = indexOfId(edge.id);
    if (idx == -1 || idx + 1 >= messages.length) return;
    final tailTime = messages[idx + 1].time;
    gaps.removeWhere((g) => g.tailTime == tailTime);
    gaps.add(
      HistoryGap(edgeId: edge.id, edgeTime: edge.time, tailTime: tailTime),
    );
  }

  void _closeGap(HistoryGap gap) {
    gaps.remove(gap);
    if (gaps.isEmpty) persistSessionCache();
  }

  Future<int> fillGapForward(
    HistoryGap gap, {
    void Function()? beforeApply,
  }) async {
    if (loadingGap || myId == 0 || !gaps.contains(gap)) return 0;
    if (gap.edgeTime <= 0 || gap.tailTime <= gap.edgeTime) {
      _closeGap(gap);
      return 0;
    }

    loadingGap = true;
    try {
      final onlyVisible = !KometSettings.viewDeleted.value;
      var slice = await loadGapSliceFromDb(
        gap.edgeTime,
        gap.tailTime,
        onlyVisible,
      );
      if (!isMounted()) return 0;

      if (slice.length < gapPageSize) {
        final fetched = await messagesModule.fetchHistory(
          myId,
          chatId,
          fromTime: gap.edgeTime,
          forward: gapPageSize,
          backward: 0,
        );
        if (!isMounted()) return 0;
        if (fetched.isNotEmpty && KometSettings.viewDeleted.value) {
          await chats.reconcileDeletedFromFetch(myId, chatId, fetched);
        }
        final refreshed = await loadGapSliceFromDb(
          gap.edgeTime,
          gap.tailTime,
          onlyVisible,
        );
        if (!isMounted()) return 0;
        if (refreshed.length <= slice.length) {
          if (refreshed.isNotEmpty) {
            beforeApply?.call();
            mergeMessages(refreshed);
          }
          _closeGap(gap);
          return refreshed.length;
        }
        slice = refreshed;
      }

      if (slice.isEmpty) {
        _closeGap(gap);
        return 0;
      }

      beforeApply?.call();
      mergeMessages(slice);

      var edge = slice.first;
      for (final m in slice) {
        if (m.time > edge.time) edge = m;
      }
      gap.edgeId = edge.id;
      gap.edgeTime = edge.time;
      if (edge.time >= gap.tailTime) _closeGap(gap);
      return slice.length;
    } catch (e) {
      logger.e('Error filling history gap: $e');
      return 0;
    } finally {
      loadingGap = false;
    }
  }

  void persistSessionCache() {
    if (myId == 0 || messages.isEmpty || hasGap) return;
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
    int? pageSize,
    bool persist = true,
  }) async {
    if (isLoadingMore || !hasMoreHistory || messages.isEmpty) return;
    isLoadingMore = true;
    onLoadingStarted();

    final size = pageSize ?? historyPageSize;
    final oldest = messages.first;
    final onlyVisible = !KometSettings.viewDeleted.value;

    try {
      var older = await loadOlderFromDb(oldest.time, onlyVisible, limit: size);

      if (older.length < size) {
        final fetched = await messagesModule.fetchHistory(
          myId,
          chatId,
          fromTime: oldest.time,
          count: size,
        );
        if (fetched.isNotEmpty) {
          if (KometSettings.viewDeleted.value) {
            await chats.reconcileDeletedFromFetch(myId, chatId, fetched);
          }
          older = await loadOlderFromDb(oldest.time, onlyVisible, limit: size);
        }
      }

      if (!isMounted()) return;
      final added = prependOlder(older);
      isLoadingMore = false;
      if (added == 0) hasMoreHistory = false;
      if (persist) persistSessionCache();
      onLoaded(added);
    } catch (e) {
      logger.e('Error loading more history: $e');
      onError(e);
    }
  }

  // #***! дешёвое локальное чтение — не ждём анимацию перехода, красим
  // сообщения из БД сразу же, ещё до сетевых частей ниже
  Future<List<CachedMessage>> loadLocalHistory({
    required void Function(List<CachedMessage> decoded, {bool markLoaded})
    onApplyMerged,
  }) async {
    final onlyVisible = !KometSettings.viewDeleted.value;
    final fullDecoded = await loadInitialFromDb(onlyVisible: onlyVisible);
    if (isMounted()) {
      onApplyMerged(fullDecoded);
    }
    return fullDecoded;
  }

  Future<void> loadRemainingHistory({
    required List<CachedMessage> localDecoded,
    required void Function(List<CachedMessage> decoded, {bool markLoaded})
    onApplyMerged,
    required void Function() onLoadingFinished,
    required void Function() onPreview,
    required void Function() onSenderNames,
  }) async {
    final onlyVisible = !KometSettings.viewDeleted.value;
    final cachedRows = await AppDatabase.loadChat(myId, chatId);
    final preview =
        cachedRows.isEmpty || !AppDatabase.chatRowIsInList(cachedRows.first);
    if (preview) {
      onPreview();
      if (cachedRows.isEmpty) {
        await chats.ensureChatCached(api, myId, chatId);
      }
      await chats.subscribeChat(api, chatId);
    }

    final fullDecoded = localDecoded;

    if (fullDecoded.isNotEmpty && chats.wasHistoryFetched(chatId)) {
      if (isMounted()) {
        onLoadingFinished();
      }
      onSenderNames();
      return;
    }

    try {
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
