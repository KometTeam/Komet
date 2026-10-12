class WebAppOriginPolicy {
  WebAppOriginPolicy(String launchUrl) : origin = _origin(Uri.parse(launchUrl));
  final String origin;

  static String _origin(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Invalid mini-app origin');
    }
    return uri.origin;
  }

  Set<String> get patterns {
    final optionalPort = Uri.parse(origin).hasPort ? '' : '(?::443)?';
    return {'^${RegExp.escape(origin)}$optionalPort\$'};
  }

  bool accepts(Uri uri, {bool isMainFrame = true}) =>
      isMainFrame &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.origin == origin;
}
