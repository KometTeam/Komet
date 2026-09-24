import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../backend/modules/pending_message_deletions.dart';
import '../../../../core/cache/message_session_cache.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../core/storage/message_ranges.dart';
import '../../../../core/utils/logger.dart';
import '../../../../main.dart';

enum WindowLoad { missing, merged, replaced }

class ChatController extends ChangeNotifier {
  static const int historyPageSize = 30;
  static const int historyInitialLimit = 50;
  static const int jumpWindowBefore = 40;
  static const int jumpWindowAfter = 20;
  static const int historyWalkPageSize = 200;
  static const int newerPageSize = 60;
  static const int _endOfTime = 1 << 62;

  ChatController() {
    _restoredSub = PendingMessageDeletions.instance.restored.listen(
      _onRestored,
    );
  }

  int chatId = 0;
  int myId = 0;

  late final StreamSubscription<RestoredMessages> _restoredSub;
  List<CachedMessage> _messages = [];
  final Map<String, int> _indexById = {};

  List<CachedMessage> get messages => _messages;
  set messages(List<CachedMessage> v) {
    _messages = _withoutPendingDeletions(v);
    _reindexAll();
  }

  bool _isPendingDeletion(CachedMessage m) =>
      PendingMessageDeletions.instance.isPending(chatId, m.id);

  List<CachedMessage> _withoutPendingDeletions(List<CachedMessage> list) {
    if (!list.any(_isPendingDeletion)) return list;
    return list.where((m) => !_isPendingDeletion(m)).toList();
  }

