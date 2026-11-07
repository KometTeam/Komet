import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum ManualLoad { unknown, missing, loaded }

class _GateState extends ValueNotifier<ManualLoad> {
  _GateState() : super(ManualLoad.unknown);

  bool probing = false;

  bool get watched => hasListeners;
}

class AutoDownloadGate {
  AutoDownloadGate._();

  @visibleForTesting
  static int capacity = 512;

  static final LinkedHashMap<String, _GateState> _states = LinkedHashMap();

  @visibleForTesting
  static Future<bool> Function(String key) isCached = _inImageCache;

  @visibleForTesting
  static int get size => _states.length;

  @visibleForTesting
  static void reset() {
    _states.clear();
    isCached = _inImageCache;
    capacity = 512;
  }

  static ValueListenable<ManualLoad> listen(String key) => _state(key);

  static bool allows(bool autoEnabled, String key) =>
      autoEnabled || _resolved(key) == ManualLoad.loaded;

  static bool awaitsTap(bool autoEnabled, String key) =>
      !autoEnabled && _resolved(key) == ManualLoad.missing;

  static void loadManually(String key) =>
      _state(key).value = ManualLoad.loaded;

  static _GateState _state(String key) {
    final existing = _states.remove(key);
    if (existing != null) {
      _states[key] = existing;
      return existing;
    }
    final created = _states[key] = _GateState();
    _evictIdle();
    return created;
  }

  static void _evictIdle() {
    var excess = _states.length - capacity;
    if (excess <= 0) return;
    final idle = <String>[];
    for (final entry in _states.entries) {
      if (excess == 0) break;
      if (entry.value.watched) continue;
      idle.add(entry.key);
      excess--;
    }
    for (final key in idle) {
      _states.remove(key)?.dispose();
    }
  }

  static ManualLoad _resolved(String key) {
    final state = _state(key);
    if (state.value == ManualLoad.unknown && !state.probing) {
      state.probing = true;
      unawaited(_probe(key, state));
    }
    return state.value;
  }

  static Future<void> _probe(String key, _GateState state) async {
    var cached = false;
    try {
      cached = await isCached(key);
    } catch (_) {}
    if (!identical(_states[key], state)) return;
    state.probing = false;
    if (state.value != ManualLoad.unknown) return;
    state.value = cached ? ManualLoad.loaded : ManualLoad.missing;
  }

  static Future<bool> _inImageCache(String key) async =>
      await DefaultCacheManager().getFileFromCache(key) != null;
}
