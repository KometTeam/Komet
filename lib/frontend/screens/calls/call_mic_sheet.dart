import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/audio_devices.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/calls/pulse_audio.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/call_no_mute.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';

Future<void> showCallMicrophoneSheet(
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
      child: _MicrophoneSheet(session: session),
    ),
  );
}

class _MicOption {
  const _MicOption({
    required this.id,
    required this.label,
    this.detail,
    this.isMonitor = false,
    this.isDevice = false,
  });

  final String id;
  final String label;
  final String? detail;
  final bool isMonitor;
  final bool isDevice;
}

class _MicrophoneSheet extends StatefulWidget {
  final CallSession session;

  const _MicrophoneSheet({required this.session});

  @override
  State<_MicrophoneSheet> createState() => _MicrophoneSheetState();
}

class _MicrophoneSheetState extends State<_MicrophoneSheet> {
  List<_MicOption>? _options;
  bool _pulseMode = false;
  String? _selected;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pulse = PulseAudio.supported && await PulseAudio.isAvailable()
        ? await PulseAudio.sources()
        : const <PulseSource>[];
    final devices = await AudioDevices.microphones();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final routed = pulse.map((source) => source.name).toSet();
    setState(() {
      _pulseMode = pulse.isNotEmpty;
      _selected = widget.session.pulseSource ?? widget.session.micDeviceId;
      _options = [
        for (final source in pulse)
          _MicOption(
            id: source.name,
            label: source.label,
            detail: source.name,
            isMonitor: source.isMonitor,
          ),
        for (var i = 0; i < devices.length; i++)
          if (!routed.contains(devices[i].id))
            _MicOption(
              id: devices[i].id,
              label: devices[i].label.isNotEmpty
                  ? devices[i].label
                  : l10n.callMicrophoneFallback(i + 1),
              isDevice: true,
            ),
      ];
    });
  }

  Future<void> _select(String? id, {required bool viaDevice}) async {
    if (_switching || id == _selected) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _switching = true);
    try {
      if (_pulseMode && !viaDevice) {
        await widget.session.setPulseSource(id);
      } else {
        await widget.session.setMicrophone(id);
      }
      if (mounted) setState(() => _selected = id);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, l10n.callMicrophoneFailed(e));
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final options = _options;
    final inputs = options?.where((o) => !o.isMonitor).toList() ?? const [];
    final monitors = options?.where((o) => o.isMonitor).toList() ?? const [];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(cs, l10n),
            if (CallNoMute.enabled) _noMuteHint(cs, l10n),
            if (options == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    _tile(
                      cs,
                      id: null,
                      label: l10n.callMicrophoneSystem,
                      icon: Symbols.settings_voice,
                      viaDevice: true,
                    ),
                    if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Text(
                          l10n.callMicrophoneEmpty,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    for (final option in inputs)
                      _tile(
                        cs,
                        id: option.id,
                        label: option.label,
                        detail: option.detail,
                        icon: Symbols.mic,
                        viaDevice: option.isDevice,
                      ),
                    if (monitors.isNotEmpty) ...[
                      _group(cs, l10n.callMicrophoneMonitors),
                      for (final option in monitors)
                        _tile(
                          cs,
                          id: option.id,
                          label: option.label,
                          detail: option.detail,
                          icon: Symbols.graphic_eq,
                          viaDevice: option.isDevice,
                        ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            l10n.callMicrophoneTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() => _options = null);
            _load();
          },
          tooltip: l10n.callMicrophoneRefresh,
          icon: Icon(Symbols.refresh, color: cs.onSurfaceVariant),
        ),
      ],
    ),
  );

  Widget _noMuteHint(ColorScheme cs, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Row(
      children: [
        Icon(Symbols.graphic_eq, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.callNoMuteHint,
            style: TextStyle(color: cs.primary, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _group(ColorScheme cs, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
    child: Text(
      title,
      style: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _tile(
    ColorScheme cs, {
    required String? id,
    required String label,
    required IconData icon,
    String? detail,
    bool viaDevice = false,
  }) {
    final selected = _selected == id;
    return ListTile(
      leading: Icon(icon, color: selected ? cs.primary : cs.onSurface),
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? cs.primary : cs.onSurface,
          fontSize: 16,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: detail == null
          ? null
          : Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
      trailing: selected ? Icon(Symbols.check, color: cs.primary) : null,
      enabled: !_switching,
      onTap: () => _select(id, viaDevice: viaDevice),
    );
  }
}
