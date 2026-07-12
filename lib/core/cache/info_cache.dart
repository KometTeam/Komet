import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../backend/api.dart';
import '../../models/chat_info.dart';
import '../../models/contact_info.dart';
import '../protocol/opcode_map.dart';

Api? _api;

void attachInfoCacheApi(Api api) {
  _api = api;
}

class _Entry<T> {
  T? value;
  DateTime? fetchedAt;
  DateTime? failedAt;
  Future<T?>? inFlight;
}

class InfoCache<T> {
  final Duration ttl;
  final Duration failureBackoff;
  final Future<T?> Function(int id) fetcher;
  final Map<int, _Entry<T>> _entries = {};

  InfoCache({
    required this.ttl,
    required this.fetcher,
    this.failureBackoff = const Duration(seconds: 10),
  });

  bool _isFresh(_Entry<T> e) {
    if (e.fetchedAt == null) return false;
    return DateTime.now().difference(e.fetchedAt!) < ttl;
  }

  bool _isInFailureBackoff(_Entry<T> e) {
    if (e.failedAt == null) return false;
    return DateTime.now().difference(e.failedAt!) < failureBackoff;
  }

  Future<T?> get(int id, {bool forceRefresh = false}) {
    final entry = _entries.putIfAbsent(id, () => _Entry<T>());

    if (!forceRefresh && _isFresh(entry)) {
      return Future.value(entry.value);
    }
    if (!forceRefresh && _isInFailureBackoff(entry)) {
      return Future.value(null);
    }
    if (entry.inFlight != null) return entry.inFlight!;

    final future = _runFetch(entry, id);
    entry.inFlight = future;
    return future;
  }

  Future<T?> _runFetch(_Entry<T> entry, int id) async {
    try {
      final result = await fetcher(id);
      entry.value = result;
      entry.fetchedAt = DateTime.now();
      entry.failedAt = null;
      return result;
    } catch (_) {
      entry.failedAt = DateTime.now();
      return null;
    } finally {
      entry.inFlight = null;
    }
  }

  T? peek(int id) {
    final entry = _entries[id];
    if (entry == null || !_isFresh(entry)) return null;
    return entry.value;
  }

  void invalidate(int id) => _entries.remove(id);
  void clear() => _entries.clear();

  void putValue(int id, T value, {DateTime? at}) {
    final entry = _entries.putIfAbsent(id, () => _Entry<T>());
    entry.value = value;
    entry.fetchedAt = at ?? DateTime.now();
    entry.failedAt = null;
  }

  void markFailed(int id, {DateTime? at}) {
    final entry = _entries.putIfAbsent(id, () => _Entry<T>());
    entry.failedAt = at ?? DateTime.now();
  }
}

class ContactInfoFetch {
  static final _cache = InfoCache<ContactInfo>(
    ttl: const Duration(minutes: 5),
    fetcher: _fetch,
  );

  static Future<ContactInfo?> get(int id, {bool forceRefresh = false}) =>
      _cache.get(id, forceRefresh: forceRefresh);

  static ContactInfo? peek(int id) => _cache.peek(id);

  static void invalidate(int id) => _cache.invalidate(id);
  static void clear() => _cache.clear();

  static Future<ContactInfo?> _fetch(int id) async {
    final api = _api;
    if (api == null || api.state != SessionState.online) return null;
    final resp = await api.sendRequest(Opcode.contactInfo, {
      'contactIds': [id],
    });
    final data = resp.payload;
    if (data is! Map) return null;
    final contacts = data['contacts'];
    if (contacts is! List || contacts.isEmpty) return null;
    final first = contacts.first;
    if (first is! Map) return null;
    return ContactInfo.fromMap(Map<String, dynamic>.from(first));
  }
}

class PresenceFetch {
  static final _cache = InfoCache<Map<String, dynamic>>(
    ttl: const Duration(seconds: 60),
    fetcher: _fetch,
  );

