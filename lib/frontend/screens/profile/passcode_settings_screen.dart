import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/security/app_lock.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../lock/lock_hero.dart';
import '../lock/passcode_setup_screen.dart';

class PasscodeSettingsScreen extends StatefulWidget {
  const PasscodeSettingsScreen({super.key});

  @override
  State<PasscodeSettingsScreen> createState() => _PasscodeSettingsScreenState();
}

class _PasscodeSettingsScreenState extends State<PasscodeSettingsScreen> {
  final AppLock _lock = AppLock.instance;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkBiometric());
  }

  Future<void> _checkBiometric() async {
    final available = await _lock.biometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _setUp({required bool changing}) async {
    final l10n = AppLocalizations.of(context)!;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasscodeSetupScreen(
          title: l10n.passcodeTitle,
          onSave: _lock.setPin,
        ),
      ),
    );
    if (done != true || !mounted) return;
    showCustomNotification(
      context,
      changing ? l10n.passcodeChanged : l10n.passcodeEnabled,
    );
  }

  Future<void> _setBiometric(bool value) async {
    if (value) {
      final ok = await _lock.authenticateBiometric(
        AppLocalizations.of(context)!.lockBiometricReason,
      );
      if (!ok) return;
    }
    Haptics.selection();
    await _lock.setBiometric(value);
  }

  Future<void> _pickIdle() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showChoiceSheet<int>(
      context,
      title: l10n.passcodeAutoLock,
      hint: l10n.passcodeAutoLockHint,
      options: AppLock.idleOptions,
      selected: _lock.idleMinutes.value,
      labelOf: (minutes) => _idleLabel(l10n, minutes),
    );
    if (picked == null) return;
    Haptics.selection();
    await _lock.setIdleMinutes(picked);
  }

  Future<void> _disable() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.passcodeDisableTitle,
      message: l10n.passcodeDisableMessage,
      confirmLabel: l10n.passcodeDisableAction,
      cancelLabel: l10n.passcodeCancel,
      destructive: true,
    );
    if (!confirmed) return;
    await _lock.disable();
    if (mounted) showCustomNotification(context, l10n.passcodeDisabled);
  }

  static String _idleLabel(AppLocalizations l10n, int minutes) => minutes <= 0
      ? l10n.passcodeAutoLockOff
      : l10n.passcodeAutoLockAfter(minutes);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.passcodeTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: _lock.enabled,
          builder: (context, enabled, _) => ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              LockHero(
                enabled: enabled,
                title: l10n.passcodeTitle,
                description: enabled
                    ? l10n.passcodeOnDescription
                    : l10n.passcodeOffDescription,
              ),
              const SizedBox(height: 16),
              if (!enabled)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _setUp(changing: false),
                    icon: const Icon(Symbols.lock),
                    label: Text(l10n.passcodeEnable),
                  ),
                )
              else ...[
                SettingsCard(
                  children: [
                    SettingsNavTile(
                      icon: Symbols.password,
                      label: l10n.passcodeChange,
                      onTap: () => _setUp(changing: true),
                    ),
                    if (_biometricAvailable)
                      ValueListenableBuilder<bool>(
                        valueListenable: _lock.biometric,
                        builder: (context, value, _) => SettingsToggleTile(
                          icon: Symbols.fingerprint,
                          label: l10n.passcodeBiometric,
                          subtitle: l10n.passcodeBiometricHint,
                          value: value,
                          onChanged: _setBiometric,
                        ),
                      ),
                    ValueListenableBuilder<int>(
                      valueListenable: _lock.idleMinutes,
                      builder: (context, minutes, _) => _ValueTile(
                        icon: Symbols.timer,
                        label: l10n.passcodeAutoLock,
                        value: _idleLabel(l10n, minutes),
                        onTap: _pickIdle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SettingsCard(
                  children: [
                    SettingsNavTile(
                      icon: Symbols.lock_open,
                      label: l10n.passcodeDisable,
                      tintColor: cs.error,
                      onTap: _disable,
                    ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                child: Text(
                  l10n.passcodeForgotHint,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ValueTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(value, style: TextStyle(color: cs.primary, fontSize: 14.5)),
              const SizedBox(width: 4),
              Icon(
                Symbols.chevron_right,
                color: cs.outline,
                size: 20,
                weight: 400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
