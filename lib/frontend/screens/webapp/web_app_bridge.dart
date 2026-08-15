import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/storage/webapp_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/media_saver.dart';
import '../../../main.dart' show api, messagesModule, webAppModule;
import '../../widgets/confirm_dialog.dart';
import '../chats/chat_list_screen.dart' show openForwardScreen;
import '../profile/web_qr_scan_screen.dart';

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

typedef WebAppMobileIdVerifier = Future<Map<String, dynamic>?> Function(
  String url,
);

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
      window.flutter_inappwebview.callHandler('webAppEvent', name, data, priv);
    } catch (e) {}
  }
  var lastGesture = 0;
  function gesture(){
    var now = Date.now();
    if (now - lastGesture < 400) { return; }
    lastGesture = now;
    try { window.flutter_inappwebview.callHandler('webAppGesture'); } catch (e) {}
  }
  ['touchstart', 'pointerdown', 'mousedown', 'click'].forEach(function(name){
    try { document.addEventListener(name, gesture, true); } catch (e) {}
  });
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
  WebAppBridge({
    required this.botId,
    required this.entryPoint,
    required this.contextResolver,
    required this.viewportResolver,
    required this.onClose,
    this.privateChannel = false,
    this.mobileIdVerifier,
    this.emitter,
  });

  final int botId;
  final String entryPoint;
  final BuildContext? Function() contextResolver;
  final Size Function() viewportResolver;
  final VoidCallback onClose;
  final bool privateChannel;
  final WebAppMobileIdVerifier? mobileIdVerifier;
  final WebAppEmitter? emitter;

  InAppWebViewController? _controller;
  DateTime? _lastGesture;
  bool _customBackButton = false;
  bool _closeConfirmation = false;

  bool get handlesBackButton => _customBackButton;

  bool get needsCloseConfirmation => _closeConfirmation;

  UserScript get userScript => UserScript(
    source: _shim,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );

  void attach(InAppWebViewController controller) {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'webAppEvent',
      callback: (args) {
        final name = args.isNotEmpty ? args[0]?.toString() : null;
        if (name == null || name.isEmpty) return null;
        final raw = args.length > 1 ? args[1]?.toString() : null;
        final private = args.length > 2 && args[2] == true;
        handleEvent(name, raw, private);
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'webAppGesture',
      callback: (args) {
        registerGesture();
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'webAppResolveShare',
      callback: (args) => null,
    );
  }

  void registerGesture() => _lastGesture = DateTime.now();

  void notifyBackPressed() => _send('WebAppBackButtonPressed', const {});

  void dispose() => _controller = null;

  void _send(String method, Map<String, dynamic> data, {bool private = false}) {
    final payload = jsonEncode(data);
    final custom = emitter;
    if (custom != null) {
      custom(method, payload, private);
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    controller.evaluateJavascript(
      source:
          'window.__kometWebAppDeliver('
          '${jsonEncode(method)}, ${jsonEncode(payload)}, $private);',
    );
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

  Future<void> handleEvent(String method, String? raw, bool private) async {
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
        _send(method, {
          'requestId': ?requestId,
          'entryPoint': entryPoint,
        });
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
        await _biometryInfo(method, requestId);
        return;
      case 'WebAppBiometryRequestAccess':
      case 'WebAppBiometryRequestAuth':
        await _biometryAuth(method, requestId);
        return;
      case 'WebAppBiometryUpdateToken':
        await _biometryUpdateToken(method, requestId, data);
        return;
      case 'WebAppBiometryOpenSettings':
        _ok(method, requestId, 'opened');
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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Передать номер телефона?',
      message: 'Мини-приложение получит ваш номер телефона.',
      confirmLabel: 'Поделиться',
      cancelLabel: 'Отклонить',
    );
    if (!confirmed) {
      _fail(method, requestId, 'user_refused_provide_phone_number');
      return;
    }
    try {
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
    await openExternalUrl(context, url);
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
      final result = await Share.share(text);
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
    final target = await openForwardScreen(context: context);
    if (target == null) {
      _send(method, {
        'requestId': ?requestId,
        'status': 'cancelled',
      });
      return;
    }
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    try {
      await messagesModule.sendMessage(accountId, target.chatId, text);
      _send(method, {
        'requestId': ?requestId,
        'status': 'shared',
      });
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
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    final backend = _backendOf(method);
    final value = data['value'];
    if (value == null) {
      await WebAppStorage.remove(accountId, botId, backend, key);
      _ok(method, requestId, 'removed');
      return;
    }
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
    final accountId = await TokenStorage.getActiveAccountId();
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
    _send(method, {
      'requestId': ?requestId,
      'key': key,
      'value': value,
    });
  }

  Future<void> _storageClear(String method, String? requestId) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'invalid_request');
      return;
    }
    await WebAppStorage.clear(accountId, botId, _backendOf(method));
    _ok(method, requestId, 'cleared');
  }

  Future<void> _biometryInfo(String method, String? requestId) async {
    final accountId = await TokenStorage.getActiveAccountId();
    final deviceId = api.deviceId ?? '';
    if (accountId == null) {
      _send(method, {
        'requestId': ?requestId,
        'available': false,
        'deviceId': deviceId,
      });
      return;
    }
    final (requested, granted) = await WebAppStorage.biometryAccess(
      accountId,
      botId,
    );
    final token = await WebAppStorage.biometryToken(accountId, botId);
    _send(method, {
      'requestId': ?requestId,
      'available': true,
      'type': const ['unknown'],
      'accessRequested': requested,
      'accessGranted': granted,
      'tokenSaved': token != null,
      'deviceId': deviceId,
    });
  }

  Future<void> _biometryAuth(String method, String? requestId) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'access_denied');
      return;
    }
    var token = await WebAppStorage.biometryToken(accountId, botId);
    if (token == null) {
      token = _randomToken();
      await WebAppStorage.saveBiometryToken(accountId, botId, token);
    }
    await WebAppStorage.setBiometryAccess(
      accountId,
      botId,
      requested: true,
      granted: true,
    );
    _send(method, {
      'requestId': ?requestId,
      'token': token,
      'status': 'authorized',
      'granted': true,
      'accessGranted': true,
    });
  }

  Future<void> _biometryUpdateToken(
    String method,
    String? requestId,
    Map<String, dynamic> data,
  ) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      _fail(method, requestId, 'access_denied');
      return;
    }
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      await WebAppStorage.removeBiometryToken(accountId, botId);
      _ok(method, requestId, 'removed');
      return;
    }
    if (token.length > 1024) {
      _fail(method, requestId, 'too_large');
      return;
    }
    await WebAppStorage.saveBiometryToken(accountId, botId, token);
    _ok(method, requestId, 'updated');
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
    _send(method, {
      'requestId': ?requestId,
      'value': value,
    });
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

  static String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