  static Future<Map<String, dynamic>?> get(
    int id, {
    bool forceRefresh = false,
  }) => _cache.get(id, forceRefresh: forceRefresh);

  static Map<String, dynamic>? peek(int id) => _cache.peek(id);

  static final Map<int, Map<String, dynamic>> _live = {};
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Map<String, dynamic>? live(int id) => _live[id] ?? _cache.peek(id);

  static bool isOnline(int id) => (live(id)?['status'] as int?) == 1;

  static void apply(int id, Map<String, dynamic> presence) {
    if (id <= 0) return;
    _live[id] = presence;
    _cache.putValue(id, presence);
    revision.value++;
  }

  static void invalidate(int id) => _cache.invalidate(id);

  static void clear() {
    _cache.clear();
    _live.clear();
    revision.value++;
  }

  static void primeAll(Map<dynamic, dynamic> presence) {
    final now = DateTime.now();
    presence.forEach((key, value) {
      if (value is! Map) return;
      final id = key is int ? key : int.tryParse(key.toString());
      if (id == null) return;
      final map = Map<String, dynamic>.from(value);
      _cache.putValue(id, map, at: now);
      _live[id] = map;
    });
    revision.value++;
  }

  static Future<Map<String, dynamic>?> _fetch(int id) async {
    final results = await _fetchBatch([id]);
    return results[id];
  }

  static Future<Map<int, Map<String, dynamic>>> getMany(
    List<int> ids, {
    bool forceRefresh = false,
  }) async {
    final result = <int, Map<String, dynamic>>{};
    final missing = <int>[];
    for (final id in ids) {
      if (!forceRefresh) {
        final cached = _cache.peek(id);
        if (cached != null) {
          result[id] = cached;
          continue;
        }
      }
      missing.add(id);
    }
    if (missing.isNotEmpty) {
      final fetched = await _fetchBatch(missing);
      final now = DateTime.now();
      for (final id in missing) {
        final value = fetched[id];
        if (value != null) {
          _cache.putValue(id, value, at: now);
          result[id] = value;
        } else {
          _cache.markFailed(id, at: now);
        }
      }
    }
    return result;
  }

  static Future<Map<int, Map<String, dynamic>>> _fetchBatch(
    List<int> ids,
  ) async {
    final api = _api;
    if (api == null || api.state != SessionState.online || ids.isEmpty) {
      return const {};
    }
    final resp = await api.sendRequest(Opcode.contactPresence, {
      'contactIds': ids,
    });
    final data = resp.payload;
    if (data is! Map) return const {};
    final presence = data['presence'];
    if (presence is! Map) return const {};
    final out = <int, Map<String, dynamic>>{};
    for (final id in ids) {
      final entry = presence[id.toString()] ?? presence[id];
      if (entry is Map) {
        out[id] = Map<String, dynamic>.from(entry);
      }
    }
    return out;
  }
}

class ChatInfoFetch {
  static final _cache = InfoCache<ChatInfo>(
    ttl: const Duration(minutes: 5),
    fetcher: _fetch,
  );

  static Future<ChatInfo?> get(int id, {bool forceRefresh = false}) =>
      _cache.get(id, forceRefresh: forceRefresh);

  static ChatInfo? peek(int id) => _cache.peek(id);

  static void invalidate(int id) => _cache.invalidate(id);
  static void clear() => _cache.clear();

  static Future<ChatInfo?> _fetch(int id) async {
    final api = _api;
    if (api == null || api.state != SessionState.online) return null;
    final resp = await api.sendRequest(Opcode.chatInfo, {
      'chatIds': [id],
    });
    final data = resp.payload;
    if (data is! Map) return null;
    final chats = data['chats'];
    if (chats is! List || chats.isEmpty) return null;
    final first = chats.first;
    if (first is! Map) return null;
    return ChatInfo.fromMap(Map<String, dynamic>.from(first));
  }
}
