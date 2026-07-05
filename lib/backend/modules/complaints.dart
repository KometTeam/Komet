import '../api.dart';
import '../../core/protocol/opcode_map.dart';

class ComplaintReason {
  final int reasonId;
  final String reasonTitle;

  const ComplaintReason({required this.reasonId, required this.reasonTitle});
}

class ComplaintsModule {
  static Map<int, List<ComplaintReason>>? _cache;

  static void clear() => _cache = null;

  static Future<Map<int, List<ComplaintReason>>> fetchReasons(Api api) async {
    final cached = _cache;
    if (cached != null) return cached;

    final response = await api.sendRequest(Opcode.complainReasonsGet, {
      'complainSync': 0,
    });
    if (!response.isOk) return cached ?? const {};

    final payload = response.payload;
    if (payload is! Map) return const {};

    final complains = payload['complains'];
    final map = <int, List<ComplaintReason>>{};
    if (complains is List) {
      for (final entry in complains) {
        if (entry is! Map) continue;
        final typeId = entry['typeId'];
        final reasons = entry['reasons'];
        if (typeId is! int || reasons is! List) continue;
        map[typeId] = reasons
            .whereType<Map>()
            .map(
              (r) => ComplaintReason(
                reasonId: r['reasonId'] is int ? r['reasonId'] as int : 0,
                reasonTitle: r['reasonTitle']?.toString() ?? '',
              ),
            )
            .where((r) => r.reasonId != 0)
            .toList();
      }
    }

    _cache = map;
    return map;
  }

  static Future<List<ComplaintReason>> reasonsFor(Api api, int typeId) async {
    final map = await fetchReasons(api);
    final forType = map[typeId];
    if (forType != null && forType.isNotEmpty) return forType;
    for (final list in map.values) {
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  static Future<bool> sendComplaint(
    Api api, {
    required int reasonId,
    required int typeId,
    required List<int> ids,
    required int parentId,
  }) async {
    final response = await api.sendRequest(Opcode.complain, {
      'reasonId': reasonId,
      'typeId': typeId,
      'ids': ids,
      'parentId': parentId,
    });
    if (!response.isOk) return false;
    final payload = response.payload;
    return payload is Map && payload['success'] == true;
  }
}
