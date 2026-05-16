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

  static const MethodChannel _channel =
      MethodChannel('ru.komet.app/vpn_bypass');

  bool _bound = false;

  bool get _supported => Platform.isAndroid;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }

  /// Вызывается перед каждым (ре)коннектом.
  Future<VpnBypassResult> applyIfNeeded() async {
    if (!_supported) {
      return const VpnBypassResult(
        enabled: false,
        reason: 'unsupported_platform',
      );
    }

    if (!await isEnabled()) {
      await _restoreDefault();
      return const VpnBypassResult(enabled: false);
    }

    final tunDetected = await _hasTunInterface();
    if (!tunDetected) {
      await _restoreDefault();
      logger.i('VPN bypass: tun-интерфейс не найден — маршрут по умолчанию');
      return const VpnBypassResult(enabled: true, tunDetected: false);
    }

    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('bindToNonVpnNetwork');
      final bound = res?['bound'] == true;
      _bound = bound;
      final result = VpnBypassResult(
        enabled: true,
        tunDetected: true,
        bound: bound,
        boundInterface: res?['interface'] as String?,
        transport: res?['transport'] as String?,
        reason: res?['reason'] as String?,
      );
      if (bound) {
        logger.i(
          'VPN bypass: трафик направлен мимо VPN → '
          '${result.boundInterface} (${result.transport})',
        );
      } else {
        logger.w('VPN bypass: не удалось обойти VPN (${result.reason})');
      }
      return result;
    } on PlatformException catch (e) {
      logger.e('VPN bypass: ошибка платформы: ${e.message}');
      return VpnBypassResult(
        enabled: true,
        tunDetected: true,
        reason: e.code,
      );
    } on MissingPluginException {
      return const VpnBypassResult(
        enabled: true,
        tunDetected: true,
        reason: 'no_plugin',
      );
    }
  }

  Future<bool> _hasTunInterface() async {
    try {
      final res = await _channel
          .invokeMapMethod<String, dynamic>('detectInterfaces');
      if (res != null && res.containsKey('hasTun')) {
        return res['hasTun'] == true;
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

  Future<void> _restoreDefault() async {
    if (!_bound) return;
    try {
      await _channel.invokeMethod('unbindNetwork');
    } catch (_) {}
    _bound = false;
  }
}
