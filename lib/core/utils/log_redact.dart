import 'package:flutter/foundation.dart';

const _redacted = '***';

const _sensitiveSubstrings = [
  'password',
  'token',
  'phone',
  'secret',
  'auth',
];

const _sensitiveExact = {
  'code',
  'verifycode',
  'smscode',
  'otp',
  'hint',
  'pin',
  'qrlink',
  'text',
  'msisdn',
  'deviceid',
  'mt_instanceid',
  'instanceid',
  'webappdata',
};

bool _isSensitiveKey(Object? key) {
  if (key is! String) return false;
  final k = key.toLowerCase();
  if (_sensitiveExact.contains(k)) return true;
  for (final s in _sensitiveSubstrings) {
    if (k.contains(s)) return true;
  }
  return false;
}

dynamic redactForLog(dynamic value) {
  if (value is Map) {
    final out = {};
    value.forEach((k, v) {
      out[k] = _isSensitiveKey(k) ? _redacted : redactForLog(v);
    });
    return out;
  }
  if (value is List) {
    return value.map(redactForLog).toList();
  }
  return value;
}

Object? payloadForLog(dynamic value) {
  if (kReleaseMode) return '<payload hidden>';
  return redactForLog(value);
}
