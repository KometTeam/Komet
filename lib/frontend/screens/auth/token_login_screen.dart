import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/storage/spoofing_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../models/spoof_profile.dart';
import '../../widgets/adaptive_shell.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';

class TokenLoginScreen extends StatefulWidget {
  final int? returnToAccountId;

  const TokenLoginScreen({super.key, this.returnToAccountId});

  @override
  State<TokenLoginScreen> createState() => _TokenLoginScreenState();
}

class _TokenLoginScreenState extends State<TokenLoginScreen> {
  final _tokenController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _osVersionController = TextEditingController();
  final _screenController = TextEditingController();
  final _timezoneController = TextEditingController();
  final _localeController = TextEditingController();
  final _deviceLocaleController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _appVersionController = TextEditingController(
    text: SpoofingService.hardcodedAppVersion,
  );
  final _buildNumberController = TextEditingController(
    text: '${SpoofingService.hardcodedBuildNumber}',
  );
  final _pushDeviceTypeController = TextEditingController(text: 'GCM');
  final _instanceIdController = TextEditingController();
  final _clientSessionIdController = TextEditingController();
  final _userAgentController = TextEditingController();

  String _selectedDeviceType = 'ANDROID';
  String _selectedArch = 'arm64-v8a';
  bool _isLoading = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _deviceNameController.dispose();
    _osVersionController.dispose();
    _screenController.dispose();
    _timezoneController.dispose();
    _localeController.dispose();
    _deviceLocaleController.dispose();
    _deviceIdController.dispose();
    _appVersionController.dispose();
    _buildNumberController.dispose();
    _pushDeviceTypeController.dispose();
    _instanceIdController.dispose();
    _clientSessionIdController.dispose();
    _userAgentController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _tokenController.text.trim().isNotEmpty &&
      _deviceNameController.text.trim().isNotEmpty &&
      _osVersionController.text.trim().isNotEmpty &&
      _deviceIdController.text.trim().isNotEmpty;

