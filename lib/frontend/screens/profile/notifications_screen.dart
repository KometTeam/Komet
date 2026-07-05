import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show accountModule, isOnemeFlavor;
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _saving = false;

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

  void _onFkmTap() {
    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(
      context,
      isOnemeFlavor
          ? l10n.notificationsFkmAlreadyHasFcm
          : l10n.notificationsFkmDownloadFcm,
    );
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
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  SectionHeader(
                    l10n.notificationsFkmSectionTitle,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  SettingsCard(
                    children: [
                      SettingsToggleTile(
                        icon: Symbols.notifications_active,
                        label: l10n.notificationsFkmEnableLabel,
                        subtitle: l10n.notificationsFkmEnableSubtitle,
                        value: false,
                        onChanged: (_) => _onFkmTap(),
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
