import 'dart:convert';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/storage/webapp_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/crypto/outgoing_message_policy.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/media_saver.dart';
import '../../../core/utils/share_origin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show api, messagesModule, webAppModule;
import '../../widgets/confirm_dialog.dart';
import '../chats/chat_list_screen.dart' show openForwardScreen;
import '../profile/web_qr_scan_screen.dart';
import 'web_app_biometry.dart';
import 'web_app_origin_policy.dart';
import '../../../core/security/app_lock.dart';

abstract class WebAppEntryPoint {
  static const String webApp = 'web_app';
  static const String url = 'url';
  static const String startButton = 'start_button';
  static const String inlineButton = 'inline_button';
  static const String chatProfile = 'chat_profile';
  static const String externalCallback = 'external_callback';
  static const String settings = 'settings';
  static const String fromSearch = 'from_search';
}

typedef WebAppMobileIdVerifier =
    Future<Map<String, dynamic>?> Function(String url);

typedef WebAppEmitter =
    void Function(String method, String payload, bool private);

const Duration _gestureWindow = Duration(milliseconds: 3000);

const Set<String> _gestureGated = {
  'WebAppMaxShare',
  'WebAppShare',
  'WebAppDownloadFile',
  'WebAppOpenLink',
  'WebAppOpenMaxLink',
};

const Map<String, String> _methodSlugs = {
  'WebAppReady': 'ready',
  'WebAppClose': 'close',
  'WebAppSetupBackButton': 'setup_back_button',
  'WebAppSetupClosingBehavior': 'setup_closing_behaviour',
  'WebAppBackButtonPressed': 'back_button_pressed',
  'WebAppSetupScreenCaptureBehavior': 'setup_screen_capture_behavior',
  'WebAppGetLaunchContext': 'launch_context',
  'WebAppGetViewportSize': 'get_viewport_size',
  'WebAppRequestPhone': 'request_phone',
  'WebAppOpenLink': 'open_link',
  'WebAppOpenMaxLink': 'open_max_link',
  'WebAppShare': 'web_app_share',
  'WebAppMaxShare': 'web_app_max_share',
  'WebAppDeviceStorageSaveKey': 'device_storage_save_key',
  'WebAppDeviceStorageGetKey': 'device_storage_get_key',
  'WebAppDeviceStorageClear': 'device_storage_clear',
  'WebAppSecureStorageSaveKey': 'secure_storage_save_key',
  'WebAppSecureStorageGetKey': 'secure_storage_get_key',
  'WebAppSecureStorageClear': 'secure_storage_clear',
  'WebAppBiometryGetInfo': 'biometry_get_info',
  'WebAppBiometryRequestAccess': 'biometry_request_access',
  'WebAppBiometryRequestAuth': 'biometry_request_auth',
  'WebAppBiometryUpdateToken': 'biometry_update_token',
  'WebAppBiometryOpenSettings': 'biometry_open_settings',
  'WebAppHapticFeedbackImpact': 'haptic_feedback_impact',
  'WebAppHapticFeedbackNotification': 'haptic_feedback_notification',
  'WebAppHapticFeedbackSelectionChange': 'haptic_feedback_selection_change',
  'WebAppDownloadFile': 'download_file',
  'WebAppOpenCodeReader': 'open_code_reader',
  'WebAppChangeScreenBrightness': 'change_screen_brightness',
  'WebAppNfcGetInfo': 'nfc_get_info',
  'WebAppNfcEmulateNfcTag': 'nfc_emulate_nfc_tag',
  'WebAppNfcOpenSystemSettings': 'nfc_open_system_settings',
  'WebAppVerifyMobileId': 'verify_mobile_id',
};

const Set<String> _silentMethods = {
  'WebAppReady',
  'WebAppStat',
  'WebAppUrlInterceptor',
  'WebAppBackButtonPressed',
};

