import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/haptics.dart';
import '../../../main.dart' show accountModule, isOnemeFlavor;
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/section_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _defaultSound = 'oki.aiff';

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
    Map<String, dynamic> settings,
    ValueChanged<bool> assign,
  ) async {
    if (_saving) return;
    setState(() {
      assign(value);
      _saving = true;
    });
    try {
      await accountModule.updatePrivacyConfig(settings);
    } catch (e) {
      if (mounted) {
        setState(() => assign(!value));
        showCustomNotification(context, 'Не удалось сохранить: $e');
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
    showCustomNotification(
      context,
      isOnemeFlavor
          ? 'А зачем? У тебя уже FCM.'
          : 'Скачай лучше FCM-версию.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Уведомления',
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
                  const SectionHeader(
                    'FKM',
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  _card(cs, [
                    _toggleRow(
                      cs,
                      icon: Symbols.notifications_active,
                      label: 'Включить уведомления',
                      subtitle:
                          'Для работы FKM уведомлений, приложению понадобится держать уведомление в шторке.',
                      value: false,
                      onChanged: (_) => _onFkmTap(),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    'Уведомления',
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  _card(cs, [
                    _toggleRow(
                      cs,
                      icon: Symbols.notifications,
                      label: 'Все уведомления',
                      value: _allNotifications,
                      onChanged: (v) => _apply(
                        v,
                        {'CHATS_PUSH_NOTIFICATION': v ? 'ON' : 'OFF'},
                        (b) => _allNotifications = b,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    'Все новые уведомления',
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  _card(cs, [
                    _toggleRow(
                      cs,
                      icon: Symbols.chat,
                      label: 'Предпросмотр сообщений',
                      value: _messagePreview,
                      enabled: _allNotifications,
                      onChanged: (v) => _apply(
                        v,
                        {'PUSH_DETAILS': v},
                        (b) => _messagePreview = b,
                      ),
                    ),
                    _divider(cs),
                    _toggleRow(
                      cs,
                      icon: Symbols.music_note,
                      label: 'Звук',
                      value: _sound,
                      enabled: _allNotifications,
                      onChanged: (v) => _apply(
                        v,
                        {
                          'PUSH_SOUND': v ? _defaultSound : '',
                          'CHATS_PUSH_SOUND': v ? _defaultSound : '',
                        },
                        (b) => _sound = b,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    'Дополнительно',
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  _card(cs, [
                    _toggleRow(
                      cs,
                      icon: Symbols.call,
                      label: 'Уведомления о звонках',
                      value: _callNotifications,
                      onChanged: (v) => _apply(
                        v,
                        {'M_CALL_PUSH_NOTIFICATION': v ? 'ON' : 'OFF'},
                        (b) => _callNotifications = b,
                      ),
                    ),
                    _divider(cs),
                    _toggleRow(
                      cs,
                      icon: Symbols.person_add,
                      label: 'Уведомления от новых контактов',
                      value: _newContacts,
                      onChanged: (v) => _apply(
                        v,
                        {'PUSH_NEW_CONTACTS': v},
                        (b) => _newContacts = b,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    'Тактильная отдача',
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                    fontSize: 14,
                  ),
                  _card(cs, [
                    _toggleRow(
                      cs,
                      icon: Symbols.vibration,
                      label: 'Тактильная отдача',
                      subtitle: 'Виброотклик при действиях в приложении',
                      value: _hapticsEnabled,
                      onChanged: _setHaptics,
                    ),
                  ]),
                ],
              ),
      ),
    );
  }

  Widget _card(ColorScheme cs, List<Widget> children) {
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Column(children: children),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 58),
      child: Divider(
        height: 1,
        thickness: 1,
        color: cs.outlineVariant.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _toggleRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
