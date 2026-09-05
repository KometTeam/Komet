import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_profile.dart';
import '../protocol/opcode_map.dart';
import '../protocol/packet.dart';

// #***! направление записи, запрос ответ или событие
enum TrafficDirection { outgoing, incoming, event }

// #***! одна строка лога трафика
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

// #***! payload в читаемый json
String prettyJson(dynamic value) {
  if (value == null) return 'null';
  try {
    return const JsonEncoder.withIndent('  ').convert(_sanitize(value));
  } catch (_) {
    return value.toString();
  }
}

const _redacted = '***';

// #***! эти поля в экспорт не пускаем
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

// #***! чувствительный ли ключ
bool _isSensitiveExportKey(Object? key) {
  if (key is! String) return false;
  return _sensitiveExportFields.contains(key.toLowerCase());
}

// #***! вырезаем чувствительное перед экспортом
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

// #***! payload в json, бинарь в <bytes: N>
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

// #***! перехват трафика для дев меню
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

  // #***! флаг захвата помним между запусками
  Future<void> load() async {
    if (!BuildProfile.trafficCapture) return;
    final prefs = await SharedPreferences.getInstance();
    captureEnabled.value = prefs.getBool(_prefKey) ?? _defaultEnabled;
  }

  Future<void> setEnabled(bool value) async {
    if (!BuildProfile.trafficCapture) return;
    if (captureEnabled.value != value) {
      captureEnabled.value = value;
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  // #***! чистка по кнопке
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  // #***! файл экспорта без токенов и телефонов
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

  // #***! хук исходящего
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

  // #***! хук входящего
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

  // #***! событие транспорта
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

  // #***! кольцо на 1000 записей
  void _add(TrafficEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    _scheduleNotify();
  }

  bool _notifyScheduled = false;

  // #***! схлопываем в микротаск чтоб юишка не умерла
  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.microtask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}
