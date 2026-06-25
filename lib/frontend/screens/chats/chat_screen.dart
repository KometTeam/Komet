import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/file_uploader.dart';
import 'package:komet/backend/modules/upload_notification_service.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/media/opus_ogg_encoder.dart';
import 'package:komet/core/media/native_video_note_recorder.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/core/utils/logger.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:komet/frontend/screens/contacts/contact_profile_screen.dart';
import 'package:komet/frontend/screens/chats/forward_picker_screen.dart';
import 'package:komet/frontend/screens/chats/poll_create_screen.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/chat_menu_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/calls/call_controller.dart';
import '../calls/call_screen.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/draft_store.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/cache/message_session_cache.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/config/app_cache_extent.dart';
import '../../../core/config/app_message_actions_style.dart';
import '../../../core/config/app_swipe_back_desktop.dart';
import '../../../core/config/app_pranks.dart';
import '../../../core/config/app_commands.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/config/komet_settings.dart';
import '../../../models/attachment.dart';
import '../../commands/command_registry.dart';
import '../../commands/slash_command.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/command_suggestions_panel.dart';
import '../../widgets/online_dot.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/theme_reveal.dart';
import '../../widgets/message_actions_overlay.dart';
import '../../widgets/attachment_panel.dart';
import '../../widgets/attachment/attachment_sheet.dart';
import '../../widgets/swipe_to_pop.dart';
import '../../widgets/schedule_time_picker.dart';
import 'scheduled_messages_screen.dart';

class _UploadStatus {
  final bool active;
  final int sent;
  final int total;

  const _UploadStatus({this.active = false, this.sent = 0, this.total = 0});

  bool get awaitingResponse => active && total > 0 && sent >= total;
  double? get progressValue =>
      (!active || total == 0 || awaitingResponse) ? null : sent / total;
}

class _DateSeparatorItem {
  final DateTime date;
  final GlobalKey key;
  _DateSeparatorItem(this.date, this.key);
}

class _MessageItem {
  final CachedMessage message;
  final int index;
  const _MessageItem(this.message, this.index);
}

