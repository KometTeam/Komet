import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/fuckmax_settings.dart';
import '../../../main.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';

class FuckmaxSettingsScreen extends StatelessWidget {
  const FuckmaxSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Fuckmax',
        backgroundColor: cs.surface,
      ),
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
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.viewDeleted,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.delete_history,
                    label: 'View deleted message',
                    subtitle: 'Показывать удалённые сообщения',
                    value: value,
                    onChanged: FuckmaxSettings.setViewDeleted,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.viewRedacted,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.history_edu,
                    label: 'View redacted message history',
                    subtitle: 'Показывать историю у редактированных сообщений',
                    value: value,
                    onChanged: FuckmaxSettings.setViewRedacted,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.fullTimestamp,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.schedule,
                    label: 'View full timestamp',
                    subtitle: 'Показывать время в секундах у сообщений',
                    value: value,
                    onChanged: FuckmaxSettings.setFullTimestamp,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              'Папки',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.hideAllChatsFolder,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.folder_off,
                    label: 'Hide "All" folder',
                    subtitle:
                        'Скрыть папку «Все», когда есть другие папки. '
                        'Чаты сортируются только по вашим папкам',
                    value: value,
                    onChanged: FuckmaxSettings.setHideAllChatsFolder,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.showHiddenChats,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.visibility_lock,
                    label: 'Show hidden chats',
                    subtitle:
                        'Показывать скрытые чаты (например, от групповых '
                        'звонков), которые обычно не отображаются в списке',
                    value: value,
                    onChanged: FuckmaxSettings.setShowHiddenChats,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              'Ghost Mode',
              padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
              fontSize: 14,
            ),
            SettingsCard(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.ghostMode,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.visibility_off,
                    label: 'Ghost Mode',
                    subtitle: 'Вас не видно в сети',
                    value: value,
                    onChanged: _setGhostMode,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.antiRead,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.mark_chat_read,
                    label: 'Anti read',
                    subtitle: 'Нечиталка сообщений',
                    value: value,
                    onChanged: FuckmaxSettings.setAntiRead,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: FuckmaxSettings.selfOnlineCheck,
                  builder: (context, value, _) => SettingsToggleTile(
                    icon: Symbols.radar,
                    label: 'Self Online Check',
                    subtitle:
                        'Каждые ~10 секунд сверяет, когда вы были онлайн. '
                        'Полезно для проверки ghost mode',
                    value: value,
                    onChanged: FuckmaxSettings.setSelfOnlineCheck,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setGhostMode(bool value) async {
    await FuckmaxSettings.setGhostMode(value);
    api.sendPing(interactive: !value);
  }
}