  void _onRestored(RestoredMessages restored) {
    if (restored.chatId != chatId) return;
    mergeMessages(restored.messages, contiguous: true);
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
    if (_isPendingDeletion(msg)) return;
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
  bool hasNewer = false;
  bool isLoadingNewer = false;
  int _newerStalledAt = -1;
  bool latestCovered = false;

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

  bool mergeMessages(
    List<CachedMessage> decodedDesc, {
    bool contiguous = false,
  }) {
    final newestLoaded = hasNewer && !contiguous && messages.isNotEmpty
        ? messages.last.time
        : null;
    final updates = <String, CachedMessage>{};
    for (final fresh in decodedDesc) {
      final old = byId(fresh.id);
      if (old == null && newestLoaded != null && fresh.time > newestLoaded) {
        continue;
      }
      if (old == null || !_sameMessage(old, fresh)) {
        updates[fresh.id] = fresh;
      }
    }

    if (updates.isEmpty) return false;

    messages = _sorted([
      for (final m in messages) updates[m.id] ?? m,
      for (final entry in updates.entries)
        if (!containsId(entry.key)) entry.value,
    ]);
    messagesRev.value++;
    return true;
  }

  static List<CachedMessage> _sorted(List<CachedMessage> list) =>
      list..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

  bool _sameMessage(CachedMessage a, CachedMessage b) {
    return a.id == b.id &&
        a.time == b.time &&
        a.status == b.status &&
        a.text == b.text &&
        a.senderId == b.senderId &&
        a.deleted == b.deleted &&
        a.editHistory?.length == b.editHistory?.length;
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
    final ranges = await AppDatabase.loadMessageRanges(myId, chatId);
    final latest = await CachedMessage.fromDbRowsAsync(rows);
    latestCovered =
        latest.isNotEmpty &&
        ranges.coversNewest(latest.map((m) => m.time).reduce(_max));
    return ranges.clipLatest(latest, _timeOf);
  }

  static int _timeOf(CachedMessage m) => m.time;
  static int _max(int a, int b) => a > b ? a : b;
  static List<int> _timesOf(List<CachedMessage> list) => [
    for (final m in list) m.time,
  ];

  Future<void> _fetchQuietly(
    int? fromTime, {
    int forward = 0,
    int? backward,
    int count = historyPageSize,
  }) async {
    try {
      final fetched = await messagesModule.fetchHistory(
        myId,
        chatId,
        fromTime: fromTime,
        forward: forward,
        backward: backward,
        count: count,
      );
      if (fetched.isNotEmpty && KometSettings.viewDeleted.value) {
        await chats.reconcileDeletedFromFetch(myId, chatId, fetched);
      }
    } catch (e) {
      logger.w('Error fetching history page: $e');
    }
  }

  bool pruneUncovered(MessageRanges ranges) {
    if (hasNewer) return false;
    final range = ranges.newest;
    if (range == null) return false;
    final kept = [
      for (final m in messages)
        if (m.time >= range.start || m.id.startsWith('temp_')) m,
    ];
    if (kept.length == messages.length) return false;
    messages = kept;
    hasMoreHistory = true;
    messagesRev.value++;
    return true;
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

  Future<List<CachedMessage>> loadNewerFromDb(
    int afterTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesBetween(
      myId,
      chatId,
      afterTime: afterTime,
      beforeTime: _endOfTime,
      limit: newerPageSize,
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

  Future<WindowLoad> loadMessageWindow({
    required String targetId,
    required int targetTime,
    int? newestKnownTime,
    bool Function()? stillWanted,
  }) async {
    if (myId == 0 || targetTime <= 0) return WindowLoad.missing;
    final onlyVisible = !KometSettings.viewDeleted.value;
    bool wanted() => isMounted() && (stillWanted?.call() ?? true);

    var ranges = await AppDatabase.loadMessageRanges(myId, chatId);
    var window = await loadWindowFromDb(targetTime, onlyVisible);
    if (!wanted()) return WindowLoad.missing;

    final covered =
        window.any((m) => m.id == targetId) &&
        ranges.coversWindow(
          centerTime: targetTime,
          windowTimes: _timesOf(window),
          before: jumpWindowBefore,
          after: jumpWindowAfter,
          newestKnownTime: newestKnownTime,
        );
    if (!covered) {
      await _fetchQuietly(
        targetTime + 1,
        forward: jumpWindowAfter,
        backward: jumpWindowBefore + 1,
      );
      if (!wanted()) return WindowLoad.missing;
      window = await loadWindowFromDb(targetTime, onlyVisible);
      ranges = await AppDatabase.loadMessageRanges(myId, chatId);
      if (!wanted()) return WindowLoad.missing;
    }
    window = ranges.clipAround(window, targetTime, _timeOf);

    if (!window.any((m) => m.id == targetId)) return WindowLoad.missing;

    if (_overlapsLoaded(window)) {
      mergeMessages(window, contiguous: true);
      persistSessionCache();
      return WindowLoad.merged;
    }

    messages = _sorted([...window]);
    hasMoreHistory = true;
    isLoadingMore = false;
    hasNewer = newestKnownTime == null || messages.last.time < newestKnownTime;
    _newerStalledAt = -1;
    messagesRev.value++;
    return WindowLoad.replaced;
  }

  bool _overlapsLoaded(List<CachedMessage> window) {
    if (messages.isEmpty) return true;
    var oldest = window.first.time;
    var newest = oldest;
    for (final m in window) {
      if (m.time < oldest) oldest = m.time;
      if (m.time > newest) newest = m.time;
    }
    final upper = _newestServerMessage()?.time ?? messages.last.time;
    return newest >= messages.first.time && oldest <= upper;
  }

  CachedMessage? _newestServerMessage() {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].id.startsWith('temp_')) return messages[i];
    }
    return null;
  }

  Future<int> loadNewerHistory({int? newestKnownTime}) async {
    if (isLoadingNewer || !hasNewer || myId == 0) return 0;
    final edge = _newestServerMessage();
    if (edge == null || edge.time == _newerStalledAt) return 0;

    isLoadingNewer = true;
    try {
      final onlyVisible = !KometSettings.viewDeleted.value;
      var ranges = await AppDatabase.loadMessageRanges(myId, chatId);
      var newer = await loadNewerFromDb(edge.time, onlyVisible);
      if (!isMounted()) return 0;

      final covered = ranges.coversNewerPage(
        edgeTime: edge.time,
        pageTimes: _timesOf(newer),
        limit: newerPageSize,
        newestKnownTime: newestKnownTime,
      );
      if (!covered) {
        await _fetchQuietly(edge.time, forward: newerPageSize, backward: 0);
        if (!isMounted()) return 0;
        newer = await loadNewerFromDb(edge.time, onlyVisible);
        ranges = await AppDatabase.loadMessageRanges(myId, chatId);
        if (!isMounted()) return 0;
      }

      final range = ranges.at(edge.time);
      final page = range == null
          ? newer
          : ranges.clipNewer(newer, edge.time, _timeOf);
      final fresh = page.where((m) => !containsId(m.id)).toList();
      if (fresh.isNotEmpty) {
        messages = _sorted([...messages, ...fresh]);
        messagesRev.value++;
      }

      final newest = _newestServerMessage()?.time ?? edge.time;
      final reachedKnown = newestKnownTime != null && newest >= newestKnownTime;
      if (reachedKnown) {
        hasNewer = false;
        persistSessionCache();
      } else if (fresh.isEmpty) {
        _newerStalledAt = edge.time;
      }
      return fresh.length;
    } catch (e) {
      logger.e('Error loading newer history: $e');
      return 0;
    } finally {
      isLoadingNewer = false;
    }
  }

  Future<void> resetToLatest() async {
    final onlyVisible = !KometSettings.viewDeleted.value;
    final latest = await loadInitialFromDb(onlyVisible: onlyVisible);
    if (!isMounted()) return;

    final floor = latest.isEmpty
        ? 0
        : latest.map((m) => m.time).reduce((a, b) => a < b ? a : b);
    final byId = {for (final m in latest) m.id: m};
    for (final m in messages) {
      if (m.time >= floor || m.id.startsWith('temp_')) {
        byId.putIfAbsent(m.id, () => m);
      }
    }

    messages = _sorted(byId.values.toList());
    hasNewer = false;
    hasMoreHistory = true;
    isLoadingMore = false;
    _newerStalledAt = -1;
    messagesRev.value++;
    persistSessionCache();
  }

  void persistSessionCache() {
    if (myId == 0 || messages.isEmpty || hasNewer) return;
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
      final edge = oldest.time;
      var ranges = await AppDatabase.loadMessageRanges(myId, chatId);
      var older = await loadOlderFromDb(edge, onlyVisible, limit: size);

      final covered = ranges.at(edge) == null
          ? older.length >= size
          : ranges.coversOlderPage(
              edgeTime: edge,
              pageTimes: _timesOf(older),
              limit: size,
            );
      if (!covered) {
        await _fetchQuietly(edge, count: size);
        if (!isMounted()) return;
        older = await loadOlderFromDb(edge, onlyVisible, limit: size);
        ranges = await AppDatabase.loadMessageRanges(myId, chatId);
      }

      if (!isMounted()) return;
      final range = ranges.at(edge);
      final page = range == null
          ? older
          : ranges.clipOlder(older, edge, _timeOf);
      final added = prependOlder(page);
      isLoadingMore = false;
      if (added == 0 && (range == null || range.start == 0)) {
        hasMoreHistory = false;
      }
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

    if (fullDecoded.isNotEmpty &&
        latestCovered &&
        chats.wasHistoryFetched(chatId)) {
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
      final ranges = await AppDatabase.loadMessageRanges(myId, chatId);
      if (isMounted()) {
        pruneUncovered(ranges);
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
    unawaited(_restoredSub.cancel());
    messagesRev.dispose();
    super.dispose();
  }
}
