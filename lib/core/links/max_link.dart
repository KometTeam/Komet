enum MaxLinkKind { call, invite, user, content, public, auth, stickerSet }

class MaxLink {
  final MaxLinkKind kind;
  final String url;

  const MaxLink(this.kind, this.url);

  static final RegExp _host = RegExp(
    r'^https?://(?:www\.)?max\.ru/(.+)$',
    caseSensitive: false,
  );

  static final RegExp _segment = RegExp(r'^[A-Za-z0-9_]+$');

  static const Set<String> _reserved = {
    'join',
    'joincall',
    'u',
    'c',
    'login',
    'ps',
    'tos',
    'privacy',
    'about',
    'help',
  };

  static bool isMaxLink(String url) => parse(url) != null;

  static MaxLink? parse(String input) {
    final url = input.trim();
    final match = _host.firstMatch(url);
    if (match == null) return null;

    final path = match.group(1)!.split('?').first.split('#').first;
    final segments = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return null;

    switch (segments.first.toLowerCase()) {
      case ':auth':
        return segments.length >= 2 ? MaxLink(MaxLinkKind.auth, url) : null;
      case 'joincall':
        return segments.length >= 2 ? MaxLink(MaxLinkKind.call, url) : null;
      case 'join':
        return segments.length >= 2 ? MaxLink(MaxLinkKind.invite, url) : null;
      case 'u':
        return segments.length >= 2 ? MaxLink(MaxLinkKind.user, url) : null;
      case 'c':
        return segments.length >= 3 ? MaxLink(MaxLinkKind.content, url) : null;
      case 'stickerset':
        return segments.length >= 2
            ? MaxLink(MaxLinkKind.stickerSet, url)
            : null;
    }

    if (_reserved.contains(segments.first.toLowerCase())) return null;
    if (!_segment.hasMatch(segments.first)) return null;
    return MaxLink(MaxLinkKind.public, url);
  }
}
