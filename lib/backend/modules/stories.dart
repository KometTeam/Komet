import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../../models/story.dart';
import '../api.dart';

/// Работа с «Историями»: лента-кольца, полные истории владельца, отметка
/// просмотра и реакции. Кэшируется в SQLite (превью, полные истории и позиция
/// просмотра) — переживает перезапуск; истёкшие кольца отсеиваются при загрузке.
class StoriesModule {
  StoriesModule(this._api);

  static const _previewsKey = 'stories_previews';
  static const _peersKey = 'stories_peers';
  static const _progressKey = 'stories_progress';

  final Api _api;

  final Map<int, StoryPreview> _previews = {};
  final Map<int, List<Story>> _peerStories = {};

  /// ownerId → storyId, на котором пользователь остановил просмотр.
  final Map<int, int> _lastViewed = {};

  int? _accountId;

  StreamSubscription<Packet>? _pushSub;

  /// Бампается при любом изменении лент/историй — UI слушает и перечитывает.
  final ValueNotifier<int> storiesChanged = ValueNotifier<int>(0);

  void _bump() => storiesChanged.value++;

  Future<int?> _acc() async {
    _accountId ??= await TokenStorage.getActiveAccountId();
    return _accountId;
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  int _normMs(int t) => t <= 0
      ? 0
      : (t < 1000000000000 ? t * 1000 : t);

  // ── Кэш (SQLite) ───────────────────────────────────────────────────────

  /// Загружает кэш из БД (превью/истории/позиции) и показывает мгновенно,
  /// до сетевого ответа. Истёкшие кольца отбрасываются.
  Future<void> loadCache() async {
    final acc = await _acc();
    if (acc == null) return;
    try {
      final rawPreviews = await AppDatabase.getSyncValue(acc, _previewsKey);
      if (rawPreviews != null && rawPreviews.isNotEmpty) {
        final list = jsonDecode(rawPreviews);
        final now = _nowMs();
        if (list is List) {
          for (final raw in list) {
            final preview = StoryPreview.fromMap(raw);
            if (preview == null || preview.isEmpty) continue;
            final exp = _normMs(preview.lastStoryExpirationTime);
            if (exp != 0 && exp < now) continue;
            // Не затираем уже загруженные из сети (более свежие) кольца.
            _previews.putIfAbsent(preview.owner.ownerId, () => preview);
          }
        }
      }

      final rawPeers = await AppDatabase.getSyncValue(acc, _peersKey);
      if (rawPeers != null && rawPeers.isNotEmpty) {
        final map = jsonDecode(rawPeers);
        if (map is Map) {
          map.forEach((key, value) {
            final ownerId = int.tryParse(key.toString());
            if (ownerId == null || value is! List) return;
            if (!_previews.containsKey(ownerId)) return;
            if (_peerStories.containsKey(ownerId)) return;
            final stories = <Story>[];
            for (final s in value) {
              final story = Story.fromMap(s);
              if (story != null) stories.add(story);
            }
            if (stories.isNotEmpty) _peerStories[ownerId] = stories;
          });
        }
      }

      final rawProgress = await AppDatabase.getSyncValue(acc, _progressKey);
      if (rawProgress != null && rawProgress.isNotEmpty) {
        final map = jsonDecode(rawProgress);
        if (map is Map) {
          map.forEach((key, value) {
            final ownerId = int.tryParse(key.toString());
            final storyId = value is int ? value : int.tryParse('$value');
            if (ownerId != null && storyId != null) {
              _lastViewed.putIfAbsent(ownerId, () => storyId);
            }
          });
        }
      }
      _bump();
    } catch (e) {
      logger.w('StoriesModule.loadCache: $e');
    }
  }

  Future<void> _persistPreviews() async {
    final acc = await _acc();
    if (acc == null) return;
    final list = _previews.values.map((p) => p.toJson()).toList();
    await AppDatabase.setSyncValue(acc, _previewsKey, jsonEncode(list));
  }

  Future<void> _persistPeers() async {
    final acc = await _acc();
    if (acc == null) return;
    final map = <String, dynamic>{};
    _peerStories.forEach((ownerId, stories) {
      map['$ownerId'] = stories.map((s) => s.toJson()).toList();
    });
    await AppDatabase.setSyncValue(acc, _peersKey, jsonEncode(map));
  }

  Future<void> _persistProgress() async {
    final acc = await _acc();
    if (acc == null) return;
    final map = <String, int>{};
    _lastViewed.forEach((ownerId, storyId) => map['$ownerId'] = storyId);
    await AppDatabase.setSyncValue(acc, _progressKey, jsonEncode(map));
  }

  // ── Позиция просмотра ──────────────────────────────────────────────────

  /// Запоминает, что у [ownerId] пользователь остановился на [storyId].
  void setLastViewed(int ownerId, int storyId) {
    if (storyId == 0 || _lastViewed[ownerId] == storyId) return;
    _lastViewed[ownerId] = storyId;
    unawaited(_persistProgress());
  }

  int? lastViewedStoryId(int ownerId) => _lastViewed[ownerId];

  /// Кольца-превью, отсортированные: сначала непрочитанные, затем по времени.
  List<StoryPreview> get previews {
    final list = _previews.values.where((p) => !p.isEmpty).toList();
    list.sort((a, b) {
      if (a.hasUnread != b.hasUnread) return a.hasUnread ? -1 : 1;
      return b.updateTime.compareTo(a.updateTime);
    });
    return list;
  }

  bool get hasAny => previews.isNotEmpty;

  StoryPreview? previewFor(int ownerId) => _previews[ownerId];

  List<Story>? cachedStories(int ownerId) => _peerStories[ownerId];

  /// Подписка на серверные пуши обновления колец (NOTIF_STORIES_UPDATE).
  void attach() {
    _pushSub ??= _api.pushStream
        .where((p) => p.opcode == Opcode.notifStoriesUpdate)
        .listen(_onPush);
  }

  void _onPush(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    final preview = StoryPreview.fromMap(payload['storiesPreview']);
    if (preview == null) return;
    _applyPreview(preview);
    _bump();
    unawaited(_persistPreviews());
  }

  void _applyPreview(StoryPreview preview) {
    if (preview.isEmpty) {
      _previews.remove(preview.owner.ownerId);
      _peerStories.remove(preview.owner.ownerId);
    } else {
      _previews[preview.owner.ownerId] = preview;
    }
  }

  /// Первая страница ленты историй. Возвращает false при ошибке/оффлайне.
  Future<bool> loadFeed({int count = 20}) async {
    if (_api.state != SessionState.online) return false;
    try {
      final packet = await _api.sendRequest(Opcode.storiesList, {
        'cursor': '',
        'count': count,
      });
      throwIfPacketError(packet);
      final data = packet.payload;
      if (data is! Map) return false;
      final rawPreviews = data['storiesPreviews'];
      if (rawPreviews is List) {
        _previews.clear();
        for (final raw in rawPreviews) {
          final preview = StoryPreview.fromMap(raw);
          if (preview != null) _applyPreview(preview);
        }
      }
      _bump();
      unawaited(_persistPreviews());
      return true;
    } catch (e) {
      logger.w('StoriesModule.loadFeed: $e');
      return false;
    }
  }

  /// Полные истории владельца. Обновляет кэш и кольцо, возвращает список.
  Future<List<Story>> getByOwner(StoryOwner owner) async {
    if (_api.state != SessionState.online) {
      return _peerStories[owner.ownerId] ?? const [];
    }
    try {
      final packet = await _api.sendRequest(Opcode.storiesGetByOwner, {
        'owners': [owner.toMap()],
      });
      throwIfPacketError(packet);
      final data = packet.payload;
      if (data is! Map) return _peerStories[owner.ownerId] ?? const [];

      final rawPreviews = data['storiesPreviews'];
      if (rawPreviews is List) {
        for (final raw in rawPreviews) {
          final preview = StoryPreview.fromMap(raw);
          if (preview != null) _applyPreview(preview);
        }
      }

      final rawPeers = data['peerStories'];
      List<Story> result = const [];
      if (rawPeers is List) {
        for (final raw in rawPeers) {
          final peer = PeerStories.fromMap(raw);
          if (peer == null) continue;
          _peerStories[peer.owner.ownerId] = peer.stories;
          if (peer.owner.ownerId == owner.ownerId) result = peer.stories;
        }
      }
      _bump();
      unawaited(_persistPreviews());
      unawaited(_persistPeers());
      return result;
    } catch (e) {
      logger.w('StoriesModule.getByOwner: $e');
      return _peerStories[owner.ownerId] ?? const [];
    }
  }

  /// Отметить историю просмотренной. Оптимистично поднимает readCount кольца.
  Future<bool> mark(StoryOwner owner, int storyId) async {
    if (_api.state != SessionState.online) return false;
    try {
      final ok = await _api.sendRequestOk(Opcode.storiesMark, {
        'owner': owner.toMap(),
        'storyId': storyId,
      });
      if (ok) _markReadLocally(owner.ownerId);
      return ok;
    } catch (e) {
      logger.w('StoriesModule.mark: $e');
      return false;
    }
  }

  void _markReadLocally(int ownerId) {
    final preview = _previews[ownerId];
    if (preview == null) return;
    if (preview.readCount >= preview.totalCount) return;
    _previews[ownerId] = preview.copyWith(readCount: preview.readCount + 1);
    _bump();
    unawaited(_persistPreviews());
  }

  /// Поставить ([reaction] != null) или снять (null) реакцию на историю.
  Future<bool> react(
    StoryOwner owner,
    int storyId,
    StoryReaction? reaction,
  ) async {
    if (_api.state != SessionState.online) return false;
    try {
      final ok = await _api.sendRequestOk(Opcode.storiesReact, {
        'owner': owner.toMap(),
        'storyId': storyId,
        if (reaction != null) 'reaction': reaction.toMap(),
      });
      if (ok) _applyReactionLocally(owner.ownerId, storyId, reaction);
      return ok;
    } catch (e) {
      logger.w('StoriesModule.react: $e');
      return false;
    }
  }

  void _applyReactionLocally(
    int ownerId,
    int storyId,
    StoryReaction? reaction,
  ) {
    final stories = _peerStories[ownerId];
    if (stories == null) return;
    final idx = stories.indexWhere((s) => s.id == storyId);
    if (idx < 0) return;
    stories[idx] = stories[idx].copyWith(
      reaction: reaction,
      clearReaction: reaction == null,
    );
    _bump();
    unawaited(_persistPeers());
  }

  /// Публикация фото-истории. [photoToken] — токен уже загруженного фото.
  /// [settings]: 1 = видно всем, 2 = только контактам. [expiration] — TTL, сек.
  /// Бросает [PacketError]/[TimeoutException] при ошибке сервера — чтобы UI
  /// показал реальную причину, а не общее «не удалось».
  Future<void> publishPhoto({
    required String photoToken,
    int settings = 1,
    int expiration = 86400,
  }) async {
    if (_api.state != SessionState.online) {
      throw const PacketError('Нет соединения с сервером');
    }
    final cid = DateTime.now().millisecondsSinceEpoch;
    final packet = await _api.sendRequest(Opcode.storiesSend, {
      'stories': [
        {
          'cid': cid,
          'settings': settings,
          'media': {'_type': 'PHOTO', 'photoToken': photoToken},
          'expiration': expiration,
        },
      ],
    });
    throwIfPacketError(packet);
    final data = packet.payload;
    if (data is Map) {
      final preview = StoryPreview.fromMap(data['storiesPreview']);
      if (preview != null) _applyPreview(preview);
      final rawStories = data['stories'];
      if (rawStories is List) {
        for (final raw in rawStories) {
          final story = Story.fromMap(raw);
          if (story == null) continue;
          final list = _peerStories.putIfAbsent(
            story.owner.ownerId,
            () => <Story>[],
          );
          list.add(story);
        }
      }
      _bump();
      unawaited(_persistPreviews());
      unawaited(_persistPeers());
    }
  }

  void clear() {
    _previews.clear();
    _peerStories.clear();
    _lastViewed.clear();
    _accountId = null;
    _bump();
  }

  void dispose() {
    _pushSub?.cancel();
    _pushSub = null;
    storiesChanged.dispose();
  }
}
