class CallLink {
  static const String base = 'https://max.ru/joincall/';

  static final RegExp _pattern = RegExp(
    r'^https?://(?:[^/\s]+\.)?max\.ru/joincall/([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );

  static final RegExp _rawPattern = RegExp(
    r'^(?:joincall/)?([A-Za-z0-9_-]+)$',
    caseSensitive: false,
  );

  static bool isCallLink(String url) => token(url) != null;

  static String? token(String url) => _pattern.firstMatch(url.trim())?.group(1);

  static String? normalizeToken(String raw) {
    final value = raw.trim();
    return token(value) ?? _rawPattern.firstMatch(value)?.group(1);
  }

  static String url(String token) => '$base$token';

  static String path(String token) => 'joincall/$token';
}
