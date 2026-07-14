import 'dart:async';

import 'package:app_links/app_links.dart';

import '../../backend/api.dart';
import '../../frontend/debug/log_export.dart';
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
  bool _pendingLogExport = false;
  Timer? _logExportRetry;
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
    if (_isLogExportLink(uri)) {
      _pendingLogExport = true;
      _flushPending();
      return;
    }
    final url = _normalize(uri);
    if (url == null) return;
    _pending = url;
    _flushPending();
  }

  void _flushPending() {
    final context = KometApp.navigatorKey.currentContext;

    if (_pendingLogExport) {
      if (context == null) {
        _logExportRetry ??= Timer(const Duration(milliseconds: 300), () {
          _logExportRetry = null;
          _flushPending();
        });
      } else {
        _pendingLogExport = false;
        exportDebugLog(context);
      }
    }

    if (!_ready || context == null) return;
    final pending = _pending;
    if (pending == null || api.state != SessionState.online) return;
    _pending = null;
    tryHandleMaxLink(context, pending);
  }

  bool _isLogExportLink(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = <String>[
      if (scheme == 'komet' && host.isNotEmpty) host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();

    if (scheme == 'komet') {
      return segments.length == 1 && segments.first == 'export-logs';
    }
    if (scheme == 'https' || scheme == 'http') {
      return (host == 'komet.pw' || host == 'www.komet.pw') &&
          segments.length == 1 &&
          segments.first == 'export-logs';
    }
    return false;
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
    _logExportRetry?.cancel();
    _logExportRetry = null;
    _sub?.cancel();
    _sub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _started = false;
  }
}
