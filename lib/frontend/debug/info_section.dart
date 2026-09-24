import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../backend/api.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/device_identity.dart';
import '../../main.dart';
import '../widgets/custom_notification.dart';
import 'dev_menu_widgets.dart';
import 'server_section.dart';

typedef _DeviceInfo = ({
  String version,
  String userId,
  String deviceId,
  String instanceId,
  String flavor,
});

class DebugInfoSection extends StatefulWidget {
  final DebugServerController server;

  const DebugInfoSection({super.key, required this.server});

  @override
  State<DebugInfoSection> createState() => _DebugInfoSectionState();
}

class _DebugInfoSectionState extends State<DebugInfoSection> {
  late final Future<_DeviceInfo> _info = _load();

  Future<_DeviceInfo> _load() async {
    final (package, profile, deviceId, instanceId) = await (
      PackageInfo.fromPlatform(),
      AppDatabase.loadActiveProfile(),
      DeviceIdentity.deviceId(),
      DeviceIdentity.instanceId(),
    ).wait;
    return (
      version: '${package.version}(${package.buildNumber})',
      userId: profile == null ? '—' : '${profile.id}',
      deviceId: api.deviceId ?? deviceId,
      instanceId: instanceId,
      flavor: appFlavor ?? 'komet',
    );
  }

  void _copy(String caption, String value) {
    Clipboard.setData(ClipboardData(text: value));
    showCustomNotification(context, 'Скопировано: $caption');
  }

  Widget _copyRow(String caption, String value) => DevRow(
    caption: caption,
    title: value,
    onTap: () => _copy(caption, value),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<_DeviceInfo>(
          future: _info,
          builder: (context, snapshot) {
            final info = snapshot.data;
            if (info == null) return const SizedBox(height: 120);
            return DevGroup(
              children: [
                _copyRow('Версия приложения', info.version),
                _copyRow('Сборка', info.flavor),
                _copyRow('ID пользователя', info.userId),
                _copyRow('deviceId', info.deviceId),
                _copyRow('mt_instanceid', info.instanceId),
              ],
            );
          },
        ),
        ListenableBuilder(
          listenable: widget.server,
          builder: (context, _) {
            final endpoint = widget.server.endpoint;
            return StreamBuilder<SessionState>(
              stream: api.stateStream,
              initialData: api.state,
              builder: (context, state) => DevGroup(
                children: [
                  _copyRow('Адрес сервера', endpoint.host),
                  _copyRow('Порт сервера', '${endpoint.port}'),
                  DevRow(
                    caption: 'Состояние сессии',
                    title: (state.data ?? api.state).name,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
