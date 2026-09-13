import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/calls/call_session.dart';
import '../../../core/utils/logger.dart';
import '../../widgets/custom_notification.dart';

String captureText(BuildContext context, String ru, String en) =>
    Localizations.localeOf(context).languageCode == 'ru' ? ru : en;

Future<DesktopCapturerSource?> showCaptureSourcePicker(BuildContext context) =>
    showDialog<DesktopCapturerSource>(
      context: context,
      builder: (_) => const _CaptureSourcePicker(),
    );

class _CaptureSourcePicker extends StatefulWidget {
  const _CaptureSourcePicker();

  @override
  State<_CaptureSourcePicker> createState() => _CaptureSourcePickerState();
}

class _CaptureSourcePickerState extends State<_CaptureSourcePicker> {
  List<DesktopCapturerSource> _sources = [];
  SourceType _type = SourceType.Window;
  String? _selected;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sources = await desktopCapturer.getSources(
        types: [SourceType.Window, SourceType.Screen],
        thumbnailSize: ThumbnailSize(320, 180),
      );
      sources.sort((a, b) {
        final type = a.type.index.compareTo(b.type.index);
        return type != 0
            ? type
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      logger.i(
        '[call][video] capture sources windows='
        '${sources.where((s) => s.type == SourceType.Window).length} '
        'screens=${sources.where((s) => s.type == SourceType.Screen).length}',
      );
      if (mounted) {
        setState(() {
          _sources = sources;
          if (!sources.any((source) => source.id == _selected)) {
            _selected = null;
          }
        });
      }
    } catch (e) {
      logger.w('[call][video] capture source enumeration failed: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm(DesktopCapturerSource source) {
    logger.i(
      '[call][video] capture source confirmed type=${source.type} '
      'id=${source.id.hashCode.toUnsigned(32).toRadixString(16)}',
    );
    Navigator.pop(context, source);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sources = _sources.where((s) => s.type == _type).toList();
    final selected = sources.where((s) => s.id == _selected).firstOrNull;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              captureText(
                context,
                'Что показать?',
                'What would you like to share?',
              ),
            ),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: captureText(context, 'Обновить', 'Refresh'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<SourceType>(
              segments: [
                ButtonSegment(
                  value: SourceType.Window,
                  icon: const Icon(Icons.web_asset),
                  label: Text(captureText(context, 'Окно', 'Window')),
                ),
                ButtonSegment(
                  value: SourceType.Screen,
                  icon: const Icon(Icons.desktop_windows),
                  label: Text(captureText(context, 'Экран', 'Screen')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() {
                _type = value.first;
                _selected = null;
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                captureText(
                  context,
                  'Будет показан только выбранный источник, без системного звука. Окно должно оставаться открытым и не свёрнутым.',
                  'Only the selected source will be shared, without system audio. Keep the window open and not minimized.',
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: SelectableText(
                        captureText(
                          context,
                          'Не удалось получить источники. Проверьте разрешение на запись экрана и повторите.\n$_error',
                          'Cannot list sources. Check screen recording permission and retry.\n$_error',
                        ),
                      ),
                    )
                  : sources.isEmpty
                  ? Center(
                      child: Text(
                        captureText(
                          context,
                          'Нет доступных источников',
                          'No sources available',
                        ),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            childAspectRatio: 1.4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        final thumbnail = source.thumbnail;
                        final active = source.id == _selected;
                        return Semantics(
                          selected: active,
                          button: true,
                          label: source.name,
                          child: InkWell(
                            onTap: () => setState(() => _selected = source.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active
                                      ? cs.primary
                                      : cs.outlineVariant,
                                  width: active ? 3 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child:
                                        thumbnail == null || thumbnail.isEmpty
                                        ? const Icon(
                                            Icons.desktop_windows,
                                            size: 48,
                                          )
                                        : Image.memory(
                                            thumbnail,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, error, stack) =>
                                                const Icon(
                                                  Icons.web_asset,
                                                  size: 48,
                                                ),
                                          ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    source.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        captureText(
                          context,
                          'Выбрано: ${selected.name}',
                          'Selected: ${selected.name}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(captureText(context, 'Отмена', 'Cancel')),
        ),
        FilledButton(
          onPressed: selected == null || _loading
              ? null
              : () => _confirm(selected),
          child: Text(captureText(context, 'Показать', 'Share')),
        ),
      ],
    );
  }
}

Future<void> showCameraPicker(BuildContext context, CallSession session) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CameraPicker(session: session),
    );

class _CameraPicker extends StatefulWidget {
  const _CameraPicker({required this.session});
  final CallSession session;
  @override
  State<_CameraPicker> createState() => _CameraPickerState();
}

class _CameraPickerState extends State<_CameraPicker> {
  List<MediaDeviceInfo>? _devices;
  Object? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _devices = null;
      _error = null;
    });
    try {
      final all = await navigator.mediaDevices.enumerateDevices();
      final seen = <String>{};
      final cameras = all
          .where(
            (d) =>
                d.kind == 'videoinput' &&
                d.deviceId.isNotEmpty &&
                seen.add(d.deviceId),
          )
          .toList();
      if (mounted) setState(() => _devices = cameras);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _select(String? id) async {
    setState(() => _busy = true);
    try {
      await widget.session.setCameraDevice(id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          captureText(
            context,
            'Не удалось включить камеру: $e',
            'Cannot enable camera: $e',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(captureText(context, 'Выбор камеры', 'Choose camera')),
            trailing: IconButton(
              onPressed: _busy ? null : _load,
              tooltip: captureText(context, 'Обновить', 'Refresh'),
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text('$_error'))
          else if (_devices == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: Text(
                      captureText(context, 'Системная камера', 'System camera'),
                    ),
                    trailing: widget.session.cameraDeviceId == null
                        ? const Icon(Icons.check)
                        : null,
                    enabled: !_busy,
                    onTap: () => _select(null),
                  ),
                  for (final (index, device) in _devices!.indexed)
                    ListTile(
                      leading: const Icon(Icons.videocam_outlined),
                      title: Text(
                        device.label.isEmpty
                            ? captureText(
                                context,
                                'Камера ${index + 1}',
                                'Camera ${index + 1}',
                              )
                            : device.label,
                      ),
                      trailing: widget.session.cameraDeviceId == device.deviceId
                          ? const Icon(Icons.check)
                          : null,
                      enabled: !_busy,
                      onTap: () => _select(device.deviceId),
                    ),
                  if (_devices!.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        captureText(
                          context,
                          'Камеры не найдены. Проверьте подключение и разрешения.',
                          'No cameras found. Check the connection and permissions.',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
