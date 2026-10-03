import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/contacts.dart';
import '../../core/config/app_commands.dart';
import '../../core/config/app_digital_id_mode.dart';
import '../../core/config/app_link_preview.dart';
import '../../core/config/app_phonebook_names.dart';
import '../../core/config/app_pranks.dart';
import '../../core/config/app_show_extra_info.dart';
import '../../core/config/app_stories.dart';
import '../../core/config/app_swipe_back_desktop.dart';
import '../../core/config/app_video_note_quality.dart';
import '../../core/contacts/device_contacts_service.dart';
import '../screens/digital_id/digital_id_web_screen.dart';
import '../widgets/custom_notification.dart';
import '../widgets/sheet_helpers.dart';
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

  void _pickVideoNoteQuality(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Качество записи кружков',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Разрешение',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ),
            for (final preset in AppVideoNoteResolution.presets)
              ValueListenableBuilder<int>(
                valueListenable: AppVideoNoteResolution.current,
                builder: (context, value, _) => ListTile(
                  title: Text(
                    '$preset×$preset',
                    style: TextStyle(color: cs.onSurface, fontSize: 16),
                  ),
                  trailing: value == preset
                      ? Icon(Symbols.check, color: cs.primary)
                      : null,
                  onTap: () => AppVideoNoteResolution.save(preset),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Частота кадров',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            ),
            for (final preset in AppVideoNoteFps.presets)
              ValueListenableBuilder<int>(
                valueListenable: AppVideoNoteFps.current,
                builder: (context, value, _) => ListTile(
                  title: Text(
                    '$preset fps',
                    style: TextStyle(color: cs.onSurface, fontSize: 16),
                  ),
                  trailing: value == preset
                      ? Icon(Symbols.check, color: cs.primary)
                      : null,
                  onTap: () => AppVideoNoteFps.save(preset),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    final cs = Theme.of(context).colorScheme;
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
            ValueListenableBuilder<int>(
              valueListenable: AppVideoNoteResolution.current,
              builder: (context, res, _) => ValueListenableBuilder<int>(
                valueListenable: AppVideoNoteFps.current,
                builder: (context, fps, _) => DevRow(
                  caption: 'Качество записи (только Android)',
                  title: '$res×$res • $fps fps',
                  onTap: () => _pickVideoNoteQuality(context),
                  trailing: Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 20,
                  ),
                ),
              ),
            ),
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
          ],
        ),
      ],
    );
  }
}
