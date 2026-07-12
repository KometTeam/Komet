import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_commands.dart';
import '../../core/config/app_digital_id_mode.dart';
import '../../core/config/app_link_preview.dart';
import '../../core/config/app_pranks.dart';
import '../../core/config/app_show_extra_info.dart';
import '../../core/config/app_stories.dart';
import '../../core/config/app_swipe_back_desktop.dart';
import '../screens/digital_id/digital_id_web_screen.dart';
import '../widgets/custom_notification.dart';
import 'debug_toggle_tile.dart';

class DebugFeatureTogglesSection extends StatelessWidget {
  const DebugFeatureTogglesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.swipe_right,
            title: 'Свайп-назад в десктоп-режиме',
            subtitle: (_) =>
                'Включает жест «провести от левого края, чтобы '
                'закрыть» внутри встроенной панели чата на '
                'десктопе — для тестирования курсором',
            valueListenable: AppSwipeBackDesktop.current,
            onChanged: AppSwipeBackDesktop.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.auto_awesome,
            title: 'Приколь4ики',
            valueListenable: AppPranks.current,
            onChanged: AppPranks.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.badge,
            title: 'Нативный Цифровой ID',
            subtitle: (native) => native
                ? 'Нативный экран (REST ext-api.max.ru)'
                : 'Оригинальная страница в WebView',
            valueListenable: AppDigitalIdNative.current,
            onChanged: AppDigitalIdNative.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await resetDigitalIdWebData();
                if (!context.mounted) return;
                showCustomNotification(
                  context,
                  'Цифровой ID сброшен — Госуслуги спросят вход заново',
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.restart_alt,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сбросить Цифровой ID',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Очистить куки и данные WebView',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.amp_stories,
            title: 'Истории',
            subtitle: (_) => 'Отображение ленты историй в списке чатов',
            valueListenable: AppStories.current,
            onChanged: AppStories.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.terminal,
            title: 'Команды',
            subtitle: (_) => 'Панель команд по вводу «/» в строке сообщения',
            valueListenable: AppCommands.current,
            onChanged: AppCommands.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.link,
            title: 'Предпросмотр ссылок',
            subtitle: (_) => 'Карточки с превью для ссылок в сообщениях',
            valueListenable: AppLinkPreview.current,
            onChanged: AppLinkPreview.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.info,
            title: 'Доп. информация',
            subtitle: (_) =>
                'Раздел «Info» в настройках и вкладка с '
                'технической информацией в профиле собеседника',
            valueListenable: AppShowExtraInfo.current,
            onChanged: AppShowExtraInfo.save,
          ),
        ),
      ],
    );
  }
}
