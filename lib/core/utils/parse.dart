int? parseIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

List<int> parseIntList(Object? v) =>
    v is List ? v.map(parseIntOrNull).whereType<int>().toList() : const <int>[];
