import 'package:flutter/foundation.dart';

const _redacted = '***';

const _sensitiveSubstrings = ['password', 'token', 'secret', 'auth'];

const _sensitiveExact = {
  'code',
  'verifycode',
  'smscode',
  'otp',
  'hint',
  'pin',
  'qrlink',
  'text',
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

bool _isPhoneKey(Object? key) {
  if (key is! String) return false;
  final k = key.toLowerCase();
  return k.contains('phone') || k == 'msisdn';
}

String _maskPhone(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.length <= 3) return text;
  return '${text.substring(0, 3)}***';
}

dynamic redactForLog(dynamic value) {
  if (value is Map) {
    final out = {};
    value.forEach((k, v) {
      if (_isPhoneKey(k)) {
        out[k] = _maskPhone(v);
      } else {
        out[k] = _isSensitiveKey(k) ? _redacted : redactForLog(v);
      }
    });
    return out;
  }
  if (value is Uint8List) {
    return '<bytes: ${value.length}>';
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
