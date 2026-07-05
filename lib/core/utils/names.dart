String displayName(Object? first, Object? last, {String fallback = ''}) {
  final f = first?.toString().trim() ?? '';
  final l = last?.toString().trim() ?? '';
  final full = [f, l].where((s) => s.isNotEmpty).join(' ');
  return full.isEmpty ? fallback : full;
}
