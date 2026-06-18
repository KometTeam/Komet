import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../widgets/glossy_pill.dart';
import '../../widgets/section_header.dart';
import '../../widgets/sheet_helpers.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _fkmEnabled = false;
  bool _personalChatsEnabled = true;
  bool _groupsEnabled = true;
  bool _channelsEnabled = true;
  String _selectedSound = 'По умолчанию';

  static const List<String> _sounds = [
    'По умолчанию',
    'Колокольчик',
    'Звон',
    'Капля',
    'Беззвучно',
  ];

  Future<void> _pickSound() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Text(
                        'Звук уведомления',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final s in _sounds)
                  ListTile(
                    onTap: () => Navigator.of(context).pop(s),
                    leading: Icon(
                      s == _selectedSound
                          ? Symbols.radio_button_checked
                          : Symbols.radio_button_unchecked,
                      color: s == _selectedSound
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    title: Text(
                      s,
                      style: TextStyle(color: cs.onSurface, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && picked != _selectedSound) {
      setState(() => _selectedSound = picked);
    }
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
        child: ListView(
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
                value: _fkmEnabled,
                onChanged: (v) => setState(() => _fkmEnabled = v),
              ),
            ]),
            const SizedBox(height: 20),
            const SectionHeader(
              'Настройки уведомлений',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            _card(cs, [
              _toggleRow(
                cs,
                icon: Symbols.person,
                label: 'Уведомления от личных чатов',
                value: _personalChatsEnabled,
                onChanged: (v) => setState(() => _personalChatsEnabled = v),
              ),
              _divider(cs),
              _toggleRow(
                cs,
                icon: Symbols.groups,
                label: 'Уведомления от групп',
                value: _groupsEnabled,
                onChanged: (v) => setState(() => _groupsEnabled = v),
              ),
              _divider(cs),
              _toggleRow(
                cs,
                icon: Symbols.campaign,
                label: 'Уведомления от каналов',
                value: _channelsEnabled,
                onChanged: (v) => setState(() => _channelsEnabled = v),
              ),
            ]),
            const SizedBox(height: 20),
            const SectionHeader(
              'Звук',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            _card(cs, [
              _tappableRow(
                cs,
                icon: Symbols.music_note,
                label: 'Звук уведомления',
                trailingText: _selectedSound,
                onTap: _pickSound,
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
  }) {
    return Material(
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
    );
  }

  Widget _tappableRow(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
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
              Text(
                trailingText,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(width: 6),
              Icon(Symbols.chevron_right, color: cs.outline, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
