import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_admin.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/calls/camera_devices.dart';
import '../../../core/config/app_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';
import 'call_participants_sheet.dart';

Future<void> showCallSettingsSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
  required VoidCallback onMicrophone,
  required VoidCallback onCamera,
  required VoidCallback onInfo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _CallSettingsSheet(
        session: session,
        onMicrophone: onMicrophone,
        onCamera: onCamera,
        onInfo: onInfo,
      ),
    ),
  );
}

Future<void> showCallCameraSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _CameraSheet(session: session),
    ),
  );
}

class _CallSettingsSheet extends StatefulWidget {
  final CallSession session;
  final VoidCallback onMicrophone;
  final VoidCallback onCamera;
  final VoidCallback onInfo;

  const _CallSettingsSheet({
    required this.session,
    required this.onMicrophone,
    required this.onCamera,
    required this.onInfo,
  });

  @override
  State<_CallSettingsSheet> createState() => _CallSettingsSheetState();
}

class _CallSettingsSheetState extends State<_CallSettingsSheet> {
  final Map<Object, bool> _pending = {};
  StreamSubscription<void>? _infoSub;

  @override
  void initState() {
    super.initState();
    _infoSub = widget.session.infoUpdates.listen((_) {
      if (mounted) setState(_pending.clear);
    });
  }

  @override
  void dispose() {
    _infoSub?.cancel();
    super.dispose();
  }

  bool _allowed(CallMedia media) =>
      _pending[media] ??
      widget.session.globalMuteState(media) != CallMuteState.mutePermanent;

  bool get _recordAllowed =>
      _pending[CallFeature.record] ??
      widget.session.rolesAllowed(CallFeature.record).isEmpty;

  Future<void> _change(
    Object key,
    bool value,
    Future<void> Function(CallAdmin admin) action,
  ) async {
    setState(() => _pending[key] = value);
    final ok = await runCallAdmin(context, widget.session, action);
    if (!ok && mounted) setState(() => _pending.remove(key));
  }

  void _setMedia(CallMedia media, bool allowed) {
    _change(
      media,
      allowed,
      (a) => a.setMuteStates({
        media: allowed ? CallMuteState.unmute : CallMuteState.mutePermanent,
      }),
    );
  }

  void _setRecord(bool allowed) {
    _change(
      CallFeature.record,
      allowed,
      (a) => a.enableFeatureForRoles(
        CallFeature.record,
        allowed ? const [] : const [CallRoleName.creator, CallRoleName.admin],
      ),
    );
  }

  void _close(VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = widget.session.self?.isAdmin == true;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _title(cs, l10n.callSettingsTitle),
            ListTile(
              leading: const Icon(Symbols.mic),
              title: Text(l10n.callSettingsMicrophone),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => _close(widget.onMicrophone),
            ),
            ListTile(
              leading: const Icon(Symbols.videocam),
              title: Text(l10n.callVideoLabel),
              trailing: const Icon(Symbols.chevron_right),
              onTap: () => _close(widget.onCamera),
            ),
            if (isAdmin) ...[
              _header(cs, l10n.callSettingsParticipantsCan),
              SwitchListTile(
                secondary: const Icon(Symbols.mic),
                title: Text(l10n.callSettingsAllowMic),
                value: _allowed(CallMedia.audio),
                onChanged: (v) => _setMedia(CallMedia.audio, v),
              ),
              SwitchListTile(
                secondary: const Icon(Symbols.videocam),
                title: Text(l10n.callSettingsAllowCamera),
                value: _allowed(CallMedia.video),
                onChanged: (v) => _setMedia(CallMedia.video, v),
              ),
              SwitchListTile(
                secondary: const Icon(Symbols.screen_share),
                title: Text(l10n.callSettingsAllowScreen),
                value: _allowed(CallMedia.screenShare),
                onChanged: (v) => _setMedia(CallMedia.screenShare, v),
              ),
              if (widget.session.info.record)
                SwitchListTile(
                  secondary: const Icon(Symbols.radio_button_checked),
                  title: Text(l10n.callSettingsAllowRecord),
                  value: _recordAllowed,
                  onChanged: _setRecord,
                ),
            ],
            const Divider(height: 16),
            ListTile(
              leading: const Icon(Symbols.info),
              title: Text(l10n.callInfoTitle),
              onTap: () => _close(widget.onInfo),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _title(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Text(
      text,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: displayFontOf(context),
      ),
    ),
  );

  Widget _header(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(
      text,
      style: TextStyle(
        color: cs.primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CameraSheet extends StatefulWidget {
  final CallSession session;

  const _CameraSheet({required this.session});

  @override
  State<_CameraSheet> createState() => _CameraSheetState();
}

class _CameraSheetState extends State<_CameraSheet> {
  late final Future<List<VideoInputDevice>> _cameras = CameraDevices.cameras();
  String? _switching;

  Future<void> _select(VideoInputDevice camera) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _switching = camera.id);
    try {
      await widget.session.selectCamera(camera.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _switching = null);
      showCustomNotification(context, l10n.callCameraUnavailable(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final current = widget.session.cameraDeviceId;
    return SafeArea(
      child: FutureBuilder<List<VideoInputDevice>>(
        future: _cameras,
        builder: (context, snapshot) {
          final cameras = snapshot.data;
          if (cameras == null) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.callVideoLabel,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: displayFontOf(context),
                  ),
                ),
              ),
              for (var i = 0; i < cameras.length; i++)
                ListTile(
                  key: ValueKey(cameras[i].id),
                  leading: Icon(
                    cameras[i].id == current
                        ? Symbols.radio_button_checked
                        : Symbols.radio_button_unchecked,
                    color: cameras[i].id == current ? cs.primary : null,
                  ),
                  title: Text(
                    cameras[i].label.isEmpty
                        ? '${l10n.callVideoLabel} ${i + 1}'
                        : cameras[i].label,
                  ),
                  trailing: _switching == cameras[i].id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _switching == null ? () => _select(cameras[i]) : null,
                ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}
