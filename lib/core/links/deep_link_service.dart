import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

import '../../backend/api.dart';
import '../../frontend/debug/log_export.dart';
import '../../frontend/screens/digital_id/digital_id_web_screen.dart';
import '../../frontend/widgets/custom_notification.dart';
import '../../frontend/widgets/max_link_handler.dart';
import '../../frontend/widgets/swipe_route.dart';
import '../../main.dart';
import '../webpush/max_web_socket.dart';
import '../webpush/web_push_service.dart';
import 'desktop_url_scheme.dart';
import 'max_link.dart';
import '../config/build_profile.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  StreamSubscription<SessionState>? _stateSub;
  String? _pending;
  bool _pendingLogExport = false;
  String? _pendingExternalCallback;
  WebPushSubscription? _pendingWebPush;
  String? _lastExternalCallback;
  Timer? _externalCallbackRetry;
  Timer? _webPushRetry;
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

  void handle(Uri uri) => _onUri(uri);

  void _onUri(Uri uri) {
    if (_isLogExportLink(uri)) {
      _pendingLogExport = true;
      _flushPending();
      return;
    }
    final webPush = _parseWebPushLink(uri);
    if (webPush != null) {
      _pendingWebPush = webPush;
      _flushPending();
      return;
    }
    if (_isExternalCallback(uri)) {
      final callbackUrl = uri.toString();
      if (callbackUrl == _lastExternalCallback) return;
      _lastExternalCallback = callbackUrl;
      _pendingExternalCallback = callbackUrl;
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

    if (_pendingExternalCallback != null) {
      if (context == null || api.state != SessionState.online) {
        _externalCallbackRetry ??= Timer(const Duration(milliseconds: 300), () {
          _externalCallbackRetry = null;
          _flushPending();
        });
      } else {
        final url = _pendingExternalCallback!;
        _pendingExternalCallback = null;
        _handleExternalCallback(context, url);
      }
    }

    if (_pendingWebPush != null) {
      if (context == null) {
        _webPushRetry ??= Timer(const Duration(milliseconds: 300), () {
          _webPushRetry = null;
          _flushPending();
        });
      } else {
        final subscription = _pendingWebPush!;
        _pendingWebPush = null;
        _handleWebPush(context, subscription);
      }
    }

    if (!_ready || context == null) return;
    final pending = _pending;
    if (pending == null) return;
    final needsConnection = MaxLink.parse(pending)?.needsConnection ?? true;
    if (needsConnection && api.state != SessionState.online) return;
    _pending = null;
    tryHandleMaxLink(context, pending);
  }

  bool _isExternalCallback(Uri uri) {
    if (!BuildProfile.digitalId) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http' && scheme != 'max') return false;
    final host = uri.host.toLowerCase();
    if (host != 'max.ru' && host != 'www.max.ru') return false;
    return uri.queryParameters['externalCallback'] == '1';
  }

  Future<void> _handleExternalCallback(BuildContext context, String url) async {
    try {
      final launch = await webAppModule.handleExternalCallback(url);
      if (!context.mounted) return;
      await pushSwipeable(
        context,
        (_) => DigitalIdWebScreen(initialLaunch: launch),
      );
    } catch (e) {
      if (context.mounted) {
        showCustomNotification(context, 'Не удалось завершить Цифровой ID: $e');
      }
    }
  }

  WebPushSubscription? _parseWebPushLink(Uri uri) {
    if (!Platform.isIOS) return null;
    if (uri.scheme.toLowerCase() != 'komet') return null;

    final segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments,
    ].where((s) => s.isNotEmpty).toList();
    if (segments.length != 1 || segments.first != 'webpush') return null;

    final endpoint = uri.queryParameters['endpoint'] ?? '';
    final publicKey = uri.queryParameters['p256dh'] ?? '';
    final authKey = uri.queryParameters['auth'] ?? '';
    if (endpoint.isEmpty || publicKey.isEmpty || authKey.isEmpty) return null;
    if (Uri.tryParse(endpoint)?.isScheme('https') != true) return null;

    return WebPushSubscription(
      endpoint: endpoint,
      publicKey: publicKey,
      authKey: authKey,
    );
  }

  Future<void> _handleWebPush(
    BuildContext context,
    WebPushSubscription subscription,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    if (!await WebPushService.instance.isAuthorized()) {
      if (context.mounted) {
        showCustomNotification(context, l10n.webPushNotAuthorized);
      }
      return;
    }

    try {
      await WebPushService.instance.registerSubscription(subscription);
      if (context.mounted) {
        showCustomNotification(context, l10n.webPushLinked);
      }
    } on MaxWebException catch (e) {
      if (context.mounted) {
        showCustomNotification(context, l10n.webPushLinkFailed(e.message));
      }
    } catch (e) {
      if (context.mounted) {
        showCustomNotification(context, l10n.webPushLinkFailed('$e'));
      }
    }
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
    _webPushRetry?.cancel();
    _webPushRetry = null;
    _sub?.cancel();
    _sub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _started = false;
  }
}
