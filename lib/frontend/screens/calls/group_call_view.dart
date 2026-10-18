import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCVideoValue;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_admin.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/calls/call_link.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../../backend/modules/chats.dart' show chats;
import '../../../main.dart' show api;
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/hint_bubble.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/max_link_nav.dart';
import '../../widgets/sheet_helpers.dart';
import '../chats/group_invite_sheets.dart';
import 'call_controls.dart';
import 'call_fullscreen.dart';
import 'call_glyphs.dart';
import 'call_grid.dart';
import 'call_participant_info.dart';
import 'call_participant_tile.dart';
import 'call_participants_sheet.dart';
import 'call_settings_sheet.dart';
import 'call_stage.dart';
import 'waving_hand_icon.dart';

typedef CallMediaBuilder =
    Widget? Function(
      CallParticipant participant,
      Widget avatar, {
      CallVideoSource? source,
      bool stage,
    });

typedef CallVideoLookup =
    ValueListenable<RTCVideoValue>? Function(CallParticipant participant);

class GroupCallView extends StatefulWidget {
  static const double wideBreakpoint = 720;

  final CallSession session;
  final String title;
  final CallParticipantResolver resolve;
  final CallMediaBuilder mediaOf;
  final CallVideoLookup videoOf;
  final bool muted;
  final bool speakerOn;
  final bool videoBusy;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleVideo;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleScreen;
  final VoidCallback onHangup;
  final VoidCallback onMinimize;
  final VoidCallback onShowMicrophones;
  final VoidCallback onShowInfo;

  const GroupCallView({
    super.key,
    required this.session,
    required this.title,
    required this.resolve,
    required this.mediaOf,
    required this.videoOf,
    required this.muted,
    required this.speakerOn,
    required this.videoBusy,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onToggleVideo,
    required this.onSwitchCamera,
    required this.onToggleScreen,
    required this.onHangup,
    required this.onMinimize,
    required this.onShowMicrophones,
    required this.onShowInfo,
  });

  @override
  State<GroupCallView> createState() => _GroupCallViewState();
}

class _GroupCallViewState extends State<GroupCallView> {
  static const Object _inviteTile = 'invite';

  StreamSubscription<CallNotice>? _noticeSub;
  StreamSubscription<void>? _infoSub;
  bool _inviteDismissed = false;
  int? _pinned;
  bool _handBusy = false;
  bool _recordBusy = false;
  int _accountId = 0;
  int _chatUnread = 0;
  CallVideoKey? _focus;
  List<Object> _gridVisible = const [];
  Size _gridTile = Size.zero;

  CallSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _subscribe();
    unawaited(_resolveAccount());
  }

  @override
  void didUpdateWidget(GroupCallView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.session, widget.session)) return;
    oldWidget.session.setVideoRequests(null);
    _unsubscribe();
    _subscribe();
    _publishVideoRequests();
  }

  @override
  void dispose() {
    _session.setVideoRequests(null);
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _noticeSub = _session.notices.listen(_onNotice);
    _infoSub = _session.infoUpdates.listen((_) {
      if (!mounted) return;
      _chatUnread = _readChatUnread();
      final focus = _focus;
      if (focus != null && !_isLive(focus)) _focus = null;
      setState(() {});
      _publishVideoRequests();
    });
    chats.chatsChanged.addListener(_onChatsChanged);
  }

  void _unsubscribe() {
    _noticeSub?.cancel();
    _infoSub?.cancel();
    chats.chatsChanged.removeListener(_onChatsChanged);
  }

  CallParticipant? _participant(int id) {
    for (final p in _session.participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _isLive(CallVideoKey key) {
    final p = _participant(key.$1);
    if (p == null) return false;
    return switch (key.$2) {
      CallVideoSource.camera => p.isSelf ? _session.localVideo : p.videoEnabled,
      CallVideoSource.screen =>
        p.isSelf ? _session.localScreen : p.screenSharing,
    };
  }

  CallVideoKey? _primaryVideo(CallParticipant p) {
    final screen = p.isSelf ? _session.localScreen : p.screenSharing;
    if (screen) return (p.id, CallVideoSource.screen);
    final camera = p.isSelf ? _session.localVideo : p.videoEnabled;
    if (camera) return (p.id, CallVideoSource.camera);
    return null;
  }

  void _setFocus(CallVideoKey? focus) {
    if (focus == _focus) return;
    setState(() => _focus = focus);
    _publishVideoRequests();
  }

  void _onGridVisible(List<Object> ids, Size tile) {
    _gridVisible = ids;
    _gridTile = tile;
    _publishVideoRequests();
  }

  void _publishVideoRequests() {
    if (!mounted) return;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final views = <CallVideoKey, CallVideoRequest>{};
    final focus = _focus;
    if (focus != null) {
      views[focus] = CallSession.stageVideoRequest;
      final width = MediaQuery.sizeOf(context).width;
      final height = _stripHeight(width >= GroupCallView.wideBreakpoint);
      final tile = Size(height * CallStrip.aspect, height) * ratio;
      final ids = _stripIds(focus);
      final fitting = CallStrip.fittingCount(width, height, 8);
      for (final id in ids.take(fitting)) {
        final p = _participant(id);
        if (p == null) continue;
        final key = p.id == focus.$1
            ? (p.id, CallVideoSource.camera)
            : _primaryVideo(p);
        if (key != null && !views.containsKey(key)) {
          views[key] = (size: tile, cover: true);
        }
      }
    } else {
      for (final id in _gridVisible.whereType<int>()) {
        final p = _participant(id);
        final key = p == null ? null : _primaryVideo(p);
        if (key != null) views[key] = (size: _gridTile * ratio, cover: true);
      }
    }
    _session.setVideoRequests(views);
  }

  static double _stripHeight(bool wide) => wide ? 120 : 92;

  List<int> _stripIds(CallVideoKey focus) => [
    for (final p in _ordered())
      if (p.id != focus.$1 || focus.$2 == CallVideoSource.screen) p.id,
  ];

  void _onChatsChanged() {
    final unread = _readChatUnread();
    if (unread != _chatUnread && mounted) setState(() => _chatUnread = unread);
  }

  int _readChatUnread() {
    final chatId = _session.chatId;
    if (chatId == null || _accountId == 0) return 0;
    return chats.cachedUnreadCount(_accountId, chatId) ?? 0;
  }

  Future<void> _resolveAccount() async {
    try {
      final id = await currentAccountId();
      if (!mounted) return;
      setState(() {
        _accountId = id;
        _chatUnread = _readChatUnread();
      });
    } catch (e) {
      logger.w('[call] active account lookup failed: $e');
    }
  }

  void _onNotice(CallNotice notice) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(context, switch (notice) {
      CallNotice.handLoweredByAdmin => l10n.callHandLoweredByAdmin,
      CallNotice.allHandsLoweredByAdmin => l10n.callAllHandsLoweredByAdmin,
      CallNotice.micMutedByAdmin => l10n.callMicMutedByAdmin,
      CallNotice.cameraMutedByAdmin => l10n.callCameraMutedByAdmin,
      CallNotice.screenMutedByAdmin => l10n.callScreenMutedByAdmin,
    });
  }

  List<CallParticipant> _ordered() {
    final all = _session.participants;
    final others = all.where((p) => !p.isSelf).toList();
    final index = {for (var i = 0; i < others.length; i++) others[i].id: i};
    int rank(CallParticipant p) {
      if (p.id == _pinned) return 0;
      if (p.handRaised) return 1;
      if (p.screenSharing) return 2;
      if (p.videoEnabled) return 3;
      return 4;
    }

    others.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      if (a.handRaised && b.handRaised) {
        final byTime = a.handRaisedAt.compareTo(b.handRaisedAt);
        if (byTime != 0) return byTime;
      }
      return index[a.id]!.compareTo(index[b.id]!);
    });
    return [...all.where((p) => p.isSelf), ...others];
  }

  void _guarded(
    BuildContext anchor,
    CallMedia media, {
    required bool turningOn,
    required VoidCallback action,
  }) {
    if (turningOn && _session.mediaLocked(media)) {
      showHintBubble(anchor, AppLocalizations.of(context)!.callMediaLocked);
      return;
    }
    action();
  }

  Future<void> _toggleHand() async {
    if (_handBusy) return;
    final l10n = AppLocalizations.of(context)!;
    _handBusy = true;
    try {
      await _session.setHandRaised(!_session.handRaised);
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          l10n.callParticipantsActionFailed('$e'),
        );
      }
    } finally {
      _handBusy = false;
    }
  }

  Future<void> _toggleRecord() async {
    if (_recordBusy) return;
    final l10n = AppLocalizations.of(context)!;
    final recording = _session.record != null;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime.now());
    setState(() => _recordBusy = true);
    await runCallAdmin(context, _session, (admin) async {
      if (recording) {
        await admin.stopRecord();
      } else {
        await admin.startRecord(name: l10n.callRecordName(date));
      }
    });
    if (mounted) setState(() => _recordBusy = false);
  }

  Future<void> _copyLink([BuildContext? anchor]) async {
    final l10n = AppLocalizations.of(context)!;
    String? token;
    try {
      token = await CallController.instance.ensureJoinLink();
    } catch (e) {
      logger.w('[call] join link failed: $e');
    }
    if (!mounted) return;
    if (token == null) {
      showCustomNotification(context, l10n.callLinkUnavailable);
      return;
    }
    await Clipboard.setData(ClipboardData(text: CallLink.url(token)));
    if (anchor != null && anchor.mounted) {
      showHintBubble(anchor, l10n.sharedLinkCopied);
    } else if (mounted) {
      showCustomNotification(context, l10n.sharedLinkCopied);
    }
  }

  Future<void> _addParticipants() async {
    final l10n = AppLocalizations.of(context)!;
    await showPickMembersSheet(
      context,
      excludeIds: {
        if (_accountId != 0) _accountId,
        for (final p in _session.participants) ?p.externalId,
      },
      title: l10n.callInviteAdd,
      successMessage: l10n.callInvited,
      failureMessage: l10n.callInviteFailed,
      submit: _invite,
    );
  }

  Future<bool> _invite(List<int> userIds) async {
    final chatId = _session.chatId;
    try {
      if (chatId != null) {
        return await chats.addMembers(api, chatId: chatId, userIds: userIds);
      }
      final admin = _session.admin;
      if (admin == null) return false;
      await admin.addParticipants([for (final id in userIds) '$id']);
      return true;
    } catch (e) {
      logger.w('[call] invite failed: $e');
      return false;
    }
  }

  Future<void> _openChat() async {
    final chatId = _session.chatId;
    if (chatId == null) return;
    final navigator = Navigator.of(context);
    widget.onMinimize();
    await openChatById(navigator.context, chatId);
  }

  Future<void> _message(CallParticipantView view) async {
    final contactId = view.contactId;
    if (contactId == null) return;
    final navigator = Navigator.of(context);
    widget.onMinimize();
    await openDialogWith(
      navigator.context,
      contactId,
      name: view.name,
      avatarUrl: view.avatarUrl,
    );
  }

  void _openParticipantMenu(CallParticipant p) {
    final view = widget.resolve(p);
    showCallParticipantMenu(
      context,
      session: _session,
      participant: p,
      view: view,
      scheme: Theme.of(context).colorScheme,
      pinned: _pinned == p.id,
      onTogglePin: () =>
          setState(() => _pinned = _pinned == p.id ? null : p.id),
      onMessage: () => _message(view),
      onSwitchCamera: widget.onSwitchCamera,
    );
  }

  void _showParticipants() {
    showCallParticipantsSheet(
      context,
      session: _session,
      scheme: Theme.of(context).colorScheme,
      resolve: widget.resolve,
      onParticipant: _openParticipantMenu,
      onCopyLink: _copyLink,
      onAddParticipants: _addParticipants,
    );
  }

  void _showSettings() {
    showCallSettingsSheet(
      context,
      session: _session,
      scheme: Theme.of(context).colorScheme,
      onMicrophone: widget.onShowMicrophones,
      onCamera: _showCameras,
      onInfo: widget.onShowInfo,
    );
  }

  void _showCameras() {
    showCallCameraSheet(
      context,
      session: _session,
      scheme: Theme.of(context).colorScheme,
    );
  }

  void _showMore() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (sheetContext) {
        void run(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        final unread = _chatUnread;
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: cs),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.chatId != null)
                    ListTile(
                      leading: const Icon(Symbols.chat),
                      title: Text(l10n.callChat),
                      trailing: unread > 0 ? _CountBadge(count: unread) : null,
                      onTap: () => run(_openChat),
                    ),
                  ListTile(
                    leading: Icon(
                      session.localScreen
                          ? Symbols.stop_screen_share
                          : Symbols.screen_share,
                    ),
                    title: Text(
                      session.localScreen
                          ? l10n.callParticipantStopScreen
                          : l10n.callShareScreen,
                    ),
                    onTap: () => run(() {
                      if (!session.localScreen &&
                          session.mediaLocked(CallMedia.screenShare)) {
                        showCustomNotification(context, l10n.callMediaLocked);
                        return;
                      }
                      widget.onToggleScreen();
                    }),
                  ),
                  if (session.localVideo)
                    ListTile(
                      leading: const Icon(Symbols.cameraswitch),
                      title: Text(l10n.callSwitchCamera),
                      onTap: () => run(widget.onSwitchCamera),
                    ),
                  if (session.canRecord)
                    ListTile(
                      leading: Icon(
                        session.record != null
                            ? Symbols.stop_circle
                            : Symbols.radio_button_checked,
                      ),
                      title: Text(
                        session.record != null
                            ? l10n.callParticipantsStopRecording
                            : l10n.callParticipantsStartRecording,
                      ),
                      onTap: () => run(_toggleRecord),
                    ),
                  ListTile(
                    leading: const Icon(Symbols.link),
                    title: Text(l10n.callInviteCopyLink),
                    onTap: () => run(_copyLink),
                  ),
                  ListTile(
                    leading: const Icon(Symbols.settings),
                    title: Text(l10n.callSettingsTitle),
                    onTap: () => run(_showSettings),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _recordingText(CallRecord record, AppLocalizations l10n) {
    final initiator = record.initiatorId;
    if (initiator == _session.selfUserId) return l10n.callRecordingSelf;
    for (final p in _session.participants) {
      if (p.id == initiator) {
        return l10n.callRecordingBy(widget.resolve(p).name);
      }
    }
    return l10n.callRecordingSomeone;
  }

  @override
  Widget build(BuildContext context) {
    final focus = _focusedOrNull();
    final peer = focus == null ? null : _participant(focus.$1);
    final remote = peer != null && !peer.isSelf ? peer : null;
    return CallFullscreenScope(
      stage: focus,
      screen: remote != null && focus?.$2 == CallVideoSource.screen
          ? _session.remoteScreenOf(remote.id)
          : null,
      video: remote == null ? null : widget.videoOf(remote),
      builder: (context, fullscreen, toggle) => fullscreen && focus != null
          ? _stageView(focus, toggle, fullscreen: true)
          : _layout(focus, toggle),
    );
  }

  Widget _layout(CallVideoKey? focus, VoidCallback toggleFullscreen) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= GroupCallView.wideBreakpoint;
        final record = _session.record;
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: wide ? _wideTopBar() : _narrowTopBar(),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: record == null
                    ? const SizedBox(key: ValueKey('no-record'))
                    : KeyedSubtree(
                        key: const ValueKey('record'),
                        child: _recordingBanner(record),
                      ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.96,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: focus == null
                      ? KeyedSubtree(
                          key: const ValueKey('grid'),
                          child: _grid(wide),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('stage'),
                          child: _stage(wide, focus, toggleFullscreen),
                        ),
                ),
              ),
              wide ? _wideControls() : _narrowControls(),
              SizedBox(height: wide ? 16 : 20),
            ],
          ),
        );
      },
    );
  }

  Widget _wideTopBar() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (anchor) => _TextPill(
                icon: Symbols.link,
                label: l10n.callLinkLabel,
                onTap: () => _copyLink(anchor),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: _titlePill(),
                ),
                const SizedBox(width: 8),
                _RoundButton(
                  icon: const Icon(Symbols.person_add, fill: 1),
                  tooltip: l10n.callInviteAdd,
                  onTap: _addParticipants,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _RoundButton(
              icon: const Icon(Symbols.close_fullscreen),
              tooltip: l10n.callTooltipMinimize,
              onTap: widget.onMinimize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowTopBar() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _RoundButton(
            icon: const Icon(Symbols.close_fullscreen),
            tooltip: l10n.callTooltipMinimize,
            onTap: widget.onMinimize,
          ),
          const SizedBox(width: 8),
          Expanded(child: Center(child: _titlePill())),
          const SizedBox(width: 8),
          _RoundButton(
            icon: const Icon(Symbols.person_add, fill: 1),
            tooltip: l10n.callInviteAdd,
            onTap: _addParticipants,
          ),
        ],
      ),
    );
  }

  Widget _titlePill() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final count = _session.participantCount;
    return CallPressScale(
      enabled: count > 0,
      pressedScale: 0.96,
      child: GlossyPill(
        color: cs.surfaceContainerHighest,
        onTap: count > 0 ? _showParticipants : null,
        depth: 6,
        padding: const EdgeInsets.fromLTRB(18, 6, 10, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: displayFontOf(context),
                    ),
                  ),
                  Text(
                    count == 0
                        ? l10n.callGroupConnecting
                        : l10n.chatCallParticipants(count),
                    maxLines: 1,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Symbols.chevron_right, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _recordingBanner(CallRecord record) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlossyPill(
        color: cs.surfaceContainerHighest,
        depth: 4,
        onTap: _session.canRecord ? _toggleRecord : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingDot(color: kDangerRed),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _recordingText(record, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(bool wide) {
    final cs = Theme.of(context).colorScheme;
    final ordered = _ordered();
    final byId = {for (final p in ordered) p.id: p};
    final alone = ordered.every((p) => p.isSelf);
    final ids = <Object>[
      for (final p in ordered) p.id,
      if (alone && ordered.isNotEmpty && !_inviteDismissed) _inviteTile,
    ];
    if (ids.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.callStatusConnecting,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
        ),
      );
    }
    final handPositions = _session.handPositions;
    return CallGrid<Object>(
      ids: ids,
      gap: wide ? 10 : 8,
      minTileSide: wide ? 160 : 110,
      indicatorColor: cs.onSurface,
      padding: EdgeInsets.fromLTRB(wide ? 8 : 8, 12, wide ? 8 : 8, 12),
      onVisibleChanged: _onGridVisible,
      tileBuilder: (context, id, size) {
        if (id == _inviteTile) {
          return _InviteTile(
            onCopy: _copyLink,
            onAdd: _addParticipants,
            onClose: () => setState(() => _inviteDismissed = true),
          );
        }
        return _participantTile(byId[id]!, handPositions);
      },
    );
  }

  Widget _participantTile(
    CallParticipant p,
    Map<int, int> handPositions, {
    CallVideoSource? source,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final view = widget.resolve(p);
    final muted = p.isSelf ? widget.muted : !p.audioEnabled;
    final CallVideoKey? video = source == null
        ? _primaryVideo(p)
        : (p.id, source);
    final expandable = video != null && _isLive(video);
    return CallParticipantTile(
      name: view.name,
      avatarUrl: view.avatarUrl,
      userId: view.contactId,
      muted: muted,
      speaking: !muted && _session.isSpeaking(p.id),
      handRaised: p.handRaised,
      handPosition: handPositions.length > 1 ? handPositions[p.id] : null,
      screenSharing: p.screenSharing,
      networkRating: p.networkRating,
      videoStalled: p.videoStalled,
      media: (avatar) => widget.mediaOf(p, avatar, source: source),
      onTap: () => _openParticipantMenu(p),
      expandTooltip: l10n.callTooltipExpand,
      onExpand: expandable ? () => _setFocus(video) : null,
      info: () => callParticipantInfo(l10n, _session, p),
    );
  }

  CallVideoKey? _focusedOrNull() {
    final focus = _focus;
    return focus != null && _isLive(focus) ? focus : null;
  }

  Widget _stageView(
    CallVideoKey focus,
    VoidCallback toggleFullscreen, {
    bool fullscreen = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final p = _participant(focus.$1)!;
    final view = widget.resolve(p);
    final screen = focus.$2 == CallVideoSource.screen;
    final muted = p.isSelf ? widget.muted : !p.audioEnabled;
    final avatar = Center(
      child: KometAvatar(
        name: view.name,
        imageUrl: view.avatarUrl,
        userId: view.contactId,
        size: 144,
      ),
    );
    return CallStage(
      key: ValueKey(focus),
      media:
          widget.mediaOf(p, avatar, source: focus.$2, stage: true) ?? avatar,
      label: screen ? l10n.callScreenOf(view.name) : view.name,
      labelIcon: screen ? Symbols.screen_share : Symbols.videocam,
      speaking: !screen && !muted && _session.isSpeaking(p.id),
      collapseTooltip: l10n.callExitFocus,
      onCollapse: () => _setFocus(null),
      fullscreenTooltip: fullscreen
          ? l10n.callExitFullscreen
          : l10n.callEnterFullscreen,
      onToggleFullscreen: toggleFullscreen,
      fullscreen: fullscreen,
    );
  }

  Widget _stage(bool wide, CallVideoKey focus, VoidCallback toggleFullscreen) {
    final handPositions = _session.handPositions;
    final strip = _stripIds(focus);
    final gap = wide ? 10.0 : 8.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 12, 8, wide ? 12 : 8),
      child: Column(
        children: [
          Expanded(child: _stageView(focus, toggleFullscreen)),
          if (strip.isNotEmpty) ...[
            SizedBox(height: gap),
            CallStrip<int>(
              ids: strip,
              height: _stripHeight(wide),
              gap: 8,
              tileBuilder: (context, id, size) {
                final other = _participant(id)!;
                return _participantTile(
                  other,
                  handPositions,
                  source: id == focus.$1 ? CallVideoSource.camera : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _wideControls() {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final video = session.localVideo;
    final screen = session.localScreen;
    final hand = session.handRaised;
    final recording = session.record != null;
    final unread = _chatUnread;
    return SizedBox(
      height: 60,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (anchor) => _SplitButton(
                    tooltip: widget.muted ? l10n.callUnmute : l10n.callMute,
                    active: widget.muted,
                    icon: CallSlashGlyph(
                      asset: 'assets/lottie/ic_mic_on_to_off.json',
                      slashed: widget.muted,
                    ),
                    onTap: () => _guarded(
                      anchor,
                      CallMedia.audio,
                      turningOn: widget.muted,
                      action: widget.onToggleMute,
                    ),
                    menuTooltip: l10n.callTooltipMicrophone,
                    onMenu: widget.onShowMicrophones,
                  ),
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (anchor) => _SplitButton(
                    tooltip: l10n.callVideoLabel,
                    active: video,
                    busy: widget.videoBusy,
                    icon: CallSlashGlyph(
                      asset: 'assets/lottie/ic_videocam_on_to_off.json',
                      slashed: !video,
                    ),
                    onTap: () => _guarded(
                      anchor,
                      CallMedia.video,
                      turningOn: !video,
                      action: widget.onToggleVideo,
                    ),
                    menuTooltip: l10n.callVideoLabel,
                    onMenu: _showCameras,
                  ),
                ),
                const SizedBox(width: 12),
                _RoundButton(
                  icon: WavingHandIcon(raised: hand),
                  tooltip: hand
                      ? l10n.callParticipantsLowerHand
                      : l10n.callParticipantsRaiseHand,
                  active: hand,
                  onTap: _toggleHand,
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (anchor) => _RoundButton(
                    icon: CallScreenGlyph(sharing: screen),
                    tooltip: screen
                        ? l10n.callParticipantStopScreen
                        : l10n.callShareScreen,
                    active: screen,
                    busy: widget.videoBusy,
                    onTap: () => _guarded(
                      anchor,
                      CallMedia.screenShare,
                      turningOn: !screen,
                      action: widget.onToggleScreen,
                    ),
                  ),
                ),
                if (session.canRecord) ...[
                  const SizedBox(width: 12),
                  _RoundButton(
                    icon: CallRecordGlyph(recording: recording),
                    tooltip: recording
                        ? l10n.callParticipantsStopRecording
                        : l10n.callParticipantsStartRecording,
                    active: recording,
                    busy: _recordBusy,
                    onTap: _toggleRecord,
                  ),
                ],
                const SizedBox(width: 12),
                _RoundButton(
                  icon: const Icon(Symbols.call_end, fill: 1),
                  tooltip: l10n.callEndButton,
                  background: kDangerRed,
                  foreground: Colors.white,
                  onTap: widget.onHangup,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.chatId != null) ...[
                    _RoundButton(
                      icon: const Icon(Symbols.chat, fill: 1),
                      tooltip: l10n.callChat,
                      badge: unread,
                      onTap: _openChat,
                    ),
                    const SizedBox(width: 12),
                  ],
                  _RoundButton(
                    icon: const Icon(Symbols.settings, fill: 1),
                    tooltip: l10n.callSettingsTitle,
                    onTap: _showSettings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowControls() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final video = session.localVideo;
    final hand = session.handRaised;
    final muted = widget.muted;
    return CallControlBar(
      children: [
        CallButton(
          icon: Symbols.volume_up,
          glyph: CallSpeakerGlyph(loud: widget.speakerOn),
          label: l10n.callSpeaker,
          background: widget.speakerOn
              ? cs.primary
              : cs.surfaceContainerHighest,
          foreground: widget.speakerOn ? cs.onPrimary : cs.onSurface,
          onTap: widget.onToggleSpeaker,
        ),
        Builder(
          builder: (anchor) => CallButton(
            icon: Symbols.mic,
            slashAsset: 'assets/lottie/ic_mic_on_to_off.json',
            slashed: muted,
            label: muted ? l10n.callUnmute : l10n.callMute,
            background: muted ? cs.primary : cs.surfaceContainerHighest,
            foreground: muted ? cs.onPrimary : cs.onSurface,
            onTap: () => _guarded(
              anchor,
              CallMedia.audio,
              turningOn: muted,
              action: widget.onToggleMute,
            ),
            onLongPress: widget.onShowMicrophones,
            micLevels: session.micLevels,
          ),
        ),
        Builder(
          builder: (anchor) => CallButton(
            icon: Symbols.videocam,
            slashAsset: 'assets/lottie/ic_videocam_on_to_off.json',
            slashed: !video,
            label: l10n.callVideoLabel,
            background: video ? cs.primary : cs.surfaceContainerHighest,
            foreground: video ? cs.onPrimary : cs.onSurface,
            busy: widget.videoBusy,
            onTap: () => _guarded(
              anchor,
              CallMedia.video,
              turningOn: !video,
              action: widget.onToggleVideo,
            ),
            onLongPress: _showCameras,
          ),
        ),
        CallButton(
          icon: Symbols.front_hand,
          glyph: WavingHandIcon(raised: hand),
          label: hand
              ? l10n.callParticipantsLowerHand
              : l10n.callParticipantsRaiseHand,
          background: hand ? cs.primary : cs.surfaceContainerHighest,
          foreground: hand ? cs.onPrimary : cs.onSurface,
          onTap: _toggleHand,
        ),
        CallButton(
          icon: Symbols.more_horiz,
          label: l10n.callMore,
          background: cs.surfaceContainerHighest,
          foreground: cs.onSurface,
          badge: _chatUnread > 0,
          onTap: _showMore,
        ),
        CallButton(
          icon: Symbols.call_end,
          label: l10n.callEndButton,
          background: kDangerRed,
          foreground: Colors.white,
          onTap: widget.onHangup,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  static const double size = 48;

  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final bool busy;
  final int badge;
  final Color? background;
  final Color? foreground;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.busy = false,
    this.badge = 0,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = background ?? (active ? cs.primary : cs.surfaceContainerHighest);
    final fg = foreground ?? (active ? cs.onPrimary : cs.onSurface);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: CallPressScale(
          enabled: !busy,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CallColorTransition(
                  background: bg,
                  foreground: fg,
                  builder: (context, bg, fg) => GlossyPill(
                    color: bg,
                    borderRadius: BorderRadius.circular(size / 2),
                    depth: 6,
                    onTap: busy ? null : onTap,
                    child: Center(
                      child: busy
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: fg,
                              ),
                            )
                          : IconTheme.merge(
                              data: IconThemeData(color: fg, size: 24),
                              child: icon,
                            ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: badge > 0
                        ? _CountBadge(
                            key: const ValueKey('badge'),
                            count: badge,
                          )
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: 1,
    end: 0.25,
  ).animate(_curve);

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SplitButton extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final String menuTooltip;
  final bool active;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const _SplitButton({
    required this.icon,
    required this.tooltip,
    required this.menuTooltip,
    required this.active,
    required this.onTap,
    required this.onMenu,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: _RoundButton.size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_RoundButton.size / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundButton(
            icon: icon,
            tooltip: tooltip,
            active: active,
            busy: busy,
            onTap: onTap,
          ),
          Tooltip(
            message: menuTooltip,
            child: CallPressScale(
              child: InkResponse(
                onTap: onMenu,
                radius: 18,
                child: SizedBox(
                  width: 30,
                  height: _RoundButton.size,
                  child: Icon(
                    Symbols.expand_more,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TextPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CallPressScale(
      pressedScale: 0.94,
      child: GlossyPill(
        color: cs.surfaceContainerHighest,
        depth: 6,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.surface, width: 2),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  final void Function(BuildContext anchor) onCopy;
  final VoidCallback onAdd;
  final VoidCallback onClose;

  const _InviteTile({
    required this.onCopy,
    required this.onAdd,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: cs.onSurface,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    );
    return Material(
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.biggest.shortestSide < 220;
          return Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.callInviteTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: compact ? 17 : 24,
                          fontWeight: FontWeight.w600,
                          fontFamily: displayFontOf(context),
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Builder(
                            builder: (anchor) => TextButton.icon(
                              style: buttonStyle,
                              onPressed: () => onCopy(anchor),
                              icon: const Icon(Symbols.content_copy, size: 20),
                              label: Text(l10n.callInviteCopyLink),
                            ),
                          ),
                          TextButton.icon(
                            style: buttonStyle,
                            onPressed: onAdd,
                            icon: const Icon(
                              Symbols.person_add,
                              size: 20,
                              fill: 1,
                            ),
                            label: Text(l10n.callInviteAdd),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  onPressed: onClose,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
