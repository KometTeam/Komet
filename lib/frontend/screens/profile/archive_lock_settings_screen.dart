import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/security/archive_lock.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/choice_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../lock/lock_hero.dart';
import '../lock/passcode_setup_screen.dart';

class ArchiveLockSettingsScreen extends StatelessWidget {
  const ArchiveLockSettingsScreen({super.key});

  static String relockLabel(AppLocalizations l10n, int minutes) {
    if (minutes <= 0) return l10n.archiveLockRelockNow;
    if (minutes % 60 == 0) return l10n.archiveLockRelockHours(minutes ~/ 60);
    return l10n.passcodeAutoLockAfter(minutes);
  }

  Future<void> _setUp(BuildContext context, {required bool changing}) async {
    final l10n = AppLocalizations.of(context)!;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasscodeSetupScreen(
          title: l10n.archiveLockTitle,
          onSave: ArchiveLock.instance.setPin,
        ),
      ),
    );
    if (done != true || !context.mounted) return;
    showCustomNotification(
      context,
      changing ? l10n.archiveLockChanged : l10n.archiveLockEnabled,
    );
  }

  Future<void> _pickRelock(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final lock = ArchiveLock.instance;
    final picked = await showChoiceSheet<int>(
      context,
      title: l10n.archiveLockRelock,
      hint: l10n.archiveLockRelockHint,
      options: ArchiveLock.relockOptions,
      selected: lock.relockMinutes.value,
      labelOf: (minutes) => relockLabel(l10n, minutes),
    );
    if (picked == null) return;
    Haptics.selection();
    await lock.setRelockMinutes(picked);
  }

  Future<void> _disable(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.archiveLockDisableTitle,
      message: l10n.archiveLockDisableMessage,
      confirmLabel: l10n.archiveLockDisableAction,
      cancelLabel: l10n.passcodeCancel,
      destructive: true,
    );
    if (!confirmed) return;
    await ArchiveLock.instance.disable();
    if (context.mounted) {
      showCustomNotification(context, l10n.archiveLockDisabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final lock = ArchiveLock.instance;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.archiveLockTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<bool>(
          valueListenable: lock.enabled,
          builder: (context, enabled, _) => ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              LockHero(
                enabled: enabled,
                title: l10n.archiveLockTitle,
                description: enabled
                    ? l10n.archiveLockOnDescription
                    : l10n.archiveLockOffDescription,
              ),
              const SizedBox(height: 16),
              if (!enabled)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _setUp(context, changing: false),
                    icon: const Icon(Symbols.lock),
                    label: Text(l10n.archiveLockEnable),
                  ),
                )
              else ...[
                SettingsCard(
                  children: [
                    SettingsNavTile(
                      icon: Symbols.password,
                      label: l10n.archiveLockChange,
                      onTap: () => _setUp(context, changing: true),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: lock.relockMinutes,
                      builder: (context, minutes, _) => SettingsNavTile(
                        icon: Symbols.timer,
                        label: l10n.archiveLockRelock,
                        value: relockLabel(l10n, minutes),
                        onTap: () => _pickRelock(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SettingsCard(
                  children: [
                    SettingsNavTile(
                      icon: Symbols.lock_open,
                      label: l10n.archiveLockDisable,
                      tintColor: cs.error,
                      onTap: () => _disable(context),
                    ),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                child: Text(
                  l10n.archiveLockForgotHint,
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
