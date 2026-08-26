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
import 'debug_toggle_tile.dart';

class DebugFeatureTogglesSection extends StatelessWidget {
  const DebugFeatureTogglesSection({super.key});

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
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _pickVideoNoteQuality(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.video_camera_front,
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
                            'Качество записи кружков',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ValueListenableBuilder<int>(
                            valueListenable: AppVideoNoteResolution.current,
                            builder: (context, res, _) =>
                                ValueListenableBuilder<int>(
                                  valueListenable: AppVideoNoteFps.current,
                                  builder: (context, fps, _) => Text(
                                    '$res×$res • $fps fps (только Android)',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
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
            icon: Symbols.flip_camera_android,
            title: 'Кружки с задней камеры',
            subtitle: (v) => v
                ? 'Запись кружка начинается с задней камеры'
                : 'Запись кружка начинается с фронтальной камеры',
            valueListenable: AppVideoNoteRearCamera.current,
            onChanged: AppVideoNoteRearCamera.save,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DebugToggleTile(
            icon: Symbols.contacts,
            title: 'Имена из телефонной книги',
            subtitle: (v) => v
                ? 'Имена собеседников показываются так, как записаны в '
                      'телефонной книге устройства'
                : 'Имена показываются так, как их прислал сервер',
            valueListenable: AppPhonebookNames.current,
            onChanged: (v) => _onPhonebookNamesChanged(context, v),
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
