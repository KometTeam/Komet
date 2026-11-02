import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_admin.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/config/app_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/official_name.dart';
import '../../widgets/sheet_helpers.dart';

class CallParticipantView {
  final String name;
  final String? avatarUrl;
  final int? contactId;

  const CallParticipantView({
    required this.name,
    this.avatarUrl,
    this.contactId,
  });
}

typedef CallParticipantResolver =
    CallParticipantView Function(CallParticipant participant);

List<CallParticipant> sortCallParticipants(Iterable<CallParticipant> all) {
  final list = all.toList();
  final order = {for (var i = 0; i < list.length; i++) list[i].id: i};
  list.sort((a, b) {
    if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
    if (a.handRaised != b.handRaised) return a.handRaised ? -1 : 1;
    if (a.handRaised) {
      final byTime = a.handRaisedAt.compareTo(b.handRaisedAt);
      if (byTime != 0) return byTime;
    }
    if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
    return order[a.id]!.compareTo(order[b.id]!);
  });
  return list;
}

Future<void> showCallParticipantsSheet(
  BuildContext context, {
  required CallSession session,
  required ColorScheme scheme,
  required CallParticipantResolver resolve,
  required void Function(CallParticipant participant) onParticipant,
  required void Function(BuildContext anchor) onCopyLink,
  required VoidCallback onAddParticipants,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _ParticipantsSheet(
        session: session,
        resolve: resolve,
        onParticipant: onParticipant,
        onCopyLink: onCopyLink,
        onAddParticipants: onAddParticipants,
      ),
    ),
  );
}

Future<void> showCallParticipantMenu(
  BuildContext context, {
  required CallSession session,
  required CallParticipant participant,
  required CallParticipantView view,
  required ColorScheme scheme,
  required bool pinned,
  required VoidCallback onTogglePin,
  required VoidCallback onMessage,
  required VoidCallback onSwitchCamera,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: scheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: _ParticipantMenu(
        session: session,
        participant: participant,
        view: view,
        pinned: pinned,
        onTogglePin: onTogglePin,
        onMessage: onMessage,
        onSwitchCamera: onSwitchCamera,
        hostContext: context,
      ),
    ),
  );
}

Future<bool> runCallAdmin(
  BuildContext context,
  CallSession session,
  Future<void> Function(CallAdmin admin) action,
) async {
  final l10n = AppLocalizations.of(context)!;
  final admin = session.admin;
  if (admin == null) {
    showCustomNotification(context, l10n.callParticipantsNoServer);
    return false;
  }
  try {
    await action(admin);
    return true;
  } catch (e) {
    if (context.mounted) {
      showCustomNotification(context, l10n.callParticipantsActionFailed('$e'));
    }
    return false;
  }
}

class _ParticipantsSheet extends StatefulWidget {
  final CallSession session;
  final CallParticipantResolver resolve;
  final void Function(CallParticipant participant) onParticipant;
  final void Function(BuildContext anchor) onCopyLink;
  final VoidCallback onAddParticipants;

  const _ParticipantsSheet({
    required this.session,
    required this.resolve,
    required this.onParticipant,
    required this.onCopyLink,
    required this.onAddParticipants,
  });

  @override
  State<_ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends State<_ParticipantsSheet> {
  final TextEditingController _search = TextEditingController();
  StreamSubscription<void>? _infoSub;
  String _query = '';

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
    _search.dispose();
    super.dispose();
  }