  Future<void> _login() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isValid) {
      showCustomNotification(context, l10n.tokenLoginError);
      return;
    }

    setState(() => _isLoading = true);

    final profile = SpoofProfile(
      enabled: true,
      deviceName: _deviceNameController.text.trim(),
      osVersion: _osVersionController.text.trim(),
      screen: _screenController.text.trim(),
      timezone: _timezoneController.text.trim(),
      locale: _localeController.text.trim(),
      deviceLocale: _deviceLocaleController.text.trim(),
      deviceId: _deviceIdController.text.trim(),
      deviceType: _selectedDeviceType,
      arch: _selectedArch,
      appVersion: _appVersionController.text.trim(),
      buildNumber:
          int.tryParse(_buildNumberController.text.trim()) ??
          SpoofingService.hardcodedBuildNumber,
      pushDeviceType: _pushDeviceTypeController.text.trim(),
      instanceId: _instanceIdController.text.trim(),
      clientSessionId: int.tryParse(_clientSessionIdController.text.trim()),
      userAgent: _userAgentController.text.trim(),
    );

    try {
      await SpoofingService.saveProfile(SpoofingService.pendingScope, profile);
      await accountModule.loginWithToken(_tokenController.text.trim());
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdaptiveShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showCustomNotification(context, '${l10n.tokenLoginFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tokenLoginTitle), centerTitle: true),
      body: AbsorbPointer(
        absorbing: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNoteCard(l10n),
              const SizedBox(height: 16),
              _buildTokenCard(l10n),
              const SizedBox(height: 16),
              _buildDeviceCard(l10n),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FilledButton(
          onPressed: _isLoading ? null : _login,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.tokenLoginButton),
        ),
      ),
    );
  }

  Widget _buildNoteCard(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer.withValues(alpha: 0.5),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Symbols.warning, size: 20, color: cs.onSecondaryContainer),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.tokenLoginNote,
                style: TextStyle(fontSize: 13, color: cs.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _tokenController,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: _decoration(l10n.tokenLoginTokenLabel, Symbols.key),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              l10n.spoofMainSectionTitle,
              padding: const EdgeInsets.only(bottom: 16, top: 4),
              fontSize: 20,
            ),
            Text(l10n.spoofDeviceTypeTitle),
            const SizedBox(height: 8),
            _chips(
              const [
                _Opt('ANDROID', 'Android', Symbols.android),
                _Opt('IOS', 'iOS', Symbols.phone_iphone),
              ],
              _selectedDeviceType,
              (v) => setState(() => _selectedDeviceType = v),
            ),
            const SizedBox(height: 16),
            _field(
              _deviceNameController,
              l10n.spoofFieldDeviceName,
              Symbols.smartphone,
            ),
            const SizedBox(height: 16),
            _field(
              _osVersionController,
              l10n.spoofFieldOsVersion,
              Symbols.layers,
            ),
            const SizedBox(height: 16),
            _field(
              _screenController,
              l10n.spoofFieldScreen,
              Symbols.fullscreen,
            ),
            const SizedBox(height: 16),
            _field(
              _timezoneController,
              l10n.spoofFieldTimezone,
              Symbols.public,
            ),
            const SizedBox(height: 16),
            _field(_localeController, l10n.spoofFieldLocale, Symbols.language),
            const SizedBox(height: 16),
            _field(
              _deviceLocaleController,
              l10n.spoofFieldDeviceLocale,
              Symbols.translate,
            ),
            const SizedBox(height: 24),
            SectionHeader(
              l10n.spoofIdentifiersSectionTitle,
              padding: const EdgeInsets.only(bottom: 16, top: 4),
              fontSize: 20,
            ),
            _field(
              _deviceIdController,
              l10n.spoofFieldDeviceId,
              Symbols.tag,
              onChanged: true,
            ),
            const SizedBox(height: 16),
            _field(
              _instanceIdController,
              l10n.spoofFieldInstanceId,
              Symbols.fingerprint,
            ),
            const SizedBox(height: 16),
            _field(
              _clientSessionIdController,
              l10n.spoofFieldClientSessionId,
              Symbols.vpn_key,
              number: true,
            ),
            const SizedBox(height: 16),
            _field(
              _appVersionController,
              l10n.spoofFieldAppVersion,
              Symbols.info,
            ),
            const SizedBox(height: 16),
            _field(
              _buildNumberController,
              l10n.spoofFieldBuildNumber,
              Symbols.numbers,
              number: true,
            ),
            const SizedBox(height: 16),
            _field(
              _pushDeviceTypeController,
              l10n.spoofFieldPushDeviceType,
              Symbols.notifications,
            ),
            const SizedBox(height: 16),
            Text(l10n.spoofFieldArchitecture),
            const SizedBox(height: 8),
            _chips(
              const [
                _Opt('arm64-v8a', 'arm64-v8a', Symbols.memory),
                _Opt('armeabi-v7a', 'armeabi-v7a', Symbols.memory),
                _Opt('arm64', 'arm64', Symbols.memory),
                _Opt('x86_64', 'x86_64', Symbols.memory),
                _Opt('x86', 'x86', Symbols.memory),
              ],
              _selectedArch,
              (v) => setState(() => _selectedArch = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool number = false,
    bool onChanged = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      onChanged: onChanged ? (_) => setState(() {}) : null,
      decoration: _decoration(label, icon),
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _chips(
    List<_Opt> options,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.value == selected;
        return ChoiceChip(
          label: Text(opt.label),
          avatar: isSelected
              ? Icon(Icons.check, size: 18, color: cs.onSecondaryContainer)
              : Icon(opt.icon, size: 18, color: cs.onSurfaceVariant),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(opt.value),
          backgroundColor: cs.surfaceContainerHighest,
          selectedColor: cs.secondaryContainer,
          side: BorderSide(
            color: isSelected ? Colors.transparent : cs.outlineVariant,
          ),
        );
      }).toList(),
    );
  }
}

class _Opt {
  final String value;
  final String label;
  final IconData icon;

  const _Opt(this.value, this.label, this.icon);
}
