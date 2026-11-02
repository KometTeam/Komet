import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

typedef ChannelViewsFetch =
    Future<Map<String, int>?> Function(
      List<String> messageIds, {
      required bool count,
    });

class ChannelViews {
  ChannelViews(this._fetch, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const Duration batchDelay = Duration(milliseconds: 300);
  static const Duration freshFor = Duration(minutes: 1);
  static const int batchSize = 50;

  final ChannelViewsFetch _fetch;
  final DateTime Function() _clock;
  final Map<String, ValueNotifier<int?>> _views = {};
  final Map<String, DateTime> _requestedAt = {};
  final LinkedHashSet<String> _queue = LinkedHashSet();
  final Set<String> _counted = {};
  Timer? _timer;
  bool _disposed = false;
  bool _refused = false;

  ValueListenable<int?> of(String messageId) {
    final views = _views.putIfAbsent(messageId, () => ValueNotifier(null));
    _enqueue(messageId);
    return views;
  }

  void _enqueue(String messageId) {
    if (_disposed || _refused || int.tryParse(messageId) == null) return;
    final requested = _requestedAt[messageId];
    if (requested != null && _clock().difference(requested) < freshFor) {
      return;
    }
    _queue.add(messageId);
    _timer ??= Timer(batchDelay, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    if (_disposed || _queue.isEmpty) return;
    final batch = _queue.take(batchSize).toList(growable: false);
    _queue.removeAll(batch);
    if (_queue.isNotEmpty) _timer = Timer(batchDelay, _flush);
    final now = _clock();
    for (final id in batch) {
      _requestedAt[id] = now;
    }
    final unseen = <String>[];
    final seen = <String>[];
    for (final id in batch) {
      (_counted.add(id) ? unseen : seen).add(id);
    }
    final results = await Future.wait([
      if (unseen.isNotEmpty) _fetch(unseen, count: true),
      if (seen.isNotEmpty) _fetch(seen, count: false),
    ]);
    if (_disposed) return;
    if (results.contains(null)) {
      _refused = true;
      _timer?.cancel();
      _timer = null;
      _queue.clear();
      return;
    }
    for (final views in results) {
      for (final MapEntry(:key, :value) in views!.entries) {
        _views[key]?.value = value;
      }
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final views in _views.values) {
      views.dispose();
    }
    _views.clear();
  }
}
