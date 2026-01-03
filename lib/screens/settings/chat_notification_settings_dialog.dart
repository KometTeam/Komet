import 'package:flutter/material.dart';
import 'package:gwid/services/notification_settings_service.dart';

/// Диалог настроек уведомлений для конкретного чата
class ChatNotificationSettingsDialog extends StatefulWidget {
  final int chatId;
  final String chatName;
  final bool isGroupChat;
  final bool isChannel;

  const ChatNotificationSettingsDialog({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isGroupChat,
    required this.isChannel,
  });

  @override
  State<ChatNotificationSettingsDialog> createState() =>
      _ChatNotificationSettingsDialogState();
}

class _ChatNotificationSettingsDialogState
    extends State<ChatNotificationSettingsDialog> {
  final _settingsService = NotificationSettingsService();
  
  bool _isLoading = true;
  bool _hasException = false;
  bool _notificationsEnabled = true;
  VibrationMode _vibrationMode = VibrationMode.short;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final exceptions = await _settingsService.getChatExceptions();
      _hasException = exceptions.containsKey(widget.chatId);

      if (_hasException) {
        final settings = exceptions[widget.chatId]!;
        _notificationsEnabled = settings['enabled'] as bool? ?? true;
        final vibrationStr = settings['vibration'] as String? ?? 'short';
        _vibrationMode = _parseVibrationMode(vibrationStr);
      } else {
        // Загружаем настройки по умолчанию для типа чата
        final settings = await _settingsService.getSettingsForChat(
          chatId: widget.chatId,
          isGroupChat: widget.isGroupChat,
          isChannel: widget.isChannel,
        );
        _notificationsEnabled = settings['enabled'] as bool? ?? true;
        final vibrationStr = settings['vibration'] as String? ?? 'short';
        _vibrationMode = _parseVibrationMode(vibrationStr);
      }
    } catch (e) {
      print('Ошибка загрузки настроек: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  VibrationMode _parseVibrationMode(String mode) {
    switch (mode) {
      case 'none':
        return VibrationMode.none;
      case 'short':
        return VibrationMode.short;
      case 'long':
        return VibrationMode.long;
      default:
        return VibrationMode.short;
    }
  }

  String _getVibrationDescription(VibrationMode mode) {
    switch (mode) {
      case VibrationMode.none:
        return 'Выключена';
      case VibrationMode.short:
        return 'Короткая';
      case VibrationMode.long:
        return 'Длинная';
    }
  }

  Future<void> _saveSettings() async {
    if (_hasException) {
      await _settingsService.setChatException(
        chatId: widget.chatId,
        enabled: _notificationsEnabled,
        vibration: _vibrationMode,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Настройки сохранены'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeException() async {
    await _settingsService.removeChatException(widget.chatId);
    setState(() {
      _hasException = false;
    });
    await _loadSettings(); // Перезагружаем настройки по умолчанию

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Исключение удалено, используются настройки по умолчанию'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showVibrationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Вибрация'),
          children: [
            RadioListTile<VibrationMode>(
              title: const Text('Без вибрации'),
              value: VibrationMode.none,
              groupValue: _vibrationMode,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
            RadioListTile<VibrationMode>(
              title: const Text('Короткая'),
              value: VibrationMode.short,
              groupValue: _vibrationMode,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
            RadioListTile<VibrationMode>(
              title: const Text('Длинная'),
              value: VibrationMode.long,
              groupValue: _vibrationMode,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
          ],
        );
      },
    ).then((selectedValue) async {
      if (selectedValue != null) {
        setState(() {
          _vibrationMode = selectedValue;
          if (!_hasException) {
            _hasException = true; // Создаём исключение при изменении
          }
        });
        await _saveSettings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Уведомления',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.chatName,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Статус исключения
                  if (_hasException)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Используются индивидуальные настройки для этого чата',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_hasException) const SizedBox(height: 16),

                  // Включить/выключить уведомления
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Уведомления'),
                    subtitle: const Text('Включить для этого чата'),
                    value: _notificationsEnabled,
                    onChanged: (value) async {
                      setState(() {
                        _notificationsEnabled = value;
                        if (!_hasException) {
                          _hasException = true; // Создаём исключение
                        }
                      });
                      await _saveSettings();
                    },
                  ),
                  const Divider(),

                  // Настройка вибрации
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.vibration_outlined),
                    title: const Text('Вибрация'),
                    trailing: Text(
                      _getVibrationDescription(_vibrationMode),
                      style: TextStyle(color: colors.primary),
                    ),
                    onTap: _notificationsEnabled ? _showVibrationDialog : null,
                    enabled: _notificationsEnabled,
                  ),
                  const Divider(),

                  const SizedBox(height: 16),

                  // Кнопки действий
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_hasException)
                        TextButton.icon(
                          icon: const Icon(Icons.restore),
                          label: const Text('Сбросить'),
                          onPressed: _removeException,
                        ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Готово'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Показать диалог настроек уведомлений для чата
Future<void> showChatNotificationSettings({
  required BuildContext context,
  required int chatId,
  required String chatName,
  required bool isGroupChat,
  required bool isChannel,
}) {
  return showDialog(
    context: context,
    builder: (context) => ChatNotificationSettingsDialog(
      chatId: chatId,
      chatName: chatName,
      isGroupChat: isGroupChat,
      isChannel: isChannel,
    ),
  );
}