const String _shim = r'''
(function(){
  if (window.__kometWebAppBridge) { return; }
  window.__kometWebAppBridge = true;
  var pending = [];
  function target(priv){
    var box = priv ? window.PrivateWebApp : window.WebApp;
    return (box && typeof box.sendEvent === 'function') ? box : null;
  }
  function flush(){
    if (!pending.length) { return; }
    var keep = [];
    for (var i = 0; i < pending.length; i++) {
      var item = pending[i];
      var box = target(item[2]);
      if (!box) { keep.push(item); continue; }
      try { box.sendEvent(item[0], item[1]); } catch (e) { keep.push(item); }
    }
    pending = keep;
  }
  setInterval(flush, 50);
  window.__kometWebAppDeliver = function(name, data, priv){
    pending.push([name, data, !!priv]);
    flush();
  };
  function post(name, data, priv){
    try {
      if (window.__kometWebAppNative) {
        window.__kometWebAppNative.postMessage(JSON.stringify([name, data, priv]));
      } else {
        window.flutter_inappwebview.callHandler('webAppEvent', name, data, priv);
      }
    } catch (e) {}
  }
  window.WebViewHandler = {
    postEvent: function(name, data){ post(name, data, false); },
    resolveShare: function(requestId, bytes, mimeType, fileName){
      try {
        window.flutter_inappwebview.callHandler(
          'webAppResolveShare', requestId, mimeType, fileName);
      } catch (e) {}
    }
  };
  window.PrivateWebViewHandler = {
    postEvent: function(name, data){ post(name, data, true); },
    resolveShare: function(){}
  };
  if (!window.AndroidPerf) {
    window.AndroidPerf = { trackFcp: function(){} };
  }
})();
''';

class WebAppBridge {
  static final Object _requestGenerationKey = Object();
  int _documentGeneration = 0;
  bool _disposed = false;

  bool get _requestIsCurrent =>
      !_disposed &&
      (originPolicy == null || _trustedDocument) &&
      (Zone.current[_requestGenerationKey] == null ||
          Zone.current[_requestGenerationKey] == _documentGeneration);

  Future<bool> _authorizedRequest() async {
    if (!_requestIsCurrent) return false;
    final active =
        accountId == null ||
        await TokenStorage.getActiveAccountId() == accountId;
    return active && _requestIsCurrent;
  }

  WebAppBridge({
    required this.botId,
    required this.entryPoint,
    required this.contextResolver,
    required this.viewportResolver,
    required this.onClose,
    required this.onRestart,
    this.privateChannel = false,
    this.mobileIdVerifier,
    this.emitter,
    this.originPolicy,
    this.accountId,
    WebAppBiometry? biometry,
    String? Function()? deviceIdResolver,
  }) : biometry = biometry ?? DeviceWebAppBiometry(contextResolver),
       deviceIdResolver = deviceIdResolver ?? _sessionDeviceId;

  final int botId;
  final String entryPoint;
  final BuildContext? Function() contextResolver;
  final Size Function() viewportResolver;
  final VoidCallback onClose;
  final VoidCallback onRestart;
  final bool privateChannel;
  final WebAppMobileIdVerifier? mobileIdVerifier;
  final WebAppEmitter? emitter;
  final WebAppBiometry biometry;
  final String? Function() deviceIdResolver;

  static String? _sessionDeviceId() => api.deviceId;
  final WebAppOriginPolicy? originPolicy;
  final int? accountId;
  bool _trustedDocument = false;

  InAppWebViewController? _controller;
  DateTime? _lastGesture;
  bool _customBackButton = false;
  bool _closeConfirmation = false;

  bool get handlesBackButton => _customBackButton;

  bool get needsCloseConfirmation => _closeConfirmation;

  UserScript get userScript => UserScript(
    source: _shim,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: true,
    allowedOriginRules: originPolicy == null
        ? <String>{}
        : {originPolicy!.origin},
  );

