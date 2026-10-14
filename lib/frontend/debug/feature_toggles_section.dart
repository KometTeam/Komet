import 'package:flutter/material.dart';

import '../../backend/modules/contacts.dart';
import '../../core/config/app_commands.dart';
import '../../core/config/app_digital_id_mode.dart';
import '../../core/config/app_link_preview.dart';
import '../../core/config/app_phonebook_names.dart';
import '../../core/config/app_pranks.dart';
import '../../core/config/app_show_extra_info.dart';
import '../../core/config/app_stories.dart';
import '../../core/config/app_swipe_back_desktop.dart';
import '../../core/config/app_unchecked_links.dart';
import '../../core/config/app_video_note_quality.dart';
import '../../core/contacts/device_contacts_service.dart';
import '../screens/digital_id/digital_id_web_screen.dart';
import '../widgets/custom_notification.dart';
import '../../main.dart' show KometAppState;
import 'dev_menu_widgets.dart';

class DebugFeatureTogglesSection extends StatelessWidget {
  final KometAppState? appState;

  const DebugFeatureTogglesSection({super.key, required this.appState});

  Future<void> _onPhonebookNamesChanged(
    BuildContext context,
    bool value,
  ) async {
    await AppPhonebookNames.save(value);
    if (value) {
      final ok = await DeviceContactsService.reload();
      if (!ok && context.mounted) {
        showCustomNotification(
          context,
          'Не удалось загрузить контакты телефона',
        );
      }
    }
    ContactsModule.revision.value++;
  }

  Future<void> _resetDigitalId(BuildContext context) async {
    await resetDigitalIdWebData();
    if (!context.mounted) return;
    showCustomNotification(
      context,
      'Цифровой ID сброшен — Госуслуги спросят вход заново',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = appState;
    return Column(
      children: [
        const DevGroupLabel('Интерфейс'),
        DevGroup(
          children: [
            DevToggleRow(
              title: 'Истории',
              description: (_) => 'Лента историй в списке чатов',
              valueListenable: AppStories.current,
              onChanged: AppStories.save,
            ),
            DevToggleRow(
              title: 'Команды',
              description: (_) => 'Панель команд по вводу «/»',
              valueListenable: AppCommands.current,
              onChanged: AppCommands.save,
            ),
            DevToggleRow(
              title: 'Предпросмотр ссылок',
              description: (_) => 'Карточки с превью ссылок в сообщениях',
              valueListenable: AppLinkPreview.current,
              onChanged: AppLinkPreview.save,
            ),
            DevToggleRow(
              title: 'Доп. информация',
              description: (_) =>
                  'Раздел «Info» в настройках и техническая вкладка '
                  'в профиле собеседника',
              valueListenable: AppShowExtraInfo.current,
              onChanged: AppShowExtraInfo.save,
            ),
            DevToggleRow(
              title: 'Имена из телефонной книги',
              description: (v) => v
                  ? 'Как записаны в телефонной книге устройства'
                  : 'Как их прислал сервер',
              valueListenable: AppPhonebookNames.current,
              onChanged: (v) => _onPhonebookNamesChanged(context, v),
            ),
            DevToggleRow(
              title: 'Приколь4ики',
              valueListenable: AppPranks.current,
              onChanged: AppPranks.save,
            ),
          ],
        ),
        const DevGroupLabel('Кружки'),
        DevGroup(
          children: [
            DevToggleRow(
              title: 'Кружки с задней камеры',
              description: (v) => v
                  ? 'Запись начинается с задней камеры'
                  : 'Запись начинается с фронтальной камеры',
              valueListenable: AppVideoNoteRearCamera.current,
              onChanged: AppVideoNoteRearCamera.save,
            ),
          ],
        ),
        const DevGroupLabel('Цифровой ID'),
        DevGroup(
          children: [
            DevToggleRow(
              title: 'Нативный Цифровой ID',
              description: (native) => native
                  ? 'Нативный экран (REST ext-api.max.ru)'
                  : 'Оригинальная страница в WebView',
              valueListenable: AppDigitalIdNative.current,
              onChanged: AppDigitalIdNative.save,
            ),
            DevRow(
              caption: 'Очистить куки и данные WebView',
              title: 'Сбросить Цифровой ID',
              onTap: () => _resetDigitalId(context),
            ),
          ],
        ),
        const DevGroupLabel('Отладка'),
        DevGroup(
          children: [
            if (state != null)
              DevToggleRow(
                title: 'Оверлей FPS',
                description: (_) => 'Фреймрейт поверх интерфейса',
                valueListenable: state.fpsOverlayEnabled,
                onChanged: state.setFpsOverlayEnabled,
              ),
            DevToggleRow(
              title: 'Свайп-назад в десктоп-режиме',
              description: (_) =>
                  'Жест от левого края во встроенной панели чата — '
                  'для теста курсором',
              valueListenable: AppSwipeBackDesktop.current,
              onChanged: AppSwipeBackDesktop.save,
            ),
            DevToggleRow(
              title: 'Не проверять ссылки',
              description: (v) => v
                  ? 'Адрес ссылки уходит как введён, без https://'
                  : 'Адрес ссылки проверяется, https:// дописывается',
              valueListenable: AppUncheckedLinks.current,
              onChanged: AppUncheckedLinks.save,
            ),
          ],
        ),
      ],
    );
  }
}
