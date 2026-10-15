import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/account/account_models.dart';
import '../../../core/config/app_badge.dart';
import '../../../core/config/app_notifications.dart';
import '../../../core/push/fkm_bridge.dart';
import '../../../core/push/fkm_controller.dart';
import '../../../core/push/notification_bridge.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/config/build_profile.dart';
import '../../../main.dart' show accountModule;
import '../../widgets/choice_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/hint_bubble.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';
import 'web_push_screen.dart';

class _PushSettingsState extends ChangeNotifier {
  bool _loading = true;
  bool _disposed = false;
  int _pending = 0;
  PrivacyConfig _confirmed = PrivacyConfig.empty();

  bool _messagePreview = true;
  String _dialogsMode = PrivacyConfig.pushOn;
  String _groupsMode = PrivacyConfig.pushOn;
  bool _callNotifications = true;
  bool _newContacts = false;

  bool get loading => _loading;
  bool get messagePreview => _messagePreview;
  String get dialogsMode => _dialogsMode;
  String get groupsMode => _groupsMode;
  bool get callNotifications => _callNotifications;
  bool get newContacts => _newContacts;

  Future<void> load() async {
    final config = await accountModule.getPrivacyConfig();
    if (_disposed) return;
    _loading = false;
    _show(config);
  }

  Future<void> setMessagePreview(bool value) => _apply(
    () => _messagePreview = value,
    () => accountModule.setMessagePreview(value),
  );

  Future<void> setDialogsMode(String mode) => _apply(
    () => _dialogsMode = mode,
    () => accountModule.setDialogsPushNotification(mode),
  );

  Future<void> setGroupsMode(String mode) => _apply(
    () => _groupsMode = mode,
    () => accountModule.setChatsPushNotification(mode),
  );

  Future<void> setCallNotifications(bool value) => _apply(
    () => _callNotifications = value,
    () => accountModule.setCallNotifications(value),
  );

  Future<void> setNewContacts(bool value) => _apply(
    () => _newContacts = value,
    () => accountModule.setNewContacts(value),
  );

  Future<void> _apply(
    VoidCallback optimistic,
    Future<PrivacyConfig> Function() request,
  ) async {
    _pending++;
    optimistic();
    notifyListeners();
    try {
      _confirmed = await request();
    } finally {
      _pending--;
      if (!_disposed && _pending == 0) _show(_confirmed);
    }
  }

