import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/komet_settings.dart';
import '../../../main.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/section_header.dart';

class KometSettingsScreen extends StatelessWidget {
  const KometSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(titleText: 'Komet', backgroundColor: cs.surface),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            const SectionHeader(
              'Сообщения',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            _card(cs, [
              _toggle(
                cs,
                icon: Symbols.delete_history,
                label: 'View deleted message',
                subtitle: 'Показывать удалённые сообщения',
                notifier: KometSettings.viewDeleted,
                onChanged: KometSettings.setViewDeleted,
              ),
              _divider(cs),
              _toggle(
                cs,
                icon: Symbols.history_edu,
                label: 'View redacted message history',
                subtitle: 'Показывать историю у редактированных сообщений',
                notifier: KometSettings.viewRedacted,
                onChanged: KometSettings.setViewRedacted,
              ),
              _divider(cs),
              _toggle(
                cs,
                icon: Symbols.schedule,
                label: 'View full timestamp',
                subtitle: 'Показывать время в секундах у сообщений',
                notifier: KometSettings.fullTimestamp,
                onChanged: KometSettings.setFullTimestamp,
              ),
            ]),
            const SizedBox(height: 20),
            const SectionHeader(
              'Ghost Mode',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            _card(cs, [
              _toggle(
                cs,
                icon: Symbols.visibility_off,
                label: 'Ghost Mode',
                subtitle: 'Не отмечать вас в сети: пинги идут скрытно',
                notifier: KometSettings.ghostMode,
                onChanged: _setGhostMode,
              ),
              _divider(cs),
              _toggle(
                cs,
                icon: Symbols.radar,
                label: 'Self Online Check',
                subtitle:
                    'Каждые ~10 секунд сверяет, когда вы были онлайн. '
                    'Полезно для проверки ghost mode',
                notifier: KometSettings.selfOnlineCheck,
                onChanged: KometSettings.setSelfOnlineCheck,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _setGhostMode(bool value) async {
    await KometSettings.setGhostMode(value);
    api.sendPing(interactive: !value);
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

  Widget _toggle(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required String subtitle,
    required ValueNotifier<bool> notifier,
    required Future<void> Function(bool) onChanged,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, value, _) {
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
