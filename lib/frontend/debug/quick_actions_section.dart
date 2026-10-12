import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../screens/auth/login_screen.dart';
import '../screens/profile/traffic_monitor_screen.dart';
import 'dev_menu_widgets.dart';

class DebugQuickActionsSection extends StatelessWidget {
  final VoidCallback onExportLog;

  const DebugQuickActionsSection({super.key, required this.onExportLog});

  @override
  Widget build(BuildContext context) {
    return DevGroup(
      children: [
        DevRow(
          icon: Symbols.drive_folder_upload,
          caption: 'Zip: логи и запросы за 24 часа',
          title: 'Отправить логи',
          onTap: onExportLog,
        ),
        DevRow(
          icon: Symbols.lan,
          caption: 'Домены, опкоды и payload сокета',
          title: 'Монитор трафика',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrafficMonitorScreen()),
          ),
        ),
        DevRow(
          icon: Symbols.dialpad,
          caption: 'Без выхода из аккаунта',
          title: 'Экран ввода номера',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      ],
    );
  }
}
