import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/webapp.dart';
import '../../../main.dart' show webAppModule;

Future<void> resetDigitalIdWebData() async {
  await CookieManager.instance().deleteAllCookies();
  try {
    await WebStorageManager.instance().deleteAllData();
  } catch (_) {}
}

const String _kBridge = r'''
(function(){
  var sawOpenLink = false;
  function ssKey(k){ return 'komet_did_ss_' + k; }
  function userId(){
    try {
      var h = decodeURIComponent(decodeURIComponent(location.hash || ''));
      var m = h.match(/"id"\s*:\s*(\d+)/);
      if (m) return m[1];
    } catch(e){}
    try {
      var m2 = (location.hash || '').match(/id\W{1,8}?(\d{4,})/);
      if (m2) return m2[1];
    } catch(e){}
    return 'anon';
  }
  try {
    var uid = userId();
    if (localStorage.getItem('komet_did_owner') !== uid) {
      try { localStorage.clear(); } catch(e){}
      try { sessionStorage.clear(); } catch(e){}
      try {
        if (window.indexedDB && indexedDB.databases) {
          indexedDB.databases().then(function(dbs){
            (dbs || []).forEach(function(db){ try { indexedDB.deleteDatabase(db.name); } catch(e){} });
          });
        }
      } catch(e){}
      localStorage.setItem('komet_did_owner', uid);
    }
  } catch(e){}
  function reply(type, data){
    setTimeout(function(){
      try { window.WebApp.receiveEvent(type, data); } catch(e){}
    }, 0);
  }
  function bioToken(){
    try {
      var k = 'komet_did_bio_token';
      var v = localStorage.getItem(k);
      if (!v) {
        v = '';
        for (var i = 0; i < 32; i++) v += Math.floor(Math.random() * 16).toString(16);
        localStorage.setItem(k, v);
      }
      return v;
    } catch(e){ return 'komet-did-fallback-token'; }
  }
  function tokenSaved(){
    try { return !!localStorage.getItem('komet_did_bio_token'); } catch(e){ return false; }
  }
  function handle(type, dataStr){
    var data = {};
    try { data = JSON.parse(dataStr || '{}'); } catch(e){}
    var requestId = data.requestId;
    switch (type) {
      case 'WebAppBiometryGetInfo':
        reply(type, {
          requestId: requestId, available: true,
          access_requested: tokenSaved(), accessRequested: tokenSaved(),
          access_granted: tokenSaved(), accessGranted: tokenSaved(),
          token_saved: tokenSaved(), tokenSaved: tokenSaved(),
          device_id: 'komet-device', deviceId: 'komet-device',
          type: 'face', biometricType: 'face'
        });
        return;
      case 'WebAppBiometryRequestAccess':
        reply(type, { requestId: requestId, granted: true, access_granted: true, accessGranted: true, status: 'granted' });
        return;
      case 'WebAppBiometryAuthenticate':
        reply(type, { requestId: requestId, token: bioToken(), success: true, status: 'authenticated' });
        return;
      case 'WebAppBiometryUpdateToken':
      case 'WebAppBiometryUpdateBiometricToken':
        reply(type, { requestId: requestId, success: true, status: 'updated' });
        return;
      case 'WebAppOpenLink':
        sawOpenLink = true;
        if (data && data.url) {
          setTimeout(function(){
            try { window.location.assign(data.url); } catch(e){}
          }, 0);
        }
        return;
      case 'WebAppClose':
        if (!sawOpenLink) {
          try { window.flutter_inappwebview.callHandler('closeWebApp'); } catch(e){}
        }
        return;
      default:
        if (type.indexOf('SecureStorage') >= 0 || type.indexOf('DeviceStorage') >= 0) {
          var key = data.key;
          if (/Set|Save|Put/i.test(type)) {
            try { localStorage.setItem(ssKey(key), JSON.stringify(data.value !== undefined ? data.value : null)); } catch(e){}
            reply(type, { requestId: requestId, success: true });
          } else if (/Remove|Delete|Clear/i.test(type)) {
            try { localStorage.removeItem(ssKey(key)); } catch(e){}
            reply(type, { requestId: requestId, success: true });
          } else {
            var val = null;
            try {
              var raw = localStorage.getItem(ssKey(key));
              val = (raw == null) ? null : JSON.parse(raw);
            } catch(e){}
            reply(type, { requestId: requestId, value: val, data: val });
          }
          return;
        }
        if (requestId != null) reply(type, { requestId: requestId });
    }
  }
  try {
    window.WebViewHandler = {
      postEvent: function(type, dataStr){
        try { handle(type, dataStr); } catch(e){}
      }
    };
  } catch(e){}
})();
''';

class DigitalIdWebScreen extends StatefulWidget {
  const DigitalIdWebScreen({super.key});

  @override
  State<DigitalIdWebScreen> createState() => _DigitalIdWebScreenState();
}

class _DigitalIdWebScreenState extends State<DigitalIdWebScreen> {
  InAppWebViewController? _controller;
  WebAppLaunch? _launch;
  String? _loadError;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _launch = null;
    });
    try {
      final launch = await webAppModule.fetchDigitalId();
      if (!mounted) return;
      setState(() => _launch = launch);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  Future<bool> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _handleBack()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Цифровой ID'),
          leading: IconButton(
            icon: const Icon(Symbols.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Symbols.refresh),
              onPressed: _launch == null ? null : () => _controller?.reload(),
            ),
          ],
          bottom: _progress > 0 && _progress < 1
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        body: _buildBody(cs),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loadError != null) {
      return _ErrorView(message: _loadError!, onRetry: _load);
    }
    final launch = _launch;
    if (launch == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(launch.url)),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _kBridge,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
        supportZoom: false,
        transparentBackground: true,
        mediaPlaybackRequiresUserGesture: false,
        useHybridComposition: true,
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: 'closeWebApp',
          callback: (args) {
            if (mounted) Navigator.of(context).maybePop();
            return null;
          },
        );
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final uri = action.request.url;
        final url = uri?.toString() ?? '';
        final scheme = uri?.scheme ?? '';
        final isCallback = url.contains('externalCallback');
        if (isCallback || (scheme != 'http' && scheme != 'https')) {
          final launchUrl = _launch?.url ?? 'https://digital-id.max.ru';
          final hashIdx = launchUrl.indexOf('#');
          final base = hashIdx >= 0 ? launchUrl.substring(0, hashIdx) : launchUrl;
          final frag = hashIdx >= 0 ? launchUrl.substring(hashIdx) : '';
          final query = uri?.query ?? '';
          final target = query.isEmpty ? launchUrl : '$base?$query$frag';
          controller.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onProgressChanged: (controller, progress) {
        if (!mounted) return;
        setState(() => _progress = progress / 100);
      },
      onReceivedError: (controller, request, error) {
        if (!mounted) return;
        if (request.isForMainFrame ?? false) {
          setState(() => _loadError = error.description);
        }
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.cloud_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
