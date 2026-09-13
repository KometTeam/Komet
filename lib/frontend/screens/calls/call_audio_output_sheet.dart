import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/audio_devices.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/config/app_fonts.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';

Future<void> showCallAudioOutputSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _AudioOutputSheet(session: session),
    ),
  );
}

class _AudioOutputSheet extends StatefulWidget {
  const _AudioOutputSheet({required this.session});

  final CallSession session;

  @override
  State<_AudioOutputSheet> createState() => _AudioOutputSheetState();
}

class _AudioOutputSheetState extends State<_AudioOutputSheet> {
  List<AudioOutputDevice>? _devices;
  String? _selected;
  bool _switching = false;

  String _text(String ru, String en) =>
      Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final devices = await AudioDevices.outputs();
    if (!mounted) return;
    setState(() {
      _selected = widget.session.audioOutputDeviceId;
      _devices = devices.where((device) => device.id != 'default').toList();
    });
  }

  Future<void> _select(String? id) async {
    if (_switching || id == _selected) return;
    setState(() => _switching = true);
    try {
      await widget.session.setAudioOutput(id);
      if (mounted) setState(() => _selected = id);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          _text(
            'Не удалось выбрать устройство: $e',
            'Could not select output: $e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final devices = _devices;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _text('Вывод звука', 'Sound output'),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: displayFontOf(context),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _switching
                        ? null
                        : () {
                            setState(() => _devices = null);
                            _load();
                          },
                    tooltip: _text('Обновить', 'Refresh'),
                    icon: Icon(Symbols.refresh, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (devices == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _tile(
                      cs,
                      id: null,
                      label: _text('Системное устройство', 'System default'),
                    ),
                    for (var i = 0; i < devices.length; i++)
                      _tile(
                        cs,
                        id: devices[i].id,
                        label: devices[i].label.isEmpty
                            ? _text(
                                'Устройство вывода ${i + 1}',
                                'Output device ${i + 1}',
                              )
                            : devices[i].label,
                      ),
                    if (devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Text(
                          _text(
                            'Дополнительные устройства не найдены',
                            'No additional output devices found',
                          ),
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tile(ColorScheme cs, {required String? id, required String label}) {
    final selected = _selected == id;
    return ListTile(
      leading: Icon(
        Symbols.speaker,
        color: selected ? cs.primary : cs.onSurface,
      ),
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? cs.primary : cs.onSurface,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: selected ? Icon(Symbols.check, color: cs.primary) : null,
      enabled: !_switching,
      onTap: () => _select(id),
    );
  }
}