  List<CallParticipant> get _visible {
    final sorted = sortCallParticipants(widget.session.participants);
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sorted;
    return sorted
        .where((p) => widget.resolve(p).name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _showBulkMenu(BuildContext anchor) {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;
    final box = anchor.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + box.size.height,
        overlay.size.width - origin.dx - box.size.width,
        0,
      ),
      items: [
        _menuItem(Symbols.mic_off, l10n.callMuteAllMics, () {
          runCallAdmin(
            context,
            session,
            (a) => a.setMuteStates({CallMedia.audio: CallMuteState.mute}),
          );
        }),
        _menuItem(Symbols.videocam_off, l10n.callMuteAllCameras, () {
          runCallAdmin(
            context,
            session,
            (a) => a.setMuteStates({CallMedia.video: CallMuteState.mute}),
          );
        }),
        _menuItem(Symbols.do_not_touch, l10n.callParticipantsLowerAllHands, () {
          _lowerAllHands();
        }),
      ],
    );
  }

  Future<void> _lowerAllHands() async {
    final message = AppLocalizations.of(context)!.callYouLoweredAllHands;
    final session = widget.session;
    final ok = await runCallAdmin(context, session, (_) {
      return session.lowerAllHands();
    });
    if (ok && mounted) showCustomNotification(context, message);
  }

