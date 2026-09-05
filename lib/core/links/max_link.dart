// #***! виды ссылок max.ru
enum MaxContentKind { public, invite, user, content }

sealed class MaxLink {
  const MaxLink();

  // #***! needsConnection значит надо дождаться сессии
  bool get needsConnection => false;

  // #***! принимаем и без схемы, max.ru/name тоже ссылка
  static final RegExp _schemeless = RegExp(
    r'^(?:www\.)?max\.ru(?:[/?#]|$)',
    caseSensitive: false,
  );

  static final RegExp _segment = RegExp(r'^[A-Za-z0-9_]+$');

  // #***! зарезервированные пути, публичным именем быть не могут
  static const Set<String> _reserved = {
    'login',
    'ps',
    'tos',
    'privacy',
    'about',
    'help',
  };

  // #***! быстрая проверка без разбора
  static bool isMaxLink(String url) => parse(url) != null;

  // #***! строка в конкретный подтип ссылки
  static MaxLink? parse(String input) {
    final uri = _canonical(input);
    if (uri == null) return null;

    final segments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    final params = uri.queryParameters;
    final url = uri.replace(scheme: 'https', host: 'max.ru').toString();

    if (segments.isEmpty) return _parseQueryOnly(params);
    if (segments.first.startsWith(':')) {
      return _parseRoute(segments, params, url);
    }
    return _parseContent(segments, params, url);
  }

  // #***! нормализация к Uri, дописываем схему убираем мусор
  static Uri? _canonical(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) {
      if (!_schemeless.hasMatch(value)) return null;
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http' && scheme != 'max') return null;
    final host = uri.host.toLowerCase();
    if (host != 'max.ru' && host != 'www.max.ru') return null;
    return uri;
  }

  // #***! ссылка ?param=... без пути
  static MaxLink _parseQueryOnly(Map<String, String> params) {
    final userId = _idParam(params, 'uid');
    if (userId != null) return MaxContactIdLink(userId);
    final chatId = _idParam(params, 'cid');
    if (chatId != null) return MaxChatIdLink(chatId);
    return const MaxRootLink();
  }

  // #***! разбор по первому сегменту
  static MaxLink _parseRoute(
    List<String> segments,
    Map<String, String> params,
    String url,
  ) {
    final route = segments.join('/').toLowerCase();
    switch (route) {
      case ':auth':
        return MaxAuthLink(url);
      case ':current':
        return const MaxCurrentLink();
      case ':share-self-out':
        return const MaxShareSelfLink();
      case ':share':
        return MaxShareTextLink(params['text']?.trim() ?? '');
      case ':folder':
        final id = params['id']?.trim();
        if (id != null && id.isNotEmpty) return MaxFolderLink(id);
    }
    if (segments.length > 1 && segments.first.toLowerCase() == ':auth') {
      return MaxAuthLink(url);
    }
    return MaxRouteLink(route, params);
  }

  // #***! остальное это контент, пост чат стикерпак
  static MaxLink? _parseContent(
    List<String> segments,
    Map<String, String> params,
    String url,
  ) {
    final first = segments.first;
    final lower = first.toLowerCase();

    if (segments.length == 1) {
      final name = _publicName(first);
      if (name == null) return null;
      final startApp = params['startapp'] ?? params['startApp'];
      if (startApp != null && startApp.isNotEmpty) {
        return MaxWebAppLink('https://max.ru/$name', startApp.split('&').first);
      }
      return MaxContentLink(
        kind: MaxContentKind.public,
        url: url,
        baseUrl: 'https://max.ru/$name',
        startPayload: _startPayload(params),
      );
    }

    if (segments.length == 2) {
      switch (lower) {
        case 'stickerset':
          return MaxStickerSetLink('$lower/${segments[1]}');
        case 'joincall':
          return MaxCallLink(url);
        case 'join':
          return MaxContentLink(
            kind: MaxContentKind.invite,
            url: url,
            baseUrl: url,
          );
        case 'u':
          return MaxContentLink(
            kind: MaxContentKind.user,
            url: url,
            baseUrl: url,
          );
      }
      final messageId = int.tryParse(segments[1]);
      final name = _publicName(first);
      if (messageId == null || name == null) return null;
      return MaxContentLink(
        kind: MaxContentKind.public,
        url: url,
        baseUrl: 'https://max.ru/$name',
        messageId: messageId,
      );
    }

    if (lower == 'c' && segments.length == 3) {
      final chatId = int.tryParse(segments[1]);
      final messageId = int.tryParse(segments[2]);
      if (chatId == null || messageId == null) return null;
      return MaxContentLink(
        kind: MaxContentKind.content,
        url: url,
        baseUrl: 'https://max.ru/c/$chatId',
        messageId: messageId,
      );
    }

    if (lower == 'join') {
      return MaxContentLink(
        kind: MaxContentKind.invite,
        url: url,
        baseUrl: url,
      );
    }
    return null;
  }

  // #***! публичное имя это один допустимый сегмент
  static String? _publicName(String segment) {
    final name = segment.startsWith('@') ? segment.substring(1) : segment;
    if (name.isEmpty) return null;
    if (_reserved.contains(name.toLowerCase())) return null;
    if (!_segment.hasMatch(name)) return null;
    return name;
  }

  static String? _startPayload(Map<String, String> params) {
    final value = params['start']?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static int? _idParam(Map<String, String> params, String key) {
    final raw = params[key]?.trim();
    if (raw == null || raw.isEmpty) return null;
    final value = int.tryParse(raw);
    return (value == null || value <= 0) ? null : value;
  }
}

// #***! дальше по классу на каждый вид ссылки
class MaxRootLink extends MaxLink {
  const MaxRootLink();
}

class MaxCurrentLink extends MaxLink {
  const MaxCurrentLink();
}

class MaxShareSelfLink extends MaxLink {
  const MaxShareSelfLink();
}

class MaxAuthLink extends MaxLink {
  final String url;

  const MaxAuthLink(this.url);

  @override
  bool get needsConnection => true;
}

class MaxCallLink extends MaxLink {
  final String url;

  const MaxCallLink(this.url);

  @override
  bool get needsConnection => true;
}

class MaxStickerSetLink extends MaxLink {
  final String path;

  const MaxStickerSetLink(this.path);

  @override
  bool get needsConnection => true;
}

class MaxShareTextLink extends MaxLink {
  final String text;

  const MaxShareTextLink(this.text);
}

class MaxFolderLink extends MaxLink {
  final String folderId;

  const MaxFolderLink(this.folderId);
}

class MaxRouteLink extends MaxLink {
  final String route;
  final Map<String, String> params;

  const MaxRouteLink(this.route, this.params);
}

class MaxContactIdLink extends MaxLink {
  final int userId;

  const MaxContactIdLink(this.userId);

  @override
  bool get needsConnection => true;
}

class MaxChatIdLink extends MaxLink {
  final int chatId;
  final int? messageId;

  const MaxChatIdLink(this.chatId, {this.messageId});
}

class MaxWebAppLink extends MaxLink {
  final String url;
  final String startApp;

  const MaxWebAppLink(this.url, this.startApp);

  @override
  bool get needsConnection => true;
}

class MaxContentLink extends MaxLink {
  final MaxContentKind kind;
  final String url;
  final String baseUrl;
  final String? startPayload;
  final int? messageId;

  const MaxContentLink({
    required this.kind,
    required this.url,
    required this.baseUrl,
    this.startPayload,
    this.messageId,
  });

  @override
  bool get needsConnection => true;
}
