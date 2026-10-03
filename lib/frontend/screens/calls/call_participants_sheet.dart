import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_admin.dart';
import '../../../core/calls/call_session.dart';
import '../../widgets/animated_slash_icon.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/prompt_dialog.dart';
import '../../widgets/sheet_helpers.dart';
import '../../../core/config/app_fonts.dart';
import '../../../l10n/app_localizations.dart';

class CallParticipantView {
  final String name;
  final String? avatarUrl;

  const CallParticipantView({required this.name, this.avatarUrl});
}

typedef CallParticipantResolver =
    CallParticipantView Function(CallParticipant participant);

Future<void> showCallParticipantsSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
  required CallParticipantResolver resolve,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _ParticipantsSheet(session: session, resolve: resolve),
    ),
  );
}

class _ParticipantsSheet extends StatefulWidget {
  final CallSession session;
  final CallParticipantResolver resolve;

  const _ParticipantsSheet({required this.session, required this.resolve});

  @override
  State<_ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends State<_ParticipantsSheet> {
  final Map<CallOption, bool> _options = {};
  final Map<CallFeature, Set<CallRoleName>> _features = {};
  bool _recording = false;
  StreamSubscription<void>? _infoSub;

  @override
  void initState() {
    super.initState();
    _infoSub = widget.session.infoUpdates.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _infoSub?.cancel();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  CallParticipant? get _self {
    for (final p in widget.session.participants) {
      if (p.isSelf) return p;
    }
    return null;
  }

  Future<bool> _run(Future<void> Function(CallAdmin admin) action) async {
    final admin = widget.session.admin;
    if (admin == null) {
      showCustomNotification(context, _l10n.callParticipantsNoServer);
      return false;
    }
    try {
      await action(admin);
      return true;
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          _l10n.callParticipantsActionFailed('$e'),
        );
      }
      return false;
    }
  }

  CallParticipantRef _ref(CallParticipant p) => CallParticipantRef(p.id);

