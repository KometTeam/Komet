import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/core/config/proxy_config.dart';
import 'package:komet/l10n/app_localizations.dart';

import '../../../main.dart';
import '../../widgets/custom_notification.dart';

class ProxySettingsSheet extends StatefulWidget {
  const ProxySettingsSheet({super.key});

  @override
  State<ProxySettingsSheet> createState() => _ProxySettingsSheetState();
}

class _ProxySettingsSheetState extends State<ProxySettingsSheet> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '1080');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  ProxyType _selectedType = ProxyType.none;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ProxyConfig.load();
    if (!mounted) return;
    setState(() {
      _selectedType = settings.type;
      _hostController.text = settings.host;
      _portController.text = '${settings.port}';
      _usernameController.text = settings.username ?? '';
      _passwordController.text = settings.password ?? '';
    });
  }

  Future<void> _apply(AppLocalizations l10n) async {
    if (_selectedType == ProxyType.none) {
      return _disable(l10n);
    }

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      showCustomNotification(context, l10n.proxyInvalidHostOrPort);
      return;
    }

    setState(() => _busy = true);
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      await ProxyConfig.save(ProxySettings(
        type: _selectedType,
        host: host,
        port: port,
        username: username.isNotEmpty ? username : null,
        password: password.isNotEmpty ? password : null,
      ));
      await api.disconnect();
      await api.connect();
      if (!mounted) return;
      if (api.state == SessionState.online) {
        showCustomNotification(context, l10n.proxySettingsSaved);
      } else {
        showCustomNotification(context, l10n.serverReconnectFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable(AppLocalizations l10n) async {
    setState(() => _busy = true);
    try {
      await ProxyConfig.clear();
      setState(() => _selectedType = ProxyType.none);
      await api.disconnect();
      await api.connect();
      if (!mounted) return;
      if (api.state == SessionState.online) {
        showCustomNotification(context, l10n.proxySettingsSaved);
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
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isActive = _selectedType != ProxyType.none;

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
                l10n.proxySettingsTitle,
                style: GoogleFonts.inter(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Proxy type selector
              _buildTypeSelector(cs, l10n),
              const SizedBox(height: 16),

              // Fields shown only when proxy is enabled
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: isActive
                    ? Column(
                        children: [
                          _buildTextField(
                            controller: _hostController,
                            label: l10n.proxyHostLabel,
                            hintText: '127.0.0.1',
                            cs: cs,
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _portController,
                            label: l10n.proxyPortLabel,
                            hintText: _selectedType == ProxyType.socks5
                                ? '1080'
                                : '8080',
                            cs: cs,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _usernameController,
                            label: l10n.proxyUsernameLabel,
                            cs: cs,
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: l10n.proxyPasswordLabel,
                            cs: cs,
                            keyboardType: TextInputType.visiblePassword,
                            obscureText: true,
                          ),
                          const SizedBox(height: 8),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : () => _apply(l10n),
                child: Text(
                  isActive ? l10n.proxyApply : l10n.proxyDisable,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme cs, AppLocalizations l10n) {
    final labels = {
      ProxyType.none: l10n.proxyTypeNone,
      ProxyType.socks5: l10n.proxyTypeSocks5,
      ProxyType.httpConnect: l10n.proxyTypeHttp,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ProxyType.values.map((type) {
          final selected = _selectedType == type;
          return Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[type]!,
                  style: GoogleFonts.inter(
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
    bool obscureText = false,
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
          obscureText: obscureText,
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
