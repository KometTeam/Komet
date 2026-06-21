import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

enum NfcEventType { received, cancelled }

class NfcEvent {
  final NfcEventType type;
  final int? id;

  const NfcEvent(this.type, this.id);
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

  Future<void> start(int selfId) =>
      _method.invokeMethod('start', {'selfId': selfId});

  Future<void> stop() async {
    if (!_supported) return;
    try {
      await _method.invokeMethod('stop');
    } catch (_) {}
  }

  NfcEvent _decodeEvent(dynamic raw) {
    final map = raw is Map ? raw : const {};
    final id = map['id'];
    final type = map['event'] == 'received'
        ? NfcEventType.received
        : NfcEventType.cancelled;
    return NfcEvent(type, id is int ? id : (id is num ? id.toInt() : null));
  }
}
