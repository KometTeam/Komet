import 'package:flutter/material.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/services/chat_read_settings_service.dart';
import 'package:gwid/app_sizes.dart';

class ReadSettingsDialogContent extends StatefulWidget {
  final Chat chat;
  final ChatReadSettings? initialSettings;
  final bool globalReadOnAction;
  final bool globalReadOnEnter;

  const ReadSettingsDialogContent({
    super.key,
    required this.chat,
    required this.initialSettings,
    required this.globalReadOnAction,
    required this.globalReadOnEnter,
  });

  @override
  State<ReadSettingsDialogContent> createState() =>
      _ReadSettingsDialogContentState();
}

class _ReadSettingsDialogContentState extends State<ReadSettingsDialogContent> {
  ChatReadSettings? _settings;
  bool _useDefault = true;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _useDefault = widget.initialSettings == null;
  }

  String _getSelectedOption() {
    if (_useDefault) {
      return 'default';
    }

    if (_settings == null) {
      return 'default';
    }

    if (_settings!.disabled) {
      return 'disabled';
    } else if (_settings!.readOnAction && _settings!.readOnEnter) {
      return 'both';
    } else if (_settings!.readOnAction) {
      return 'action';
    } else if (_settings!.readOnEnter) {
      return 'enter';
    }
    return 'default';
  }

  Future<void> _setOption(String option) async {
    setState(() {
      if (option == 'default') {
        _useDefault = true;
        _settings = null;
      } else {
        _useDefault = false;
        switch (option) {
          case 'disabled':
            _settings = ChatReadSettings(
              readOnAction: false,
              readOnEnter: false,
              disabled: true,
            );
            break;
          case 'action':
            _settings = ChatReadSettings(
              readOnAction: true,
              readOnEnter: false,
              disabled: false,
            );
            break;
          case 'enter':
            _settings = ChatReadSettings(
              readOnAction: false,
              readOnEnter: true,
              disabled: false,
            );
            break;
          case 'both':
          default:
            _settings = ChatReadSettings(
              readOnAction: true,
              readOnEnter: true,
              disabled: false,
            );
            break;
        }
      }
    });

    if (_useDefault || _settings == null) {
      await ChatReadSettingsService.instance.resetSettings(widget.chat.id);
    } else {
      await ChatReadSettingsService.instance.saveSettings(
        widget.chat.id,
        _settings!,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getDefaultDescription() {
    final action = widget.globalReadOnAction ? 'при действиях' : '';
    final enter = widget.globalReadOnEnter ? 'при входе' : '';

    if (action.isNotEmpty && enter.isNotEmpty) {
      return 'Чтение $action и $enter';
    } else if (action.isNotEmpty) {
      return 'Чтение $action';
    } else if (enter.isNotEmpty) {
      return 'Чтение $enter';
    }
    return 'Чтение отключено';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedOption = _getSelectedOption();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Настройки чтения сообщений',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('По умолчанию'),
                    subtitle: Text(_getDefaultDescription()),
                    value: 'default',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Отключить чтение'),
                    subtitle: const Text(
                      'Сообщения не будут отмечаться как прочитанные',
                    ),
                    value: 'disabled',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Чтение при действиях'),
                    subtitle: const Text(
                      'Отмечать прочитанным при отправке сообщения',
                    ),
                    value: 'action',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Чтение при входе в чат'),
                    subtitle: const Text(
                      'Отмечать прочитанным при открытии чата',
                    ),
                    value: 'enter',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Чтение при действиях и при входе'),
                    subtitle: const Text(
                      'Отмечать прочитанным при отправке и при открытии',
                    ),
                    value: 'both',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
