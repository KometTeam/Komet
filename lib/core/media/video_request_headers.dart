Map<String, String> videoRequestHeaders(
  Uri uri, {
  required String? sessionUserAgent,
}) {
  if (!_isOkCdnHost(uri.host)) return const {};
  final userAgent = sessionUserAgent?.trim();
  if (userAgent == null || userAgent.isEmpty) return const {};
  return {'User-Agent': userAgent};
}

bool _isOkCdnHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'okcdn.ru' || normalized.endsWith('.okcdn.ru');
}
