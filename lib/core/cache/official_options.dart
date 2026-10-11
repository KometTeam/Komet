import 'dart:async';

import '../../backend/modules/messages.dart' show ContactCache;
import 'info_cache.dart';

class OfficialOptions {
  OfficialOptions._();

  static final Set<int> _pending = {};
  static final Set<int> _requested = {};
  static bool _scheduled = false;

  static void request(int id) {
    if (id == 0 || ContactCache.getOptions(id) != null) return;
    if (!_requested.add(id)) return;
    _pending.add(id);
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_flush);
    }
  }

  static void requestAll(Iterable<int> ids) {
    for (final id in ids) {
      request(id);
    }
  }

  static Future<void> _flush() async {
    _scheduled = false;
    final ids = _pending.toList();
    _pending.clear();
    if (ids.isEmpty) return;
    final infos = await ContactInfoFetch.getMany(ids);
    _requested.removeWhere((id) => ids.contains(id) && !infos.containsKey(id));
    if (infos.isEmpty) return;
    for (final entry in infos.entries) {
      ContactCache.putOptions(
        entry.key,
        entry.value.options.toSet(),
        notify: false,
      );
    }
    ContactCache.officialRevision.value++;
  }
}
