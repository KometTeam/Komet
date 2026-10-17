const Set<String> _unconfirmedStatuses = {'pending', 'sending', 'error'};

const Duration historySettleWindow = Duration(minutes: 2);

class HistoryPage {
  HistoryPage._(this.ids, this.oldest, this.newest);

  final Set<String> ids;
  final int oldest;
  final int newest;

  static HistoryPage? of(List<dynamic> messages) {
    final ids = <String>{};
    int? oldest;
    int? newest;
    for (final m in messages) {
      if (m is! Map) continue;
      final id = m['id']?.toString();
      if (id != null && id.isNotEmpty) ids.add(id);
      final time = m['time'];
      if (time is! int) continue;
      if (oldest == null || time < oldest) oldest = time;
      if (newest == null || time > newest) newest = time;
    }
    if (oldest == null || newest == null) return null;
    return HistoryPage._(ids, oldest, newest);
  }

  List<String> missingFrom(
    Iterable<Map<String, dynamic>> localRows, {
    required bool reachesNow,
    required int settledBefore,
  }) {
    final missing = <String>[];
    final seen = <String>{};
    for (final row in localRows) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty || id.startsWith('temp_') || ids.contains(id)) continue;
      if (!seen.add(id)) continue;
      if (_unconfirmedStatuses.contains(row['status'])) continue;
      if (_isSet(row['deleted'])) continue;
      final time = _intOf(row['time']);
      if (time == null || time < oldest || time >= settledBefore) continue;
      if (!reachesNow && time > newest) continue;
      missing.add(id);
    }
    return missing;
  }

  static bool _isSet(Object? flag) =>
      flag == true || (flag is int && flag != 0);

  static int? _intOf(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
}