  void _show(PrivacyConfig config) {
    _confirmed = config;
    _messagePreview = config.pushDetails;
    _dialogsMode = config.dialogsPushNotification;
    _groupsMode = config.chatsPushNotification;
    _callNotifications = config.mCallPushNotification == PrivacyConfig.pushOn;
    _newContacts = config.pushNewContacts;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Future<void> _save(BuildContext context, Future<void> request) async {
  try {
    await request;
  } catch (e) {
    if (!context.mounted) return;
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.notificationsSaveFailed(e.toString()),
    );
  }
}

String _modeLabel(AppLocalizations l10n, String mode) => switch (mode) {
  PrivacyConfig.pushOff => l10n.notificationsModeOff,
  PrivacyConfig.pushReplies => l10n.notificationsModeReplies,
  _ => l10n.notificationsModeOn,
};

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with ReloadOnReconnect {
  final _push = _PushSettingsState();
  late final AppLifecycleListener _lifecycle;

  bool _fkmBusy = false;
  bool _batteryRestricted = false;
  bool _hapticsEnabled = Haptics.enabled;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshBatteryState);
    _push.load();
    _refreshBatteryState();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _push.dispose();
    super.dispose();
  }

  @override
  void reloadAfterReconnect() => _push.load();

  Future<void> _refreshBatteryState() async {
    if (!FkmBridge.instance.isSupported) return;
    final ignoring = await FkmBridge.instance.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _batteryRestricted = !ignoring);
  }

  Future<void> _openBatterySettings(BuildContext anchor) async {
    if (!FkmBridge.instance.isSupported) {
      showHintBubble(
        anchor,
        AppLocalizations.of(context)!.notificationsAndroidOnly,
      );
      return;
    }
    await (_batteryRestricted
        ? FkmBridge.instance.requestIgnoreBatteryOptimizations()
        : FkmBridge.instance.openBatteryOptimizationSettings());
  }

  Future<void> _openSystemSettings(BuildContext anchor) async {
    if (!Platform.isAndroid) {
      showHintBubble(
        anchor,
        AppLocalizations.of(context)!.notificationsAndroidOnly,
      );
      return;
    }
    await NotificationBridge.instance.openSystemSettings();
  }

  Future<void> _setHaptics(bool value) async {
    await Haptics.setEnabled(value);
    if (value) Haptics.success();
    if (mounted) setState(() => _hapticsEnabled = value);
  }

  void _openWebPush() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const WebPushScreen()));
  }

  void _openOtherNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _OtherNotificationsScreen(push: _push),
      ),
    );
  }

  Future<void> _pickMode({
    required String title,
    required String current,
    required List<String> modes,
    required Future<void> Function(String mode) apply,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showChoiceSheet<String>(
      context,
      title: title,
      options: modes,
      selected: current,
      labelOf: (mode) => _modeLabel(l10n, mode),
    );
    if (picked == null || picked == current || !mounted) return;
    await _save(context, apply(picked));
  }

  Future<void> _onFkmChanged(BuildContext anchor, bool value) async {
    final l10n = AppLocalizations.of(context)!;
    if (!FkmController.instance.isSupported) {
      showHintBubble(
        anchor,
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
        child: ListenableBuilder(
          listenable: Listenable.merge([_push, AppNotifications.enabled]),
          builder: (context, _) => _push.loading
              ? const Center(child: SmallSpinner(size: 36))
              : _buildList(context, cs, l10n),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    final allEnabled = AppNotifications.enabled.value;

    return ListView(
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
          l10n.notificationsNetworkSectionTitle,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        ),
        SettingsCard(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: FkmController.instance.enabled,
              builder: (context, fkmEnabled, _) => SettingsToggleTile(
                icon: Symbols.cell_tower,
                label: l10n.notificationsBackgroundLabel,
                subtitle: l10n.notificationsBackgroundSubtitle,
                value: fkmEnabled,
                enabled: !_fkmBusy,
                onChanged: (v) => _onFkmChanged(context, v),
              ),
            ),
            Builder(
              builder: (context) => SettingsNavTile(
                icon: Symbols.battery_saver,
                label: l10n.notificationsBatteryLabel,
                subtitle: l10n.notificationsBatterySubtitle,
                trailing: _batteryRestricted
                    ? Icon(Symbols.error, fill: 1, color: cs.error, size: 22)
                    : null,
                onTap: () => _openBatterySettings(context),
                isLast: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SettingsCard(
          children: [
            SettingsToggleTile(
              icon: Symbols.notifications,
              label: l10n.notificationsAllLabel,
              value: allEnabled,
              onChanged: AppNotifications.setEnabled,
            ),
            SettingsToggleTile(
              icon: Symbols.chat,
              label: l10n.notificationsPreviewLabel,
              value: _push.messagePreview,
              enabled: allEnabled,
              onChanged: (v) => _save(context, _push.setMessagePreview(v)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Dimmed(
          active: allEnabled,
          child: SettingsCard(
            children: [
              SettingsNavTile(
                icon: Symbols.person,
                label: l10n.notificationsDialogsLabel,
                value: _modeLabel(l10n, _push.dialogsMode),
                onTap: () => _pickMode(
                  title: l10n.notificationsDialogsLabel,
                  current: _push.dialogsMode,
                  modes: const [PrivacyConfig.pushOn, PrivacyConfig.pushOff],
                  apply: _push.setDialogsMode,
                ),
              ),
              SettingsNavTile(
                icon: Symbols.group,
                label: l10n.notificationsGroupsLabel,
                value: _modeLabel(l10n, _push.groupsMode),
                onTap: () => _pickMode(
                  title: l10n.notificationsGroupsLabel,
                  current: _push.groupsMode,
                  modes: const [
                    PrivacyConfig.pushOn,
                    PrivacyConfig.pushReplies,
                    PrivacyConfig.pushOff,
                  ],
                  apply: _push.setGroupsMode,
                ),
              ),
              SettingsNavTile(
                icon: Symbols.notifications_unread,
                label: l10n.notificationsOtherLabel,
                onTap: _openOtherNotifications,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsCard(
          children: [
            Builder(
              builder: (context) => SettingsNavTile(
                icon: Symbols.tune,
                label: l10n.notificationsSystemLabel,
                subtitle: l10n.notificationsSystemSubtitle,
                onTap: () => _openSystemSettings(context),
                isLast: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _LauncherBadgeSection(),
        SectionHeader(
          l10n.notificationsHapticsSectionTitle,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
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
    );
  }
}

class _Dimmed extends StatelessWidget {
  final bool active;
  final Widget child;

  const _Dimmed({required this.active, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: active ? 1 : 0.4,
      child: IgnorePointer(ignoring: !active, child: child),
    );
  }
}

class _OtherNotificationsScreen extends StatelessWidget {
  final _PushSettingsState push;

  const _OtherNotificationsScreen({required this.push});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.notificationsOtherLabel,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: push,
          builder: (context, _) => ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              SettingsCard(
                children: [
                  SettingsToggleTile(
                    icon: Symbols.call,
                    label: l10n.notificationsCallsLabel,
                    value: push.callNotifications,
                    onChanged: (v) =>
                        _save(context, push.setCallNotifications(v)),
                  ),
                  SettingsToggleTile(
                    icon: Symbols.person_add,
                    label: l10n.notificationsNewContactsLabel,
                    value: push.newContacts,
                    onChanged: (v) => _save(context, push.setNewContacts(v)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LauncherBadgeSection extends StatelessWidget {
  const _LauncherBadgeSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l10n.notificationsBadgeSectionTitle,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        ),
        ListenableBuilder(
          listenable: Listenable.merge([
            AppBadge.enabled.current,
            AppBadge.includeMuted.current,
            AppBadge.countMessages.current,
          ]),
          builder: (context, _) {
            final enabled = AppBadge.enabled.current.value;
            return SettingsCard(
              children: [
                SettingsToggleTile(
                  icon: Symbols.app_badging,
                  label: l10n.notificationsBadgeLabel,
                  value: enabled,
                  onChanged: AppBadge.enabled.save,
                ),
                SettingsToggleTile(
                  icon: Symbols.notifications_off,
                  label: l10n.notificationsBadgeMutedLabel,
                  value: AppBadge.includeMuted.current.value,
                  enabled: enabled,
                  onChanged: AppBadge.includeMuted.save,
                ),
                SettingsToggleTile(
                  icon: Symbols.mark_chat_unread,
                  label: l10n.notificationsBadgeMessagesLabel,
                  subtitle: l10n.notificationsBadgeMessagesSubtitle,
                  value: AppBadge.countMessages.current.value,
                  enabled: enabled,
                  onChanged: AppBadge.countMessages.save,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
