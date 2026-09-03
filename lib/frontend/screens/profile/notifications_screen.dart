import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/push/fkm_bridge.dart';
import '../../../core/push/fkm_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/config/build_profile.dart';
import '../../../main.dart' show accountModule;
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import 'web_push_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with ReloadOnReconnect {
  bool _loading = true;
  bool _saving = false;
  bool _fkmBusy = false;

  bool _allNotifications = true;
  bool _messagePreview = true;
  bool _sound = true;
  bool _callNotifications = true;
  bool _newContacts = false;
  bool _hapticsEnabled = Haptics.enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reloadAfterReconnect() => _load();

  Future<void> _load() async {
    final config = await accountModule.getPrivacyConfig();
    if (!mounted) return;
    setState(() {
      _allNotifications = config.chatsPushNotification == 'ON';
      _messagePreview = config.pushDetails;
      _sound = config.pushSound.isNotEmpty || config.chatsPushSound.isNotEmpty;
      _callNotifications = config.mCallPushNotification == 'ON';
      _newContacts = config.pushNewContacts;
      _loading = false;
    });
  }

  Future<void> _apply(
    bool value,
    Future<void> Function() action,
    ValueChanged<bool> assign,
  ) async {
    if (_saving) return;
    setState(() {
      assign(value);
      _saving = true;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => assign(!value));
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.notificationsSaveFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setHaptics(bool value) async {
    await Haptics.setEnabled(value);
    if (value) Haptics.success();
    if (mounted) setState(() => _hapticsEnabled = value);
  }

  void _openWebPush() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const WebPushScreen()),
    );
  }

  Future<void> _onFkmChanged(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (!FkmController.instance.isSupported) {
      showCustomNotification(
        context,
        Platform.isIOS
            ? l10n.notificationsFkmIosUnsupported
            : l10n.notificationsFkmUnsupported,
      );
      return;
    }
    if (_fkmBusy) return;

    if (value && BuildProfile.firebasePush) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.notificationsFkmAlreadyHasFcm,
        message: l10n.notificationsFkmConfirmMessage,
        confirmLabel: l10n.notificationsFkmConfirmAction,
      );
      if (!confirmed) return;
    }

    setState(() => _fkmBusy = true);
    try {
      final applied = await FkmController.instance.setEnabled(value);
      if (!mounted) return;
      if (!applied) {
        showCustomNotification(context, l10n.notificationsFkmPermissionDenied);
        return;
      }
      if (value) await _offerBatteryExemption();
    } finally {
      if (mounted) setState(() => _fkmBusy = false);
    }
  }

  Future<void> _offerBatteryExemption() async {
    if (await FkmBridge.instance.isIgnoringBatteryOptimizations()) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.notificationsFkmBatteryTitle,
      message: l10n.notificationsFkmBatteryMessage,
      confirmLabel: l10n.notificationsFkmBatteryAction,
    );
    if (!confirmed) return;
    await FkmBridge.instance.requestIgnoreBatteryOptimizations();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.notificationsTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: SmallSpinner(size: 36))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  if (Platform.isIOS) ...[
                    SettingsCard(
                      children: [
                        SettingsNavTile(
                          icon: Symbols.install_mobile,
                          label: l10n.webPushTitle,
                          onTap: _openWebPush,
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  SectionHeader(
                    l10n.notificationsFkmSectionTitle,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  SettingsCard(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: FkmController.instance.enabled,
                        builder: (context, fkmEnabled, _) => SettingsToggleTile(
                          icon: Symbols.notifications_active,
                          label: l10n.notificationsFkmEnableLabel,
                          subtitle: l10n.notificationsFkmEnableSubtitle,
                          value: fkmEnabled,
                          enabled: !_fkmBusy,
                          onChanged: _onFkmChanged,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    l10n.notificationsMainSectionTitle,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  SettingsCard(
                    children: [
                      SettingsToggleTile(
                        icon: Symbols.notifications,
                        label: l10n.notificationsAllLabel,
                        value: _allNotifications,
                        onChanged: (v) => _apply(
                          v,
                          () => accountModule.setChatsPushNotification(v),
                          (b) => _allNotifications = b,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    l10n.notificationsNewSectionTitle,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  SettingsCard(
                    children: [
                      SettingsToggleTile(
                        icon: Symbols.chat,
                        label: l10n.notificationsPreviewLabel,
                        value: _messagePreview,
                        enabled: _allNotifications,
                        onChanged: (v) => _apply(
                          v,
                          () => accountModule.setMessagePreview(v),
                          (b) => _messagePreview = b,
                        ),
                      ),
                      SettingsToggleTile(
                        icon: Symbols.music_note,
                        label: l10n.notificationsSoundLabel,
                        value: _sound,
                        enabled: _allNotifications,
                        onChanged: (v) => _apply(
                          v,
                          () => accountModule.setNotificationSound(v),
                          (b) => _sound = b,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    l10n.notificationsAdditionalSectionTitle,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  SettingsCard(
                    children: [
                      SettingsToggleTile(
                        icon: Symbols.call,
                        label: l10n.notificationsCallsLabel,
                        value: _callNotifications,
                        onChanged: (v) => _apply(
                          v,
                          () => accountModule.setCallNotifications(v),
                          (b) => _callNotifications = b,
                        ),
                      ),
                      SettingsToggleTile(
                        icon: Symbols.person_add,
                        label: l10n.notificationsNewContactsLabel,
                        value: _newContacts,
                        onChanged: (v) => _apply(
                          v,
                          () => accountModule.setNewContacts(v),
                          (b) => _newContacts = b,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    l10n.notificationsHapticsSectionTitle,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  SettingsCard(
                    children: [
                      SettingsToggleTile(
                        icon: Symbols.vibration,
                        label: l10n.notificationsHapticsLabel,
                        subtitle: l10n.notificationsHapticsSubtitle,
                        value: _hapticsEnabled,
                        onChanged: _setHaptics,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
