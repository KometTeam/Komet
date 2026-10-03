import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/audio_devices.dart';
import '../../../core/calls/camera_devices.dart';
import '../../../core/config/app_camera.dart';
import '../../../core/config/app_microphone.dart';
import '../../../core/config/app_video_note_quality.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';

class MediaDevicesScreen extends StatefulWidget {
  const MediaDevicesScreen({super.key});

  @override
  State<MediaDevicesScreen> createState() => _MediaDevicesScreenState();
}

class _MediaDevicesScreenState extends State<MediaDevicesScreen> {
  List<AudioInputDevice>? _microphones;
  List<VideoInputDevice>? _cameras;

  bool get _videoNotesAvailable =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final results = await Future.wait([
      AudioDevices.microphones(),
      CameraDevices.cameras(),
    ]);
    if (!mounted) return;
    setState(() {
      _microphones = results[0] as List<AudioInputDevice>;
      _cameras = results[1] as List<VideoInputDevice>;
    });
  }

  void _pickMicrophone(String id) {
    Haptics.selection();
    unawaited(AppMicrophone.save(id));
  }

  void _pickCamera(String id) {
    Haptics.selection();
    unawaited(AppCamera.save(id));
  }

  static IconData _cameraIcon(CameraFacing facing) => switch (facing) {
    CameraFacing.front => Symbols.camera_front,
    CameraFacing.back => Symbols.camera_rear,
    CameraFacing.external => Symbols.videocam,
  };

  String _cameraLabel(AppLocalizations l10n, VideoInputDevice camera, int i) {
    final facing = switch (camera.facing) {
      CameraFacing.front => l10n.mediaDevicesFront,
      CameraFacing.back => l10n.mediaDevicesBack,
      CameraFacing.external => null,
    };
    final looksTechnical =
        camera.label.isEmpty || camera.label.toLowerCase().contains('facing');
    if (looksTechnical) {
      return facing == null
          ? l10n.mediaDevicesCameraFallback(i + 1)
          : '$facing · ${l10n.mediaDevicesCameraFallback(i + 1)}';
    }
    return camera.label;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final microphones = _microphones;
    final cameras = _cameras;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.mediaDevicesTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _Section(
              title: l10n.mediaDevicesMicrophone,
              hint: l10n.mediaDevicesMicrophoneHint,
            ),
            ValueListenableBuilder<String>(
              valueListenable: AppMicrophone.current,
              builder: (context, selected, _) => SettingsCard(
                children: [
                  _ChoiceTile(
                    icon: Symbols.settings_voice,
                    label: l10n.mediaDevicesSystemMicrophone,
                    selected: selected.isEmpty,
                    onTap: () => _pickMicrophone(''),
                  ),
                  if (microphones == null)
                    const _Loading()
                  else
                    for (var i = 0; i < microphones.length; i++)
                      _ChoiceTile(
                        icon: Symbols.mic,
                        label: microphones[i].label.isNotEmpty
                            ? microphones[i].label
                            : l10n.callMicrophoneFallback(i + 1),
                        selected: selected == microphones[i].id,
                        onTap: () => _pickMicrophone(microphones[i].id),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Section(
              title: l10n.mediaDevicesCamera,
              hint: l10n.mediaDevicesCameraHint,
            ),
            ValueListenableBuilder<String>(
              valueListenable: AppCamera.current,
              builder: (context, selected, _) => SettingsCard(
                children: [
                  _ChoiceTile(
                    icon: Symbols.photo_camera,
                    label: l10n.mediaDevicesSystemCamera,
                    selected: selected.isEmpty,
                    onTap: () => _pickCamera(''),
                  ),
                  if (cameras == null)
                    const _Loading()
                  else
                    for (var i = 0; i < cameras.length; i++)
                      _ChoiceTile(
                        icon: _cameraIcon(cameras[i].facing),
                        label: _cameraLabel(l10n, cameras[i], i),
                        selected: selected == cameras[i].id,
                        onTap: () => _pickCamera(cameras[i].id),
                      ),
                ],
              ),
            ),
            if (_videoNotesAvailable) ...[
              const SizedBox(height: 22),
              _Section(title: l10n.mediaDevicesVideoNotes, hint: null),
              ValueListenableBuilder<bool>(
                valueListenable: AppVideoNoteCamera.useCustom,
                builder: (context, custom, _) => SettingsCard(
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: AppCamera.current,
                      builder: (context, camera, _) => SettingsToggleTile(
                        icon: Symbols.tune,
                        label: l10n.mediaDevicesVideoNoteCustom,
                        subtitle: custom && camera.isEmpty
                            ? l10n.mediaDevicesVideoNoteCustomMissing
                            : l10n.mediaDevicesVideoNoteCustomHint,
                        value: custom,
                        onChanged: AppVideoNoteCamera.setUseCustom,
                      ),
                    ),
                    if (!custom)
                      ValueListenableBuilder<bool>(
                        valueListenable: AppVideoNoteRearCamera.current,
                        builder: (context, rear, _) => SettingsToggleTile(
                          icon: Symbols.flip_camera_android,
                          label: l10n.mediaDevicesVideoNoteRear,
                          subtitle: l10n.mediaDevicesVideoNoteRearHint,
                          value: rear,
                          onChanged: AppVideoNoteRearCamera.save,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? hint;

  const _Section({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title, padding: EdgeInsets.zero, fontSize: 14),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SmallSpinner(
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? cs.primary : cs.onSurfaceVariant,
                size: 22,
                weight: 400,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: selected
                    ? Icon(
                        Symbols.check_circle,
                        key: const ValueKey('on'),
                        color: cs.primary,
                        fill: 1,
                        size: 22,
                      )
                    : const SizedBox.square(
                        key: ValueKey('off'),
                        dimension: 22,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