  PopupMenuItem<void> _menuItem(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return PopupMenuItem<void>(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;
    final isAdmin = session.self?.isAdmin == true;
    final participants = _visible;
    final handPositions = session.handPositions;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.callParticipantsTitle(session.participantCount),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: displayFontOf(context),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (anchor) => IconButton(
                      tooltip: l10n.callInviteCopyLink,
                      onPressed: () => widget.onCopyLink(anchor),
                      icon: const Icon(Symbols.link),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.callInviteAdd,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onAddParticipants();
                    },
                    icon: const Icon(Symbols.person_add),
                  ),
                  if (isAdmin)
                    Builder(
                      builder: (anchor) => IconButton(
                        tooltip: l10n.callMore,
                        onPressed: () => _showBulkMenu(anchor),
                        icon: const Icon(Symbols.more_vert),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  prefixIcon: const Icon(Symbols.search, size: 20),
                  hintText: l10n.callParticipantsSearchHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: participants.length,
                itemBuilder: (_, i) =>
                    _row(cs, l10n, participants[i], handPositions),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(
    ColorScheme cs,
    AppLocalizations l10n,
    CallParticipant p,
    Map<int, int> handPositions,
  ) {
    final session = widget.session;
    final view = widget.resolve(p);
    final role = <String>[
      if (p.isSelf) l10n.callParticipantYou,
      if (p.isCreator)
        l10n.callParticipantsCreator
      else if (p.isAdmin)
        l10n.callParticipantsAdmin,
    ];
    final hasMenu = !p.isSelf || session.participantCount > 1 || p.handRaised;
    final position = handPositions.length > 1 ? handPositions[p.id] : null;

    return ListTile(
      key: ValueKey(p.id),
      leading: KometAvatar(
        name: view.name,
        imageUrl: view.avatarUrl,
        userId: view.contactId,
        size: 40,
      ),
      title: OfficialName(
        contactId: view.contactId ?? 0,
        text: view.name,
        maxLines: 1,
        style: TextStyle(color: cs.onSurface, fontSize: 16),
      ),
      subtitle: role.isEmpty
          ? null
          : Text(
              role.join(' · '),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.handRaised) ...[
            Icon(Symbols.front_hand, size: 20, fill: 1, color: cs.tertiary),
            if (position != null)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  '$position',
                  style: TextStyle(
                    color: cs.tertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
          if (p.screenSharing) ...[
            Icon(Symbols.screen_share, size: 20, color: cs.primary),
            const SizedBox(width: 8),
          ],
          if (!(p.isSelf ? session.isMuted : !p.audioEnabled))
            Icon(Symbols.mic, size: 20, color: cs.onSurfaceVariant)
          else
            Icon(Symbols.mic_off, size: 20, color: cs.error),
          if (hasMenu)
            Icon(Symbols.more_vert, size: 20, color: cs.onSurfaceVariant),
        ],
      ),
      onTap: hasMenu ? () => widget.onParticipant(p) : null,
    );
  }
}

class _ParticipantMenu extends StatelessWidget {
  final CallSession session;
  final CallParticipant participant;
  final CallParticipantView view;
  final bool pinned;
  final VoidCallback onTogglePin;
  final VoidCallback onMessage;
  final VoidCallback onSwitchCamera;
  final BuildContext hostContext;

  const _ParticipantMenu({
    required this.session,
    required this.participant,
    required this.view,
    required this.pinned,
    required this.onTogglePin,
    required this.onMessage,
    required this.onSwitchCamera,
    required this.hostContext,
  });

  CallParticipantRef get _ref => CallParticipantRef(participant.id);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final target = participant;
    final me = session.self;
    final iAmAdmin = me?.isAdmin == true;
    final mine = target.isSelf;

    void close(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    void admin(Future<void> Function(CallAdmin admin) action) {
      Navigator.of(context).pop();
      runCallAdmin(hostContext, session, action);
    }

    final items = <Widget>[
      if (!mine && view.contactId != null)
        _item(cs, Symbols.chat, l10n.callParticipantMessage, () {
          close(onMessage);
        }),
      if (mine && session.localVideo)
        _item(cs, Symbols.cameraswitch, l10n.callSwitchCamera, () {
          close(onSwitchCamera);
        }),
      if (!mine)
        _item(
          cs,
          pinned ? Symbols.keep_off : Symbols.push_pin,
          pinned ? l10n.msgActionsUnpin : l10n.msgActionsPin,
          () => close(onTogglePin),
        ),
      if (target.handRaised && (iAmAdmin || mine))
        _item(cs, Symbols.back_hand, l10n.callParticipantsLowerHand, () {
          if (mine) {
            Navigator.of(context).pop();
            runCallAdmin(hostContext, session, (_) {
              return session.setHandRaised(false);
            });
          } else {
            Navigator.of(context).pop();
            _lowerHand(l10n.callYouLoweredHand);
          }
        }),
      if (iAmAdmin &&
          !mine &&
          target.screenSharing &&
          (me?.isCreator == true || !target.isAdmin))
        _item(
          cs,
          Symbols.stop_screen_share,
          l10n.callParticipantStopScreen,
          () {
            admin(
              (a) => a.setMuteStates({
                CallMedia.screenShare: CallMuteState.mute,
              }, participant: _ref),
            );
          },
        ),
      if (iAmAdmin && !mine && target.audioEnabled)
        _item(cs, Symbols.mic_off, l10n.callParticipantsMuteMic, () {
          admin(
            (a) => a.setMuteStates({
              CallMedia.audio: CallMuteState.mute,
            }, participant: _ref),
          );
        }),
      if (iAmAdmin && !mine && target.videoEnabled)
        _item(cs, Symbols.videocam_off, l10n.callParticipantMuteCamera, () {
          admin(
            (a) => a.setMuteStates({
              CallMedia.video: CallMuteState.mute,
            }, participant: _ref),
          );
        }),
      if (iAmAdmin && !mine && !target.isAdmin)
        _item(
          cs,
          Symbols.person_remove,
          l10n.callParticipantsRemoveFromCall,
          () => _confirmRemove(context),
          destructive: true,
        ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  KometAvatar(
                    name: view.name,
                    imageUrl: view.avatarUrl,
                    userId: view.contactId,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      view.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: displayFontOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...items,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _lowerHand(String message) async {
    final ok = await runCallAdmin(hostContext, session, (_) {
      return session.lowerHandOf(participant.id);
    });
    if (ok && hostContext.mounted) {
      showCustomNotification(hostContext, message);
    }
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      message: l10n.callParticipantRemoveConfirm(view.name),
      confirmLabel: l10n.callParticipantsRemoveFromCall,
      destructive: true,
    );
    if (!confirmed) return;
    navigator.pop();
    if (!hostContext.mounted) return;
    await runCallAdmin(hostContext, session, (a) => a.removeParticipant(_ref));
  }

  Widget _item(
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
}