  void _participantActions(CallParticipant p) {
    final cs = Theme.of(context).colorScheme;
    final l10n = _l10n;
    final view = widget.resolve(p);
    final isAdmin = p.isAdmin;
    final isSpeaker = p.isSpeaker;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  view.name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: displayFontOf(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  p.roles.isEmpty
                      ? l10n.callParticipantFallback
                      : p.roles.join(' · '),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
              _action(cs, Symbols.mic_off, l10n.callParticipantsMuteMic, () {
                Navigator.pop(sheetContext);
                _run((a) => a.muteMicrophone(_ref(p)));
              }),
              _action(
                cs,
                Symbols.videocam_off,
                l10n.callParticipantsRequestCamera,
                () {
                  Navigator.pop(sheetContext);
                  _run(
                    (a) =>
                        a.requestMedia({CallMedia.video}, participant: _ref(p)),
                  );
                },
              ),
              _action(
                cs,
                isAdmin ? Symbols.remove_moderator : Symbols.shield_person,
                isAdmin
                    ? l10n.callParticipantsRevokeAdmin
                    : l10n.adminAppointAction,
                () {
                  Navigator.pop(sheetContext);
                  _run(
                    (a) => a.setRoles(_ref(p), [
                      CallRoleName.admin,
                    ], revoke: isAdmin),
                  );
                },
              ),
              _action(
                cs,
                isSpeaker ? Symbols.voice_over_off : Symbols.record_voice_over,
                isSpeaker
                    ? l10n.callParticipantsRevokeSpeaker
                    : l10n.callParticipantsMakeSpeaker,
                () {
                  Navigator.pop(sheetContext);
                  _run(
                    (a) => a.setRoles(_ref(p), [
                      CallRoleName.speaker,
                    ], revoke: isSpeaker),
                  );
                },
              ),
              _action(
                cs,
                Symbols.arrow_upward,
                l10n.callParticipantsPromote,
                () {
                  Navigator.pop(sheetContext);
                  _run((a) => a.setPromoted(_ref(p), true));
                },
              ),
              _action(
                cs,
                Symbols.arrow_downward,
                l10n.callParticipantsDemote,
                () {
                  Navigator.pop(sheetContext);
                  _run((a) => a.setPromoted(_ref(p), false));
                },
              ),
              _action(cs, Symbols.push_pin, l10n.msgActionsPin, () {
                Navigator.pop(sheetContext);
                _run((a) => a.setPinned(_ref(p), true));
              }),
              _action(cs, Symbols.keep_off, l10n.msgActionsUnpin, () {
                Navigator.pop(sheetContext);
                _run((a) => a.setPinned(_ref(p), false));
              }),
              _action(
                cs,
                Symbols.person_remove,
                l10n.callParticipantsRemoveFromCall,
                () {
                  Navigator.pop(sheetContext);
                  _run((a) => a.removeParticipant(_ref(p)));
                },
                destructive: true,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(colorScheme: cs),
        child: StatefulBuilder(
          builder: (_, setSheet) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sheetTitle(cs, _l10n.callParticipantsCallSettings),
                  for (final option in CallOption.values)
                    SwitchListTile(
                      value: _options[option] ?? false,
                      title: Text(
                        _optionLabel(option),
                        style: TextStyle(color: cs.onSurface, fontSize: 15),
                      ),
                      subtitle: Text(
                        option.wire,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (value) async {
                        setSheet(() => _options[option] = value);
                        final ok = await _run(
                          (a) => a.setOptions({option: value}),
                        );
                        if (!ok) setSheet(() => _options[option] = !value);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFeatures() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(colorScheme: cs),
        child: StatefulBuilder(
          builder: (_, setSheet) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sheetTitle(cs, _l10n.callParticipantsFeatureAccess),
                  for (final feature in CallFeature.values)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _featureLabel(feature),
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final role in CallRoleName.values)
                                FilterChip(
                                  label: Text(role.wire),
                                  selected:
                                      _features[feature]?.contains(role) ??
                                      false,
                                  onSelected: (selected) {
                                    final set = _features.putIfAbsent(
                                      feature,
                                      () => <CallRoleName>{},
                                    );
                                    setSheet(() {
                                      selected
                                          ? set.add(role)
                                          : set.remove(role);
                                    });
                                    _run(
                                      (a) => a.enableFeatureForRoles(
                                        feature,
                                        set.toList(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addByLink() async {
    final l10n = _l10n;
    final link = await showTextInputDialog(
      context,
      title: l10n.chatInfoAddMember,
      description: l10n.callParticipantsInviteLink,
      confirmLabel: l10n.chatInfoAddMembersAction,
    );
    if (link == null || link.trim().isEmpty || !mounted) return;
    await _run((a) => a.addParticipantByLink(link.trim()));
  }

  String _optionLabel(CallOption option) => switch (option) {
    CallOption.requireAuthToJoin => _l10n.callParticipantsOptionAuthOnly,
    CallOption.waitingHall => _l10n.callParticipantsOptionWaitingHall,
    CallOption.recurring => _l10n.callParticipantsOptionRecurring,
    CallOption.feedback => _l10n.callParticipantsOptionFeedback,
    CallOption.audienceMode => _l10n.callParticipantsOptionAudienceMode,
    CallOption.asr => _l10n.callParticipantsSpeechTranscription,
    CallOption.waitForAdmin => _l10n.callParticipantsOptionWaitForAdmin,
    CallOption.adminIsHere => _l10n.callParticipantsOptionAdminIsHere,
  };

  String _featureLabel(CallFeature feature) => switch (feature) {
    CallFeature.addParticipant => _l10n.memberPermissionAddMembers,
    CallFeature.admin => _l10n.adminEditTitle,
    CallFeature.asr => _l10n.callParticipantsSpeechTranscription,
    CallFeature.movieShare => _l10n.callParticipantsFeatureMovieShare,
    CallFeature.record => _l10n.callParticipantsCallRecording,
    CallFeature.speaker => _l10n.callParticipantsFeatureSpeaker,
  };

  Widget _sheetTitle(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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

  Widget _action(
    ColorScheme cs,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final color = destructive ? cs.error : cs.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final participants = widget.session.participants;
    final self = _self;
    final handRaised = self?.handRaised ?? false;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetTitle(cs, l10n.callParticipantsTitle(participants.length)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(cs, Symbols.mic_off, l10n.callParticipantsMuteAll, () {
                  _run((a) => a.muteEveryone());
                }),
                _chip(
                  cs,
                  Symbols.do_not_touch,
                  l10n.callParticipantsLowerAllHands,
                  () {
                    _run((a) => a.lowerAllHands());
                  },
                ),
                _chip(
                  cs,
                  handRaised ? Symbols.back_hand : Symbols.front_hand,
                  handRaised
                      ? l10n.callParticipantsLowerHand
                      : l10n.callParticipantsRaiseHand,
                  () => _run((a) => a.setHandRaised(!handRaised)),
                  active: handRaised,
                ),
                _chip(
                  cs,
                  _recording
                      ? Symbols.stop_circle
                      : Symbols.radio_button_checked,
                  _recording
                      ? l10n.callParticipantsStopRecording
                      : l10n.callParticipantsStartRecording,
                  () async {
                    final next = !_recording;
                    setState(() => _recording = next);
                    final ok = await _run(
                      (a) => next
                          ? a.startRecord(
                              name: l10n.callParticipantsCallRecording,
                            )
                          : a.stopRecord(),
                    );
                    if (!ok && mounted) setState(() => _recording = !next);
                  },
                  active: _recording,
                ),
                _chip(cs, Symbols.tune, l10n.videoViewerSettings, _showOptions),
                _chip(
                  cs,
                  Symbols.shield_person,
                  l10n.callParticipantsRolePermissions,
                  _showFeatures,
                ),
                _chip(
                  cs,
                  Symbols.person_add,
                  l10n.callParticipantsAddByLink,
                  _addByLink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: participants.length,
              itemBuilder: (_, i) => _tile(cs, participants[i]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _chip(
    ColorScheme cs,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: active ? cs.onPrimary : cs.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(color: active ? cs.onPrimary : cs.onSurface),
      backgroundColor: active ? cs.primary : cs.surfaceContainerHighest,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }

  Widget _tile(ColorScheme cs, CallParticipant p) {
    final l10n = _l10n;
    final view = widget.resolve(p);
    final subtitle = <String>[
      if (p.isCreator)
        l10n.callParticipantsCreator
      else if (p.isAdmin)
        l10n.callParticipantsAdmin,
      if (p.isSpeaker) l10n.callParticipantsSpeaker,
      if (p.handRaised) l10n.callParticipantsHandRaised,
    ];

    return ListTile(
      leading: KometAvatar(name: view.name, imageUrl: view.avatarUrl, size: 40),
      title: Text(
        view.name,
        style: TextStyle(color: cs.onSurface, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle.join(' · '),
              style: TextStyle(color: cs.primary, fontSize: 13),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.screenSharing)
            Icon(Symbols.screen_share, size: 18, color: cs.primary),
          if (p.videoEnabled)
            Icon(Symbols.videocam, size: 18, color: cs.onSurfaceVariant),
          AnimatedSlashIcon(
            icon: Symbols.mic,
            slashedIcon: Symbols.mic_off,
            slashed: !p.audioEnabled,
            size: 18,
            color: p.audioEnabled ? cs.onSurfaceVariant : cs.error,
          ),
        ],
      ),
      onTap: p.isSelf ? null : () => _participantActions(p),
    );
  }
}
