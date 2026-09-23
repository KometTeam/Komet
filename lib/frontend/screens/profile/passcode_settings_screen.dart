import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/sheet_helpers.dart';
import '../lock/lock_glyph.dart';
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
      MaterialPageRoute(builder: (_) => const PasscodeSetupScreen()),
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
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    l10n.passcodeAutoLock,
                    style: TextStyle(
                      fontFamily: displayFontOf(sheetContext),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.passcodeAutoLockHint,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
                for (final minutes in AppLock.idleOptions)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(_idleLabel(l10n, minutes)),
                    trailing: minutes == _lock.idleMinutes.value
                        ? Icon(Symbols.check, color: cs.primary)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, minutes),
                  ),
              ],
            ),
          ),
        );
      },
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
              _Hero(enabled: enabled),
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

class _Hero extends StatelessWidget {
  final bool enabled;

  const _Hero({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SettingsPanel(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: enabled ? 1 : 0),
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutBack,
            builder: (context, closed, _) => Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  cs.surfaceContainerHighest,
                  cs.primaryContainer,
                  closed.clamp(0.0, 1.0),
                ),
              ),
              child: LockGlyph(
                closed: closed,
                size: 52,
                color: Color.lerp(
                  cs.onSurfaceVariant,
                  cs.onPrimaryContainer,
                  closed.clamp(0.0, 1.0),
                )!,
                holeColor: Color.lerp(
                  cs.surfaceContainerHighest,
                  cs.primaryContainer,
                  closed.clamp(0.0, 1.0),
                )!,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.passcodeTitle,
            style: TextStyle(
              fontFamily: displayFontOf(context),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            enabled ? l10n.passcodeOnDescription : l10n.passcodeOffDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
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
