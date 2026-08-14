import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../backend/modules/webapp.dart' show WebAppLaunch;
import '../../../core/utils/logger.dart';
import '../../../main.dart' show api, webAppModule, digitalIdModule;
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
  if (!/(^|\.)max\.ru$/i.test(location.hostname)) { return; }
  var sawOpenLink = false;
  var DBG = !!window.__KOMET_DID_DEBUG;
  function log(m){ try { console.log('[BRIDGE] ' + m); } catch(e){} }
  try { log('UA ' + navigator.userAgent); } catch(e){}
  var lastTouch = 0;
  var lastExternalOpen = 0;
  try {
    ['touchstart','pointerdown','mousedown','click'].forEach(function(ev){
      document.addEventListener(ev, function(){ lastTouch = Date.now(); }, true);
    });
  } catch(e){}
  if (DBG) {
    try {
      var origFetch = window.fetch;
      window.fetch = function(){
        var u, method = 'GET';
        try {
          if (typeof arguments[0] === 'string') { u = arguments[0]; }
          else if (arguments[0]) { u = arguments[0].url; method = arguments[0].method || method; }
          if (arguments[1] && arguments[1].method) method = arguments[1].method;
        } catch(e){}
        var watched = ('' + u).indexOf('ext-api') >= 0 || ('' + u).indexOf('digital-id') >= 0 || ('' + u).indexOf('oneme.ru') >= 0;
        var path = ('' + u).split('?')[0];
        if (watched) {
          var body = '';
          try {
            if (arguments[1] && typeof arguments[1].body === 'string') body = arguments[1].body.slice(0, 300);
            else if (arguments[0] && arguments[0]._bodyInit && typeof arguments[0]._bodyInit === 'string') body = arguments[0]._bodyInit.slice(0, 300);
          } catch(e){}
          var auth = '';
          try {
            var h = (arguments[1] && arguments[1].headers) || (arguments[0] && arguments[0].headers);
            if (h) {
              if (typeof h.get === 'function') auth = h.get('Authorization') || h.get('authorization') || '';
              else if (typeof h.forEach === 'function') { h.forEach(function(v,k){ if (('' + k).toLowerCase() === 'authorization') auth = v; }); }
              else auth = h['Authorization'] || h['authorization'] || '';
            }
          } catch(e){}
          log('FETCH> ' + method + ' ' + path + (auth ? ' AUTH=[' + ('' + auth).slice(0, 70) + ']' : ' AUTH=none') + (body ? ' body=' + body : ''));
        }
        return origFetch.apply(this, arguments).then(function(r){
          if (watched) {
            try { r.clone().text().then(function(t){ log('FETCH< ' + r.status + ' ' + path + ' :: ' + t.slice(0, 500)); }); } catch(e){}
          }
          return r;
        }).catch(function(err){ if (watched) log('FETCH ERR ' + path + ' ' + err); throw err; });
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
    var prev = localStorage.getItem('komet_did_owner');
    log('owner check uid=' + uid + ' prev=' + prev);
    // Wipe ТОЛЬКО при реальной смене аккаунта (реальный id -> другой реальный id).
    // Никогда не чистим, когда id не удалось определить ('anon') или его не было —
    // иначе флапающий userId() стирает device-binding на каждом перезапуске (петля).
    if (uid !== 'anon' && prev && prev !== 'anon' && prev !== uid) {
      log('owner switch ' + prev + ' -> ' + uid + ' :: wiping did storage');
      try { localStorage.clear(); } catch(e){}
      try { sessionStorage.clear(); } catch(e){}
      try {
        if (window.indexedDB && indexedDB.databases) {
          indexedDB.databases().then(function(dbs){
            (dbs || []).forEach(function(db){ try { indexedDB.deleteDatabase(db.name); } catch(e){} });
          });
        }
      } catch(e){}
    }
    if (uid !== 'anon') { localStorage.setItem('komet_did_owner', uid); }
  } catch(e){}
  var pending = [];
  function chan(priv){
    var pub = (window.WebApp && typeof window.WebApp.sendEvent === 'function') ? window.WebApp : null;
    var prv = (window.PrivateWebApp && typeof window.PrivateWebApp.sendEvent === 'function') ? window.PrivateWebApp : null;
    if (priv) return prv;
    return pub || prv;
  }
  function flush(){
    if (!pending.length) return;
    var keep = [];
    for (var i = 0; i < pending.length; i++) {
      var it = pending[i];
      var t = chan(it[2]);
      if (!t) { keep.push(it); continue; }
      try { t.sendEvent(it[0], it[1]); } catch(e){ log('sendEvent err ' + e); keep.push(it); }
    }
    pending = keep;
  }
  setInterval(flush, 50);
  function reply(type, data, priv){
    var payload;
    try { payload = JSON.stringify(data == null ? {} : data); } catch(e){ payload = '{}'; }
    log('reply ' + (priv ? '[priv] ' : '') + type + ' ' + payload);
    pending.push([type, payload, !!priv]);
    setTimeout(flush, 0);
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
  function didDeviceId(){
    // Реальный device_id (как MAX: ANDROID_ID/persisted). Приоритет — прокинутый
    // из Dart стабильный per-install id (переопределяемый под реальный id из MAX);
    // фолбэк — стабильный 16-hex в localStorage (формат ANDROID_ID).
    try { if (window.__KOMET_DID_DEVICE_ID) return '' + window.__KOMET_DID_DEVICE_ID; } catch(e){}
    try {
      var k = 'komet_did_device_id';
      var v = localStorage.getItem(k);
      if (!v) {
        v = '';
        for (var i = 0; i < 16; i++) v += Math.floor(Math.random() * 16).toString(16);
        localStorage.setItem(k, v);
      }
      return v;
    } catch(e){ return 'komet-device'; }
  }
  var NO_REPLY = {
    WebAppReady: 1, WebAppSetupBackButton: 1, WebAppBackButtonPressed: 1,
    WebAppUrlInterceptor: 1, WebAppSetupClosingBehavior: 1, WebAppStat: 1,
    WebAppHapticFeedbackImpact: 1, WebAppHapticFeedbackNotification: 1,
    WebAppHapticFeedbackSelectionChange: 1
  };
  function handle(type, dataStr, priv){
    var data = {};
    try { data = JSON.parse(dataStr || '{}'); } catch(e){}
    log('recv ' + (priv ? '[priv] ' : '') + type + ' ' + dataStr);
    var requestId = data.requestId;
    switch (type) {
      case 'WebAppBiometryGetInfo':
        reply(type, {
          requestId: requestId, available: true,
          accessRequested: tokenSaved(), accessGranted: tokenSaved(),
          access_requested: tokenSaved(), access_granted: tokenSaved(),
          tokenSaved: tokenSaved(), token_saved: tokenSaved(),
          deviceId: didDeviceId(), device_id: didDeviceId(),
          type: ['face']
        });
        return;
      case 'WebAppBiometryRequestAccess':
        reply(type, { requestId: requestId, granted: true, access_granted: true, accessGranted: true, status: 'authorized' });
        return;
      case 'WebAppBiometryAuthenticate':
      case 'WebAppBiometryRequestAuth':
        reply(type, { requestId: requestId, token: bioToken(), success: true, status: 'authorized' });
        return;
      case 'WebAppBiometryUpdateToken':
      case 'WebAppBiometryUpdateBiometricToken':
        reply(type, { requestId: requestId, success: true, status: 'updated' });
        return;
      case 'WebAppGetLaunchContext':
        reply(type, { requestId: requestId, entryPoint: 'default' });
        return;
      case 'WebAppGetViewportSize':
        reply(type, { requestId: requestId, height: window.innerHeight, width: window.innerWidth, isStateStable: true });
        return;
      case 'WebAppSetupScreenCaptureBehavior':
        reply(type, { requestId: requestId, isScreenCaptureEnabled: !!data.isScreenCaptureEnabled });
        return;
      case 'WebAppRequestPhone':
        reply(type, { requestId: requestId, error: { code: 'client.request_phone.user_refused_provide_phone_number' } });
        return;
      case 'WebAppVerifyMobileId':
        (function(){
          try {
            window.flutter_inappwebview.callHandler('verifyMobileId', data.url).then(function(res){
              if (res && typeof res.statusCode !== 'undefined') {
                reply(type, { requestId: requestId, statusCode: res.statusCode, headers: res.headers || {}, data: res.data || '' }, true);
              } else {
                reply(type, { requestId: requestId, error: { code: 'client.verify_mobile_id.request_failed' } }, true);
              }
            }).catch(function(e){
              reply(type, { requestId: requestId, error: { code: 'client.verify_mobile_id.request_failed' } }, true);
            });
          } catch(e){
            reply(type, { requestId: requestId, error: { code: 'client.verify_mobile_id.json_decode_error' } }, true);
          }
        })();
        return;
      case 'WebAppOpenLink':
        sawOpenLink = true;
        var now = Date.now();
        if (data && data.url && (now - lastTouch < 8000) && (now - lastExternalOpen > 15000)) {
          lastExternalOpen = now;
          try { window.flutter_inappwebview.callHandler('openExternal', data.url); } catch(e){}
        } else {
          log('OpenLink dropped (gesture ' + (now - lastTouch) + 'ms, sinceOpen ' + (now - lastExternalOpen) + 'ms)');
        }
        return;
      case 'WebAppClose':
        return;
      default:
        if (type.indexOf('SecureStorage') >= 0 || type.indexOf('DeviceStorage') >= 0) {
          var backend = (type.indexOf('SecureStorage') >= 0) ? 's' : 'd';
          var pfx = 'komet_did_' + backend + '_';
          var key = data.key;
          if (/Set|Save|Put/i.test(type)) {
            try { localStorage.setItem(pfx + key, JSON.stringify(data.value !== undefined ? data.value : null)); } catch(e){}
            reply(type, { requestId: requestId, status: 'saved' });
          } else if (/Clear/i.test(type)) {
            try {
              var rm = [];
              for (var i = 0; i < localStorage.length; i++) { var k = localStorage.key(i); if (k && k.indexOf(pfx) === 0) rm.push(k); }
              for (var j = 0; j < rm.length; j++) localStorage.removeItem(rm[j]);
            } catch(e){}
            reply(type, { requestId: requestId, status: 'cleared' });
          } else if (/Remove|Delete/i.test(type)) {
            try { localStorage.removeItem(pfx + key); } catch(e){}
            reply(type, { requestId: requestId, status: 'removed' });
          } else {
            var val = null;
            try {
              var raw = localStorage.getItem(pfx + key);
              val = (raw == null) ? null : JSON.parse(raw);
            } catch(e){}
            reply(type, { requestId: requestId, key: key, value: val });
          }
          return;
        }
        if (NO_REPLY[type]) return;
        reply(type, { requestId: requestId });
    }
  }
  try {
    window.WebViewHandler = {
      postEvent: function(type, dataStr){ try { handle(type, dataStr, false); } catch(e){} },
      resolveShare: function(){}
    };
    window.PrivateWebViewHandler = {
      postEvent: function(type, dataStr){ try { handle(type, dataStr, true); } catch(e){} },
      resolveShare: function(){}
    };
    if (!window.AndroidPerf) window.AndroidPerf = { trackFcp: function(){} };
  } catch(e){}
})();
''';

class DigitalIdWebScreen extends StatelessWidget {
  final WebAppLaunch? initialLaunch;

  const DigitalIdWebScreen({super.key, this.initialLaunch});

  @override
  Widget build(BuildContext context) {
    // Тот же device_id, что уходит в handshake (опкод 6, sessionInit),
    // с учётом спуфинга — сервер привязывает Цифровой ID к device'у сессии.
    final deviceId = api.deviceId ?? '';
    return WebAppScreen(
      title: 'Цифровой ID',
      preferSystemUserAgent: true,
      loader: () async => initialLaunch ?? await webAppModule.fetchDigitalId(),
      extraUserScripts: [
        UserScript(
          source:
              'window.__KOMET_DID_DEBUG=$kDebugMode; window.__KOMET_DID_DEVICE_ID=${jsonEncode(deviceId)};',
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
        controller.addJavaScriptHandler(
          handlerName: 'openExternal',
          callback: (args) async {
            final url = args.isNotEmpty ? args.first?.toString() : null;
            final uri = (url != null && url.isNotEmpty) ? Uri.tryParse(url) : null;
            if (uri != null) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            }
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'verifyMobileId',
          callback: (args) async {
            final url = args.isNotEmpty ? args.first?.toString() : null;
            if (url == null || url.isEmpty) return null;
            return digitalIdModule.fetchMobileIdVerification(url);
          },
        );
      },
      onExternalCallback: webAppModule.handleExternalCallback,
      onConsoleMessage: (controller, consoleMessage) {
        final msg = '[DID] ${consoleMessage.message}';
        final lvl = consoleMessage.messageLevel.toString().toUpperCase();
        if (lvl.contains('ERROR')) {
          logger.e(msg);
        } else if (lvl.contains('WARNING')) {
          logger.w(msg);
        } else {
          logger.i(msg);
        }
      },
      onLoadStart: (controller, url) {
        if (url != null) {
          logger.i('[DID] loadStart: ${url.scheme}://${url.host}${url.path}');
        }
      },
      shouldOverrideUrlLoading: (_, action, _) async {
        final uri = action.request.url;
        final url = uri?.toString() ?? '';
        final scheme = uri?.scheme ?? '';
        if (kDebugMode) {
          debugPrint(
            '[KOMET-DID] nav: ${url.length > 140 ? url.substring(0, 140) : url}',
          );
        }
        if (scheme != 'http' && scheme != 'https') {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }
}
