import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../main.dart';
import '../screens/profile/traffic_monitor_screen.dart';
import '../widgets/connection_status.dart';
import 'debug_toggle_tile.dart';

class DebugNetworkSection extends StatelessWidget {
  final KometAppState? appState;

  const DebugNetworkSection({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = appState;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: state == null
              ? const SizedBox.shrink()
              : DebugToggleTile(
                  icon: Symbols.speed,
                  title: 'Оверлей FPS',
                  subtitle: (_) =>
                      'Показ текущего фреймрейта поверх интерфейса',
                  valueListenable: state.fpsOverlayEnabled,
                  onChanged: state.setFpsOverlayEnabled,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: state == null
              ? const SizedBox.shrink()
              : DebugToggleTile(
                  icon: Symbols.vpn_key_off,
                  title: 'Обход VPN',
                  subtitle: (_) =>
                      'Если обнаружен VPN (tun-интерфейс), '
                      'подключаться напрямую через Wi-Fi или '
                      'моб. сеть в обход туннеля. Только Android',
                  valueListenable: state.vpnBypassEnabled,
                  onChanged: state.setVpnBypassEnabled,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.wifi_off,
            title: 'Офлайн (тест)',
            subtitle: (_) =>
                'Показать индикаторы соединения во всех '
                'экранах, не разрывая реальную сессию',
            valueListenable: debugForceOffline,
            onChanged: (v) => debugForceOffline.value = v,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: state == null
              ? const SizedBox.shrink()
              : DebugToggleTile(
                  icon: Symbols.gpp_bad,
                  title: 'Отключить проверку TLS',
                  subtitle: (_) =>
                      'Принимать любой сертификат сервера. '
                      'Только для отладки через MitM-прокси — '
                      'соединение становится уязвимым к '
                      'перехвату трафика',
                  valueListenable: state.tlsInsecureEnabled,
                  onChanged: state.setTlsInsecureEnabled,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrafficMonitorScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.lan,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Монитор трафика',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Реалтайм: домены, опкоды и payload внутри '
                            'сокет-соединения',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
