import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../main.dart' show webAppModule, digitalIdModule;
import '../webapp/web_app_screen.dart';

Future<void> resetDigitalIdWebData() async {
  await CookieManager.instance().deleteAllCookies();
  try {
    await WebStorageManager.instance().deleteAllData();
  } catch (_) {}
}

Future<void> resetDigitalIdSession() async {
  digitalIdModule.reset();
  try {
    await resetDigitalIdWebData();
  } catch (_) {}
}

const String _kBridge = r'''
(function(){
  var sawOpenLink = false;
  var DBG = !!window.__KOMET_DID_DEBUG;
  function log(m){ if (!DBG) return; try { console.log('[BRIDGE] ' + m); } catch(e){} }
  if (DBG) {
    try {
      var origFetch = window.fetch;
      window.fetch = function(){
        var u;
        try { u = (typeof arguments[0] === 'string') ? arguments[0] : (arguments[0] && arguments[0].url); } catch(e){}
        var watched = ('' + u).indexOf('ext-api') >= 0;
        return origFetch.apply(this, arguments).then(function(r){
          if (watched) {
            try { r.clone().text().then(function(t){ log('FETCH ' + r.status + ' ' + u + ' :: ' + t.slice(0, 200)); }); } catch(e){}
          }
          return r;
        }).catch(function(err){ if (watched) log('FETCH ERR ' + u + ' ' + err); throw err; });
      };
    } catch(e){}
  }
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
    log('recv ' + type + ' ' + dataStr);
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

class DigitalIdWebScreen extends StatelessWidget {
  const DigitalIdWebScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WebAppScreen(
      title: 'Цифровой ID',
      loader: () => webAppModule.fetchDigitalId(),
      extraUserScripts: [
        UserScript(
          source: 'window.__KOMET_DID_DEBUG=$kDebugMode;',
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
        UserScript(
          source: _kBridge,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ],
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'closeWebApp',
          callback: (args) {
            if (context.mounted) Navigator.of(context).maybePop();
            return null;
          },
        );
      },
      onConsoleMessage: kDebugMode
          ? (controller, consoleMessage) {
              debugPrint('[KOMET-DID] ${consoleMessage.message}');
            }
          : null,
      onLoadStart: kDebugMode
          ? (controller, url) {
              final u = url?.toString() ?? '';
              debugPrint(
                '[KOMET-DID] loadStart: ${u.length > 160 ? u.substring(0, 160) : u}',
              );
            }
          : null,
      shouldOverrideUrlLoading: (controller, action, currentUrl) async {
        final uri = action.request.url;
        final url = uri?.toString() ?? '';
        final scheme = uri?.scheme ?? '';
        if (kDebugMode) {
          debugPrint(
            '[KOMET-DID] nav: ${url.length > 140 ? url.substring(0, 140) : url}',
          );
        }
        final isCallback =
            url.contains('?externalCallback=') ||
            url.contains('&externalCallback=');
        if (isCallback || (scheme != 'http' && scheme != 'https')) {
          final launchUrl = currentUrl ?? 'https://digital-id.max.ru';
          final hashIdx = launchUrl.indexOf('#');
          final base = hashIdx >= 0
              ? launchUrl.substring(0, hashIdx)
              : launchUrl;
          final frag = hashIdx >= 0 ? launchUrl.substring(hashIdx) : '';
          final query = uri?.query ?? '';
          final target = query.isEmpty ? launchUrl : '$base?$query$frag';
          controller.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }
}
