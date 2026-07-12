import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

class VpnBypassResult {
  final bool enabled;
  final bool tunDetected;
  final bool bound;
  final String? boundInterface;
  final String? transport;
  final String? reason;

  const VpnBypassResult({
    required this.enabled,
    this.tunDetected = false,
    this.bound = false,
    this.boundInterface,
    this.transport,
    this.reason,
  });

  @override
  String toString() =>
      'VpnBypassResult(enabled: $enabled, tun: $tunDetected, bound: $bound, '
      'iface: $boundInterface, transport: $transport, reason: $reason)';
}

/// При активном VPN (tun-интерфейс) привязывает процесс к не-VPN сети
/// (wlan*/rmnet*). Только Android, по умолчанию выключено.
class VpnBypassService {
  VpnBypassService._();
  static final VpnBypassService instance = VpnBypassService._();

  static const String prefKey = 'dev_vpn_bypass';

  static const MethodChannel _channel = MethodChannel(
    'ru.komet.app/vpn_bypass',
  );

  bool _bound = false;

  final _eventController = StreamController<VpnBypassResult>.broadcast();

  /// Эмитит результат каждой попытки обхода (для уведомления в UI).
  Stream<VpnBypassResult> get events => _eventController.stream;

  bool get _supported => Platform.isAndroid;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }

  /// true — обход включён, платформа поддерживается и активен VPN.
  Future<bool> shouldArm() async {
    if (!_supported) return false;
    if (!await isEnabled()) return false;
    return _isVpnActive();
  }

  /// Привязывает процесс к non-VPN сети (wlan*/rmnet*).
  Future<VpnBypassResult> bind() async {
    VpnBypassResult result;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'bindToNonVpnNetwork',
      );
      final bound = res?['bound'] == true;
      _bound = bound;
      result = VpnBypassResult(
        enabled: true,
        tunDetected: true,
        bound: bound,
        boundInterface: res?['interface'] as String?,
        transport: res?['transport'] as String?,
        reason: res?['reason'] as String?,
      );
    } on PlatformException catch (e) {
      logger.e('VPN bypass: ошибка платформы: ${e.message}');
      result = VpnBypassResult(
        enabled: true,
        tunDetected: true,
        reason: e.code,
      );
    } on MissingPluginException {
      result = const VpnBypassResult(
        enabled: true,
        tunDetected: true,
        reason: 'no_plugin',
      );
    }
    if (result.bound) {
      logger.i(
        'VPN bypass: привязано к ${result.boundInterface} '
        '(${result.transport})',
      );
    } else {
      logger.w('VPN bypass: обойти не удалось (${result.reason})');
    }
    _eventController.add(result);
    return result;
  }

  Future<bool> _isVpnActive() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'detectInterfaces',
      );
      if (res != null) {
        if (res['hasTun'] == true || res['hasVpn'] == true) return true;
        if (res.containsKey('hasTun')) return false;
      }
    } catch (_) {}
    try {
      final ifaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: true,
      );
      return ifaces.any((i) {
        final n = i.name.toLowerCase();
        return n.startsWith('tun') ||
            n.startsWith('ppp') ||
            n.startsWith('ipsec') ||
            n.startsWith('wg');
      });
    } catch (_) {
      return false;
    }
  }

  /// Возвращает маршрутизацию процесса к системной (через VPN, если он есть).
  Future<void> restoreDefault() async {
    if (!_bound) return;
    try {
      await _channel.invokeMethod('unbindNetwork');
    } catch (_) {}
    _bound = false;
  }
}
