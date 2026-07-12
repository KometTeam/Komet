import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/parse.dart';

enum NfcEventType { received, exchanging, cancelled, error }

class NfcEvent {
  final NfcEventType type;
  final int? id;
  final int? phone;
  final String? reason;

  const NfcEvent(this.type, this.id, {this.phone, this.reason});
}

class NfcStatus {
  final bool supported;
  final bool enabled;

  const NfcStatus({required this.supported, required this.enabled});

  bool get ready => supported && enabled;
}

class NfcExchangeService {
  NfcExchangeService._();
  static final NfcExchangeService instance = NfcExchangeService._();

  static const MethodChannel _method = MethodChannel('ru.komet.app/nfc');
  static const EventChannel _events = EventChannel('ru.komet.app/nfc_events');

  bool get _supported => Platform.isAndroid;

  Future<NfcStatus> status() async {
    if (!_supported) return const NfcStatus(supported: false, enabled: false);
    try {
      final res = await _method.invokeMapMethod<String, dynamic>('status');
      return NfcStatus(
        supported: res?['supported'] == true,
        enabled: res?['enabled'] == true,
      );
    } catch (_) {
      return const NfcStatus(supported: false, enabled: false);
    }
  }

  Stream<NfcEvent> get events =>
      _events.receiveBroadcastStream().map(_decodeEvent);

  Future<void> start(int selfId, int selfPhone) =>
      _method.invokeMethod('start', {'selfId': selfId, 'selfPhone': selfPhone});

  Future<void> stop() async {
    if (!_supported) return;
    try {
      await _method.invokeMethod('stop');
    } catch (_) {}
  }

  NfcEvent _decodeEvent(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final parsedId = parseIntOrNull(map['id']);
    final parsedPhone = parseIntOrNull(map['phone']);
    switch (map['event']) {
      case 'received':
        return NfcEvent(NfcEventType.received, parsedId, phone: parsedPhone);
      case 'exchanging':
        return const NfcEvent(NfcEventType.exchanging, null);
      case 'error':
        return NfcEvent(
          NfcEventType.error,
          null,
          reason: map['reason'] as String?,
        );
      default:
        return const NfcEvent(NfcEventType.cancelled, null);
    }
  }
}
