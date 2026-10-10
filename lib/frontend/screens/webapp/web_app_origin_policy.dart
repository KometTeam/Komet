class WebAppOriginPolicy {
  WebAppOriginPolicy(String launchUrl) : origin = _origin(Uri.parse(launchUrl));
  final String origin;

  static String _origin(Uri uri) {
    if (!const {'https', 'http'}.contains(uri.scheme) || uri.host.isEmpty) {
      throw const FormatException('Invalid mini-app origin');
    }
    return uri.origin;
  }

  Set<String> get patterns {
    final port = Uri.parse(origin).scheme == 'https' ? 443 : 80;
    final optionalPort = Uri.parse(origin).hasPort ? '' : '(?::$port)?';
    return {'^${RegExp.escape(origin)}$optionalPort\$'};
  }

  bool accepts(Uri uri, {bool isMainFrame = true}) =>
      isMainFrame &&
      const {'https', 'http'}.contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.origin == origin;
}
