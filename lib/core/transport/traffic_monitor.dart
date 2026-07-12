import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../protocol/opcode_map.dart';
import '../protocol/packet.dart';

enum TrafficDirection { outgoing, incoming, event }

class TrafficEntry {
  final TrafficDirection direction;
  final DateTime time;
  final String label;
  final int? opcode;
  final int? seq;
  final int? cmd;
  final dynamic payload;
  final int? byteSize;
  final String? detail;

  TrafficEntry({
    required this.direction,
    required this.time,
    required this.label,
    this.opcode,
    this.seq,
    this.cmd,
    this.payload,
    this.byteSize,
    this.detail,
  });

  String get prettyPayload => prettyJson(payload);
}

String prettyJson(dynamic value) {
  if (value == null) return 'null';
  try {
    return const JsonEncoder.withIndent('  ').convert(_sanitize(value));
  } catch (_) {
    return value.toString();
  }
}

const _redacted = '***';

const _sensitiveExportFields = {
  'token',
  'accesstoken',
  'refreshtoken',
  'authtoken',
  'password',
  'secret',
  'phone',
  'phonenumber',
  'email',
  'msisdn',
  'otp',
  'smscode',
  'verifycode',
  'pin',
  'qrlink',
  'webappdata',
  'deviceid',
  'instanceid',
  'mt_instanceid',
  'text',
  'caption',
};

bool _isSensitiveExportKey(Object? key) {
  if (key is! String) return false;
  return _sensitiveExportFields.contains(key.toLowerCase());
}

dynamic _redactForExport(dynamic value) {
  if (value is Map) {
    final out = {};
    value.forEach((k, v) {
      out[k] = _isSensitiveExportKey(k) ? _redacted : _redactForExport(v);
    });
    return out;
  }
  if (value is List) return value.map(_redactForExport).toList();
  return value;
}

dynamic _sanitize(dynamic value) {
  if (value is Map) {
    final out = <String, dynamic>{};
    value.forEach((k, v) => out[k.toString()] = _sanitize(v));
    return out;
  }
  if (value is Uint8List) return '<bytes: ${value.length}>';
  if (value is List) return value.map(_sanitize).toList();
  if (value is num || value is bool || value is String) return value;
  return value.toString();
}

/// Перехватчик сокет-трафика для меню разработчика.
///
/// Захват включается только пока открыт экран монитора ([enabled]),
/// поэтому в обычной работе хуки в sender/dispatcher/connection почти
/// бесплатны (один ранний выход по флагу).
class TrafficMonitor extends ChangeNotifier {
  TrafficMonitor._();
  static final TrafficMonitor instance = TrafficMonitor._();

  static const int _maxEntries = 1000;
  static const String _prefKey = 'dev_traffic_capture';
  static const bool _defaultEnabled = false;

  final List<TrafficEntry> _entries = [];
  String? _activeEndpoint;

  final ValueNotifier<bool> captureEnabled = ValueNotifier(_defaultEnabled);

  bool get enabled => captureEnabled.value;

  List<TrafficEntry> get entries => List.unmodifiable(_entries);
  String? get activeEndpoint => _activeEndpoint;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    captureEnabled.value = prefs.getBool(_prefKey) ?? _defaultEnabled;
  }

  Future<void> setEnabled(bool value) async {
    if (captureEnabled.value != value) {
      captureEnabled.value = value;
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  /// Сериализует захваченный трафик для экспорта.
  /// Чувствительные поля payload (токены, телефоны, коды и т.п.)
  /// маскируются через [redactForLog] — файлом можно делиться.
  String buildExport({String? appVersion}) {
    final data = <String, dynamic>{
      'tool': 'Komet traffic monitor',
      'appVersion': ?appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'endpoint': _activeEndpoint,
      'entryCount': _entries.length,
      'sensitiveDataRedacted': true,
      'entries': _entries.map(_entryToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, dynamic> _entryToJson(TrafficEntry e) {
    return <String, dynamic>{
      'time': e.time.toIso8601String(),
      'direction': e.direction.name,
      'label': e.label,
      if (e.opcode != null) 'opcode': e.opcode,
      if (e.seq != null) 'seq': e.seq,
      if (e.cmd != null) 'cmd': e.cmd,
      if (e.byteSize != null) 'bytes': e.byteSize,
      if (e.detail != null) 'detail': e.detail,
      if (e.payload != null) 'payload': _sanitize(_redactForExport(e.payload)),
    };
  }

  void recordOutgoing(int opcode, dynamic payload, int seq, int byteSize) {
    if (!enabled) return;
    _add(
      TrafficEntry(
        direction: TrafficDirection.outgoing,
        time: DateTime.now(),
        label: Opcode.name(opcode),
        opcode: opcode,
        seq: seq,
        cmd: CmdType.request,
        payload: payload,
        byteSize: byteSize,
      ),
    );
  }

  void recordIncoming(Packet packet, int byteSize) {
    if (!enabled) return;
    _add(
      TrafficEntry(
        direction: TrafficDirection.incoming,
        time: DateTime.now(),
        label: Opcode.name(packet.opcode),
        opcode: packet.opcode,
        seq: packet.seq,
        cmd: packet.cmd,
        payload: packet.payload,
        byteSize: byteSize,
      ),
    );
  }

  void recordEvent(String label, {String? detail, String? endpoint}) {
    if (endpoint != null) _activeEndpoint = endpoint;
    if (!enabled) return;
    _add(
      TrafficEntry(
        direction: TrafficDirection.event,
        time: DateTime.now(),
        label: label,
        detail: detail,
      ),
    );
  }

  void _add(TrafficEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    _scheduleNotify();
  }

  bool _notifyScheduled = false;

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.microtask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}
