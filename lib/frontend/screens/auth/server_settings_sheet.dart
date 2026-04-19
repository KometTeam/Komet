import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/core/config/config.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';
import '../../widgets/custom_notification.dart';

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
      await api.disconnect();
      api.connect(); 
      final online = await api.stateStream
          .firstWhere((s) =>
              s == SessionState.online || s == SessionState.disconnected)
          .timeout(const Duration(seconds: 15),
              onTimeout: () => SessionState.disconnected);
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
      _hostController.text = ServerConfig.defaultHost;
      _portController.text = '${ServerConfig.defaultPort}';
      await api.disconnect();
      api.connect();
      final online = await api.stateStream
          .firstWhere((s) =>
              s == SessionState.online || s == SessionState.disconnected)
          .timeout(const Duration(seconds: 15),
              onTimeout: () => SessionState.disconnected);
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.serverSettingsTitle,
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _hostController,
                label: l10n.serverHostLabel,
                hintText: ServerConfig.defaultHost,
                cs: cs,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _portController,
                label: l10n.serverPortLabel,
                hintText: '${ServerConfig.defaultPort}',
                cs: cs,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required ColorScheme cs,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          enabled: !_busy,
          style: GoogleFonts.inter(
            color: cs.onSurface,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 15,
            ),
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