  Future<void> attach(InAppWebViewController controller) async {
    if (defaultTargetPlatform == TargetPlatform.linux || kIsWeb) {
      throw UnsupportedError('Secure mini-app bridge is unavailable');
    }
    _disposed = false;
    _controller = controller;
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await WebViewFeature.isFeatureSupported(
        WebViewFeature.WEB_MESSAGE_LISTENER,
      )) {
        throw UnsupportedError(
          'Update Android System WebView to open mini-apps',
        );
      }
      await controller.addWebMessageListener(
        WebMessageListener(
          jsObjectName: '__kometWebAppNative',
          allowedOriginRules: {originPolicy!.origin},
          onPostMessage: (message, sourceOrigin, isMainFrame, replyProxy) {
            if (!_trustedDocument ||
                sourceOrigin == null ||
                !originPolicy!.accepts(
                  sourceOrigin,
                  isMainFrame: isMainFrame,
                )) {
              return;
            }
            final raw = message?.data;
            if (raw is! String || raw.length > 65536) return;
            try {
              final args = jsonDecode(raw);
              if (args is! List ||
                  args.length != 3 ||
                  args[0] is! String ||
                  (args[1] != null && args[1] is! String) ||
                  args[2] is! bool) {
                return;
              }
              handleEvent(
                args[0] as String,
                args[1] as String?,
                args[2] as bool,
              );
            } on FormatException {
              return;
            }
          },
        ),
      );
      return;
    }
    controller.addJavaScriptHandler(
      handlerName: 'webAppEvent',
      callback: (JavaScriptHandlerFunctionData data) {
        if (!_trustedDocument ||
            originPolicy?.accepts(
                  Uri.parse(data.origin.toString()),
                  isMainFrame: data.isMainFrame,
                ) !=
                true) {
          return null;
        }
        final args = data.args;
        final name = args.isNotEmpty ? args[0]?.toString() : null;
        if (name == null || name.isEmpty) return null;
        final raw = args.length > 1 ? args[1]?.toString() : null;
        final private = args.length > 2 && args[2] == true;
        handleEvent(name, raw, private);
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'webAppResolveShare',
      callback: (JavaScriptHandlerFunctionData data) => null,
    );
  }

  void registerGesture() {
    if (_trustedDocument || originPolicy == null) _lastGesture = DateTime.now();
  }

  void documentStarted(Uri? uri) {
    _documentGeneration++;
    _lastGesture = null;
    _trustedDocument = uri != null && originPolicy?.accepts(uri) == true;
  }

  void notifyBackPressed() => _send('WebAppBackButtonPressed', const {});

  void dispose() {
    _disposed = true;
    _documentGeneration++;
    _controller = null;
  }

  void _send(
    String method,
    Map<String, dynamic> data, {
    bool private = false,
  }) async {
    if (!_requestIsCurrent) return;
    final payload = jsonEncode(data);
    final custom = emitter;
    if (custom != null) {
      custom(method, payload, private);
      return;
    }
    final controller = _controller;
    if (controller == null || !_trustedDocument) return;
    try {
      final url = await controller.getUrl();
      if (url == null ||
          originPolicy?.accepts(Uri.parse(url.toString())) != true ||
          !identical(controller, _controller) ||
          !_requestIsCurrent) {
        return;
      }
      if (accountId != null &&
          await TokenStorage.getActiveAccountId() != accountId) {
        return;
      }
      if (!_requestIsCurrent) return;
      await controller.evaluateJavascript(
        source:
            'if (window === window.top && '
            'location.origin === ${jsonEncode(originPolicy?.origin)}) {'
            'window.__kometWebAppDeliver('
            '${jsonEncode(method)}, ${jsonEncode(payload)}, $private);}',
      );
    } catch (error) {
      logger.w('webapp delivery: $error');
    }
  }

  void _ok(
    String method,
    String? requestId,
    String status, {
    bool private = false,
  }) {
    _send(method, {
      'status': status,
      'requestId': ?requestId,
    }, private: private);
  }

  void _fail(
    String method,
    String? requestId,
    String reason, {
    bool private = false,
  }) {
    if (requestId == null) return;
    final slug = _methodSlugs[method] ?? 'unsupported_method';
    _send(method, {
      'requestId': requestId,
      'error': {'code': 'client.$slug.$reason'},
    }, private: private);
  }

  Future<void> handleEvent(String method, String? raw, bool private) =>
      runZoned(
        () => _handleEvent(method, raw, private),
        zoneValues: {_requestGenerationKey: _documentGeneration},
      );

  Future<void> _handleEvent(String method, String? raw, bool private) async {
    if (!await _authorizedRequest()) return;
    if (accountId != null &&
        await TokenStorage.getActiveAccountId() != accountId) {
      return;
    }
    if (private && !privateChannel) return;
    if (_gestureGated.contains(method) && !_hasRecentGesture) return;

    Map<String, dynamic> data = const {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        _fail(method, null, 'json_decode_error', private: private);
        return;
      }
    }
    final requestId = data['requestId']?.toString();

    switch (method) {
      case 'WebAppClose':
        onClose();
        return;
      case 'WebAppSetupBackButton':
        _customBackButton = data['isVisible'] == true;
        return;
      case 'WebAppSetupClosingBehavior':
        _closeConfirmation = data['needConfirmation'] == true;
        return;
      case 'WebAppSetupScreenCaptureBehavior':
        _send(method, {
          'requestId': ?requestId,
          'isScreenCaptureEnabled': data['isScreenCaptureEnabled'] == true,
        });
        return;
      case 'WebAppGetLaunchContext':
        _send(method, {'requestId': ?requestId, 'entryPoint': entryPoint});
        return;
      case 'WebAppGetViewportSize':
        final size = viewportResolver();
        _send(method, {
          'requestId': ?requestId,
          'height': size.height.round(),
          'width': size.width.round(),
          'isStateStable': true,
        });
        return;
      case 'WebAppRequestPhone':
        await _requestPhone(method, requestId);
        return;
      case 'WebAppOpenLink':
      case 'WebAppOpenMaxLink':
        await _openLink(data['url']?.toString());
        return;
      case 'WebAppShare':
        await _share(method, requestId, data);
        return;
      case 'WebAppMaxShare':
        await _maxShare(method, requestId, data);
        return;
      case 'WebAppDeviceStorageSaveKey':
      case 'WebAppSecureStorageSaveKey':
        await _storageSave(method, requestId, data);
        return;
      case 'WebAppDeviceStorageGetKey':
      case 'WebAppSecureStorageGetKey':
        await _storageGet(method, requestId, data);
        return;
      case 'WebAppDeviceStorageClear':
      case 'WebAppSecureStorageClear':
        await _storageClear(method, requestId);
        return;
      case 'WebAppBiometryGetInfo':
        await _biometryInfo(method, requestId, private);
        return;
      case 'WebAppBiometryRequestAccess':
        await _biometryRequestAccess(method, requestId, data, private);
        return;
      case 'WebAppBiometryRequestAuth':
        await _biometryAuth(method, requestId, data, private);
        return;
      case 'WebAppBiometryUpdateToken':
        await _biometryUpdateToken(method, requestId, data, private);
        return;
      case 'WebAppBiometryOpenSettings':
        await _biometryOpenSettings(method, requestId, private);
        return;
      case 'WebAppHapticFeedbackImpact':
        await _impact(data['impactStyle']?.toString());
        _ok(method, requestId, 'impactOccured');
        return;
      case 'WebAppHapticFeedbackNotification':
        await _notification(data['notificationType']?.toString());
        _ok(method, requestId, 'notificationOccured');
        return;
      case 'WebAppHapticFeedbackSelectionChange':
        await Haptics.selection();
        _ok(method, requestId, 'selectionChanged');
        return;
      case 'WebAppDownloadFile':
        await _downloadFile(method, requestId, data);
        return;
      case 'WebAppOpenCodeReader':
        await _openCodeReader(method, requestId);
        return;
      case 'WebAppNfcGetInfo':
        _send(method, {
          'requestId': ?requestId,
          'available': false,
          'enabled': false,
        });
        return;
      case 'WebAppVerifyMobileId':
        await _verifyMobileId(method, requestId, data, private);
        return;
      case 'WebAppChangeScreenBrightness':
      case 'WebAppNfcEmulateNfcTag':
      case 'WebAppNfcOpenSystemSettings':
        _fail(method, requestId, 'not_supported', private: private);
        return;
      default:
        if (_silentMethods.contains(method)) return;
        _fail(method, requestId, 'unsupported_method', private: private);
    }
  }

  bool get _hasRecentGesture {
    final last = _lastGesture;
    if (last == null) return false;
    return DateTime.now().difference(last) < _gestureWindow;
  }

  Future<void> _requestPhone(String method, String? requestId) async {
    final context = contextResolver();
    if (context == null) {
      _fail(method, requestId, 'request_error');
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.webAppPhoneRequestTitle,
      message: l10n.webAppPhoneRequestMessage,
      confirmLabel: l10n.webAppPhoneRequestShare,
      cancelLabel: l10n.joinRequestsDecline,
    );
    if (!confirmed) {
      _fail(method, requestId, 'user_refused_provide_phone_number');
      return;
    }
    try {
      if (!await _authorizedRequest()) return;
      final phone = await webAppModule.requestPhone(botId);
      _send(method, {
        'requestId': ?requestId,
        'phone': phone.phone,
        'hash': phone.hash,
        'authDate': phone.authDate,
      });
    } catch (_) {
      _fail(method, requestId, 'request_error');
    }
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final context = contextResolver();
    if (context == null) return;
    if (!await _authorizedRequest()) return;
    if (!context.mounted) return;
    await openExternalUrl(context, url, fromWebContent: true);
  }

  Future<void> _share(
    String method,
    String? requestId,
    Map<String, dynamic> data,
  ) async {
    final text = _shareText(data);
    if (text == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    try {
      final result = await AppLock.instance.external(
        () => Share.share(
          text,
          sharePositionOrigin: shareOriginOf(contextResolver()),
        ),
      );
      _send(method, {
        'requestId': ?requestId,
        'status': result.status == ShareResultStatus.dismissed
            ? 'cancelled'
            : 'shared',
      });
    } catch (_) {
      _fail(method, requestId, 'invalid_request');
    }
  }

  Future<void> _maxShare(
    String method,
    String? requestId,
    Map<String, dynamic> data,
  ) async {
    final text = _shareText(data);
    if (text == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final context = contextResolver();
    if (context == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final session = api.session;
    final target = await openForwardScreen(context: context);
    if (target == null) {
      _send(method, {'requestId': ?requestId, 'status': 'cancelled'});
      return;
    }
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    try {
      await OutgoingMessagePolicy.load(accountId);
      if (accountId != await TokenStorage.getActiveAccountId()) {
        throw StateError('Account changed');
      }
      if (!await _authorizedRequest()) return;
      await messagesModule.sendMessage(
        accountId,
        target.chatId,
        text,
        beforeSend: () {
          if (session == null || !identical(api.session, session)) {
            throw StateError('Account changed');
          }
          OutgoingMessagePolicy.requireSupported(accountId, target.chatId);
        },
      );
      _send(method, {'requestId': ?requestId, 'status': 'shared'});
    } catch (_) {
      _fail(method, requestId, 'invalid_request');
    }
  }

  String? _shareText(Map<String, dynamic> data) {
    final text = data['text']?.toString();
    final link = data['link']?.toString();
    final parts = [
      if (text != null && text.isNotEmpty) text,
      if (link != null && link.isNotEmpty) link,
    ];
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  WebAppStorageBackend _backendOf(String method) =>
      method.startsWith('WebAppSecure')
      ? WebAppStorageBackend.secure
      : WebAppStorageBackend.device;

  Future<void> _storageSave(
    String method,
    String? requestId,
    Map<String, dynamic> data,
  ) async {
    final key = data['key']?.toString();
    if (key == null || key.isEmpty) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final backend = _backendOf(method);
    final value = data['value'];
    if (value == null) {
      if (!await _authorizedRequest()) return;
      await WebAppStorage.remove(accountId, botId, backend, key);
      _ok(method, requestId, 'removed');
      return;
    }
    if (!await _authorizedRequest()) return;
    final saved = await WebAppStorage.save(
      accountId,
      botId,
      backend,
      key,
      value.toString(),
    );
    if (!saved) {
      _fail(method, requestId, 'too_many_keys');
      return;
    }
    _ok(method, requestId, 'updated');
  }

  Future<void> _storageGet(
    String method,
    String? requestId,
    Map<String, dynamic> data,
  ) async {
    final key = data['key']?.toString();
    if (key == null || key.isEmpty) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final value = await WebAppStorage.read(
      accountId,
      botId,
      _backendOf(method),
      key,
    );
    if (value == null) {
      _fail(method, requestId, 'not_found');
      return;
    }
    _send(method, {'requestId': ?requestId, 'key': key, 'value': value});
  }

  Future<void> _storageClear(String method, String? requestId) async {
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    if (!await _authorizedRequest()) return;
    await WebAppStorage.clear(accountId, botId, _backendOf(method));
    _ok(method, requestId, 'cleared');
  }

  static const int _biometryReasonLimit = 128;
  static const int _biometryTokenLimit = 1024;

  String? _biometryReason(Map<String, dynamic> data) {
    final reason = data['reason']?.toString().trim();
    if (reason == null || reason.isEmpty) return null;
    return reason.length > _biometryReasonLimit
        ? reason.substring(0, _biometryReasonLimit)
        : reason;
  }

  Future<Map<String, dynamic>> _biometryState(int? accountId) async {
    final deviceId = deviceIdResolver();
    if (accountId == null) {
      return {
        'available': false,
        'type': const ['unknown'],
        'accessRequested': false,
        'accessGranted': false,
        'tokenSaved': false,
        'deviceId': deviceId,
      };
    }
    final types = await biometry.types();
    final (requested, granted) = await WebAppStorage.biometryAccess(
      accountId,
      botId,
    );
    final token = await WebAppStorage.biometryToken(accountId, botId);
    return {
      'available': types.isNotEmpty,
      'type': types.isEmpty ? const ['unknown'] : types,
      'accessRequested': requested,
      'accessGranted': granted,
      'tokenSaved': token != null,
      'deviceId': deviceId,
    };
  }

  Future<void> _biometryInfo(
    String method,
    String? requestId,
    bool private,
  ) async {
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    _send(method, {
      'requestId': ?requestId,
      ...await _biometryState(accountId),
    }, private: private);
  }

  Future<void> _biometryRequestAccess(
    String method,
    String? requestId,
    Map<String, dynamic> data,
    bool private,
  ) async {
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'access_denied', private: private);
      return;
    }
    if ((await biometry.types()).isEmpty) {
      _fail(method, requestId, 'not_supported', private: private);
      return;
    }
    final (requested, _) = await WebAppStorage.biometryAccess(accountId, botId);
    if (!requested) {
      final allowed = await biometry.confirmAccess(_biometryReason(data));
      if (allowed == null) {
        _fail(method, requestId, 'request_error', private: private);
        return;
      }
      if (!await _authorizedRequest()) return;
      await WebAppStorage.setBiometryAccess(
        accountId,
        botId,
        requested: true,
        granted: allowed,
      );
    }
    _send(method, {
      'requestId': ?requestId,
      ...await _biometryState(accountId),
    }, private: private);
  }

  Future<void> _biometryAuth(
    String method,
    String? requestId,
    Map<String, dynamic> data,
    bool private,
  ) async {
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'access_denied', private: private);
      return;
    }
    if ((await biometry.types()).isEmpty) {
      _fail(method, requestId, 'not_supported', private: private);
      return;
    }
    final (_, granted) = await WebAppStorage.biometryAccess(accountId, botId);
    if (!granted) {
      _fail(method, requestId, 'permission_denied', private: private);
      return;
    }
    final token = await WebAppStorage.biometryToken(accountId, botId);
    if (token == null) {
      _fail(method, requestId, 'token_not_found', private: private);
      return;
    }
    if (!await biometry.authenticate(_biometryReason(data))) {
      _fail(method, requestId, 'access_denied', private: private);
      return;
    }
    _send(method, {
      'requestId': ?requestId,
      'status': 'authorized',
      'token': token,
    }, private: private);
  }

  Future<void> _biometryUpdateToken(
    String method,
    String? requestId,
    Map<String, dynamic> data,
    bool private,
  ) async {
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'access_denied', private: private);
      return;
    }
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      if (!await _authorizedRequest()) return;
      await WebAppStorage.removeBiometryToken(accountId, botId);
      _ok(method, requestId, 'removed', private: private);
      return;
    }
    if (token.length > _biometryTokenLimit) {
      _fail(method, requestId, 'too_large', private: private);
      return;
    }
    if ((await biometry.types()).isEmpty) {
      _fail(method, requestId, 'not_supported', private: private);
      return;
    }
    final (_, granted) = await WebAppStorage.biometryAccess(accountId, botId);
    if (!granted) {
      _fail(method, requestId, 'permission_denied', private: private);
      return;
    }
    if (!await biometry.authenticate(_biometryReason(data))) {
      _fail(method, requestId, 'permission_denied', private: private);
      return;
    }
    if (!await _authorizedRequest()) return;
    await WebAppStorage.saveBiometryToken(accountId, botId, token);
    _ok(method, requestId, 'updated', private: private);
  }

  Future<void> _biometryOpenSettings(
    String method,
    String? requestId,
    bool private,
  ) async {
    final accountId = this.accountId ?? await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'access_denied', private: private);
      return;
    }
    if ((await biometry.types()).isEmpty) {
      _fail(method, requestId, 'not_supported', private: private);
      return;
    }
    final (_, granted) = await WebAppStorage.biometryAccess(accountId, botId);
    final allowed = await biometry.confirmAccess(null);
    if (allowed == null) {
      _fail(method, requestId, 'request_error', private: private);
      return;
    }
    if (!await _authorizedRequest()) return;
    await WebAppStorage.setBiometryAccess(
      accountId,
      botId,
      requested: true,
      granted: allowed,
    );
    _ok(method, requestId, 'opened', private: private);
    if (allowed != granted) onRestart();
  }

  Future<void> _impact(String? style) async {
    switch (style) {
      case 'heavy':
      case 'rigid':
        await Haptics.heavy();
        return;
      case 'medium':
        await Haptics.medium();
        return;
      default:
        await Haptics.tap();
    }
  }

  Future<void> _notification(String? type) async {
    if (type == 'error') {
      await Haptics.error();
      return;
    }
    await Haptics.success();
  }

  Future<void> _downloadFile(
    String method,
    String? requestId,
    Map<String, dynamic> data,
  ) async {
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final rawName = data['file_name']?.toString();
    final name = (rawName == null || rawName.isEmpty)
        ? 'webapp_${DateTime.now().millisecondsSinceEpoch}'
        : rawName;
    final result = await saveMediaFile(
      cacheName: 'webapp_${botId}_${url.hashCode & 0x7fffffff}_$name',
      resolveUrl: () async => url,
      saveName: name,
      kind: SaveMediaKind.file,
    );
    _send(method, {
      'requestId': ?requestId,
      'status': result.ok ? 'success' : 'cancelled',
    });
  }

  Future<void> _openCodeReader(String method, String? requestId) async {
    final context = contextResolver();
    if (context == null) {
      _fail(method, requestId, 'not_supported');
      return;
    }
    final value = await Navigator.of(context).push<String>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const WebQrScanScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (value == null || value.isEmpty) {
      _fail(method, requestId, 'cancelled');
      return;
    }
    _send(method, {'requestId': ?requestId, 'value': value});
  }

  Future<void> _verifyMobileId(
    String method,
    String? requestId,
    Map<String, dynamic> data,
    bool private,
  ) async {
    final verifier = mobileIdVerifier;
    final url = data['url']?.toString();
    if (verifier == null || url == null || url.isEmpty) {
      _fail(method, requestId, 'not_supported', private: private);
      return;
    }
    try {
      final result = await verifier(url);
      if (result == null) {
        _fail(method, requestId, 'request_error', private: private);
        return;
      }
      _send(method, {
        'requestId': ?requestId,
        'statusCode': result['statusCode'],
        'headers': result['headers'] ?? const <String, String>{},
        'data': result['data'] ?? '',
      }, private: private);
    } catch (_) {
      _fail(method, requestId, 'request_error', private: private);
    }
  }
}
