import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/config.dart';
import '../../main.dart';
import '../widgets/custom_notification.dart';
import '../widgets/prompt_dialog.dart';
import '../widgets/sheet_helpers.dart';
import '../widgets/small_spinner.dart';
import 'dev_menu_widgets.dart';

typedef ServerEndpoint = ({String host, int port, bool trustMincifryCa});

class DebugServerController extends ChangeNotifier {
  ServerEndpoint _endpoint = (
    host: ServerConfig.defaultHost,
    port: ServerConfig.defaultPort,
    trustMincifryCa: ServerConfig.defaultTrustMincifryCa,
  );
  bool _busy = false;
  bool _disposed = false;

  ServerEndpoint get endpoint => _endpoint;
  bool get busy => _busy;
  bool get isDefault =>
      _endpoint.host == ServerConfig.defaultHost &&
      _endpoint.port == ServerConfig.defaultPort &&
      _endpoint.trustMincifryCa == ServerConfig.defaultTrustMincifryCa;

  Future<void> load() async {
    _endpoint = await ServerConfig.loadEndpoint();
    _notify();
  }

  Future<bool?> apply({String? host, int? port, bool? trustMincifryCa}) {
    final next = (
      host: host ?? _endpoint.host,
      port: port ?? _endpoint.port,
      trustMincifryCa: trustMincifryCa ?? _endpoint.trustMincifryCa,
    );
    if (next == _endpoint) return Future.value(null);
    return _reconnect(
      next,
      () => ServerConfig.saveEndpoint(
        host: next.host,
        port: next.port,
        trustMincifryCa: next.trustMincifryCa,
      ),
    );
  }

  Future<bool?> reset() => _reconnect((
    host: ServerConfig.defaultHost,
    port: ServerConfig.defaultPort,
    trustMincifryCa: ServerConfig.defaultTrustMincifryCa,
  ), ServerConfig.resetEndpoint);

  Future<bool?> _reconnect(
    ServerEndpoint next,
    Future<void> Function() persist,
  ) async {
    if (_busy) return null;
    _busy = true;
    _endpoint = next;
    _notify();
    try {
      await persist();
      return await api.reconnectToEndpoint();
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

void reportServerReconnect(BuildContext context, bool? online) {
  if (online == null) return;
  showCustomNotification(
    context,
    online ? 'Подключено к серверу' : 'Не удалось подключиться к серверу',
  );
}

class DebugServerSection extends StatelessWidget {
  final DebugServerController controller;

  const DebugServerSection({super.key, required this.controller});

  Future<void> _pickHost(BuildContext context) async {
    final host = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: kSheetShape,
      isScrollControlled: true,
      builder: (_) => _HostPickerSheet(current: controller.endpoint.host),
    );
    if (host == null) return;
    final online = await controller.apply(host: host);
    if (context.mounted) reportServerReconnect(context, online);
  }

  Future<void> _editPort(BuildContext context) async {
    final raw = await showTextInputDialog(
      context,
      title: 'Порт сервера',
      hint: '${ServerConfig.defaultPort}',
      initialValue: '${controller.endpoint.port}',
      confirmLabel: 'Сохранить',
      keyboardType: TextInputType.number,
    );
    if (raw == null || !context.mounted) return;
    final port = int.tryParse(raw.trim());
    if (!ServerConfig.isValidPort(port)) {
      showCustomNotification(context, 'Порт должен быть от 1 до 65535');
      return;
    }
    final online = await controller.apply(port: port);
    if (context.mounted) reportServerReconnect(context, online);
  }

  Future<void> _setTrust(BuildContext context, bool trust) async {
    final online = await controller.apply(trustMincifryCa: trust);
    if (context.mounted) reportServerReconnect(context, online);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final endpoint = controller.endpoint;
        final busy = controller.busy;
        return DevGroup(
          children: [
            DevRow(
              caption: 'Адрес сервера',
              title: endpoint.host,
              onTap: busy ? null : () => _pickHost(context),
              trailing: busy
                  ? SmallSpinner(size: 20, color: cs.onSurfaceVariant)
                  : Icon(Symbols.chevron_right, color: cs.outline, size: 20),
            ),
            DevRow(
              caption: 'Порт сервера',
              title: '${endpoint.port}',
              onTap: busy ? null : () => _editPort(context),
            ),
            DevSwitchRow(
              title: 'Доверять сертификату Минцифры',
              value: endpoint.trustMincifryCa,
              onChanged: busy ? null : (v) => _setTrust(context, v),
            ),
          ],
        );
      },
    );
  }
}

class _HostPickerSheet extends StatelessWidget {
  final String current;

  const _HostPickerSheet({required this.current});

  Future<void> _enterCustom(BuildContext context) async {
    final isPreset = ServerConfig.presetHosts.contains(current);
    final raw = await showTextInputDialog(
      context,
      title: 'Свой сервер',
      hint: 'host.example.com',
      initialValue: isPreset ? null : current,
      confirmLabel: 'Подключиться',
      keyboardType: TextInputType.url,
    );
    if (raw == null || !context.mounted) return;
    final host = _normalizeHost(raw);
    if (host.isEmpty) {
      showCustomNotification(context, 'Введите адрес сервера');
      return;
    }
    Navigator.pop(context, host);
  }

  static String _normalizeHost(String raw) => raw
      .trim()
      .replaceFirst(RegExp(r'^[a-z]+://', caseSensitive: false), '')
      .replaceFirst(RegExp(r'/.*$'), '');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCustom = !ServerConfig.presetHosts.contains(current);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: SheetGrabber(margin: EdgeInsets.only(bottom: 12)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Сервер для подключения',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final host in ServerConfig.presetHosts)
              _HostOption(
                title: host,
                subtitle: host == ServerConfig.defaultHost
                    ? 'По умолчанию'
                    : null,
                selected: host == current,
                onTap: () => Navigator.pop(context, host),
              ),
            _HostOption(
              title: 'Свой вариант',
              subtitle: isCustom ? current : 'Указать адрес вручную',
              selected: isCustom,
              onTap: () => _enterCustom(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostOption extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _HostOption({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = this.subtitle;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        title,
        style: TextStyle(color: cs.onSurface, fontSize: 16),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
      trailing: selected ? Icon(Symbols.check, color: cs.primary) : null,
      onTap: onTap,
    );
  }
}
