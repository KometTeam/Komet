import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/core/config/config.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/labeled_settings_field.dart';
import '../../widgets/sheet_helpers.dart';

class ServerSettingsSheet extends StatefulWidget {
  const ServerSettingsSheet({super.key});

  @override
  State<ServerSettingsSheet> createState() => _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends State<ServerSettingsSheet> {
  final TextEditingController _hostController = TextEditingController(
    text: ServerConfig.defaultHost,
  );
  final TextEditingController _portController = TextEditingController(
    text: '${ServerConfig.defaultPort}',
  );
  bool _busy = false;
  bool _trustMincifryCa = ServerConfig.defaultTrustMincifryCa;
  bool _trustKnownAvTls = ServerConfig.defaultTrustKnownAvTls;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final endpoint = await ServerConfig.loadEndpoint();
    if (!mounted) return;
    setState(() {
      _hostController.text = endpoint.host;
      _portController.text = '${endpoint.port}';
      _trustMincifryCa = endpoint.trustMincifryCa;
      _trustKnownAvTls = endpoint.trustKnownAvTls;
    });
  }

  Future<void> _apply(AppLocalizations l10n) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      showCustomNotification(context, l10n.serverInvalidHostOrPort);
      return;
    }
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ServerConfig.prefHostKey, host);
      await prefs.setInt(ServerConfig.prefPortKey, port);
      await prefs.setBool(ServerConfig.prefTrustMincifryKey, _trustMincifryCa);
      await prefs.setBool(
        ServerConfig.prefTrustKnownAvTlsKey,
        _trustKnownAvTls,
      );
      await api.disconnect();
      unawaited(api.connect());
      final online = await api.stateStream
          .firstWhere(
            (s) => s == SessionState.online || s == SessionState.disconnected,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => SessionState.disconnected,
          );
      if (!mounted) return;
      if (online == SessionState.online) {
        showCustomNotification(context, l10n.serverSettingsSaved);
      } else {
        showCustomNotification(context, l10n.serverReconnectFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetToDefault(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ServerConfig.prefHostKey);
      await prefs.remove(ServerConfig.prefPortKey);
      await prefs.remove(ServerConfig.prefTrustMincifryKey);
      await prefs.remove(ServerConfig.prefTrustKnownAvTlsKey);
      _hostController.text = ServerConfig.defaultHost;
      _portController.text = '${ServerConfig.defaultPort}';
      _trustMincifryCa = ServerConfig.defaultTrustMincifryCa;
      _trustKnownAvTls = ServerConfig.defaultTrustKnownAvTls;
      await api.disconnect();
      api.connect();
      final online = await api.stateStream
          .firstWhere(
            (s) => s == SessionState.online || s == SessionState.disconnected,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => SessionState.disconnected,
          );
      if (!mounted) return;
      if (online == SessionState.online) {
        showCustomNotification(context, l10n.serverSettingsSaved);
      } else {
        showCustomNotification(context, l10n.serverReconnectFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: SheetGrabber(margin: EdgeInsets.only(bottom: 16)),
              ),
              Text(
                l10n.serverSettingsTitle,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              LabeledSettingsField(
                controller: _hostController,
                label: l10n.serverHostLabel,
                hintText: ServerConfig.defaultHost,
                keyboardType: TextInputType.url,
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              LabeledSettingsField(
                controller: _portController,
                label: l10n.serverPortLabel,
                hintText: '${ServerConfig.defaultPort}',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                enabled: !_busy,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.serverTrustMincifryTitle,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.serverTrustMincifrySubtitle,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _trustMincifryCa,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _trustMincifryCa = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.serverTrustKnownAvTlsTitle,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.serverTrustKnownAvTlsSubtitle,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _trustKnownAvTls,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _trustKnownAvTls = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : () => _apply(l10n),
                child: Text(l10n.serverApply),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => _resetToDefault(l10n),
                child: Text(l10n.serverUseDefault),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
