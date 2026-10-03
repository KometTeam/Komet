import 'package:flutter/material.dart';

import '../../main.dart';
import '../widgets/connection_status.dart';
import 'dev_menu_widgets.dart';

class DebugNetworkSection extends StatelessWidget {
  final KometAppState? appState;

  const DebugNetworkSection({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final state = appState;
    return DevGroup(
      children: [
        if (state != null)
          DevToggleRow(
            title: 'Обход VPN',
            description: (_) =>
                'При tun-интерфейсе подключаться напрямую через Wi-Fi '
                'или моб. сеть. Только Android',
            valueListenable: state.vpnBypassEnabled,
            onChanged: state.setVpnBypassEnabled,
          ),
        DevToggleRow(
          title: 'Офлайн (тест)',
          description: (_) =>
              'Индикаторы соединения без разрыва реальной сессии',
          valueListenable: debugForceOffline,
          onChanged: (v) => debugForceOffline.value = v,
        ),
        if (state != null)
          DevToggleRow(
            title: 'Отключить проверку TLS',
            description: (_) =>
                'Принимать любой сертификат — только для MitM-прокси',
            valueListenable: state.tlsInsecureEnabled,
            onChanged: state.setTlsInsecureEnabled,
          ),
      ],
    );
  }
}