class _RecordingDot extends StatefulWidget {
  final Color color;
  const _RecordingDot({required this.color});

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.25).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  final List<double> amps;
  final Color color;

  const _LiveWavePainter({required this.amps, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const slot = 5.0;
    const barW = 3.0;
    final count = (size.width / slot).floor();
    if (count <= 0 || amps.isEmpty) return;

    final start = amps.length > count ? amps.length - count : 0;
    final visible = amps.sublist(start);
    final center = size.height / 2;
    final paint = Paint()..color = color;
    final offset = size.width - visible.length * slot;

    for (var i = 0; i < visible.length; i++) {
      final h = (visible[i] * size.height).clamp(2.0, size.height);
      final x = offset + i * slot + (slot - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, center - h / 2, barW, h),
          const Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) => true;
}

class _ButtonClipper extends CustomClipper<Rect> {
  final double t;
  const _ButtonClipper(this.t);

  @override
  Rect getClip(Size size) {
    if (t <= 0.001) {
      return Rect.fromLTRB(-120, -260, size.width + 120, size.height + 40);
    }
    return Rect.fromLTRB(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_ButtonClipper old) => old.t != t;
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool embedded;
  final VoidCallback? onClose;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  double _keyboardReserve = 0;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final ValueNotifier<bool> _hasText = ValueNotifier(false);
  bool _isLoading = true;
  final ValueNotifier<bool> _showAttachmentPanel = ValueNotifier(false);
  final ValueNotifier<_UploadStatus> _uploadStatus = ValueNotifier(
    const _UploadStatus(),
  );
  StreamSubscription<UploadEvent>? _uploadSub;
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<MessageEvent>? _messageEventSub;
  StreamSubscription<SessionState>? _connSub;
  final Map<String, ValueNotifier<Map<String, dynamic>?>> _reactionNotifiers =
      {};
  final Map<String, ValueNotifier<List<double>>> _photoUploadProgress = {};
  final ValueNotifier<int> _scheduledCount = ValueNotifier(0);

  AudioRecorder? _voiceRecorder;
  final ValueNotifier<bool> _isRecordingVoice = ValueNotifier(false);
  final ValueNotifier<int> _voiceElapsedMs = ValueNotifier(0);
  final ValueNotifier<double> _voiceCancelDrag = ValueNotifier(0);
  final ValueNotifier<double> _voiceAmplitude = ValueNotifier(0);
  final ValueNotifier<int> _voiceWaveRev = ValueNotifier(0);
  final ValueNotifier<bool> _voiceLocked = ValueNotifier(false);
  final ValueNotifier<double> _voiceLockDrag = ValueNotifier(0);
  final Stopwatch _voiceStopwatch = Stopwatch();
  final List<double> _voiceAmps = [];
  Timer? _voiceTimer;
  StreamSubscription<Amplitude>? _voiceAmpSub;
  String? _voicePath;
  bool _voiceCancelled = false;
  bool _voiceStopRequested = false;
  bool _voiceTranscode = false;

  final ValueNotifier<bool> _videoNoteMode = ValueNotifier(false);
  final NativeVideoNoteRecorder _noteRec = NativeVideoNoteRecorder();
  final ValueNotifier<int?> _noteTextureId = ValueNotifier(null);
  final ValueNotifier<bool> _noteCamReady = ValueNotifier(false);
  final ValueNotifier<bool> _isRecordingNote = ValueNotifier(false);
  final ValueNotifier<int> _noteElapsedMs = ValueNotifier(0);
  final ValueNotifier<double> _noteCancelDrag = ValueNotifier(0);
  final Stopwatch _noteStopwatch = Stopwatch();
  Timer? _noteTimer;
  bool _noteCancelled = false;
  bool _noteStopRequested = false;

  ValueListenable<List<double>>? _photoProgressFor(CachedMessage m) =>
      _photoUploadProgress[m.id];

  ValueNotifier<Map<String, dynamic>?> _reactionNotifierFor(CachedMessage m) {
    final existing = _reactionNotifiers[m.id];
    if (existing != null) return existing;
    final info = m.payload?['reactionInfo'];
    final notifier = ValueNotifier<Map<String, dynamic>?>(
      info is Map ? Map<String, dynamic>.from(info) : null,
    );
    _reactionNotifiers[m.id] = notifier;
    return notifier;
  }

  void _pruneReactionNotifiers() {
    final liveIds = _messages.map((m) => m.id).toSet();
    final dead = _reactionNotifiers.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in dead) {
      _reactionNotifiers.remove(id)?.dispose();
    }
  }

  final Set<int> _typingUserIds = {};
  final Map<int, Timer> _typingTimers = {};
  int _otherStatus = 0;
  int? _otherSeenTime;
  int? _participantsCount;

  final ValueNotifier<CachedMessage?> _replyTo = ValueNotifier(null);
  final ValueNotifier<String?> _highlightMessageId = ValueNotifier(null);

  bool _prankActive = false;
  String? _prankBubbleId;
  final GlobalKey _prankBubbleKey = GlobalKey();
  final GlobalKey _prankCaptureKey = GlobalKey();
  OverlayEntry? _prankRevealEntry;
  AnimationController? _prankRevealController;
  ui.Image? _prankRevealImage;
  final ValueNotifier<String> _headerStatusNotifier = ValueNotifier('');
  final ValueNotifier<int> _otherReadTime = ValueNotifier(0);
  int _tempIdCounter = 0;
  late final AnimationController _attachAnim;
  late final AnimationController _commandAnim;
  bool _commandPanelVisible = false;
  final ValueNotifier<List<SlashCommand>> _commandMatches =
      ValueNotifier(const []);

  String _nextTempId() =>
      'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';
  late AnimationController _shimmerController;
  Timer? _shimmerStartTimer;
  bool _historyKickedOff = false;
  bool _previewChat = false;
  List<CachedMessage> _messages = [];
  final ValueNotifier<int> _messagesRev = ValueNotifier(0);
  final Set<String> _deletingIds = {};

  static const int _historyPageSize = 30;
  static const int _historyInitialLimit = 50;
  static const double _avgMessageHeight = 72.0;
  static const double _historyPrefetchExtent = _avgMessageHeight * 8;
  bool _isLoadingMore = false;
  bool _hasMoreHistory = true;
  List<Object>? _combinedItemsCache;
  int? _combinedItemsKey;
  bool _floatingDateScheduled = false;
  int _myId = 0;
  CachedChat? chat;

  final ValueNotifier<DateTime?> _floatingDate = ValueNotifier(null);
  Timer? _floatingDateTimer;
  late final AnimationController _floatingDateAnimController;
  late final CurvedAnimation _floatingDateCurved;
  final Map<int, GlobalKey> _separatorKeys = {};
  String? _lastSentId;
  String? _lastMarkedId;
  final ValueNotifier<int> _otherUnread = ValueNotifier(0);

  final ValueNotifier<Set<String>> _selectedIds = ValueNotifier(const {});
  late final AnimationController _selectionAnim;

  bool get _selectionMode => _selectedIds.value.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatsModule.chatsChanged.addListener(_onChatsBump);
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollForDate);
    _scrollController.addListener(_maybeLoadMoreHistory);
    AppVisualStyle.current.addListener(_onVisualStyleChanged);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _showAttachmentPanel.addListener(_onAttachPanelToggle);
    _commandAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _selectionAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    AppCommands.current.addListener(_updateCommandPanel);
    _pushSub = api.pushStream
        .where(
          (p) =>
              p.opcode == Opcode.notifMark ||
              p.opcode == Opcode.notifTyping ||
              p.opcode == Opcode.notifMsgDelayed,
        )
        .listen(_onIncomingPush);
    _messageEventSub = ChatsModule.messageEvents
        .where((e) => e.chatId == widget.chatId)
        .listen(_onMessageEvent);
    _connSub = api.stateStream.listen((_) {
      if (mounted) _recomputeHeaderStatus();
    });
    debugForceOffline.addListener(_recomputeHeaderStatus);
    PresenceFetch.revision.addListener(_onPresenceChanged);
    _floatingDateAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 380),
    );
    _floatingDateCurved = CurvedAnimation(
      parent: _floatingDateAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    unawaited(_fastPreloadCache());
    unawaited(_loadParticipantsCount());
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrameRendered);
  }

  Future<void> _loadParticipantsCount() async {
    if (widget.chatType != 'CHAT' && widget.chatType != 'CHANNEL') return;
    final info = await ChatsModule.getChatInfo(api, widget.chatId);
    if (!mounted) return;
    final count = info?['participantsCount'] as int?;
    if (count != null && count != _participantsCount) {
      _participantsCount = count;
      _recomputeHeaderStatus();
    }
  }

  Future<void> _fastPreloadCache() async {
    final p = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    _myId = p?.id ?? 0;
    _restoreDraft();
    unawaited(_refreshBadge());

    ChatsModule.getChat(_myId, widget.chatId)
        .then((value) {
          if (mounted && value.isNotEmpty) {
            setState(() {
              chat = value.first;
            });
            _seedPresenceFromChat();
            _recomputeHeaderStatus();
            _syncOtherReadTime();
          }
        })
        .catchError((_) {});

    final cached = MessageSessionCache.get(_myId, widget.chatId);
    if (cached != null && cached.messages.isNotEmpty) {
      setState(() {
        _messages = List<CachedMessage>.of(cached.messages);
        _hasMoreHistory = !cached.reachedStart;
        _messagesRev.value++;
        _isLoading = false;
        _onLoadingFinished();
      });
      _syncReactionNotifiersFromMessages();
      return;
    }

    final firstRows = await AppDatabase.loadMessages(
      _myId,
      widget.chatId,
      limit: 20,
      onlyVisible: !KometSettings.viewDeleted.value,
    );
    if (!mounted) return;
    if (firstRows.isNotEmpty) {
      final first = firstRows.reversed
          .map((r) => CachedMessage.fromDbRow(r))
          .toList();
      setState(() {
        _messages = first;
        _messagesRev.value++;
        _isLoading = false;
        _onLoadingFinished();
      });
    }
  }

  void _onFirstFrameRendered(Duration _) {
    if (!mounted) return;
    if (widget.embedded) {
      _kickoffHistory();
      return;
    }
    final anim = ModalRoute.of(context)?.animation;
    if (anim == null || anim.status == AnimationStatus.completed) {
      _kickoffHistory();
      return;
    }
    Timer? safety;
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      anim.removeStatusListener(onStatus);
      safety?.cancel();
      if (!mounted) return;
      _kickoffHistory();
    }

    anim.addStatusListener(onStatus);
    safety = Timer(const Duration(milliseconds: 400), () {
      anim.removeStatusListener(onStatus);
      if (!mounted) return;
      _kickoffHistory();
    });
  }

  void _kickoffHistory() {
    if (_historyKickedOff) return;
    _historyKickedOff = true;
    _shimmerStartTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_isLoading) return;
      _shimmerController.repeat();
    });
    _loadHistory();
  }

  void _onLoadingFinished() {
    _shimmerStartTimer?.cancel();
    _shimmerStartTimer = null;
    if (_shimmerController.isAnimating) _shimmerController.stop();
    _markRead();
  }

  void _markRead() {
    if (_myId == 0 || _messages.isEmpty) return;
    final newest = _messages.last;
    if (newest.senderId == _myId) return;
    if (newest.id == _lastMarkedId) return;
    _lastMarkedId = newest.id;
    unawaited(
      ChatsModule.markRead(api, _myId, widget.chatId, newest.id, newest.time),
    );
  }

  bool _badgeRefreshing = false;
  bool _badgeRefreshQueued = false;

  void _onChatsBump() {
    if (_badgeRefreshing) {
      _badgeRefreshQueued = true;
      return;
    }
    unawaited(_runBadgeRefresh());
  }

  Future<void> _runBadgeRefresh() async {
    _badgeRefreshing = true;
    try {
      await _refreshBadge();
    } finally {
      _badgeRefreshing = false;
      if (_badgeRefreshQueued && mounted) {
        _badgeRefreshQueued = false;
        unawaited(_runBadgeRefresh());
      }
    }
  }

  Future<void> _refreshBadge() async {
    if (_myId == 0) return;
    final total =
        await AppDatabase.sumUnread(_myId, excludeChatId: widget.chatId);
    if (mounted) _otherUnread.value = total;
  }

  Future<void> _loadHistory() async {
    if (_myId == 0) {
      final activeProfile = await AppDatabase.loadActiveProfile();
      if (!mounted) return;
      _myId = activeProfile?.id ?? 0;
    }
    if (widget.chatType == 'DIALOG') {
      unawaited(_loadOtherPresence());
    }
    unawaited(_refreshScheduledCount());
    await _loadRemainingHistory();
  }

  Future<void> _loadRemainingHistory() async {
    final onlyVisible = !KometSettings.viewDeleted.value;
    final fullRows = await AppDatabase.loadMessages(
      _myId,
      widget.chatId,
      limit: _historyInitialLimit,
      onlyVisible: onlyVisible,
    );
    final fullDecoded = await CachedMessage.fromDbRowsAsync(fullRows);
    if (mounted) {
      _applyMergedMessages(fullDecoded);
    }

    if (fullRows.isNotEmpty &&
        ChatsModule.wasHistoryFetched(widget.chatId)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _onLoadingFinished();
        });
      }
      _loadForwardedSenderNames();
      _loadGroupSenderNames();
      return;
    }

    try {
      final cachedRows = await AppDatabase.loadChat(_myId, widget.chatId);
      if (cachedRows.isEmpty) {
        _previewChat = true;
        await ChatsModule.ensureChatCached(api, _myId, widget.chatId);
        await ChatsModule.subscribeChat(api, widget.chatId);
      }
      final serverMessages = await messagesModule.fetchHistory(
        _myId,
        widget.chatId,
      );
      ChatsModule.markHistoryFetched(widget.chatId);
      if (KometSettings.viewDeleted.value) {
        await ChatsModule.reconcileDeletedFromFetch(
          _myId,
          widget.chatId,
          serverMessages,
        );
      }
      final updatedRows = await AppDatabase.loadMessages(
        _myId,
        widget.chatId,
        limit: _historyInitialLimit,
        onlyVisible: onlyVisible,
      );
      final updatedDecoded = await CachedMessage.fromDbRowsAsync(updatedRows);
      if (mounted) {
        _applyMergedMessages(updatedDecoded, markLoaded: true);
      }
      unawaited(
        ChatsModule.reconcileLastMessageIfPlaceholder(_myId, widget.chatId),
      );
      _loadForwardedSenderNames();
      _loadGroupSenderNames();
    } catch (e) {
      logger.e('Error fetching history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _onLoadingFinished();
        });
      }
    }
  }

  void _maybeLoadMoreHistory() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || !_hasMoreHistory) return;
    if (_messages.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.maxScrollExtent - pos.pixels <= _historyPrefetchExtent) {
      unawaited(_loadMoreHistory());
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || !_hasMoreHistory || _messages.isEmpty) return;
    _isLoadingMore = true;
    setState(() {});

    final oldest = _messages.first;
    final onlyVisible = !KometSettings.viewDeleted.value;

    try {
      var older = await _loadOlderFromDb(oldest.time, onlyVisible);

      if (older.length < _historyPageSize) {
        final fetched = await messagesModule.fetchHistory(
          _myId,
          widget.chatId,
          fromTime: oldest.time,
          count: _historyPageSize,
        );
        if (fetched.isNotEmpty) {
          if (KometSettings.viewDeleted.value) {
            await ChatsModule.reconcileDeletedFromFetch(
              _myId,
              widget.chatId,
              fetched,
            );
          }
          older = await _loadOlderFromDb(oldest.time, onlyVisible);
        }
      }

      if (!mounted) return;
      final added = _prependOlder(older);
      setState(() {
        _isLoadingMore = false;
        if (added == 0) _hasMoreHistory = false;
      });
      _persistSessionCache();
      _loadForwardedSenderNames();
      _loadGroupSenderNames();
    } catch (e) {
      logger.e('Error loading more history: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<List<CachedMessage>> _loadOlderFromDb(
    int beforeTime,
    bool onlyVisible,
  ) async {
    final rows = await AppDatabase.loadMessagesBefore(
      _myId,
      widget.chatId,
      beforeTime: beforeTime,
      limit: _historyPageSize,
      onlyVisible: onlyVisible,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  int _prependOlder(List<CachedMessage> olderDesc) {
    if (olderDesc.isEmpty) return 0;
    final existing = _messages.map((m) => m.id).toSet();
    final toAdd = <CachedMessage>[];
    for (final m in olderDesc.reversed) {
      if (existing.add(m.id)) toAdd.add(m);
    }
    if (toAdd.isEmpty) return 0;
    _messages = [...toAdd, ..._messages];
    _messagesRev.value++;
    _syncReactionNotifiersFromMessages();
    return toAdd.length;
  }

  void _persistSessionCache() {
    if (_myId == 0 || _messages.isEmpty) return;
    MessageSessionCache.save(
      _myId,
      widget.chatId,
      _messages,
      reachedStart: !_hasMoreHistory,
    );
  }

  void _applyMergedMessages(
    List<CachedMessage> decodedDesc, {
    bool markLoaded = false,
  }) {
    final byId = <String, CachedMessage>{for (final m in _messages) m.id: m};
    var changed = false;
    for (final fresh in decodedDesc) {
      final old = byId[fresh.id];
      if (old == null) {
        byId[fresh.id] = fresh;
        changed = true;
      } else if (!_sameMessage(old, fresh)) {
        byId[fresh.id] = fresh;
        changed = true;
      }
    }

    if (!changed && !markLoaded) return;

    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = a.time.compareTo(b.time);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    setState(() {
      if (changed) {
        _messages = merged;
        _messagesRev.value++;
      }
      if (markLoaded) {
        _isLoading = false;
        _onLoadingFinished();
      }
    });
    if (changed) {
      _syncReactionNotifiersFromMessages();
      _pruneReactionNotifiers();
      _persistSessionCache();
    }
  }

  void _syncReactionNotifiersFromMessages() {
    for (final m in _messages) {
      final info = m.payload?['reactionInfo'];
      final value = info is Map ? Map<String, dynamic>.from(info) : null;
      final existing = _reactionNotifiers[m.id];
      if (existing == null) {
        _reactionNotifiers[m.id] = ValueNotifier(value);
      } else if (!_reactionsEqual(existing.value, value)) {
        existing.value = value;
      }
    }
  }

  bool _reactionsEqual(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k].toString() != b[k].toString()) return false;
    }
    return true;
  }

  bool _sameMessage(CachedMessage a, CachedMessage b) {
    return a.id == b.id &&
        a.time == b.time &&
        a.status == b.status &&
        a.text == b.text &&
        a.senderId == b.senderId &&
        a.deleted == b.deleted;
  }

  @override
  void deactivate() {
    _saveDraft();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveDraft();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    _persistSessionCache();
    if (_previewChat) {
      unawaited(ChatsModule.subscribeChat(api, widget.chatId, subscribe: false));
    }
    WidgetsBinding.instance.removeObserver(this);
    ChatsModule.chatsChanged.removeListener(_onChatsBump);
    _otherUnread.dispose();
    _saveDraft();
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollForDate);
    _scrollController.removeListener(_maybeLoadMoreHistory);
    AppVisualStyle.current.removeListener(_onVisualStyleChanged);
    _floatingDateTimer?.cancel();
    _floatingDateCurved.dispose();
    _floatingDateAnimController.dispose();
    _floatingDate.dispose();
    _hasText.dispose();
    _scheduledCount.dispose();
    _showAttachmentPanel.removeListener(_onAttachPanelToggle);
    _showAttachmentPanel.dispose();
    _uploadSub?.cancel();
    _pushSub?.cancel();
    _messageEventSub?.cancel();
    _connSub?.cancel();
    _voiceTimer?.cancel();
    _voiceAmpSub?.cancel();
    _voiceRecorder?.dispose();
    _noteTimer?.cancel();
    _noteOverlay?.remove();
    _noteRec.dispose();
    _noteTextureId.dispose();
    _videoNoteMode.dispose();
    _noteCamReady.dispose();
    _isRecordingNote.dispose();
    _noteElapsedMs.dispose();
    _noteCancelDrag.dispose();
    _isRecordingVoice.dispose();
    _voiceElapsedMs.dispose();
    _voiceCancelDrag.dispose();
    _voiceAmplitude.dispose();
    _voiceWaveRev.dispose();
    _voiceLocked.dispose();
    _voiceLockDrag.dispose();
    debugForceOffline.removeListener(_recomputeHeaderStatus);
    for (final n in _reactionNotifiers.values) {
      n.dispose();
    }
    _reactionNotifiers.clear();
    for (final n in _photoUploadProgress.values) {
      n.dispose();
    }
    _photoUploadProgress.clear();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    PresenceFetch.revision.removeListener(_onPresenceChanged);
    _headerStatusNotifier.dispose();
    _otherReadTime.dispose();
    _messagesRev.dispose();
    _finishPrankReveal();
    _uploadStatus.dispose();
    _attachAnim.dispose();
    AppCommands.current.removeListener(_updateCommandPanel);
    _commandAnim.dispose();
    _selectionAnim.dispose();
    _selectedIds.dispose();
    _commandMatches.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _shimmerStartTimer?.cancel();
    _shimmerController.dispose();
    _replyTo.dispose();
    _highlightMessageId.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText.value) {
      _hasText.value = newHasText;
    }
    _updateCommandPanel();
  }

  List<SlashCommand> _matchingCommands(String raw) {
    if (!AppCommands.current.value) return const [];
    final text = raw.trimLeft();
    if (!text.startsWith('/')) return const [];
    if (text.contains(RegExp(r'\s'))) return const [];
    final query = text.toLowerCase();
    for (final c in kSlashCommands) {
      if (!c.hidden && c.name.toLowerCase() == query) return const [];
    }
    return kSlashCommands
        .where((c) => !c.hidden && c.name.toLowerCase().startsWith(query))
        .toList(growable: false);
  }

  void _updateCommandPanel() {
    final matches = _matchingCommands(_messageController.text);
    final show = matches.isNotEmpty;
    if (show && !listEquals(_commandMatches.value, matches)) {
      _commandMatches.value = matches;
    }
    if (show == _commandPanelVisible) return;
    _commandPanelVisible = show;
    if (show) {
      _commandAnim.forward();
    } else {
      _commandAnim.reverse();
    }
  }

  void _onCommandSelected(SlashCommand c) {
    final text = '${c.name} ';
    _messageController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _messageFocusNode.requestFocus();
  }

  void _restoreDraft() {
    if (_myId == 0 || _messageController.text.isNotEmpty) return;
    final draft = DraftStore.instance.get(_myId, widget.chatId);
    if (draft == null || draft.isEmpty) return;
    _messageController.text = draft;
    _messageController.selection =
        TextSelection.collapsed(offset: draft.length);
  }

  void _saveDraft() {
    if (_myId == 0) return;
    unawaited(
      DraftStore.instance.set(_myId, widget.chatId, _messageController.text),
    );
  }

  void _onAttachPanelToggle() {
    if (_showAttachmentPanel.value) {
      _attachAnim.forward();
    } else {
      _attachAnim.reverse();
    }
  }

  Widget _buildCommandPanel() {
    return AnimatedBuilder(
      animation: _commandAnim,
      child: ValueListenableBuilder<List<SlashCommand>>(
        valueListenable: _commandMatches,
        builder: (context, matches, _) => CommandSuggestionsPanel(
          commands: matches,
          onSelected: _onCommandSelected,
        ),
      ),
      builder: (context, child) {
        final t = _commandAnim.value;
        if (t == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: IgnorePointer(
            ignoring: t < 1,
            child: Opacity(
              opacity: t,
              child: child,
            ),
          ),
        );
      },
    );
  }

  int _computeOtherReadTime() {
    final c = chat;
    if (c == null) return 0;
    int otherReadTime = 0;
    for (final entry in c.participants.entries) {
      if (entry.key != _myId && entry.value > otherReadTime) {
        otherReadTime = entry.value;
      }
    }
    return otherReadTime;
  }

  void _syncOtherReadTime() {
    final t = _computeOtherReadTime();
    if (_otherReadTime.value != t) _otherReadTime.value = t;
  }

  void _checkPrankTrigger(CachedMessage msg) {
    if (!AppPranks.current.value || _prankActive || _prankBubbleId != null) {
      return;
    }
    if ((msg.text ?? '').trim().toUpperCase() != 'THE WORLD') return;
    setState(() => _prankBubbleId = msg.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runPrankReveal();
    });
  }

  ThemeData _prankPinkTheme(ThemeData base) {
    final cs = base.colorScheme;
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFFF0F5),
      colorScheme: cs.copyWith(
        surface: const Color(0xFFFFF0F5),
        surfaceContainerHigh: const Color(0xFFFFE3EC),
        surfaceContainerHighest: const Color(0xFFFFD9E6),
        primary: const Color(0xFFE8579A),
        primaryContainer: const Color(0xFFFFD6E5),
        onPrimaryContainer: const Color(0xFF7A1F4B),
      ),
    );
  }

  void _runPrankReveal() {
    if (_prankActive) return;
    final overlay = Navigator.of(context).overlay;
    final captureCtx = _prankCaptureKey.currentContext;
    final renderObject = captureCtx?.findRenderObject();
    if (overlay == null || renderObject is! RenderRepaintBoundary) {
      setState(() => _prankActive = true);
      return;
    }

    Offset center;
    final bubbleBox =
        _prankBubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (bubbleBox != null && bubbleBox.attached) {
      center = bubbleBox.localToGlobal(bubbleBox.size.center(Offset.zero));
    } else {
      final size = MediaQuery.sizeOf(context);
      center = Offset(size.width / 2, size.height / 2);
    }

    final ui.Image snapshot;
    try {
      final dpr = math.min(MediaQuery.of(context).devicePixelRatio, 2.0);
      snapshot = renderObject.toImageSync(pixelRatio: dpr);
    } catch (_) {
      setState(() => _prankActive = true);
      return;
    }

    _finishPrankReveal();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    final entry = ThemeRevealOverlay.build(
      snapshot: snapshot,
      center: center,
      animation: controller,
    );

    _prankRevealController = controller;
    _prankRevealEntry = entry;
    _prankRevealImage = snapshot;

    overlay.insert(entry);
    setState(() => _prankActive = true);
    Haptics.success();

    WidgetsBinding.instance.endOfFrame.then((_) {
      if (_prankRevealController != controller) return;
      controller.forward().then((_) {
        if (_prankRevealController != controller) return;
        _finishPrankReveal();
      }, onError: (_) {});
    });
  }

  void _finishPrankReveal() {
    _prankRevealEntry?.remove();
    _prankRevealEntry = null;
    _prankRevealController?.dispose();
    _prankRevealController = null;
    final img = _prankRevealImage;
    _prankRevealImage = null;
    if (img != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => img.dispose());
    }
  }

  String? _effectiveStatus(CachedMessage msg) {
    if (msg.senderId != _myId) return null;
    if (msg.status == 'sending' || msg.status == 'error') return msg.status;
    if (chat == null) return 'sent';
    final otherReadTime = _otherReadTime.value;
    if (otherReadTime > 0 && otherReadTime >= msg.time) return 'read';
    return 'sent';
  }

  void _onIncomingPush(Packet packet) {
    if (!mounted) return;
    switch (packet.opcode) {
      case Opcode.notifMark:
        _onMessageRead(packet);
      case Opcode.notifTyping:
        _onTyping(packet);
      case Opcode.notifMsgDelayed:
        final p = packet.payload;
        if (p is Map && p['chatId'] == widget.chatId) {
          // lastDelayedUpdateTime — авторитетный признак от сервера:
          // 0 — отложенных в чате не осталось, иначе они есть. Реагируем
          // мгновенно по пушу, не дожидаясь повторного запроса.
          final t = p['lastDelayedUpdateTime'];
          if (t is int && t == 0) {
            _scheduledCount.value = 0;
          } else {
            if (_scheduledCount.value == 0) _scheduledCount.value = 1;
            _refreshScheduledCount();
          }
        }
    }
  }

  void _markHasScheduled() {
    if (_scheduledCount.value == 0) _scheduledCount.value = 1;
  }

  Future<void> _refreshScheduledCount() async {
    if (_myId == 0) return;
    try {
      final list = await messagesModule.fetchDelayedMessages(
        _myId,
        widget.chatId,
      );
      if (mounted) _scheduledCount.value = list.length;
    } catch (_) {}
  }

  void _bumpMessages() {
    _combinedItemsCache = null;
    _messagesRev.value++;
  }

  void _enterSelection(CachedMessage message) {
    if (message.isControl) return;
    Haptics.medium();
    if (_selectedIds.value.contains(message.id)) return;
    _selectedIds.value = {..._selectedIds.value, message.id};
    _syncSelectionAnim();
  }

  void _toggleSelection(CachedMessage message) {
    if (message.isControl) return;
    final next = Set<String>.from(_selectedIds.value);
    if (!next.remove(message.id)) next.add(message.id);
    Haptics.selection();
    _selectedIds.value = next;
    _syncSelectionAnim();
  }

  void _clearSelection() {
    if (_selectedIds.value.isEmpty) return;
    _selectedIds.value = const {};
    _syncSelectionAnim();
  }

  void _syncSelectionAnim() {
    if (_selectedIds.value.isEmpty) {
      _selectionAnim.reverse();
    } else if (_selectionAnim.status != AnimationStatus.forward &&
        _selectionAnim.value < 1) {
      _selectionAnim.forward();
    }
  }

  List<CachedMessage> _selectedMessages(Set<String> ids) =>
      _messages.where((m) => ids.contains(m.id)).toList();

  CachedMessage? _singleCopyableText(Set<String> ids) {
    CachedMessage? found;
    var textCount = 0;
    for (final m in _messages) {
      if (!ids.contains(m.id)) continue;
      if ((m.text ?? '').isEmpty) continue;
      if (++textCount > 1) return null;
      found = m;
    }
    return found;
  }

  CachedMessage? _singleEditable(Set<String> ids) {
    if (ids.length != 1) return null;
    final list = _selectedMessages(ids);
    if (list.isEmpty) return null;
    return _canEditMessage(list.first) ? list.first : null;
  }

  void _copySelected(CachedMessage message) {
    final text = message.text;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    Haptics.tap();
    showCustomNotification(context, 'Скопировано');
    _clearSelection();
  }

  void _editSelected(CachedMessage message) {
    _clearSelection();
    _startEditMessage(message);
  }

  Future<void> _deleteSelected() async {
    final msgs = _selectedMessages(_selectedIds.value);
    if (msgs.isEmpty) return;

    final serverMsgs =
        msgs.where((m) => !m.id.startsWith('temp_')).toList();
    if (serverMsgs.isEmpty) {
      for (final m in msgs) {
        _startDeleteAnimation(m.id);
      }
      _clearSelection();
      return;
    }

    final canForEveryone = serverMsgs.every((m) => m.senderId == _myId);
    final forEveryone = await _showDeleteMessageDialog(canForEveryone);
    if (forEveryone == null || !mounted) return;

    final ok = await messagesModule.deleteMessages(
      widget.chatId,
      serverMsgs.map((m) => m.id).toList(),
      forEveryone: forEveryone,
    );
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось удалить сообщения');
      return;
    }
    for (final m in msgs) {
      _startDeleteAnimation(m.id);
    }
    _clearSelection();
  }

  void _replySelected() {
    final msgs = _selectedMessages(_selectedIds.value);
    if (msgs.isEmpty) return;
    final message = msgs.first;
    _clearSelection();
    _startReply(message);
  }

  void _forwardSelected() {
    final msgs = _selectedMessages(_selectedIds.value);
    _clearSelection();
    unawaited(_forwardMessages(msgs));
  }

  Future<void> _forwardMessages(List<CachedMessage> msgs) async {
    final forwardable =
        msgs.where((m) => !m.id.startsWith('temp_')).toList();
    if (forwardable.isEmpty) {
      showCustomNotification(context, 'Нечего пересылать');
      return;
    }

    final target = await showForwardPicker(
      context: context,
      accountId: _myId,
      messageCount: forwardable.length,
    );
    if (target == null || !mounted) return;

    final ordered = [...forwardable]..sort((a, b) => a.time.compareTo(b.time));
    var ok = 0;
    for (final m in ordered) {
      final mid = int.tryParse(m.id);
      if (mid == null) continue;
      try {
        await messagesModule.forwardMessage(target.chatId, widget.chatId, mid);
        ok++;
      } catch (_) {}
    }
    if (!mounted) return;
    if (ok == 0) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось переслать');
      return;
    }
    Haptics.send();
    showCustomNotification(
      context,
      target.chatId == widget.chatId
          ? 'Переслано'
          : 'Переслано в «${target.name}»',
    );
  }

  Widget _buildComposerArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _selectionAnim,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            if (t == 0) return child!;
            if (t == 1) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, 48 * t),
                  child: Opacity(opacity: 1 - t, child: child),
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _attachAnim,
                builder: (context, _) {
                  if (_attachAnim.value == 0) {
                    return const SizedBox.shrink();
                  }
                  final curve = _attachAnim.status == AnimationStatus.reverse
                      ? Curves.easeIn
                      : Curves.easeOut;
                  final t = curve.transform(_attachAnim.value);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: t,
                        child: Opacity(
                          opacity: t,
                          child: AttachmentPanel(
                            onClose: () => _showAttachmentPanel.value = false,
                            onPickFile: _pickAndUploadFile,
                            onSendById: _sendFileById,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              _buildInputArea(context),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: _selectionAnim,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            if (t == 0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: t,
                child: Opacity(opacity: t, child: child),
              ),
            );
          },
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: _selectedIds,
            builder: (context, selected, _) =>
                _buildSelectionBottomBar(cs, selected),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionBottomBar(ColorScheme cs, Set<String> selected) {
    final single = selected.length == 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (single) ...[
              Expanded(
                child: _selectionActionPill(
                  cs,
                  icon: Symbols.reply,
                  label: 'Ответить',
                  iconLeading: false,
                  onTap: _replySelected,
                ),
              ),
              const SizedBox(width: 12),
            ] else
              const Spacer(),
            Expanded(
              child: _selectionActionPill(
                cs,
                icon: Symbols.forward,
                label: 'Переслать',
                iconLeading: true,
                onTap: _forwardSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectionActionPill(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required bool iconLeading,
    required VoidCallback onTap,
  }) {
    final textWidget = Text(
      label,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Outfit',
      ),
    );
    final iconWidget = Icon(icon, color: cs.onSurface, size: 22, weight: 500);
    return GlossyPill(
      onTap: onTap,
      color: Color.alphaBlend(
        cs.surfaceContainerHighest.withValues(alpha: 0.92),
        cs.surface,
      ),
      borderRadius: BorderRadius.circular(28),
      depth: 8,
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        width: 0.5,
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: iconLeading
              ? [iconWidget, const SizedBox(width: 8), textWidget]
              : [textWidget, const SizedBox(width: 8), iconWidget],
        ),
      ),
    );
  }

  bool _canEditMessage(CachedMessage message) {
    if (message.senderId != _myId) return false;
    if (message.id.startsWith('temp_')) return false;
    if (message.isControl) return false;
    final status = message.status;
    if (status == 'sending' || status == 'error') return false;
    return true;
  }

  Future<void> _startEditMessage(CachedMessage message) async {
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: message.text ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Изменить сообщение',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 6,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Текст сообщения',
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      controller.dispose();
      return;
    }

    final newText = controller.text.trim();
    controller.dispose();
    if (newText == (message.text ?? '')) return;

    final ok = await messagesModule.editMessage(
      widget.chatId,
      message.id,
      text: newText,
    );
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось изменить сообщение');
      return;
    }

    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx != -1) {
      final old = _messages[idx];
      final edited = CachedMessage(
        id: old.id,
        accountId: old.accountId,
        chatId: old.chatId,
        senderId: old.senderId,
        text: newText.isEmpty ? null : newText,
        time: old.time,
        status: 'EDITED',
        payload: old.payload,
        attachments: old.attachments,
        isControl: old.isControl,
      );
      _messages[idx] = edited;
      _bumpMessages();
      unawaited(_persistOutgoing(edited));
    }
    Haptics.send();
  }

  Future<void> _confirmDeleteMessage(CachedMessage message, bool isMe) async {
    final isLocalOnly = message.id.startsWith('temp_');
    final canForEveryone = isMe && !isLocalOnly;

    if (isLocalOnly) {
      _startDeleteAnimation(message.id);
      return;
    }

    final forEveryone = await _showDeleteMessageDialog(canForEveryone);
    if (forEveryone == null || !mounted) return;

    final ok = await messagesModule.deleteMessages(
      widget.chatId,
      [message.id],
      forEveryone: forEveryone,
    );
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось удалить сообщение');
      return;
    }
    _startDeleteAnimation(message.id);
  }

  void _startDeleteAnimation(String messageId) {
    if (!_deletingIds.add(messageId)) return;
    Haptics.tap();
    _bumpMessages();
  }

  Future<void> _finalizeDelete(String messageId) async {
    if (!mounted) return;
    _deletingIds.remove(messageId);
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages.removeAt(idx);
      _reactionNotifiers.remove(messageId)?.dispose();
    }
    _bumpMessages();
    try {
      await AppDatabase.deleteMessage(_myId, widget.chatId, messageId);
      await ChatsModule.reconcileLastMessage(_myId, widget.chatId);
    } catch (_) {}
  }

  Future<bool?> _showDeleteMessageDialog(bool canForEveryone) {
    final cs = Theme.of(context).colorScheme;
    var alsoForEveryone = canForEveryone;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              backgroundColor: cs.surfaceContainerHigh,
              title: const Text('Удалить сообщение'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вы точно хотите удалить это сообщение?',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                  ),
                  if (canForEveryone) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => setLocalState(
                        () => alsoForEveryone = !alsoForEveryone,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: alsoForEveryone,
                            onChanged: (v) => setLocalState(
                              () => alsoForEveryone = v ?? false,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Также удалить для ${widget.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    canForEveryone && alsoForEveryone,
                  ),
                  child: Text('Удалить', style: TextStyle(color: cs.error)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onMessageEvent(MessageEvent event) {
    if (!mounted) return;
    switch (event) {
      case MessageAddedEvent(:final message):
        if (message.senderId == _myId) return;
        if (_messages.any((m) => m.id == message.id)) return;
        _lastSentId = message.id;
        _messages.add(message);
        _bumpMessages();
        _clearTyping(message.senderId);
        Haptics.tap();
        _scrollToBottom();
        _checkPrankTrigger(message);
        _markRead();
      case MessageEditedEvent(:final message):
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx == -1) return;
        _messages[idx] = message;
        _bumpMessages();
      case MessageSentEvent(:final tempId, :final message):
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx == -1) return;
        _lastSentId = message.id;
        _messages[idx] = message;
        _bumpMessages();
      case MessageRemovedEvent(:final messageId):
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;
        _messages.removeAt(idx);
        _bumpMessages();
        _reactionNotifiers.remove(messageId)?.dispose();
      case MessageMarkedDeletedEvent(:final messageId):
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;
        if (_messages[idx].deleted) return;
        _messages[idx] = _messages[idx].copyWith(deleted: true);
        _bumpMessages();
      case MessageReactionsChangedEvent(:final messageId, :final reactionInfo):
        _reactionNotifiers[messageId]?.value = reactionInfo;
    }
  }

  Future<void> _loadOtherPresence() async {
    if (_myId == 0) return;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return;
    if (PresenceFetch.live(otherId) != null) return;
    try {
      final entry = await PresenceFetch.get(otherId);
      if (!mounted || entry == null) return;
      PresenceFetch.apply(otherId, entry);
    } catch (_) {}
  }

  void _onPresenceChanged() {
    if (!mounted || widget.chatType != 'DIALOG' || _myId == 0) return;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return;
    final p = PresenceFetch.live(otherId);
    if (p == null) return;
    _otherStatus = (p['status'] as int?) ?? 0;
    _otherSeenTime = p['seen'] as int?;
    _recomputeHeaderStatus();
  }

  Widget _withOnlineDot(ColorScheme cs, Widget avatar, {double dotSize = 12}) {
    if (widget.chatType != 'DIALOG' || _myId == 0) return avatar;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return avatar;
    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: OnlineDot(
            userId: otherId,
            borderColor: cs.surface,
            size: dotSize,
          ),
        ),
      ],
    );
  }

  void _onVisualStyleChanged() {
    if (mounted) setState(() {});
  }

  Widget _backWithBadge(ColorScheme cs, Widget button) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        button,
        Positioned(
          right: -2,
          bottom: 0,
          child: IgnorePointer(child: _backUnreadBadge(cs)),
        ),
      ],
    );
  }

  Widget _backUnreadBadge(ColorScheme cs) {
    return ValueListenableBuilder<int>(
      valueListenable: _otherUnread,
      builder: (context, count, _) {
        return AnimatedScale(
          scale: count > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: cs.surface, width: 1.5),
            ),
            alignment: Alignment.center,
            child: _RollingCount(
              count: count > 99 ? 99 : count,
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    final glossy = AppVisualStyle.current.value == VisualStyle.glossy;
    final height = glossy ? 76.0 : kToolbarHeight;
    return AppBar(
      backgroundColor: glossy ? Colors.transparent : cs.surfaceContainerHigh,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: cs.onSurface),
      elevation: 0,
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      centerTitle: false,
      title: SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: _selectionAnim,
          builder: (context, _) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            return ValueListenableBuilder<Set<String>>(
              valueListenable: _selectedIds,
              builder: (context, selected, _) => Stack(
                fit: StackFit.expand,
                children: [
                  if (t < 1)
                    IgnorePointer(
                      ignoring: t > 0.5,
                      child: Opacity(
                        opacity: 1 - t,
                        child: Transform.translate(
                          offset: Offset(0, -height * 0.4 * t),
                          child: glossy
                              ? _glossyHeaderRow(cs)
                              : _materialHeaderRow(cs),
                        ),
                      ),
                    ),
                  if (t > 0)
                    IgnorePointer(
                      ignoring: t < 0.5,
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, height * 0.4 * (1 - t)),
                          child: _selectionTopBar(cs, selected, glossy),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _glossyHeaderRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          _backWithBadge(
            cs,
            SizedBox(
              width: 56,
              height: 56,
              child: GlossyPill(
                onTap: () {
                  if (widget.embedded) {
                    widget.onClose?.call();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Center(
                  child: Icon(
                    widget.embedded ? Symbols.close : Symbols.arrow_back,
                    color: cs.onSurface,
                    weight: 500,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlossyPill(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatInfoScreen(
                    chatId: widget.chatId,
                    name: widget.name,
                    imageUrl: widget.imageUrl,
                    chatType: widget.chatType,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              child: Row(
                children: [
                  _withOnlineDot(
                    cs,
                    widget.imageUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 22,
                            backgroundImage: CachedNetworkImageProvider(
                              widget.imageUrl,
                              maxWidth: 144,
                              maxHeight: 144,
                            ),
                          )
                        : CircleAvatar(
                            radius: 22,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              widget.name.isNotEmpty
                                  ? widget.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.name,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat?.isOfficial ?? false) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Symbols.verified,
                                color: cs.primary,
                                size: 16,
                                weight: 600,
                                fill: 1,
                              ),
                            ],
                          ],
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: _headerStatusNotifier,
                          builder: (context, status, _) => Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlossyPill(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _scheduledCount,
                    builder: (_, count, _) => count > 0
                        ? IconButton(
                            icon: Icon(
                              Symbols.schedule,
                              weight: 500,
                              color: cs.onSurface,
                            ),
                            onPressed: _openScheduledMessages,
                          )
                        : const SizedBox.shrink(),
                  ),
                  IconButton(
                    icon: Icon(Symbols.call, weight: 500, color: cs.onSurface),
                    onPressed: _startCall,
                  ),
                  Builder(
                    builder: (btnContext) => IconButton(
                      icon: Icon(
                        Symbols.more_vert,
                        weight: 500,
                        color: cs.onSurface,
                      ),
                      onPressed: () => _openChatMenu(btnContext),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialHeaderRow(ColorScheme cs) {
    return Row(
      children: [
        _backWithBadge(
          cs,
          IconButton(
            icon: Icon(
              widget.embedded ? Symbols.close : Symbols.arrow_back,
              weight: 400,
              color: cs.onSurface,
            ),
            onPressed: () {
              if (widget.embedded) {
                widget.onClose?.call();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatInfoScreen(
                  chatId: widget.chatId,
                  name: widget.name,
                  imageUrl: widget.imageUrl,
                  chatType: widget.chatType,
                ),
              ),
            ),
            child: Row(
              children: [
                _withOnlineDot(
                  cs,
                  widget.imageUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 18,
                          backgroundImage: CachedNetworkImageProvider(
                            widget.imageUrl,
                            maxWidth: 144,
                            maxHeight: 144,
                          ),
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            widget.name.isNotEmpty
                                ? widget.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                  dotSize: 11,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.name,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat?.isOfficial ?? false) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Symbols.verified,
                              color: cs.primary,
                              size: 16,
                              weight: 600,
                              fill: 1,
                            ),
                          ],
                        ],
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: _headerStatusNotifier,
                        builder: (context, status, _) => Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _scheduledCount,
          builder: (_, count, _) => count > 0
              ? IconButton(
                  icon: Icon(Symbols.schedule, weight: 400, color: cs.onSurface),
                  onPressed: _openScheduledMessages,
                )
              : const SizedBox.shrink(),
        ),
        IconButton(
          icon: Icon(Symbols.call, weight: 400, color: cs.onSurface),
          onPressed: _startCall,
        ),
        Builder(
          builder: (btnContext) => IconButton(
            icon: Icon(Symbols.more_vert, weight: 400, color: cs.onSurface),
            onPressed: () => _openChatMenu(btnContext),
          ),
        ),
      ],
    );
  }

  Widget _selectionTopBar(ColorScheme cs, Set<String> selected, bool glossy) {
    final count = selected.length;
    final copyMsg = _singleCopyableText(selected);
    final editMsg = _singleEditable(selected);
    final label = 'Выбрано $count';

    if (!glossy) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Symbols.close, color: cs.onSurface),
              onPressed: _clearSelection,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            if (copyMsg != null)
              IconButton(
                icon: Icon(Symbols.content_copy, color: cs.onSurface),
                onPressed: () => _copySelected(copyMsg),
              ),
            if (editMsg != null)
              IconButton(
                icon: Icon(Symbols.edit, color: cs.onSurface),
                onPressed: () => _editSelected(editMsg),
              ),
            IconButton(
              icon: Icon(Symbols.delete, color: cs.onSurface),
              onPressed: _deleteSelected,
            ),
          ],
        ),
      );
    }

    Widget actionBtn(IconData icon, VoidCallback onTap) => IconButton(
      icon: Icon(icon, weight: 500, color: cs.onSurface),
      onPressed: onTap,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: GlossyPill(
              onTap: _clearSelection,
              child: Center(
                child: Icon(
                  Symbols.close,
                  color: cs.onSurface,
                  weight: 500,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlossyPill(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlossyPill(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (copyMsg != null)
                    actionBtn(Symbols.content_copy, () => _copySelected(copyMsg)),
                  if (editMsg != null)
                    actionBtn(Symbols.edit, () => _editSelected(editMsg)),
                  actionBtn(Symbols.delete, _deleteSelected),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChatMenu(BuildContext btnContext) {
    final box = btnContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    showChatMenu(
      context: context,
      anchorRect: anchorRect,
      items: [
        ChatMenuItem(
          icon: Symbols.volume_up,
          label: 'Уведомления',
          showChevron: true,
          dividerAfter: true,
          onTap: () {},
        ),
        ChatMenuItem(
          icon: Symbols.videocam,
          label: 'Видеозвонок',
          onTap: () {},
        ),
        ChatMenuItem(icon: Symbols.search, label: 'Поиск', onTap: () {}),
        ChatMenuItem(
          icon: Symbols.wallpaper,
          label: 'Изменить обои',
          onTap: () {},
        ),
        ChatMenuItem(
          icon: Symbols.mop,
          label: 'Очистить историю',
          onTap: () {},
        ),
        ChatMenuItem(
          icon: Symbols.delete,
          label: 'Удалить чат',
          onTap: () {},
        ),
      ],
    );
  }

  Future<void> _startCall() async {
    if (widget.chatType != 'DIALOG') {
      showCustomNotification(context, 'Звонки доступны только в диалогах');
      return;
    }
    // Звонок уже идёт (возможно, свёрнут) — просто открываем его экран снова.
    final navigator = Navigator.of(context);
    final active = CallController.instance.activeSession;
    if (active != null) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: widget.name,
            avatarUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            session: active,
          ),
        ),
      );
      _onCallScreenClosed();
      return;
    }
    final peerId = widget.chatId ^ _myId;
    if (peerId <= 0) return;
    try {
      final session = await CallController.instance.startOutgoing(peerId);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: widget.name,
            avatarUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            session: session,
          ),
        ),
      );
      _onCallScreenClosed();
    } catch (_) {
      if (!mounted) return;
      showCustomNotification(context, 'Не удалось начать звонок');
    }
  }

  void _onCallScreenClosed() {
    if (!mounted) return;
    if (CallController.instance.activeSession != null) return;
    unawaited(_refreshAfterCall());
  }

  Future<void> _refreshAfterCall() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _myId == 0) return;
    try {
      final serverMessages =
          await messagesModule.fetchHistory(_myId, widget.chatId);
      if (KometSettings.viewDeleted.value) {
        await ChatsModule.reconcileDeletedFromFetch(
          _myId,
          widget.chatId,
          serverMessages,
        );
      }
      final rows = await AppDatabase.loadMessages(
        _myId,
        widget.chatId,
        limit: 100,
        onlyVisible: !KometSettings.viewDeleted.value,
      );
      final decoded = await CachedMessage.fromDbRowsAsync(rows);
      if (mounted) _applyMergedMessages(decoded);
    } catch (_) {}
  }

  void _seedPresenceFromChat() {
    if (widget.chatType != 'DIALOG' || _myId == 0) return;
    if (_otherStatus != 0 || _otherSeenTime != null) return;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return;
    final p = PresenceFetch.live(otherId);
    if (p == null) return;
    _otherStatus = (p['status'] as int?) ?? 0;
    _otherSeenTime = p['seen'] as int?;
  }

  void _recomputeHeaderStatus() {
    _headerStatusNotifier.value = _headerStatus();
  }

  String _headerStatus() {
    final conn = connectionStatusLabel(api.state);
    if (conn != null) return conn;
    if (_typingUserIds.isNotEmpty) return 'Печатает...';
    if (widget.chatType == 'CHAT') {
      final count = _participantsCount ?? chat?.participants.length ?? 0;
      return '$count участников';
    }
    if (widget.chatType == 'CHANNEL') {
      final count = _participantsCount ?? chat?.participants.length ?? 0;
      return '$count подписчиков';
    }
    if (_otherStatus == 1) return 'В сети';
    if (_otherStatus == 2 || _otherStatus == 3) return 'Был(-а) недавно';
    final s = _otherSeenTime;
    if (s != null && s > 0) return formatLastSeen(s);
    return '';
  }

  void _onTyping(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    if (payload['chatId'] != widget.chatId) return;
    final userId = payload['userId'];
    if (userId is! int || userId == _myId) return;

    _typingTimers[userId]?.cancel();
    _typingTimers[userId] = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      _typingUserIds.remove(userId);
      _typingTimers.remove(userId);
      _recomputeHeaderStatus();
    });
    if (_typingUserIds.add(userId)) {
      _recomputeHeaderStatus();
    }
  }

  void _clearTyping(int userId) {
    _typingTimers.remove(userId)?.cancel();
    if (_typingUserIds.remove(userId)) {
      _recomputeHeaderStatus();
    }
  }

  void _onMessageRead(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    if (payload['chatId'] != widget.chatId) return;
    final userId = payload['userId'];
    if (userId is! int || userId == _myId) return;
    final mark = payload['mark'];
    if (mark is! int) return;
    if (payload['setAsUnread'] == true) return;
    final c = chat;
    if (c == null) return;
    if (c.participants[userId] == mark) return;
    c.participants[userId] = mark;
    _syncOtherReadTime();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == 0) return;

    if (AppCommands.current.value && text.startsWith('/')) {
      final command = findSlashCommand(text);
      if (command == null) {
        _messageController.clear();
        _hasText.value = false;
        showCustomNotification(context, 'ТАКОЙ КОМАНДЫ НЕТУ🚨🚨🚨');
        return;
      }
      if (command.run != null) {
        final args = commandArgs(text);
        _messageController.clear();
        _hasText.value = false;
        unawaited(command.run!(_commandContext(args)));
        return;
      }
    }

    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = api.state == SessionState.online;

    final reply = _replyTo.value;
    final int? replyId = reply == null ? null : int.tryParse(reply.id);
    Map<String, dynamic>? replyPayload;
    if (reply != null && replyId != null) {
      replyPayload = {
        'link': {
          'type': 'REPLY',
          'chatId': widget.chatId,
          'message': {
            'id': replyId,
            'sender': reply.senderId,
            'text': reply.text,
            'time': reply.time,
            'attaches': reply.payload?['attaches'] ?? const [],
          },
        },
      };
    }
    _replyTo.value = null;

    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      text: text,
      time: now,
      status: online ? 'sending' : 'pending',
      payload: replyPayload,
    );

    _hasText.value = false;
    _lastSentId = tempId;
    _messages.add(composed);
    _messageController.clear();
    if (DraftStore.instance.get(_myId, widget.chatId) != null) {
      unawaited(DraftStore.instance.clear(_myId, widget.chatId));
    }
    _bumpMessages();
    unawaited(_persistOutgoing(composed));
    unawaited(ChatsModule.applyOutgoing(
      _myId,
      widget.chatId,
      messageId: tempId,
      time: now,
      text: text,
      status: composed.status ?? 'sending',
    ));

    // Instant tactile "whoosh" the moment the message leaves the composer,
    // not after the network round-trip — feedback must feel immediate.
    Haptics.send();

    _scrollToBottom();
    _checkPrankTrigger(composed);

    if (!online) return;

    try {
      final actualId = await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
        replyToMessageId: replyId,
      );

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        final sent = CachedMessage(
          id: actualId.isNotEmpty ? actualId : tempId,
          accountId: _myId,
          chatId: widget.chatId,
          senderId: _myId,
          text: text,
          time: now,
          status: 'sent',
          payload: replyPayload,
        );
        _messages[index] = sent;
        _bumpMessages();
        unawaited(_persistOutgoing(sent, removeId: tempId));
        unawaited(ChatsModule.applyOutgoing(
          _myId,
          widget.chatId,
          messageId: sent.id,
          time: now,
          text: text,
          status: 'sent',
        ));
      }

      if (chat == null) {
        unawaited(
          ChatsModule.refreshChats(api, [widget.chatId]).then((list) {
            if (!mounted || list.isEmpty) return;
            setState(() => chat = list.first);
            _syncOtherReadTime();
          }),
        );
      }
    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        final queued = CachedMessage(
          id: tempId,
          accountId: _myId,
          chatId: widget.chatId,
          senderId: _myId,
          text: text,
          time: now,
          status: 'pending',
          payload: replyPayload,
        );
        _messages[index] = queued;
        _bumpMessages();
        unawaited(_persistOutgoing(queued));
        unawaited(ChatsModule.applyOutgoing(
          _myId,
          widget.chatId,
          messageId: tempId,
          time: now,
          text: text,
          status: 'pending',
        ));
      }
    }
  }

  int? _resolveOtherId() {
    if (widget.chatType != 'DIALOG' || _myId == 0) return null;
    final id = widget.chatId ^ _myId;
    return id > 0 ? id : null;
  }

  CachedMessage _replaceMessage(
    int index, {
    String? id,
    String? text,
    String? status,
  }) {
    final old = _messages[index];
    final updated = CachedMessage(
      id: id ?? old.id,
      accountId: old.accountId,
      chatId: old.chatId,
      senderId: old.senderId,
      text: text ?? old.text,
      time: old.time,
      status: status ?? old.status,
      payload: old.payload,
      attachments: old.attachments,
      isControl: old.isControl,
    );
    _messages[index] = updated;
    _bumpMessages();
    return updated;
  }

  Future<String> _postCommandMessage(String text) async {
    if (!mounted || _myId == 0) return '';
    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = api.state == SessionState.online;
    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      text: text,
      time: now,
      status: online ? 'sending' : 'pending',
    );
    _messages.add(composed);
    _bumpMessages();
    _scrollToBottom();
    unawaited(_persistOutgoing(composed));
    unawaited(ChatsModule.applyOutgoing(
      _myId,
      widget.chatId,
      messageId: tempId,
      time: now,
      text: text,
      status: composed.status ?? 'sending',
    ));
    if (!online) return tempId;
    try {
      final actualId = await messagesModule.sendMessage(_myId, widget.chatId, text);
      final realId = actualId.isNotEmpty ? actualId : tempId;
      final i = _messages.indexWhere((m) => m.id == tempId);
      if (i != -1) {
        final sent = _replaceMessage(i, id: realId, status: 'sent');
        unawaited(_persistOutgoing(sent, removeId: tempId));
        unawaited(ChatsModule.applyOutgoing(
          _myId,
          widget.chatId,
          messageId: realId,
          time: now,
          text: text,
          status: 'sent',
        ));
      }
      return realId;
    } catch (_) {
      return tempId;
    }
  }

  Future<void> _updateCommandMessage(String id, String text) async {
    if (id.isEmpty) return;
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      final edited = _replaceMessage(i, text: text, status: 'EDITED');
      unawaited(_persistOutgoing(edited));
    }
    if (!id.startsWith('temp_')) {
      await messagesModule.editMessage(widget.chatId, id, text: text);
    }
  }

  CommandContext _commandContext(String args) => CommandContext(
    accountId: _myId,
    chatId: widget.chatId,
    otherUserId: _resolveOtherId(),
    args: args,
    messages: messagesModule,
    isOnline: () => api.state == SessionState.online,
    isActive: () => mounted,
    notify: (message, {duration}) {
      if (mounted) showCustomNotification(context, message, duration: duration);
    },
    postMessage: _postCommandMessage,
    updateMessage: _updateCommandMessage,
  );

  Future<void> _scheduleMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == 0) return;

    final when = await _pickScheduleTime();
    if (when == null || !mounted) return;

    try {
      await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
        scheduledTime: when.millisecondsSinceEpoch,
      );
      if (!mounted) return;
      _hasText.value = false;
      _messageController.clear();
      Haptics.send();
      _markHasScheduled();
      showCustomNotification(
        context,
        'Запланировано на ${formatDateTimeWords(when)}',
      );
    } catch (_) {
      if (!mounted) return;
      Haptics.error();
      showCustomNotification(context, 'Не удалось запланировать сообщение');
    }
  }

  Future<DateTime?> _pickScheduleTime() => showScheduleTimePicker(context);

  void _openScheduledMessages() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ScheduledMessagesScreen(
              chatId: widget.chatId,
              accountId: _myId,
              chatName: widget.name,
            ),
          ),
        )
        .then((_) {
          if (mounted) _refreshScheduledCount();
        });
  }

  Future<void> _persistOutgoing(CachedMessage msg, {String? removeId}) async {
    try {
      if (removeId != null && removeId != msg.id) {
        await AppDatabase.deleteMessage(_myId, widget.chatId, removeId);
      }
      await AppDatabase.saveMessages([msg.toDbRow()]);
    } catch (_) {}
  }

  Future<void> _loadGroupSenderNames() async {
    if (widget.chatType != 'CHAT' && widget.chatType != 'CHANNEL') return;

    final unknownIds = <int>{};
    for (final msg in _messages) {
      if (msg.isControl) continue;
      final id = msg.senderId;
      if (id == 0 || id == _myId) continue;
      if (ContactCache.get(id) == null) unknownIds.add(id);
    }
    if (unknownIds.isEmpty) return;

    final resolved = await messagesModule.ensureContactNames(unknownIds);
    if (resolved && mounted) _bumpMessages();
  }

  Future<void> _loadForwardedSenderNames() async {
    final forwardIds = <int>{};
    for (final msg in _messages) {
      if (msg.attachments != null) {
        for (final a in msg.attachments!) {
          if (a is ForwardedMessageAttachment) {
            if (a.originalSenderName == null &&
                ContactCache.get(a.originalSenderId) == null) {
              forwardIds.add(a.originalSenderId);
            }
          }
        }
      }
    }
    if (forwardIds.isEmpty) return;

    final resolved = <int, ({String name, String? avatar})>{};
    for (final id in forwardIds) {
      final name = await messagesModule.searchContactById(id);
      if (name != null) {
        resolved[id] = (name: name, avatar: ContactCache.getAvatar(id));
      }
    }
    if (resolved.isEmpty || !mounted) return;

    var anyChanged = false;
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final attaches = msg.attachments;
      if (attaches == null) continue;

      var msgChanged = false;
      final newAttaches = attaches.map((a) {
        if (a is ForwardedMessageAttachment &&
            a.originalSenderName == null &&
            resolved.containsKey(a.originalSenderId)) {
          final r = resolved[a.originalSenderId]!;
          msgChanged = true;
          return ForwardedMessageAttachment(
            originalSenderId: a.originalSenderId,
            originalSenderName: r.name,
            originalSenderAvatar: r.avatar,
            originalMessageId: a.originalMessageId,
            originalTime: a.originalTime,
            originalText: a.originalText,
            originalChatId: a.originalChatId,
            originalAttachments: a.originalAttachments,
            originalContact: a.originalContact,
          );
        }
        return a;
      }).toList();

      if (!msgChanged) continue;
      anyChanged = true;
      _messages[i] = CachedMessage(
        id: msg.id,
        accountId: msg.accountId,
        chatId: msg.chatId,
        senderId: msg.senderId,
        text: msg.text,
        time: msg.time,
        status: msg.status,
        payload: msg.payload,
        attachments: newAttaches,
      );
    }

    if (anyChanged) {
      _bumpMessages();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startReply(CachedMessage message) {
    _replyTo.value = message;
    _messageFocusNode.requestFocus();
  }

  void _cancelReply() {
    _replyTo.value = null;
  }

  void _openSenderProfile(int senderId) {
    if (senderId == 0 || senderId == _myId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactProfileScreen(
          contactId: senderId,
          initialName: ContactCache.get(senderId),
          initialAvatarUrl: ContactCache.getAvatar(senderId),
        ),
      ),
    );
  }

  void _jumpToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) {
      showCustomNotification(context, 'Сообщение не загружено');
      return;
    }

    final key = _keyForMessage(messageId);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.4,
      );
    }

    _highlightMessageId.value = messageId;
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (_highlightMessageId.value == messageId) {
        _highlightMessageId.value = null;
      }
    });
  }

  final Map<String, GlobalKey> _messageKeys = {};

  GlobalKey _keyForMessage(String messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  List<Object> _buildCombinedItems() {
    final key = Object.hash(_messagesRev.value, _messages.length);
    final cached = _combinedItemsCache;
    if (cached != null && _combinedItemsKey == key) return cached;

    final List<Object> items = [];
    final Set<int> usedDates = {};

    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.time);
      final dayMillis = DateTime(
        msgDate.year,
        msgDate.month,
        msgDate.day,
      ).millisecondsSinceEpoch;

      bool needSeparator = i == 0;
      if (!needSeparator) {
        final prevDate = DateTime.fromMillisecondsSinceEpoch(
          _messages[i - 1].time,
        );
        final prevDayMillis = DateTime(
          prevDate.year,
          prevDate.month,
          prevDate.day,
        ).millisecondsSinceEpoch;
        needSeparator = dayMillis != prevDayMillis;
      }

      if (needSeparator) {
        _separatorKeys.putIfAbsent(dayMillis, () => GlobalKey());
        usedDates.add(dayMillis);
        items.add(
          _DateSeparatorItem(
            DateTime.fromMillisecondsSinceEpoch(dayMillis),
            _separatorKeys[dayMillis]!,
          ),
        );
      }

      items.add(_MessageItem(msg, i));
    }

    _separatorKeys.removeWhere((k, _) => !usedDates.contains(k));
    _combinedItemsCache = items;
    _combinedItemsKey = key;
    return items;
  }

  void _onScrollForDate() {
    if (!_scrollController.hasClients) return;

    _floatingDateTimer?.cancel();
    _floatingDateTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) _floatingDateAnimController.reverse();
    });

    if (_floatingDateScheduled) return;
    _floatingDateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _floatingDateScheduled = false;
      _updateFloatingDate();
    });
  }

  void _updateFloatingDate() {
    if (!mounted || _separatorKeys.isEmpty) return;
    DateTime? result;

    final listRenderBox = _listKey.currentContext?.findRenderObject();
    if (listRenderBox is! RenderBox) return;

    _separatorKeys.forEach((dayMillis, gkey) {
      final ctx = gkey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) return;
      final pos = box.localToGlobal(Offset.zero, ancestor: listRenderBox);
      if (pos.dy + box.size.height < 4) {
        final date = DateTime.fromMillisecondsSinceEpoch(dayMillis);
        if (result == null || date.isAfter(result!)) {
          result = date;
        }
      }
    });

    if (result == null) return;

    final bool dateChanged = result != _floatingDate.value;
    _floatingDate.value = result;

    if (dateChanged) {
      _floatingDateAnimController.forward(from: 0);
    } else {
      _floatingDateAnimController.forward();
    }
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Сегодня';
    if (d == yesterday) return 'Вчера';

    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildDateSeparatorWidget(
    BuildContext context,
    DateTime date, {
    Key? key,
    bool floating = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontStyle: floating ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _prankActive
        ? _prankPinkTheme(Theme.of(context))
        : Theme.of(context);
    final cs = theme.colorScheme;

    // TODO: Локализация
    // TODO: Cклонения
    final mq = MediaQuery.of(context);
    final bottomInset = _keyboardReserve > 0
        ? math.max(mq.viewInsets.bottom, _keyboardReserve)
        : mq.viewInsets.bottom;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedIds,
      builder: (context, selected, child) => PopScope(
        canPop: selected.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _clearSelection();
        },
        child: child!,
      ),
      child: MediaQuery(
      data: mq.copyWith(
        viewInsets: mq.viewInsets.copyWith(bottom: bottomInset),
      ),
      child: Theme(
        data: theme,
        child: RepaintBoundary(
          key: _prankCaptureKey,
          child: ValueListenableBuilder<bool>(
            valueListenable: AppSwipeBackDesktop.current,
            builder: (context, desktopSwipe, child) => SwipeToPop(
              enabled: widget.embedded && desktopSwipe,
              onPop: widget.onClose,
              child: child!,
            ),
            child: Scaffold(
              backgroundColor: cs.surface,
              appBar: _buildAppBar(cs),
              body: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _isLoading && _messages.isEmpty
                              ? _buildShimmerLoading()
                              : _buildMessagesList(),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildCommandPanel(),
                        ),
                      ],
                    ),
                  ),
                  _buildComposerArea(context),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ValueListenableBuilder<int>(
      valueListenable: _messagesRev,
      builder: (context, _, _) => _buildMessagesListContent(),
    );
  }

  Widget _buildLoadMoreIndicator() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesListContent() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final items = _buildCombinedItems();

    return Stack(
      key: _listKey,
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _otherReadTime,
          builder: (context, _, _) => ValueListenableBuilder<double>(
            valueListenable: AppCacheExtent.current,
            builder: (context, cacheExtent, _) => ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              cacheExtent: cacheExtent,
              itemCount: items.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  return _buildLoadMoreIndicator();
                }
                final item = items[items.length - 1 - index];

                if (item is _DateSeparatorItem) {
                  return _buildDateSeparatorWidget(
                    context,
                    item.date,
                    key: item.key,
                  );
                }

                final msgItem = item as _MessageItem;
                final message = msgItem.message;
                final msgIndex = msgItem.index;
                final isMe = message.senderId == _myId;
                final prevMessage = msgIndex > 0
                    ? _messages[msgIndex - 1]
                    : null;
                final nextMessage = msgIndex < _messages.length - 1
                    ? _messages[msgIndex + 1]
                    : null;

                final bubble = MessageBubble(
                  message: message,
                  isMe: isMe,
                  myId: _myId,
                  prevMessage: prevMessage,
                  nextMessage: nextMessage,
                  chatType: chat?.type ?? 'CHAT',
                  overrideStatus: _effectiveStatus(message),
                  reactionsListenable: _reactionNotifierFor(message),
                  uploadProgress: _photoProgressFor(message),
                  onReplyTap: _jumpToMessage,
                  onAvatarTap: _openSenderProfile,
                );

                final pressable = _SelectableMessageRow(
                  message: message,
                  isMe: isMe,
                  selectedIds: _selectedIds,
                  selectionAnim: _selectionAnim,
                  isSelectionActive: () => _selectionMode,
                  onToggleSelection: () => _toggleSelection(message),
                  onEnterSelection: () => _enterSelection(message),
                  onDelete: () => _confirmDeleteMessage(message, isMe),
                  onEdit: _canEditMessage(message)
                      ? () => _startEditMessage(message)
                      : null,
                  onReply: message.isControl
                      ? null
                      : () => _startReply(message),
                  onForward: message.isControl
                      ? null
                      : () => _forwardMessages([message]),
                  child: bubble,
                );

                final isChannel =
                    (chat?.type ?? widget.chatType) == 'CHANNEL';
                final swipeable = (message.isControl || isChannel)
                    ? pressable
                    : _SwipeToReply(
                        isMe: isMe,
                        onReply: () => _startReply(message),
                        child: pressable,
                      );

                final Widget child;
                if (_deletingIds.contains(message.id)) {
                  child = _DeletingMessageAnimation(
                    key: ValueKey('del_${message.id}'),
                    onComplete: () => _finalizeDelete(message.id),
                    child: IgnorePointer(child: swipeable),
                  );
                } else if (message.id == _lastSentId) {
                  child = _SentMessageAnimation(
                    key: ValueKey('anim_${message.id}'),
                    onComplete: () {
                      if (mounted) {
                        _lastSentId = null;
                        _bumpMessages();
                      }
                    },
                    child: swipeable,
                  );
                } else {
                  child = swipeable;
                }

                final highlightable = ValueListenableBuilder<String?>(
                  valueListenable: _highlightMessageId,
                  builder: (context, hl, c) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    color: hl == message.id
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: c,
                  ),
                  child: child,
                );

                final builtItem = RepaintBoundary(
                  key: ValueKey('msg_${message.id}'),
                  child: KeyedSubtree(
                    key: _keyForMessage(message.id),
                    child: highlightable,
                  ),
                );
                return message.id == _prankBubbleId
                    ? KeyedSubtree(key: _prankBubbleKey, child: builtItem)
                    : builtItem;
              },
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<DateTime?>(
              valueListenable: _floatingDate,
              builder: (context, date, _) {
                if (date == null) return const SizedBox.shrink();
                return AnimatedBuilder(
                  animation: _floatingDateCurved,
                  builder: (context, child) {
                    final t = _floatingDateCurved.value;
                    return Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.82 + 0.18 * t,
                        child: child,
                      ),
                    );
                  },
                  child: _buildDateSeparatorWidget(
                    context,
                    date,
                    floating: true,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final cs = Theme.of(context).colorScheme;
        final placeholder = cs.surfaceContainerHighest;
        final opacity = 0.3 + (0.4 * _shimmerController.value);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 8,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final hasImage = index % 3 == 0;
            final hasReactions = index % 2 == 0;
            final width1 = 60.0 + (index * 15 % 50);
            final width2 = 120.0 + (index * 25 % 80);

            return Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: placeholder,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: width1,
                            height: 10,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: width2,
                            height: 32,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          if (hasImage) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 120,
                              decoration: BoxDecoration(
                                color: placeholder,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ],
                          if (hasReactions) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: List.generate(
                                3,
                                (i) => Container(
                                  width: 32,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: placeholder,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const int _voiceMinMs = 800;
  static const double _voiceCancelThreshold = 110;
  static const double _voiceLockThreshold = 90;

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice.value || _myId == 0) return;
    _voiceStopRequested = false;
    final rec = _voiceRecorder ??= AudioRecorder();
    try {
      final AudioEncoder encoder;
      final String ext;
      // Предпочитаем собственный кодер (libopus → Ogg/Opus): его формат сервер
      // гарантированно принимает. Нативный Opus от record (напр. на Android)
      // CDN не дообрабатывает — остаётся attachment.not.ready.
      if (await OpusOggEncoder.ensureAvailable() &&
          await rec.isEncoderSupported(AudioEncoder.wav)) {
        encoder = AudioEncoder.wav;
        ext = 'wav';
        _voiceTranscode = true;
      } else if (await rec.isEncoderSupported(AudioEncoder.opus)) {
        encoder = AudioEncoder.opus;
        ext = 'ogg';
        _voiceTranscode = false;
      } else {
        if (mounted) {
          showCustomNotification(
            context,
            'Голосовые сообщения недоступны на этой платформе',
          );
        }
        return;
      }
      if (!await rec.hasPermission()) {
        if (mounted) showCustomNotification(context, 'Нет доступа к микрофону');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      _voiceAmps.clear();
      _voiceCancelled = false;
      _voicePath = path;
      await rec.start(
        RecordConfig(
          encoder: encoder,
          numChannels: 1,
          sampleRate: 48000,
        ),
        path: path,
      );
      if (!mounted) {
        try {
          await rec.stop();
        } catch (_) {}
        return;
      }
      _voiceStopwatch
        ..reset()
        ..start();
      _voiceElapsedMs.value = 0;
      _voiceCancelDrag.value = 0;
      _voiceLocked.value = false;
      _voiceLockDrag.value = 0;
      _isRecordingVoice.value = true;
      FocusManager.instance.primaryFocus?.unfocus();
      Haptics.send();
      _voiceTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _voiceElapsedMs.value = _voiceStopwatch.elapsedMilliseconds;
      });
      _voiceAmpSub = rec
          .onAmplitudeChanged(const Duration(milliseconds: 70))
          .listen((amp) {
            final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
            _voiceAmps.add(norm);
            _voiceAmplitude.value = norm;
            _voiceWaveRev.value++;
          });
      if (_voiceStopRequested) {
        _voiceStopRequested = false;
        await _stopVoiceRecording(cancel: false);
      }
    } catch (_) {
      _isRecordingVoice.value = false;
      if (mounted) showCustomNotification(context, 'Не удалось начать запись');
    }
  }

  void _handleVoiceDrag(Offset offsetFromOrigin) {
    if (!_isRecordingVoice.value || _voiceLocked.value) return;

    final lock = (-offsetFromOrigin.dy / _voiceLockThreshold).clamp(0.0, 1.0);
    _voiceLockDrag.value = lock;
    if (lock >= 1.0) {
      _voiceLocked.value = true;
      _voiceLockDrag.value = 0;
      _voiceCancelDrag.value = 0;
      Haptics.send();
      return;
    }

    final drag = (-offsetFromOrigin.dx / _voiceCancelThreshold).clamp(0.0, 1.0);
    _voiceCancelDrag.value = drag;
    if (drag >= 1.0 && !_voiceCancelled) {
      _voiceCancelled = true;
      Haptics.error();
      _stopVoiceRecording(cancel: true);
    }
  }

  void _handleVoiceEnd() {
    if (_voiceLocked.value) return;
    _stopVoiceRecording(cancel: false);
  }

  Future<void> _stopVoiceRecording({required bool cancel}) async {
    if (!_isRecordingVoice.value) {
      _voiceStopRequested = true;
      return;
    }
    final rec = _voiceRecorder;
    if (rec == null) {
      _isRecordingVoice.value = false;
      return;
    }

    _voiceTimer?.cancel();
    _voiceTimer = null;
    await _voiceAmpSub?.cancel();
    _voiceAmpSub = null;
    _voiceStopwatch.stop();
    final elapsed = _voiceStopwatch.elapsedMilliseconds;
    _isRecordingVoice.value = false;
    _voiceCancelDrag.value = 0;
    _voiceAmplitude.value = 0;
    _voiceLocked.value = false;
    _voiceLockDrag.value = 0;

    String? path;
    try {
      path = await rec.stop();
    } catch (_) {}
    path ??= _voicePath;
    final amps = List<double>.from(_voiceAmps);
    _voiceAmps.clear();

    final shouldCancel = cancel || _voiceCancelled || elapsed < _voiceMinMs;
    if (shouldCancel || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    var file = File(path);
    if (_voiceTranscode) {
      final ogg = await _transcodeWavToOgg(file);
      if (ogg == null) {
        if (mounted) {
          showCustomNotification(context, 'Не удалось закодировать запись');
        }
        return;
      }
      file = ogg;
    }
    await _sendVoice(file, elapsed, amps);
  }

  Future<File?> _transcodeWavToOgg(File wav) async {
    try {
      final bytes = await wav.readAsBytes();
      final ogg = await OpusOggEncoder.wavToOggOpus(bytes);
      try {
        await wav.delete();
      } catch (_) {}
      if (ogg == null) return null;
      final oggPath = '${wav.path.substring(0, wav.path.length - 3)}ogg';
      final out = File(oggPath);
      await out.writeAsBytes(ogg, flush: true);
      return out;
    } catch (_) {
      return null;
    }
  }

  Uint8List _buildWave(List<double> amps, {int bars = 80}) {
    final out = Uint8List(bars);
    if (amps.isEmpty) return out;
    for (var i = 0; i < bars; i++) {
      final start = (i * amps.length / bars).floor();
      final end = (((i + 1) * amps.length / bars).ceil()).clamp(
        start + 1,
        amps.length,
      );
      var peak = 0.0;
      for (var j = start; j < end; j++) {
        if (amps[j] > peak) peak = amps[j];
      }
      out[i] = (peak * 120).round().clamp(0, 120);
    }
    return out;
  }

  Future<void> _sendVoice(File file, int durationMs, List<double> amps) async {
    if (_myId == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    final wave = _buildWave(amps);
    final tempId = _nextTempId();
    final progress = ValueNotifier<List<double>>(const [0]);
    _photoUploadProgress[tempId] = progress;
    _messages.add(
      CachedMessage(
        id: tempId,
        accountId: _myId,
        chatId: widget.chatId,
        senderId: _myId,
        time: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        attachments: [AudioAttachment(duration: durationMs)],
      ),
    );
    _lastSentId = tempId;
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();

    try {
      try {
        final len = await file.length();
        final head = await file
            .openRead(0, 80)
            .fold<List<int>>([], (a, b) => a..addAll(b));
        final hex = head.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final ascii = String.fromCharCodes(
          head.map((b) => (b >= 32 && b < 127) ? b : 46),
        );
        logger.w('VOICE size=$len hex=$hex ascii=$ascii');
      } catch (_) {}
      final info = await messagesModule.requestAudioUploadUrl();
      if (info == null || info.url.isEmpty) throw Exception('no_url');

      final ok = await fileUploader.uploadMediaFile(
        Uri.parse(info.url),
        file,
        onProgress: (sent, total) {
          if (total > 0) progress.value = [(sent / total).clamp(0.0, 1.0)];
        },
      );
      if (!ok) throw Exception('upload_failed');
      if (!mounted) {
        _disposePhotoProgress(tempId);
        return;
      }

      final serverMsg = await messagesModule.sendAudioMessage(
        widget.chatId,
        info.token,
        duration: durationMs,
        wave: wave,
      );
      if (!mounted) {
        _disposePhotoProgress(tempId);
        return;
      }
      if (serverMsg == null) throw Exception('send_failed');

      final real = CachedMessage.fromPushPayload(_myId, widget.chatId, serverMsg);
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        _messages[idx] = real;
        _bumpMessages();
        unawaited(_persistOutgoing(real, removeId: tempId));
      }
      _disposePhotoProgress(tempId);
    } catch (_) {
      if (mounted) {
        _failPhotoMessage(tempId);
      } else {
        _disposePhotoProgress(tempId);
      }
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // ── Видеосообщения-кружки ──────────────────────────────────────────
  Future<void> _toggleComposerMode() async {
    final toVideo = !_videoNoteMode.value;
    _videoNoteMode.value = toVideo;
    Haptics.tap();
    if (toVideo) {
      await _initNoteCamera();
    } else {
      await _disposeNoteCamera();
    }
  }

  Future<void> _initNoteCamera() async {
    if (_noteRec.textureId != null) return;
    if (!_noteRec.isAvailable) {
      if (mounted) showCustomNotification(context, 'Камера недоступна');
      return;
    }
    try {
      final ok = await _noteRec.init();
      if (!ok) {
        if (mounted) showCustomNotification(context, 'Камера недоступна');
        return;
      }
      if (!mounted || !_videoNoteMode.value) {
        await _disposeNoteCamera();
        return;
      }
      _noteTextureId.value = _noteRec.textureId;
      _noteCamReady.value = true;
    } catch (e) {
      logger.w('initNoteCamera: $e');
      if (mounted) showCustomNotification(context, 'Камера недоступна');
    }
  }

  Future<void> _disposeNoteCamera() async {
    _noteCamReady.value = false;
    _noteTextureId.value = null;
    await _noteRec.dispose();
  }

  Future<void> _startNoteRecording() async {
    if (_isRecordingNote.value) return;
    _noteStopRequested = false;
    if (_noteRec.textureId == null) {
      await _initNoteCamera();
      return;
    }
    try {
      final ok = await _noteRec.start();
      if (!ok) {
        _isRecordingNote.value = false;
        return;
      }
      if (!mounted) {
        await _noteRec.stop();
        return;
      }
      _noteStopwatch
        ..reset()
        ..start();
      _noteElapsedMs.value = 0;
      _noteCancelDrag.value = 0;
      _noteCancelled = false;
      _isRecordingNote.value = true;
      FocusManager.instance.primaryFocus?.unfocus();
      Haptics.send();
      _noteTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _noteElapsedMs.value = _noteStopwatch.elapsedMilliseconds;
      });
      _showNoteOverlay();
      if (_noteStopRequested) {
        _noteStopRequested = false;
        await _stopNoteRecording(cancel: false);
      }
    } catch (e) {
      logger.w('startNoteRecording: $e');
      _isRecordingNote.value = false;
    }
  }

  void _handleNoteDrag(Offset offsetFromOrigin) {
    if (!_isRecordingNote.value) return;
    final drag = (-offsetFromOrigin.dx / _voiceCancelThreshold).clamp(0.0, 1.0);
    _noteCancelDrag.value = drag;
    if (drag >= 1.0 && !_noteCancelled) {
      _noteCancelled = true;
      Haptics.error();
      _stopNoteRecording(cancel: true);
    }
  }

  void _handleNoteEnd() => _stopNoteRecording(cancel: false);

  Future<void> _stopNoteRecording({required bool cancel}) async {
    if (!_isRecordingNote.value) {
      _noteStopRequested = true;
      return;
    }
    _noteTimer?.cancel();
    _noteTimer = null;
    _noteStopwatch.stop();
    final elapsed = _noteStopwatch.elapsedMilliseconds;
    _isRecordingNote.value = false;
    _noteCancelDrag.value = 0;
    _hideNoteOverlay();

    final path = await _noteRec.stop();

    final shouldCancel = cancel || _noteCancelled || elapsed < _voiceMinMs;
    if (shouldCancel || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    // Файл уже квадратный 480×480 (нативная запись) — шлём как есть.
    await _sendVideoNote(File(path), elapsed);
  }

  Future<void> _sendVideoNote(File file, int durationMs) async {
    if (_myId == 0) {
      try {
        await file.delete();
      } catch (_) {}
      return;
    }
    final tempId = _nextTempId();
    final progress = ValueNotifier<List<double>>(const [0]);
    _photoUploadProgress[tempId] = progress;
    _messages.add(
      CachedMessage(
        id: tempId,
        accountId: _myId,
        chatId: widget.chatId,
        senderId: _myId,
        time: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        attachments: [VideoAttachment(duration: durationMs, videoType: 1)],
      ),
    );
    _lastSentId = tempId;
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();

    try {
      final info = await messagesModule.requestVideoNoteUploadUrl();
      if (info == null || info.url.isEmpty) throw Exception('no_url');
      final ok = await fileUploader.uploadMediaFile(
        Uri.parse(info.url),
        file,
        onProgress: (sent, total) {
          if (total > 0) progress.value = [(sent / total).clamp(0.0, 1.0)];
        },
      );
      if (!ok) throw Exception('upload_failed');
      if (!mounted) {
        _disposePhotoProgress(tempId);
        return;
      }
      final serverMsg = await messagesModule.sendVideoNoteMessage(
        widget.chatId,
        info.token,
        duration: durationMs,
      );
      if (!mounted) {
        _disposePhotoProgress(tempId);
        return;
      }
      if (serverMsg == null) throw Exception('send_failed');
      final real = CachedMessage.fromPushPayload(_myId, widget.chatId, serverMsg);
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        _messages[idx] = real;
        _bumpMessages();
        unawaited(_persistOutgoing(real, removeId: tempId));
      }
      _disposePhotoProgress(tempId);
    } catch (_) {
      if (mounted) {
        _failPhotoMessage(tempId);
      } else {
        _disposePhotoProgress(tempId);
      }
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  OverlayEntry? _noteOverlay;

  void _showNoteOverlay() {
    _noteOverlay?.remove();
    _noteOverlay = OverlayEntry(
      builder: (context) {
        final texId = _noteTextureId.value;
        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: texId != null
                          ? Texture(textureId: texId)
                          : Container(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<int>(
                    valueListenable: _noteElapsedMs,
                    builder: (context, ms, _) => Text(
                      _formatVoiceElapsed(ms),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: _noteCancelDrag,
                    builder: (context, drag, _) => Opacity(
                      opacity: (0.5 + drag * 0.5).clamp(0.0, 1.0),
                      child: const Text(
                        '‹ влево — отмена',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    final overlay = Overlay.of(context, rootOverlay: true);
    overlay.insert(_noteOverlay!);
  }

  void _hideNoteOverlay() {
    _noteOverlay?.remove();
    _noteOverlay = null;
  }

  String _formatVoiceElapsed(int ms) {
    final totalSec = ms ~/ 1000;
    final m = (totalSec ~/ 60).toString();
    final s = (totalSec % 60).toString().padLeft(2, '0');
    final ds = ((ms % 1000) ~/ 100).toString();
    return '$m:$s,$ds';
  }

  Widget _recordingButtonVisual({
    required Widget pill,
    required ColorScheme cs,
    required bool active,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: active ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, a, _) {
        if (a <= 0.001) return pill;
        return ValueListenableBuilder<double>(
          valueListenable: _voiceAmplitude,
          builder: (context, amp, _) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: amp),
            duration: const Duration(milliseconds: 110),
            builder: (context, v, _) {
              final glow = a * (88.0 + v * 76.0);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 27 - glow / 2,
                    top: 27 - glow / 2,
                    child: Container(
                      width: glow,
                      height: glow,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.error.withValues(alpha: a * (0.16 + v * 0.12)),
                      ),
                    ),
                  ),
                  _voiceLockChip(cs),
                  Transform.scale(
                    scale: 1.0 + a * 0.14 + a * v * 0.24,
                    child: pill,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _voiceLockChip(ColorScheme cs) {
    return Positioned(
      bottom: 62,
      child: ValueListenableBuilder<double>(
        valueListenable: _voiceLockDrag,
        builder: (context, lock, _) => Opacity(
          opacity: (0.5 + lock * 0.5).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, lock * 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.surfaceContainerHighest.withValues(alpha: 0.96),
                  cs.surface,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.lock,
                    size: 16,
                    color: lock > 0.6 ? cs.primary : cs.onSurfaceVariant,
                  ),
                  Icon(
                    Symbols.keyboard_arrow_up,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRecordingIndicator(ColorScheme cs) {
    return Container(
      color: Color.alphaBlend(
        cs.surfaceContainerHighest.withValues(alpha: 0.92),
        cs.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _voiceAmplitude,
            builder: (context, amp, child) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: amp),
              duration: const Duration(milliseconds: 120),
              builder: (context, v, child) => Transform.scale(
                scale: 1.0 + v * 0.7,
                child: child,
              ),
              child: child,
            ),
            child: _RecordingDot(color: cs.error),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<int>(
            valueListenable: _voiceElapsedMs,
            builder: (context, ms, _) => Text(
              _formatVoiceElapsed(ms),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: _voiceCancelDrag,
              builder: (context, drag, _) {
                if (drag > 0.01) {
                  return Opacity(
                    opacity: (0.45 + drag * 0.55).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Symbols.arrow_back,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Отмена',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox(
                  height: 26,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _voiceWaveRev,
                    builder: (context, _, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _LiveWavePainter(
                        amps: _voiceAmps,
                        color: cs.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: _voiceLocked,
            builder: (context, locked, _) => locked
                ? GestureDetector(
                    onTap: () => _stopVoiceRecording(cancel: true),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Symbols.delete, size: 22, color: cs.error),
                    ),
                  )
                : Text(
                    '‹ влево — отмена',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mutedIcon = cs.onSurfaceVariant.withValues(alpha: 0.85);

    if (widget.chatType == "CHANNEL") {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: GlossyPill(
            onTap: () {},
            color: Color.alphaBlend(
              cs.surfaceContainerHighest.withValues(alpha: 0.92),
              cs.surface,
            ),
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.symmetric(vertical: 16),
            depth: 8,
            borderSide: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  'Отключить уведомления',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReplyPreview(cs),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(
                  minHeight: 54,
                  maxHeight: 180,
                ),
                child: GlossyPill(
                  color: Color.alphaBlend(
                    cs.surfaceContainerHighest.withValues(alpha: 0.92),
                    cs.surface,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  depth: 8,
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                  child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _attachAnim,
                      builder: (context, child) {
                        final t = _attachAnim.value;
                        return IgnorePointer(
                          ignoring: t > 0.5,
                          child: Opacity(
                            opacity: (1 - t).clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Symbols.face,
                              color: mutedIcon,
                              size: 24,
                              weight: 400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey ==
                                          LogicalKeyboardKey.enter &&
                                      !HardwareKeyboard
                                          .instance
                                          .isShiftPressed) {
                                    if (_hasText.value) _sendMessage();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _messageFocusNode,
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                  ),
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: 'Message',
                                    hintStyle: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _AttachButton(
                              hasText: _hasText,
                              onOpen: _openAttachmentSheet,
                              onLongOpen: _openAttachmentSheetScheduled,
                              uploadStatus: _uploadStatus,
                              mutedIcon: mutedIcon,
                              cs: cs,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        height: 54,
                        child: AnimatedBuilder(
                          animation: _attachAnim,
                          builder: (context, child) {
                            final t = _attachAnim.value;
                            return IgnorePointer(
                              ignoring: t < 0.5,
                              child: Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: _HistoryStrip(
                            anim: _attachAnim,
                            cs: cs,
                            onTapEntry: _sendHistoryFile,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isRecordingVoice,
                        builder: (context, recording, _) => IgnorePointer(
                          ignoring: !recording,
                          child: AnimatedSlide(
                            offset: recording
                                ? Offset.zero
                                : const Offset(0.06, 0),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: AnimatedOpacity(
                              opacity: recording ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              child: _buildVoiceRecordingIndicator(cs),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _attachAnim,
              builder: (context, child) {
                final t = _attachAnim.value;
                return ClipRect(
                  clipper: _ButtonClipper(t),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: (1 - t).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _attachAnim,
                    builder: (context, child) {
                      final t = _attachAnim.value;
                      return Transform.translate(
                        offset: Offset(t * 80, 0),
                        child: Opacity(
                          opacity: (1 - t * 1.5).clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _hasText,
                      builder: (context, hasText, _) =>
                          ValueListenableBuilder<bool>(
                            valueListenable: _voiceLocked,
                            builder: (context, locked, _) =>
                                ValueListenableBuilder<bool>(
                                  valueListenable: _isRecordingVoice,
                                  builder: (context, recording, _) =>
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _videoNoteMode,
                                        builder: (context, videoMode, _) {
                                          final sendMode = hasText || locked;
                                          final pill = GlossyPill(
                                            color: sendMode
                                                ? cs.primary
                                                : recording
                                                ? cs.error
                                                : cs.surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(27),
                                            onTap: hasText
                                                ? _sendMessage
                                                : locked
                                                ? () => _stopVoiceRecording(
                                                    cancel: false,
                                                  )
                                                : null,
                                            onLongPress: hasText
                                                ? _scheduleMessage
                                                : null,
                                            depth: 8,
                                            child: SizedBox(
                                              width: 54,
                                              height: 54,
                                              child: Center(
                                                child: Icon(
                                                  sendMode
                                                      ? Symbols.send
                                                      : videoMode
                                                      ? Symbols.videocam
                                                      : Symbols.mic,
                                                  color: sendMode
                                                      ? cs.onPrimary
                                                      : recording
                                                      ? cs.onError
                                                      : cs.onSurface,
                                                  size: 24,
                                                  weight: 400,
                                                ),
                                              ),
                                            ),
                                          );
                                          final visual = _recordingButtonVisual(
                                            pill: pill,
                                            cs: cs,
                                            active: recording && !locked,
                                          );
                                          return GestureDetector(
                                            onTap: sendMode
                                                ? null
                                                : _toggleComposerMode,
                                            onLongPressStart: sendMode
                                                ? null
                                                : (_) => videoMode
                                                      ? _startNoteRecording()
                                                      : _startVoiceRecording(),
                                            onLongPressMoveUpdate: sendMode
                                                ? null
                                                : (d) => videoMode
                                                      ? _handleNoteDrag(
                                                          d.offsetFromOrigin,
                                                        )
                                                      : _handleVoiceDrag(
                                                          d.offsetFromOrigin,
                                                        ),
                                            onLongPressEnd: sendMode
                                                ? null
                                                : (_) => videoMode
                                                      ? _handleNoteEnd()
                                                      : _handleVoiceEnd(),
                                            child: visual,
                                          );
                                        },
                                      ),
                                ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(ColorScheme cs) {
    return ValueListenableBuilder<CachedMessage?>(
      valueListenable: _replyTo,
      builder: (context, reply, _) {
        if (reply == null) return const SizedBox.shrink();
        final name = reply.senderId == _myId
            ? 'Вы'
            : (ContactCache.get(reply.senderId) ?? 'Сообщение');
        final info = ReplyInfo(
          senderId: reply.senderId,
          text: reply.text,
          attachments: reply.attachments,
        );
        final preview = info.previewText();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
          child: Row(
            children: [
              Icon(Symbols.reply, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Container(width: 2, height: 34, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ответ $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Symbols.close, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: _cancelReply,
              ),
            ],
          ),
        );
      },
    );
  }

  String _addOptimisticFileMessage(FileAttachment attachment) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final tempId = _nextTempId();
    final msg = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: [attachment],
    );
    _lastSentId = tempId;
    _messages.add(msg);
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();
    return tempId;
  }

  void _updateFileMessageStatus(
    String tempId,
    String status, {
    FileAttachment? attachment,
  }) {
    if (!mounted) return;
    final idx = _messages.indexWhere((m) => m.id == tempId);
    if (idx == -1) return;
    final old = _messages[idx];
    _messages[idx] = CachedMessage(
      id: tempId,
      accountId: old.accountId,
      chatId: old.chatId,
      senderId: old.senderId,
      text: old.text,
      time: old.time,
      status: status,
      payload: old.payload,
      attachments: attachment != null ? [attachment] : old.attachments,
    );
    _bumpMessages();
  }

  Future<void> _sendHistoryFile(FileHistoryEntry entry) async {
    final tempId = _addOptimisticFileMessage(
      FileAttachment(
        fileId: entry.fileId,
        fileToken: entry.token,
        name: entry.filename,
        size: entry.size,
      ),
    );
    _showAttachmentPanel.value = false;
    try {
      final ok = await messagesModule.sendFileMessage(
        widget.chatId,
        entry.fileId,
        token: entry.token,
      );
      _updateFileMessageStatus(tempId, ok ? 'sent' : 'error');
    } catch (_) {
      _updateFileMessageStatus(tempId, 'error');
    }
  }

  Future<bool> _sendFileById(int fileId) async {
    final tempId = _addOptimisticFileMessage(FileAttachment(fileId: fileId));
    try {
      final ok = await messagesModule.sendFileMessage(widget.chatId, fileId);
      if (!mounted) return ok;
      if (ok) {
        FileHistoryCache.add(
          FileHistoryEntry(fileId: fileId, sentAt: DateTime.now()),
        );
        _updateFileMessageStatus(tempId, 'sent');
        _showAttachmentPanel.value = false;
      } else {
        _updateFileMessageStatus(tempId, 'error');
        showCustomNotification(context, 'Ошибка отправки');
      }
      return ok;
    } catch (e) {
      _updateFileMessageStatus(tempId, 'error');
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
      return false;
    }
  }

  Future<void> _openAttachmentSheetScheduled() async {
    final when = await _pickScheduleTime();
    if (when == null || !mounted) return;
    await _openAttachmentSheet(scheduledTime: when.millisecondsSinceEpoch);
  }

  Future<void> _openAttachmentSheet({int? scheduledTime}) async {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hadKeyboard = keyboard > 0;
    if (hadKeyboard) {
      setState(() => _keyboardReserve = keyboard);
      FocusManager.instance.primaryFocus?.unfocus();
    }
    await showAttachmentSheet(
      context,
      title: widget.name,
      onSend: scheduledTime == null
          ? _sendPhotos
          : (picked, caption) =>
                _sendScheduledPhotos(picked, caption, scheduledTime),
      onPickFile: scheduledTime == null
          ? _pickAndUploadFile
          : () => _pickAndUploadFile(scheduledTime: scheduledTime),
      onShareLocation: _shareLocation,
      onCreatePoll: _createPoll,
    );
    if (!mounted || !hadKeyboard) return;
    _messageFocusNode.requestFocus();
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _keyboardReserve = 0);
  }

  Future<void> _sendPhotos(List<PickedPhoto> picked, String caption) async {
    if (_myId == 0) return;
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await _sendVideo(videos[i], cap);
    }
    if (photos.isEmpty) return;

    final files = <File>[];
    final attachments = <PhotoAttachment>[];
    for (final photo in photos) {
      final edited = photo.editedFile;
      final file =
          edited ?? photo.item.localFile ?? await photo.item.originFile();
      if (file == null) continue;
      final dim = edited != null
          ? await imageFileDimensions(edited)
          : await photo.item.dimensions();
      files.add(file);
      attachments.add(
        PhotoAttachment(localPath: file.path, width: dim?.$1, height: dim?.$2),
      );
    }
    if (files.isEmpty || !mounted) return;

    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final progress = ValueNotifier<List<double>>(
      List<double>.filled(files.length, 0),
    );
    _photoUploadProgress[tempId] = progress;

    _messages.add(
      CachedMessage(
        id: tempId,
        accountId: _myId,
        chatId: widget.chatId,
        senderId: _myId,
        text: caption.isEmpty ? null : caption,
        time: now,
        status: 'sending',
        attachments: attachments,
      ),
    );
    _lastSentId = tempId;
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();

    try {
      final tokens = await Future.wait(
        List.generate(
          files.length,
          (i) => _uploadOnePhoto(files[i], i, progress),
        ),
      );
      if (!mounted) {
        _disposePhotoProgress(tempId);
        return;
      }
      if (tokens.any((t) => t == null)) {
        _failPhotoMessage(tempId);
        return;
      }

      progress.value = List<double>.filled(files.length, 1);

      final serverMsg = await messagesModule.sendPhotoMessage(
        widget.chatId,
        tokens.cast<String>(),
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) {
        _disposePhotoProgress(tempId);
        return;
      }
      if (serverMsg == null) {
        _failPhotoMessage(tempId);
        return;
      }

      final real = CachedMessage.fromPushPayload(
        _myId,
        widget.chatId,
        serverMsg,
      );
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        _messages[idx] = real;
        _bumpMessages();
        unawaited(_persistOutgoing(real));
      }
      _disposePhotoProgress(tempId);
    } catch (e) {
      if (mounted) {
        _failPhotoMessage(tempId);
      } else {
        _disposePhotoProgress(tempId);
      }
    }
  }

  Future<void> _sendVideo(
    PickedPhoto video,
    String caption, {
    int? scheduledTime,
  }) async {
    if (_myId == 0) return;
    final file =
        video.editedFile ??
        video.item.localFile ??
        await video.item.originFile();
    if (file == null || !mounted) return;

    final scheduled = scheduledTime != null;
    final durationMs = video.item.duration?.inMilliseconds;

    String? tempId;
    ValueNotifier<List<double>>? progress;
    if (scheduled) {
      showCustomNotification(context, 'Загрузка…');
    } else {
      tempId = _nextTempId();
      progress = ValueNotifier<List<double>>(const [0]);
      _photoUploadProgress[tempId] = progress;
      _messages.add(
        CachedMessage(
          id: tempId,
          accountId: _myId,
          chatId: widget.chatId,
          senderId: _myId,
          text: caption.isEmpty ? null : caption,
          time: DateTime.now().millisecondsSinceEpoch,
          status: 'sending',
          attachments: [VideoAttachment(duration: durationMs)],
        ),
      );
      _lastSentId = tempId;
      _bumpMessages();
      Haptics.send();
      _scrollToBottom();
    }

    final progressNotifier = progress;
    try {
      final info = await messagesModule.requestVideoUploadUrl();
      if (info == null || info.url.isEmpty) throw Exception('no_url');

      final ok = await fileUploader.uploadVideoFile(
        Uri.parse(info.url),
        file,
        onProgress: progressNotifier == null
            ? null
            : (sent, total) {
                if (total > 0) {
                  progressNotifier.value = [(sent / total).clamp(0.0, 1.0)];
                }
              },
      );
      if (!ok) throw Exception('upload_failed');
      if (!mounted) {
        if (tempId != null) _disposePhotoProgress(tempId);
        return;
      }

      final serverMsg = await messagesModule.sendVideoMessage(
        widget.chatId,
        info.token,
        caption: caption.isEmpty ? null : caption,
        scheduledTime: scheduledTime,
      );
      if (!mounted) {
        if (tempId != null) _disposePhotoProgress(tempId);
        return;
      }
      if (serverMsg == null) throw Exception('send_failed');

      if (scheduled) {
        Haptics.send();
        _markHasScheduled();
        showCustomNotification(
          context,
          'Запланировано на '
          '${formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(scheduledTime))}',
        );
      } else {
        final real = CachedMessage.fromPushPayload(
          _myId,
          widget.chatId,
          serverMsg,
        );
        final idx = _messages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _messages[idx] = real;
          _bumpMessages();
          unawaited(_persistOutgoing(real, removeId: tempId));
        }
        _disposePhotoProgress(tempId!);
      }
    } catch (_) {
      if (!mounted) {
        if (tempId != null) _disposePhotoProgress(tempId);
        return;
      }
      if (scheduled) {
        Haptics.error();
        showCustomNotification(context, 'Не удалось запланировать видео');
      } else {
        _failPhotoMessage(tempId!);
      }
    }
  }

  Future<void> _sendScheduledPhotos(
    List<PickedPhoto> picked,
    String caption,
    int scheduledTime,
  ) async {
    if (_myId == 0) return;
    final videos = picked.where((ph) => ph.item.isVideo).toList();
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty && videos.isEmpty) return;

    for (var i = 0; i < videos.length; i++) {
      final cap = (photos.isEmpty && i == 0) ? caption : '';
      await _sendVideo(videos[i], cap, scheduledTime: scheduledTime);
    }
    if (photos.isEmpty) return;

    final files = <File>[];
    for (final photo in photos) {
      final edited = photo.editedFile;
      final file =
          edited ?? photo.item.localFile ?? await photo.item.originFile();
      if (file != null) files.add(file);
    }
    if (files.isEmpty || !mounted) return;

    showCustomNotification(context, 'Загрузка…');
    final progress = ValueNotifier<List<double>>(
      List<double>.filled(files.length, 0),
    );
    try {
      final tokens = await Future.wait(
        List.generate(
          files.length,
          (i) => _uploadOnePhoto(files[i], i, progress),
        ),
      );
      if (!mounted) return;
      if (tokens.any((t) => t == null)) {
        showCustomNotification(context, 'Не удалось загрузить фото');
        return;
      }

      final result = await messagesModule.sendPhotoMessage(
        widget.chatId,
        tokens.cast<String>(),
        caption: caption.isEmpty ? null : caption,
        scheduledTime: scheduledTime,
      );
      if (!mounted) return;
      if (result != null) {
        Haptics.send();
        _markHasScheduled();
        showCustomNotification(
          context,
          'Запланировано на '
          '${formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(scheduledTime))}',
        );
      } else {
        showCustomNotification(context, 'Не удалось запланировать');
      }
    } catch (_) {
      if (mounted) {
        Haptics.error();
        showCustomNotification(context, 'Ошибка при загрузке');
      }
    } finally {
      progress.dispose();
    }
  }

  Future<void> _sendAttachMessage(
    List<MessageAttachment> optimistic,
    Future<Map<String, dynamic>?> Function() send,
  ) async {
    if (_myId == 0) return;
    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;

    final tempMessage = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      time: now,
      status: 'sending',
      attachments: optimistic,
    );
    _messages.add(tempMessage);
    _lastSentId = tempId;
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();

    try {
      final serverMsg = await send();
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx == -1) return;
      if (serverMsg == null) {
        _updateFileMessageStatus(tempId, 'error');
        showCustomNotification(context, 'Ошибка отправки');
        return;
      }
      final real = CachedMessage.fromPushPayload(_myId, widget.chatId, serverMsg);
      _messages[idx] = real;
      _bumpMessages();
      unawaited(_persistOutgoing(real, removeId: tempId));
    } catch (e) {
      if (!mounted) return;
      _updateFileMessageStatus(tempId, 'error');
      showCustomNotification(context, 'Ошибка: $e');
    }
  }

  Future<void> _shareLocation() async {
    final position = await _resolveCurrentPosition();
    if (position == null || !mounted) return;
    final lat = position.latitude;
    final lon = position.longitude;
    await _sendAttachMessage(
      [LocationAttachment(latitude: lat, longitude: lon, zoom: 15)],
      () => messagesModule.sendLocationMessage(widget.chatId, lat, lon),
    );
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showCustomNotification(context, 'Включите геолокацию');
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) showCustomNotification(context, 'Нет доступа к геолокации');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Не удалось получить геопозицию');
      return null;
    }
  }

  Future<void> _createPoll() async {
    final draft = await showCreatePollSheet(context);
    if (draft == null || !mounted) return;
    await _sendAttachMessage(
      [PollAttachment(pollId: 0, title: draft.title)],
      () => messagesModule.sendPollMessage(
        widget.chatId,
        draft.title,
        draft.answers,
        multiple: draft.multiple,
        anonymous: draft.anonymous,
      ),
    );
  }

  Future<String?> _uploadOnePhoto(
    File file,
    int index,
    ValueNotifier<List<double>> progress,
  ) async {
    final url = await messagesModule.requestPhotoUploadUrl();
    if (url == null || url.isEmpty) return null;
    return fileUploader.uploadPhoto(
      Uri.parse(url),
      file,
      filename: _photoFilename(file),
      onProgress: (sent, total) {
        if (total <= 0) return;
        final next = List<double>.from(progress.value);
        if (index < next.length) {
          next[index] = (sent / total).clamp(0.0, 1.0);
          progress.value = next;
        }
      },
    );
  }

  String _photoFilename(File file) {
    final segments = file.uri.pathSegments;
    final name = segments.isNotEmpty ? segments.last : '';
    return name.isNotEmpty ? name : 'photo.jpg';
  }

  void _failPhotoMessage(String tempId) {
    final idx = _messages.indexWhere((m) => m.id == tempId);
    if (idx != -1) {
      final old = _messages[idx];
      _messages[idx] = CachedMessage(
        id: old.id,
        accountId: old.accountId,
        chatId: old.chatId,
        senderId: old.senderId,
        text: old.text,
        time: old.time,
        status: 'error',
        attachments: old.attachments,
      );
      _bumpMessages();
    }
    _disposePhotoProgress(tempId);
    Haptics.error();
  }

  void _disposePhotoProgress(String tempId) {
    _photoUploadProgress.remove(tempId)?.dispose();
  }

  Future<void> _pickAndUploadFile({int? scheduledTime}) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    _showAttachmentPanel.value = false;
    _uploadStatus.value = _UploadStatus(active: true, total: file.size);

    final scheduled = scheduledTime != null;
    final tempId = scheduled
        ? null
        : _addOptimisticFileMessage(
            FileAttachment(name: file.name, size: file.size),
          );

    UploadNotificationService.start(file.name);

    var notifLastSent = 0;
    var notifLastMs = DateTime.now().millisecondsSinceEpoch;
    var notifSpeedBps = 0;
    var notifLastPercent = -1;

    void stopNotif() => UploadNotificationService.stop();

    _uploadSub?.cancel();
    _uploadSub = fileUploader
        .upload(
          chatId: widget.chatId,
          file: File(file.path!),
          filename: file.name,
          totalSize: file.size,
          scheduledTime: scheduledTime,
        )
        .listen(
          (event) {
            if (!mounted) return;
            switch (event) {
              case UploadProgress(:final sent, :final total):
                _uploadStatus.value = _UploadStatus(
                  active: true,
                  sent: sent,
                  total: total,
                );
                final nowMs = DateTime.now().millisecondsSinceEpoch;
                final elapsed = nowMs - notifLastMs;
                if (elapsed >= 500) {
                  notifSpeedBps = ((sent - notifLastSent) * 1000 / elapsed)
                      .round();
                  notifLastSent = sent;
                  notifLastMs = nowMs;
                }
                final percent = total > 0 ? (sent * 100 ~/ total) : 0;
                if (percent != notifLastPercent) {
                  notifLastPercent = percent;
                  UploadNotificationService.update(
                    filename: file.name,
                    progressPercent: percent,
                    speedBps: notifSpeedBps,
                  );
                }
              case UploadDone(:final fileId, :final token, :final url):
                stopNotif();
                FileHistoryCache.add(
                  FileHistoryEntry(
                    fileId: fileId,
                    url: url,
                    token: token,
                    filename: file.name,
                    size: file.size,
                    sentAt: DateTime.now(),
                  ),
                );
                if (scheduled) {
                  Haptics.send();
                  showCustomNotification(
                    context,
                    'Запланировано на '
                    '${formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(scheduledTime))}',
                  );
                } else {
                  _updateFileMessageStatus(
                    tempId!,
                    'sent',
                    attachment: FileAttachment(
                      fileId: fileId,
                      fileToken: token,
                      name: file.name,
                      size: file.size,
                    ),
                  );
                }
              case UploadError(:final message):
                stopNotif();
                showCustomNotification(context, 'Ошибка: $message');
                if (tempId != null) _updateFileMessageStatus(tempId, 'error');
            }
          },
          onDone: () {
            if (!mounted) return;
            stopNotif();
            if (tempId != null) {
              final inFlight = _messages.firstWhere(
                (m) => m.id == tempId,
                orElse: () => CachedMessage(
                  id: '',
                  accountId: 0,
                  chatId: 0,
                  senderId: 0,
                  time: 0,
                ),
              );
              if (inFlight.id == tempId && inFlight.status == 'sending') {
                _updateFileMessageStatus(tempId, 'error');
              }
            }
            _uploadStatus.value = const _UploadStatus();
            _uploadSub = null;
          },
          onError: (Object e) {
            if (!mounted) return;
            stopNotif();
            showCustomNotification(context, 'Ошибка: $e');
            if (tempId != null) _updateFileMessageStatus(tempId, 'error');
            _uploadStatus.value = const _UploadStatus();
            _uploadSub = null;
          },
        );
  }
}

class _AttachButton extends StatelessWidget {
  final ValueNotifier<bool> hasText;
  final VoidCallback onOpen;
  final VoidCallback onLongOpen;
  final ValueNotifier<_UploadStatus> uploadStatus;
  final Color mutedIcon;
  final ColorScheme cs;

  const _AttachButton({
    required this.hasText,
    required this.onOpen,
    required this.onLongOpen,
    required this.uploadStatus,
    required this.mutedIcon,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hasText, uploadStatus]),
      builder: (context, _) {
        final isText = hasText.value;
        final status = uploadStatus.value;
        final iconColor = status.awaitingResponse
            ? cs.primary
            : (status.active
                  ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                  : mutedIcon);
        final disabled = isText || status.active;
        final onTap = disabled ? null : onOpen;
        final onLongPress = disabled ? null : onLongOpen;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isText ? 0 : 36,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isText ? 0 : 1,
            child: isText
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (status.active)
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: status.progressValue,
                                color: cs.primary,
                              ),
                            ),
                          Icon(
                            Symbols.attachment,
                            color: iconColor,
                            size: 22,
                            weight: 400,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  final Animation<double> anim;
  final ColorScheme cs;
  final Future<void> Function(FileHistoryEntry entry) onTapEntry;

  const _HistoryStrip({
    required this.anim,
    required this.cs,
    required this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<FileHistoryEntry>>(
      valueListenable: FileHistoryCache.notifier,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return Center(
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                final v = anim.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: v,
                  child: Text(
                    'история пуста...',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                );
              },
            ),
          );
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: history.length,
          itemBuilder: (ctx, idx) {
            final e = history[idx];
            final startInterval = (idx * 0.05).clamp(0.0, 0.45);
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final raw = ((anim.value - startInterval) / 0.45).clamp(
                  0.0,
                  1.0,
                );
                final v = Curves.easeOutCubic.transform(raw);
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(-14 * (1 - v), 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 54,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTapEntry(e),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForFilename(e.filename),
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                _labelForEntry(e),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => FileHistoryCache.remove(e.fileId),
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Symbols.close,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _labelForEntry(FileHistoryEntry e) {
  final n = e.filename;
  if (n == null || n.isEmpty) return e.fileId.toString();
  final lastDot = n.lastIndexOf('.');
  return lastDot > 0 ? n.substring(0, lastDot) : n;
}

IconData _iconForFilename(String? name) {
  if (name == null || !name.contains('.')) return Symbols.description;
  final ext = name.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'bmp':
    case 'heic':
    case 'heif':
      return Symbols.image;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
    case 'webm':
    case '3gp':
      return Symbols.movie;
    case 'mp3':
    case 'wav':
    case 'ogg':
    case 'flac':
    case 'm4a':
    case 'aac':
      return Symbols.audio_file;
    case 'pdf':
      return Symbols.picture_as_pdf;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return Symbols.folder_zip;
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
    case 'odt':
    case 'md':
      return Symbols.article;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Symbols.table_chart;
    case 'ppt':
    case 'pptx':
      return Symbols.slideshow;
    case 'dart':
    case 'js':
    case 'ts':
    case 'py':
    case 'java':
    case 'kt':
    case 'swift':
    case 'cpp':
    case 'c':
    case 'h':
    case 'rs':
    case 'go':
    case 'rb':
    case 'php':
    case 'html':
    case 'css':
    case 'json':
    case 'xml':
    case 'yaml':
    case 'yml':
      return Symbols.code;
    default:
      return Symbols.description;
  }
}

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  const _SwipeToReply({
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _maxDrag = 72.0;
  static const double _triggerThreshold = 56.0;

  late final AnimationController _springBack;
  double _dragX = 0.0;
  double _springFrom = 0.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _springBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      final t = Curves.easeOut.transform(_springBack.value);
      setState(() => _dragX = _springFrom * (1 - t));
    });
  }

  @override
  void dispose() {
    _springBack.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_springBack.isAnimating) _springBack.stop();
    var next = _dragX + d.delta.dx;
    if (next > 0) next = 0;
    if (next < -_maxDrag) next = -_maxDrag;
    final wasTriggered = _triggered;
    _triggered = next <= -_triggerThreshold;
    if (_triggered && !wasTriggered) Haptics.medium();
    setState(() => _dragX = next);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_triggered) widget.onReply();
    _triggered = false;
    _springFrom = _dragX;
    _springBack.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = (-_dragX / _triggerThreshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 16,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Symbols.reply, size: 20, color: cs.primary),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragX, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _SelectableMessageRow extends StatefulWidget {
  final Widget child;
  final CachedMessage message;
  final bool isMe;
  final ValueListenable<Set<String>> selectedIds;
  final Animation<double> selectionAnim;
  final bool Function() isSelectionActive;
  final VoidCallback onToggleSelection;
  final VoidCallback onEnterSelection;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onReply;
  final VoidCallback? onForward;

  const _SelectableMessageRow({
    required this.child,
    required this.message,
    required this.isMe,
    required this.selectedIds,
    required this.selectionAnim,
    required this.isSelectionActive,
    required this.onToggleSelection,
    required this.onEnterSelection,
    required this.onDelete,
    this.onEdit,
    this.onReply,
    this.onForward,
  });

  @override
  State<_SelectableMessageRow> createState() => _SelectableMessageRowState();
}

class _SelectableMessageRowState extends State<_SelectableMessageRow> {
  static const double _gutterWidth = 40;

  final GlobalKey _boundaryKey = GlobalKey();
  Offset? _lastTapDown;

  void _openMenu() {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;
    final rawDpr = MediaQuery.of(ctx).devicePixelRatio;
    final dpr = rawDpr > 2.0 ? 2.0 : rawDpr;

    final ui.Image snapshot;
    try {
      snapshot = renderObject.toImageSync(pixelRatio: dpr);
    } catch (_) {
      return;
    }

    Haptics.tap();

    final controller = MessageActionsController();
    showMessageActions(
      context: ctx,
      snapshot: snapshot,
      originRect: rect,
      tapPoint: _lastTapDown ?? rect.center,
      isMe: widget.isMe,
      messageText: widget.message.text,
      controller: controller,
      style: AppMessageActionsStyle.current.value,
      interaction: MessageActionsInteraction.tap,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onDispose: controller.dispose,
    );
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;

    final controller = MessageActionsController();
    showMessageActions(
      context: ctx,
      originRect: rect,
      tapPoint: details.globalPosition,
      isMe: widget.isMe,
      messageText: widget.message.text,
      controller: controller,
      style: MessageActionsStyle.list,
      interaction: MessageActionsInteraction.click,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onDispose: controller.dispose,
    );
  }

  void _handleTap() {
    if (widget.isSelectionActive()) {
      widget.onToggleSelection();
    } else {
      _openMenu();
    }
  }

  void _handleLongPress() {
    if (widget.isSelectionActive()) {
      widget.onToggleSelection();
    } else {
      widget.onEnterSelection();
    }
  }

  Widget _buildCheckCircle(bool selected, ColorScheme cs) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? cs.primary
              : cs.onSurfaceVariant.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Symbols.check, size: 16, weight: 700, color: cs.onPrimary)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isControl) return widget.child;
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.selectionAnim,
      builder: (context, _) {
        final t = Curves.easeOut.transform(
          widget.selectionAnim.value.clamp(0.0, 1.0),
        );
        return ValueListenableBuilder<Set<String>>(
          valueListenable: widget.selectedIds,
          builder: (context, selected, _) {
            final isSelected = selected.contains(widget.message.id);
            final active = selected.isNotEmpty;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _lastTapDown = d.globalPosition,
              onTap: _handleTap,
              onLongPress: _handleLongPress,
              onSecondaryTapDown: active ? null : _onSecondaryTapDown,
              child: ColoredBox(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: IgnorePointer(
                        ignoring: active,
                        child: Padding(
                          padding: EdgeInsets.only(left: _gutterWidth * t),
                          child: widget.child,
                        ),
                      ),
                    ),
                    if (t > 0)
                      Positioned(
                        left: 8,
                        bottom: 10,
                        child: Opacity(
                          opacity: t,
                          child: _buildCheckCircle(isSelected, cs),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DeletingMessageAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const _DeletingMessageAnimation({
    super.key,
    required this.child,
    required this.onComplete,
  });

  @override
  State<_DeletingMessageAnimation> createState() =>
      _DeletingMessageAnimationState();
}

class _DeletingMessageAnimationState extends State<_DeletingMessageAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _collapse;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)),
    );
    _scale = Tween<double>(begin: 1, end: 0.82).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)),
    );
    _collapse = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 1.0, curve: Curves.easeInOut)),
    );
    _ctrl.forward().whenComplete(() {
      if (_fired) return;
      _fired = true;
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _collapse,
      axisAlignment: 0.0,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class _SentMessageAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const _SentMessageAnimation({
    super.key,
    required this.child,
    required this.onComplete,
  });

  @override
  State<_SentMessageAnimation> createState() => _SentMessageAnimationState();
}

class _SentMessageAnimationState extends State<_SentMessageAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(
      begin: 16,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _RollingCount extends StatefulWidget {
  final int count;
  final TextStyle style;

  const _RollingCount({required this.count, required this.style});

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount> {
  late int _count = widget.count;
  bool _increasing = true;

  @override
  void didUpdateWidget(_RollingCount old) {
    super.didUpdateWidget(old);
    if (widget.count != _count) {
      _increasing = widget.count > _count;
      _count = widget.count;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final incoming = (child.key as ValueKey<int>).value == _count;
        final Offset begin;
        if (incoming) {
          begin = _increasing ? const Offset(0, -1) : const Offset(0, 1);
        } else {
          begin = _increasing ? const Offset(0, 1) : const Offset(0, -1);
        }
        return ClipRect(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: begin, end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
        );
      },
      child: Text(
        '${widget.count}',
        key: ValueKey<int>(widget.count),
        style: widget.style,
      ),
    );
  }
}
