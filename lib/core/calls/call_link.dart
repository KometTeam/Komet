class CallLink {
  static final RegExp _pattern = RegExp(
    r'^https?://(?:[^/\s]+\.)?max\.ru/joincall/([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );

  static bool isCallLink(String url) => token(url) != null;

  static String? token(String url) =>
      _pattern.firstMatch(url.trim())?.group(1);
}
