import 'dart:async';

import 'package:app_links/app_links.dart';

import '../../backend/api.dart';
import '../../frontend/widgets/max_link_handler.dart';
import '../../main.dart';
import 'desktop_url_scheme.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  StreamSubscription<SessionState>? _stateSub;
  String? _pending;
  bool _ready = false;
  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;

    await DesktopUrlScheme.register();

    _stateSub = api.stateStream.listen((state) {
      if (state == SessionState.online) _flushPending();
    });

    _sub = _appLinks.uriLinkStream.listen(_onUri);
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _onUri(initial);
    } catch (_) {}
  }

  void markReady() {
    _ready = true;
    _flushPending();
  }

  void _onUri(Uri uri) {
    final url = _normalize(uri);
    if (url == null) return;
    _pending = url;
    _flushPending();
  }

  void _flushPending() {
    final pending = _pending;
    if (pending == null || !_ready) return;
    if (api.state != SessionState.online) return;
    final context = KometApp.navigatorKey.currentContext;
    if (context == null) return;

    _pending = null;
    tryHandleMaxLink(context, pending);
  }

  String? _normalize(Uri uri) {
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'https' || scheme == 'http') {
      final host = uri.host.toLowerCase();
      if (host == 'max.ru' || host == 'www.max.ru') return uri.toString();
      return null;
    }

    if (scheme == 'komet' || scheme == 'max') {
      final segments = <String>[
        if (uri.host.isNotEmpty && uri.host.toLowerCase() != 'max.ru') uri.host,
        ...uri.pathSegments,
      ].where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return null;
      final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return 'https://max.ru/${segments.join('/')}$query';
    }

    return null;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _started = false;
  }
}
