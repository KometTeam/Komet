import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chat_preview.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/file_uploader.dart';
import 'package:komet/backend/modules/upload_notification_service.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:komet/frontend/screens/contacts/contact_profile_screen.dart';
import 'package:komet/frontend/screens/chats/chat_list_screen.dart';
import 'package:komet/frontend/screens/chats/poll_create_screen.dart';
import 'package:komet/frontend/widgets/animated_text_swap.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/chat_menu_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../l10n/app_localizations.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../backend/modules/animoji.dart';
import '../../../models/animoji.dart';
import '../../../backend/modules/complaints.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/media/rlottie/rlottie.dart';
import '../calls/call_screen.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/chat_activity_store.dart';
import '../../../core/storage/chat_wallpaper_store.dart';
import '../../../core/storage/draft_store.dart';
import '../../../core/storage/archived_chats_store.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/cache/message_session_cache.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/emoji_keyword_index.dart';
import '../../../core/utils/logger.dart';
import '../../../core/config/app_cache_extent.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/app_message_actions_style.dart';
import '../../../core/config/app_swipe_back_desktop.dart';
import 'chat/chat_prank_controller.dart';
import 'chat/chat_controller.dart';
import 'chat/voice_record_controller.dart';
import 'chat/video_note_controller.dart';
import 'chat/command_panel_controller.dart';
import 'chat/sticker_panel_controller.dart';
import 'chat/chat_search_controller.dart';
import 'chat/message_search_result.dart';
import 'chat/upload_status.dart';
import 'chat/view/search_view.dart';
import 'chat/view/composer_input.dart';
import 'chat/view/sticker_panel_view.dart';
import 'chat/view/command_panel_view.dart';
import 'chat/view/selection_bar.dart';
import 'chat/view/chat_header.dart';
import 'chat/view/shimmer_loading.dart';
import '../../../core/config/app_commands.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/config/app_chat_chrome.dart';
import '../../../core/config/komet_settings.dart';
import '../../../models/attachment.dart';
import '../../../models/sticker.dart';
import '../../commands/command_registry.dart';
import '../../commands/slash_command.dart';
import '../../widgets/rich_message_controller.dart';
import '../../../core/utils/text_format.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_actions_overlay.dart';
import '../../widgets/lottie_image.dart';
import '../../widgets/attachment_panel.dart';
import '../../widgets/attachment/attachment_sheet.dart';
import '../../widgets/sticker_pack_sheet.dart';
import '../../widgets/swipe_to_pop.dart';
import '../../widgets/swipe_route.dart';
import '../../widgets/schedule_time_picker.dart';
import '../../widgets/chat_wallpaper_sheet.dart';
import '../../widgets/chat_wallpaper_view.dart';
import 'scheduled_messages_screen.dart';
import 'chat_wallpaper_preview_screen.dart';

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

class _UnreadSeparatorItem {
  const _UnreadSeparatorItem();
}

class _FrostedPanel extends StatelessWidget {
  final Color tint;
  final Border? border;
  final Widget child;

  const _FrostedPanel({required this.tint, this.border, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(color: tint, border: border),
          child: child,
        ),
      ),
    );
  }
}

class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;

  const _MeasureSize({required this.onHeight, required this.child});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final GlobalKey _key = GlobalKey();
  double _last = -1;

  void _report() {
    if (!mounted) return;
    final height = _key.currentContext?.size?.height;
    if (height == null) return;
    if ((height - _last).abs() > 0.5) {
      _last = height;
      widget.onHeight(height);
    }
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReport();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: SizedBox(key: _key, child: widget.child),
      ),
    );
  }
}

class ForwardRequest {
  final int sourceChatId;
  final List<CachedMessage> optimistic;

  const ForwardRequest({required this.sourceChatId, required this.optimistic});
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool embedded;
  final VoidCallback? onClose;
  final ForwardRequest? forwardRequest;
  final String? initialMessageId;
  final int? initialMessageTime;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.embedded = false,
    this.onClose,
    this.forwardRequest,
    this.initialMessageId,
    this.initialMessageTime,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final RichMessageController _messageController = RichMessageController();
  final FocusNode _messageFocusNode = FocusNode();
  double _keyboardReserve = 0;
  bool _keyboardWasOpen = false;
  bool _keyboardBeforeStickers = false;
  final ScrollController _scrollController = ScrollController();
  bool _userDidScroll = false;
  String? _pinnedMessageId;
  double _pinnedAlignment = 0;
  int? _unreadAnchorTime;
  bool _awaitingPosition = false;
  bool _navigatingToTarget = false;
  bool _initialPositionDone = false;
  bool _positioningInFlight = false;
  bool _initialTargetHandled = false;
  bool _suppressHistoryAutoload = false;
  int _readMarkTime = 0;
  Timer? _readMarkTimer;
  final GlobalKey _listKey = GlobalKey();
  final ValueNotifier<bool> _hasText = ValueNotifier(false);
  bool _isLoading = true;
  final ValueNotifier<bool> _showAttachmentPanel = ValueNotifier(false);
  late final StickerPanelController _stickers;
  final ValueNotifier<UploadStatus> _uploadStatus = ValueNotifier(
    const UploadStatus(),
  );
  StreamSubscription<UploadEvent>? _uploadSub;
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<MessageEvent>? _messageEventSub;
  StreamSubscription<SessionState>? _connSub;
  final Map<String, ValueNotifier<Map<String, dynamic>?>> _reactionNotifiers =
      {};
  final Map<String, ValueNotifier<List<double>>> _photoUploadProgress = {};
  final ValueNotifier<int> _scheduledCount = ValueNotifier(0);

  late final VoiceRecordController _voiceRec = VoiceRecordController(
    contextOf: () => context,
    isMounted: () => mounted,
    myId: () => _myId,
    onRecorded: _sendVoice,
  );

  late final VideoNoteController _note = VideoNoteController(
    contextOf: () => context,
    isMounted: () => mounted,
    onRecorded: _sendVideoNote,
    formatElapsed: formatVoiceElapsed,
  );

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

  void _reactToMessage(CachedMessage message, String emoji) {
    if (message.isControl || message.id.startsWith('temp_')) return;
    final notifier = _reactionNotifierFor(message);
    final previous = notifier.value;
    final applied = _applyLocalReaction(previous, emoji);
    notifier.value = applied;
    final isToggleOff = applied == null || applied['yourReaction'] == null;
    unawaited(_sendReaction(message, emoji, isToggleOff, previous));
  }

  Future<void> _sendReaction(
    CachedMessage message,
    String emoji,
    bool isToggleOff,
    Map<String, dynamic>? previous,
  ) async {
    ({bool ok, Map<String, dynamic>? info}) result;
    try {
      result = isToggleOff
          ? await messagesModule.cancelReaction(widget.chatId, message.id)
          : await messagesModule.setReaction(widget.chatId, message.id, emoji);
    } catch (_) {
      result = (ok: false, info: null);
    }
    if (!mounted) return;
    final notifier = _reactionNotifiers[message.id];
    if (notifier == null) return;
    if (!result.ok) {
      notifier.value = previous;
      Haptics.error();
      showCustomNotification(context, 'Не удалось обновить реакцию');
      return;
    }
    notifier.value = result.info;
    _applyReactionInfoToMessage(message.id, result.info);
  }

  void _applyReactionInfoToMessage(String messageId, Map<String, dynamic>? info) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final payload = <String, dynamic>{...?_messages[idx].payload};
    if (info == null) {
      payload.remove('reactionInfo');
    } else {
      payload['reactionInfo'] = info;
    }
    _messages[idx] = _messages[idx].copyWith(payload: payload);
  }

  Map<String, dynamic>? _applyLocalReaction(
    Map<String, dynamic>? current,
    String emoji,
  ) {
    final counters = <String, int>{};
    final order = <String>[];
    final rawCounters = current?['counters'];
    if (rawCounters is List) {
      for (final c in rawCounters) {
        if (c is! Map) continue;
        final r = c['reaction']?.toString();
        if (r == null || r.isEmpty) continue;
        final n = c['count'];
        counters[r] = n is int ? n : 0;
        order.add(r);
      }
    }

    void decrement(String key) {
      final next = (counters[key] ?? 1) - 1;
      if (next <= 0) {
        counters.remove(key);
        order.remove(key);
      } else {
        counters[key] = next;
      }
    }

    final prev = current?['yourReaction']?.toString();
    String? your;
    if (prev != null &&
        EmojiKeywordIndex.normalize(prev) == EmojiKeywordIndex.normalize(emoji)) {
      decrement(prev);
      your = null;
    } else {
      if (prev != null && prev.isNotEmpty) decrement(prev);
      if (!counters.containsKey(emoji)) order.add(emoji);
      counters[emoji] = (counters[emoji] ?? 0) + 1;
      your = emoji;
    }

    if (counters.isEmpty) return null;
    final total = counters.values.fold<int>(0, (a, b) => a + b);
    return {
      'counters': [
        for (final key in order) {'reaction': key, 'count': counters[key]},
      ],
      'yourReaction': ?your,
      'totalCount': total,
    };
  }

  void _pruneReactionNotifiers() {
    final liveIds = _messages.map((m) => m.id).toSet();
    final dead = _reactionNotifiers.keys
        .where((id) => !liveIds.contains(id))
        .toList();
    for (final id in dead) {
      _reactionNotifiers.remove(id)?.dispose();
    }
    _messageKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  int _otherStatus = 0;
  int? _otherSeenTime;
  int? _participantsCount;

  final ValueNotifier<CachedMessage?> _replyTo = ValueNotifier(null);
  final ValueNotifier<String?> _highlightMessageId = ValueNotifier(null);
  Timer? _highlightTimer;
  final ValueNotifier<double?> _jumpCacheExtent = ValueNotifier<double?>(null);
  Timer? _goToMessageSettleTimer;
  static const double _jumpCacheExtentPx = 800.0;

  late final ChatSearchController _search;
  late final AnimationController _searchAnim;
  final FocusNode _searchFocusNode = FocusNode();

  late final ChatPrankController _prank = ChatPrankController(
    vsync: this,
    contextOf: () => context,
    isMounted: () => mounted,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  final ValueNotifier<String> _headerStatusNotifier = ValueNotifier('');
  final ValueNotifier<int> _otherReadTime = ValueNotifier(0);
  int _tempIdCounter = 0;
  late final AnimationController _attachAnim;
  late final CommandPanelController _commandPanel;

  String _nextTempId() =>
      'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';
  late AnimationController _shimmerController;
  Timer? _shimmerStartTimer;
  bool _previewChat = false;
  bool _forwardRequestDone = false;

  final ChatController _chatController = ChatController();

  List<CachedMessage> get _messages => _chatController.messages;
  set _messages(List<CachedMessage> v) => _chatController.messages = v;
  ValueNotifier<int> get _messagesRev => _chatController.messagesRev;
  bool get _historyKickedOff => _chatController.historyKickedOff;
  set _historyKickedOff(bool v) => _chatController.historyKickedOff = v;

  final GlobalKey _messageListKey = GlobalKey();
  _ChatMessageList? _messageListWidget;
  final Set<String> _deletingIds = {};

  static const double _avgMessageHeight = 72.0;
  static const double _historyPrefetchExtent = _avgMessageHeight * 8;
  static const double _glossyHeaderHeight = 76.0;
  static const double _glossySearchHeight = 58.0;
  bool get _isLoadingMore => _chatController.isLoadingMore;
  set _isLoadingMore(bool v) => _chatController.isLoadingMore = v;
  bool get _hasMoreHistory => _chatController.hasMoreHistory;
  set _hasMoreHistory(bool v) => _chatController.hasMoreHistory = v;
  List<Object>? _combinedItemsCache;
  int? _combinedItemsKey;
  bool _floatingDateScheduled = false;
  int get _myId => _chatController.myId;
  set _myId(int v) => _chatController.myId = v;
  CachedChat? chat;
  bool _peerIsBot = false;
  ChatWallpaper? _wallpaper;

  ChatChromeStyle get _effectiveChrome {
    final chrome = AppChatChrome.current.value;
    if (_wallpaper != null && chrome == ChatChromeStyle.none) {
      return ChatChromeStyle.blur;
    }
    return chrome;
  }

  final ValueNotifier<double> _composerHeight = ValueNotifier(96);
  final ValueNotifier<double> _pinnedBannerHeight = ValueNotifier(0);

  final ValueNotifier<DateTime?> _floatingDate = ValueNotifier(null);
  Timer? _floatingDateTimer;
  late final AnimationController _floatingDateAnimController;
  late final CurvedAnimation _floatingDateCurved;
  final Map<int, GlobalKey> _separatorKeys = {};
  String? _lastSentId;
  final ValueNotifier<int> _otherUnread = ValueNotifier(0);
  final ValueNotifier<bool> _animojiHold = ValueNotifier(true);

  final ValueNotifier<Set<String>> _selectedIds = ValueNotifier(const {});
  late final AnimationController _selectionAnim;

  bool get _selectionMode => _selectedIds.value.isNotEmpty;

  void _prewarmQuickReactions() {
    if (!mounted || !RlottieEngine.instance.available) return;
    final dpr =
        (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0).clamp(1.0, 2.0);
    final px = ((44.0 * dpr).clamp(96.0, 512.0) / 32).ceil() * 32;
    for (final a in animojiModule.quickAnimojis) {
      final url = a.lottieUrl;
      if (url != null && url.isNotEmpty) {
        unawaited(RlottieEngine.instance.prewarm(url, px));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _chatController.chatId = widget.chatId;
    _chatController.isMounted = () => mounted;
    unawaited(PushService.clearChatNotification(widget.chatId));
    unawaited(animojiModule
        .ensureLoaded()
        .then((_) => _prewarmQuickReactions())
        .catchError((_) {}));
    WidgetsBinding.instance.addObserver(this);
    chats.chatsChanged.addListener(_onChatsBump);
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollForDate);
    _scrollController.addListener(_maybeLoadMoreHistory);
    _scrollController.addListener(_recordScrollPixels);
    _scrollController.addListener(_scheduleReadMarker);
    AppVisualStyle.current.addListener(_onVisualStyleChanged);
    AppChatChrome.current.addListener(_onVisualStyleChanged);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _stickers = StickerPanelController(
      vsync: this,
      onSendTyping: () => messagesModule.sendTyping(widget.chatId, 'STICKER'),
    );
    _showAttachmentPanel.addListener(_onAttachPanelToggle);
    _commandPanel = CommandPanelController(
      vsync: this,
      textOf: () => _messageController.text,
      onSelected: _onCommandSelected,
    );
    _selectionAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _searchAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _search = ChatSearchController(
      chatId: widget.chatId,
      isMounted: () => mounted,
    );
    _pushSub = api.pushStream
        .where(
          (p) =>
              p.opcode == Opcode.notifMark ||
              p.opcode == Opcode.notifTyping ||
              p.opcode == Opcode.notifMsgDelayed,
        )
        .listen(_onIncomingPush);
    _messageEventSub = chats.messageEvents
        .where((e) => e.chatId == widget.chatId)
        .listen(_onMessageEvent);
    ChatActivityStore.instance
        .listenable(widget.chatId)
        .addListener(_recomputeHeaderStatus);
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

    unawaited(
      _fastPreloadCache().then((_) {
        if (mounted) unawaited(_runForwardRequest());
      }),
    );
    unawaited(_loadParticipantsCount());
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrameRendered);
  }

  Future<void> _loadParticipantsCount() async {
    if (widget.chatType != 'CHAT' && widget.chatType != 'CHANNEL') return;
    final info = await chats.getChatInfo(api, widget.chatId);
    if (!mounted) return;
    final count = info?['participantsCount'] as int?;
    if (count != null && count != _participantsCount) {
      _participantsCount = count;
      _recomputeHeaderStatus();
    }
  }

  Future<void> _loadPeerKind() async {
    if (widget.chatType != 'DIALOG' || _myId == 0) return;
    final peerId = widget.chatId ^ _myId;
    if (peerId <= 0) return;
    final cached = ContactInfoFetch.peek(peerId);
    if (cached != null) _applyPeerKind(cached.isBot);
    final info = await ContactInfoFetch.get(peerId);
    if (info != null) _applyPeerKind(info.isBot);
  }

  void _applyPeerKind(bool isBot) {
    if (!mounted || _peerIsBot == isBot) return;
    setState(() => _peerIsBot = isBot);
  }

  Future<void> _fastPreloadCache() async {
    final p = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    _myId = p?.id ?? 0;
    if (p != null && p.id != 0) {
      final myName = [
        p.firstName,
        p.lastName,
      ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      if (myName.isNotEmpty) ContactCache.put(p.id, myName);
      ContactCache.putAvatar(p.id, p.baseUrl);
    }
    _restoreDraft();
    unawaited(_loadPeerKind());
    unawaited(_loadWallpaper());
    unawaited(_refreshBadge());

    try {
      final chatRows = await chats.getChat(_myId, widget.chatId);
      if (!mounted) return;
      if (chatRows.isNotEmpty) {
        setState(() {
          chat = chatRows.first;
        });
        _bumpMessages();
        _seedPresenceFromChat();
        _recomputeHeaderStatus();
        _syncOtherReadTime();
      }
    } catch (_) {}

    _resolveUnreadAnchor();

    final cached = MessageSessionCache.get(_myId, widget.chatId);
    if (cached != null && cached.messages.isNotEmpty) {
      setState(() {
        _messages = List<CachedMessage>.of(cached.messages);
        _hasMoreHistory = !cached.reachedStart;
        _messagesRev.value++;
      });
      _syncReactionNotifiersFromMessages();
      _revealOrHoldInitial();
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
      });
      _revealOrHoldInitial();
    }
  }

  void _resolveUnreadAnchor() {
    final c = chat;
    _readMarkTime = c?.participants[_myId] ?? 0;
    if (c == null || c.unreadCount <= 0) {
      _unreadAnchorTime = null;
    } else {
      final myMark = c.participants[_myId] ?? 0;
      _unreadAnchorTime = myMark > 0 ? myMark : null;
    }
    _awaitingPosition = c != null && c.unreadCount > 0;
  }

  void _resolveCountBasedAnchor() {
    final c = chat;
    if (c == null || c.unreadCount <= 0 || _messages.isEmpty) return;
    final unread = c.unreadCount;
    if (_messages.length > unread) {
      _unreadAnchorTime = _messages[_messages.length - unread - 1].time;
    } else if (!_hasMoreHistory) {
      _unreadAnchorTime = _messages.first.time - 1;
    }
  }

  void _revealOrHoldInitial() {
    if (_awaitingPosition && !_canPositionNow()) return;
    setState(() {
      _isLoading = false;
      _onLoadingFinished();
    });
  }

  bool _canPositionNow() {
    if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
    final ua = _unreadAnchorTime;
    if (ua == null) return false;
    final firstUnread = _messages.indexWhere((m) => m.time > ua);
    if (firstUnread == -1) return _newestMessageLoaded();
    return firstUnread > 0 || !_hasMoreHistory;
  }

  bool _newestMessageLoaded() {
    if (_messages.isEmpty) return false;
    final serverLast = chat?.lastMsgTime ?? 0;
    return _messages.last.time >= serverLast;
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
    _animojiHold.value = false;
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
    _applyInitialPositioning();
  }

  void _recordScrollPixels() {
    if (!_scrollController.hasClients) return;
    if (_initialPositionDone &&
        _scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      _userDidScroll = true;
      _pinnedMessageId = null;
    }
  }

  void _positionToMessage(String messageId, double alignment) {
    _pinnedMessageId = messageId;
    _pinnedAlignment = alignment.clamp(0.0, 1.0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToLoadedMessage(
        messageId,
        alignment: _pinnedAlignment,
        highlight: false,
        notifyIfMissing: false,
        onSettled: () {
          if (mounted) setState(_markPositioned);
        },
      );
    });
  }

  void _reapplyPinIfNeeded() {
    final id = _pinnedMessageId;
    if (id == null || _userDidScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pinnedMessageId != id || _userDidScroll) return;
      _alignLoadedMessage(id, _pinnedAlignment, 0);
    });
  }

  void _applyInitialPositioning() {
    if (_initialPositionDone) {
      if (_shimmerController.isAnimating) _shimmerController.stop();
      _scheduleReadMarker();
      return;
    }
    if (_positioningInFlight) return;
    if (_messages.isEmpty) {
      if (!_hasMoreHistory) _markPositioned();
      return;
    }

    final c = chat;
    if (c != null && c.unreadCount > 0) {
      if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
      final ua = _unreadAnchorTime;
      if (ua == null) {
        if (_hasMoreHistory) {
          _positioningInFlight = true;
          unawaited(_loadUntilUnreadReady());
        } else {
          _markPositioned();
        }
        return;
      }
      final firstUnread = _messages.indexWhere((m) => m.time > ua);
      if (firstUnread == -1) {
        _markPositioned();
        return;
      }
      if (firstUnread > 0 || !_hasMoreHistory) {
        _initialPositionDone = true;
        _positionToMessage(_messages[firstUnread].id, 0.15);
      } else {
        _positioningInFlight = true;
        unawaited(_loadUntilUnreadReady());
      }
      return;
    }

    _markPositioned();
  }

  void _markPositioned() {
    _positioningInFlight = false;
    _initialPositionDone = true;
    _awaitingPosition = false;
    _isLoading = false;
    if (_shimmerController.isAnimating) _shimmerController.stop();
    _scheduleReadMarker();
    _maybeRunInitialTarget();
  }

  void _maybeRunInitialTarget() {
    if (_initialTargetHandled || widget.initialMessageId == null) return;
    _initialTargetHandled = true;
    _beginTargetNavigation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_navigateToInitialMessage());
    });
  }

  void _beginTargetNavigation() {
    _navigatingToTarget = true;
    _jumpCacheExtent.value = _jumpCacheExtentPx;
    _goToMessageSettleTimer?.cancel();
    if (!_shimmerController.isAnimating) _shimmerController.repeat();
  }

  void _finishTargetNavigation() {
    _goToMessageSettleTimer?.cancel();
    if (!mounted) {
      _navigatingToTarget = false;
      return;
    }
    if (_navigatingToTarget) {
      setState(() => _navigatingToTarget = false);
    }
    if (_shimmerController.isAnimating) _shimmerController.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpCacheExtent.value = null;
    });
  }

  void _requestGoToMessage(String id, int time) {
    if (!mounted) return;
    setState(_beginTargetNavigation);
    _goToMessageSettleTimer = Timer(const Duration(milliseconds: 340), () {
      if (mounted) unawaited(_runGoToMessage(id, time));
    });
  }

  Future<void> _loadUntilUnreadReady() async {
    var guard = 0;
    while (mounted && guard < 80 && _hasMoreHistory) {
      if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
      final ua = _unreadAnchorTime;
      if (ua != null && _messages.indexWhere((m) => m.time > ua) > 0) break;
      guard++;
      final before = _messages.isEmpty ? 0 : _messages.first.time;
      await _loadMoreHistory();
      if (!mounted) return;
      final after = _messages.isEmpty ? 0 : _messages.first.time;
      if (after == before) break;
    }
    if (!mounted) return;
    if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
    final ua = _unreadAnchorTime;
    final idx = ua == null ? -1 : _messages.indexWhere((m) => m.time > ua);
    _positioningInFlight = false;
    _initialPositionDone = true;
    if (idx >= 0) {
      _positionToMessage(_messages[idx].id, 0.15);
    } else {
      setState(_markPositioned);
    }
  }

  void _scheduleReadMarker() {
    _readMarkTimer?.cancel();
    _readMarkTimer = Timer(
      const Duration(milliseconds: 350),
      _updateReadMarker,
    );
  }

  void _updateReadMarker() {
    if (!mounted || _myId == 0 || _messages.isEmpty) return;
    if (_awaitingPosition || !_initialPositionDone) return;
    if (!_scrollController.hasClients) return;
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox) return;
    final viewportBottom = listBox.size.height;
    if (viewportBottom <= 0) return;

    CachedMessage? candidate;
    int topIndex = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      final ctx = _messageKeys[m.id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      final bottom = top + box.size.height;
      if (bottom <= 0 || top >= viewportBottom) continue;
      candidate ??= m;
      topIndex = i;
    }
    if (candidate == null) return;

    final atBottom = candidate.id == _messages.last.id;

    if (_unreadAnchorTime != null &&
        _unreadSeparatorScrolledPast(
          atBottom,
          topIndex,
          listBox,
          viewportBottom,
        )) {
      _unreadAnchorTime = null;
      _bumpMessages();
    }

    if (candidate.time <= _readMarkTime) return;
    _readMarkTime = candidate.time;
    final remaining = _messages
        .where((m) => m.time > _readMarkTime && m.senderId != _myId)
        .length;
    unawaited(
      chats.markReadUpTo(
        api,
        _myId,
        widget.chatId,
        candidate.id,
        candidate.time,
        remaining: remaining,
      ),
    );
  }

  bool _unreadSeparatorScrolledPast(
    bool atBottom,
    int topIndex,
    RenderBox listBox,
    double viewportBottom,
  ) {
    if (atBottom) return true;
    final ua = _unreadAnchorTime;
    if (ua == null) return false;
    final firstUnread = _messages.indexWhere((m) => m.time > ua);
    if (firstUnread == -1) return true;
    if (topIndex >= 0 && topIndex > firstUnread) return true;
    final box = _messageKeys[_messages[firstUnread].id]?.currentContext
        ?.findRenderObject();
    if (box is RenderBox && box.attached) {
      final top = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (top <= 0) return true;
    }
    return false;
  }

  Future<void> _markMessageUnread(CachedMessage message) async {
    final unread = await chats.markUnread(
      api,
      _myId,
      widget.chatId,
      message.time,
    );
    if (!mounted) return;
    if (unread == null) {
      showCustomNotification(context, 'Не удалось пометить непрочитанным');
      return;
    }
    Navigator.of(context).pop();
  }

  bool _canPinMessage(CachedMessage message) {
    if (message.isControl) return false;
    if (int.tryParse(message.id) == null) return false;
    return chat?.canPinMessages(_myId) ?? false;
  }

  Future<void> _togglePinMessage(CachedMessage message) async {
    final messageId = int.tryParse(message.id);
    if (messageId == null) return;
    final previousChat = chat;
    final willUnpin = chat?.pinnedMsgId == messageId;
    if (willUnpin) {
      _applyPinnedMessageLocally();
    } else {
      final preview = _pinnedPreviewFor(message);
      _applyPinnedMessageLocally(
        messageId: messageId,
        text: preview.text,
        time: message.time,
        isPreview: preview.isPreview,
      );
    }
    final error = await chats.setPinnedMessage(
      api,
      chatId: widget.chatId,
      messageId: willUnpin ? null : messageId,
      notify: !willUnpin,
    );
    if (!mounted) return;
    if (error != null) {
      if (previousChat != null) setState(() => chat = previousChat);
      showCustomNotification(context, error);
      return;
    }
    showCustomNotification(
      context,
      willUnpin ? 'Сообщение откреплено' : 'Сообщение закреплено',
    );
  }

  Future<void> _unpinCurrentMessage() async {
    final previousChat = chat;
    _applyPinnedMessageLocally();
    final error = await chats.setPinnedMessage(
      api,
      chatId: widget.chatId,
      messageId: null,
      notify: false,
    );
    if (!mounted) return;
    if (error != null) {
      if (previousChat != null) setState(() => chat = previousChat);
      showCustomNotification(context, error);
      return;
    }
    showCustomNotification(context, 'Сообщение откреплено');
  }

  ({String? text, bool isPreview}) _pinnedPreviewFor(CachedMessage message) {
    final payload = message.payload;
    if (payload != null) return pinnedMessagePreview(payload);
    return pinnedMessagePreview({
      'text': message.text,
      'attaches':
          message.attachments?.map((a) => a.toMap()).toList() ?? const [],
    });
  }

  void _applyPinnedMessageLocally({
    int? messageId,
    String? text,
    int? time,
    bool isPreview = false,
  }) {
    final current = chat;
    if (current == null) return;
    setState(() {
      chat = current.copyWith(
        pinnedMsgId: messageId,
        pinnedMsgText: text,
        pinnedMsgTime: time,
        pinnedMsgIsPreview: isPreview,
      );
    });
  }

  void _jumpToPinnedMessage() {
    final id = chat?.pinnedMsgId;
    final time = chat?.pinnedMsgTime;
    if (id == null) return;
    unawaited(_openPinnedMessage(id.toString(), time ?? 0));
  }

  Future<void> _openPinnedMessage(String messageId, int time) async {
    if (!_messages.any((m) => m.id == messageId)) {
      var guard = 0;
      while (mounted &&
          guard < 60 &&
          _hasMoreHistory &&
          !_messages.any((m) => m.id == messageId) &&
          (_messages.isEmpty || _messages.first.time > time)) {
        guard++;
        final before = _messages.isEmpty ? 0 : _messages.first.time;
        await _loadMoreHistory();
        if (!mounted) return;
        final after = _messages.isEmpty ? 0 : _messages.first.time;
        if (after == before) break;
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (_messages.any((m) => m.id == messageId)) {
      _scrollToLoadedMessage(messageId);
    } else {
      showCustomNotification(context, 'Сообщение не загружено');
    }
  }

  bool _badgeRefreshing = false;
  bool _badgeRefreshQueued = false;

  void _onChatsBump() {
    unawaited(_reloadChatMeta());
    if (_badgeRefreshing) {
      _badgeRefreshQueued = true;
      return;
    }
    unawaited(_runBadgeRefresh());
  }

  Future<void> _reloadChatMeta() async {
    if (_myId == 0) return;
    final rows = await chats.getChat(_myId, widget.chatId);
    if (!mounted || rows.isEmpty) return;
    final fresh = rows.first;
    final current = chat;
    if (current != null &&
        current.pinnedMsgId == fresh.pinnedMsgId &&
        current.pinnedMsgText == fresh.pinnedMsgText &&
        current.pinnedMsgTime == fresh.pinnedMsgTime &&
        current.pinnedMsgIsPreview == fresh.pinnedMsgIsPreview &&
        current.owner == fresh.owner &&
        current.options.length == fresh.options.length &&
        current.options.containsAll(fresh.options) &&
        current.admins.length == fresh.admins.length &&
        current.admins.containsAll(fresh.admins)) {
      return;
    }
    setState(() => chat = fresh);
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
    final total = await AppDatabase.sumUnread(
      _myId,
      excludeChatId: widget.chatId,
      excludeChatIds: ArchivedChatsStore.instance.archivedChatIds(_myId),
    );
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
    await _chatController.loadRemainingHistory(
      onApplyMerged: _applyMergedMessages,
      onLoadingFinished: () {
        setState(() {
          _isLoading = false;
          _onLoadingFinished();
        });
      },
      onPreview: () => _previewChat = true,
      onSenderNames: () {
        _loadForwardedSenderNames();
        _loadGroupSenderNames();
      },
    );
  }

  void _maybeLoadMoreHistory() {
    if (!_scrollController.hasClients) return;
    if (_suppressHistoryAutoload) return;
    if (_isLoading || _isLoadingMore || !_hasMoreHistory) return;
    if (_messages.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.maxScrollExtent - pos.pixels <= _historyPrefetchExtent) {
      unawaited(_loadMoreHistory());
    }
  }

  Future<void> _loadMoreHistory() async {
    await _chatController.loadMoreHistory(
      onLoadingStarted: _bumpMessages,
      onLoaded: (added) {
        if (added > 0) _syncReactionNotifiersFromMessages();
        _bumpMessages();
        _loadForwardedSenderNames();
        _loadGroupSenderNames();
      },
      onError: (_) {
        if (mounted) {
          _isLoadingMore = false;
          _bumpMessages();
        }
      },
    );
  }

  void _applyMergedMessages(
    List<CachedMessage> decodedDesc, {
    bool markLoaded = false,
  }) {
    final changed = _chatController.mergeMessages(decodedDesc);

    if (!changed && !markLoaded) return;

    setState(() {
      if (markLoaded) {
        _isLoading = false;
        _onLoadingFinished();
      }
    });
    if (changed) {
      _syncReactionNotifiersFromMessages();
      _pruneReactionNotifiers();
      _chatController.persistSessionCache();
      _reapplyPinIfNeeded();
    }
  }

  void _syncReactionNotifiersFromMessages() {
    for (final m in _messages) {
      if (_reactionNotifiers.containsKey(m.id)) continue;
      final info = m.payload?['reactionInfo'];
      _reactionNotifiers[m.id] = ValueNotifier(
        info is Map ? Map<String, dynamic>.from(info) : null,
      );
    }
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
      if (_voiceRec.isRecording.value) {
        unawaited(_voiceRec.stop(cancel: true));
      }
      if (_note.isRecording.value) {
        unawaited(_note.stop(cancel: true));
      }
      _saveDraft();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = View.of(context);
    final keyboardOpen = view.viewInsets.bottom / view.devicePixelRatio > 100;
    if (_keyboardWasOpen && !keyboardOpen && _messageFocusNode.hasFocus) {
      _messageFocusNode.unfocus();
    }
    _keyboardWasOpen = keyboardOpen;
  }

  @override
  void dispose() {
    _chatController.persistSessionCache();
    if (_previewChat) {
      unawaited(chats.subscribeChat(api, widget.chatId, subscribe: false));
    }
    WidgetsBinding.instance.removeObserver(this);
    chats.chatsChanged.removeListener(_onChatsBump);
    _otherUnread.dispose();
    _animojiHold.dispose();
    _saveDraft();
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollForDate);
    _scrollController.removeListener(_maybeLoadMoreHistory);
    _scrollController.removeListener(_recordScrollPixels);
    _scrollController.removeListener(_scheduleReadMarker);
    _readMarkTimer?.cancel();
    AppVisualStyle.current.removeListener(_onVisualStyleChanged);
    AppChatChrome.current.removeListener(_onVisualStyleChanged);
    _composerHeight.dispose();
    _pinnedBannerHeight.dispose();
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
    _voiceRec.dispose();
    _note.dispose();
    debugForceOffline.removeListener(_recomputeHeaderStatus);
    for (final n in _reactionNotifiers.values) {
      n.dispose();
    }
    _reactionNotifiers.clear();
    for (final n in _photoUploadProgress.values) {
      n.dispose();
    }
    _photoUploadProgress.clear();
    ChatActivityStore.instance
        .listenable(widget.chatId)
        .removeListener(_recomputeHeaderStatus);
    PresenceFetch.revision.removeListener(_onPresenceChanged);
    if (_wallpaperListening) {
      ChatWallpaperStore.instance.revision
          .removeListener(_applyEffectiveWallpaper);
    }
    _headerStatusNotifier.dispose();
    _otherReadTime.dispose();
    _chatController.dispose();
    _prank.dispose();
    _uploadStatus.dispose();
    _attachAnim.dispose();
    _commandPanel.dispose();
    _selectionAnim.dispose();
    _searchAnim.dispose();
    _searchFocusNode.dispose();
    _search.dispose();
    _selectedIds.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _stickers.dispose();
    _scrollController.dispose();
    _shimmerStartTimer?.cancel();
    _shimmerController.dispose();
    _replyTo.dispose();
    _highlightTimer?.cancel();
    _highlightMessageId.dispose();
    _goToMessageSettleTimer?.cancel();
    _jumpCacheExtent.dispose();
    _messageKeys.clear();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText.value) {
      _hasText.value = newHasText;
    }
    _commandPanel.update();
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
    _messageController.selection = TextSelection.collapsed(
      offset: draft.length,
    );
  }

  void _saveDraft() {
    if (_myId == 0) return;
    unawaited(
      DraftStore.instance.set(
        _myId,
        widget.chatId,
        _messageController.buildContent().text,
      ),
    );
  }

  void _onAttachPanelToggle() {
    if (_showAttachmentPanel.value) {
      _attachAnim.forward();
    } else {
      _attachAnim.reverse();
    }
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

  String? _effectiveStatus(CachedMessage msg) {
    if (msg.senderId != _myId) return null;
    if (msg.status == 'sending' || msg.status == 'error') return msg.status;
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

    final serverMsgs = msgs.where((m) => !m.id.startsWith('temp_')).toList();
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
    final forwardable = msgs.where((m) => !m.id.startsWith('temp_')).toList();
    if (forwardable.isEmpty) {
      showCustomNotification(context, 'Нечего пересылать');
      return;
    }

    final target = await openForwardScreen(
      context: context,
      messageCount: forwardable.length,
    );
    if (target == null || !mounted) return;

    if (api.state != SessionState.online) {
      showCustomNotification(context, 'Нет соединения');
      return;
    }

    final ordered = [...forwardable]..sort((a, b) => a.time.compareTo(b.time));

    if (target.chatId == widget.chatId) {
      await _forwardIntoCurrentChat(ordered);
      return;
    }

    final optimistic = await _seedForwardsToChat(target, ordered);
    if (!mounted) return;
    Haptics.send();
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: target.chatId,
        name: target.name,
        imageUrl: target.imageUrl,
        chatType: target.chatType,
        forwardRequest: ForwardRequest(
          sourceChatId: widget.chatId,
          optimistic: optimistic,
        ),
      ),
    );
  }

  Future<void> _forwardIntoCurrentChat(List<CachedMessage> sources) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final optimistic = <CachedMessage>[];
    var i = 0;
    for (final src in sources) {
      final msg = MessagesModule.buildForwardMessage(
        myId: _myId,
        targetChatId: widget.chatId,
        sourceChatId: widget.chatId,
        source: src,
        tempId: _nextTempId(),
        time: now + i,
        status: 'sending',
      );
      optimistic.add(msg);
      _messages.add(msg);
      unawaited(_persistOutgoing(msg));
      i++;
    }
    _bumpMessages();
    Haptics.send();
    _scrollToBottom();
    if (optimistic.isNotEmpty) {
      final last = optimistic.last;
      unawaited(
        chats.applyOutgoing(
          _myId,
          widget.chatId,
          messageId: last.id,
          time: last.time,
          text: MessagesModule.forwardPreviewText(last),
          status: 'sending',
        ),
      );
    }
    for (final opt in optimistic) {
      await _sendOneForward(opt, widget.chatId);
    }
  }

  Future<List<CachedMessage>> _seedForwardsToChat(
    ForwardTarget target,
    List<CachedMessage> sources,
  ) async {
    await chats.ensureChatCached(api, _myId, target.chatId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final optimistic = <CachedMessage>[];
    var i = 0;
    for (final src in sources) {
      final msg = MessagesModule.buildForwardMessage(
        myId: _myId,
        targetChatId: target.chatId,
        sourceChatId: widget.chatId,
        source: src,
        tempId: _nextTempId(),
        time: now + i,
        status: 'sending',
      );
      optimistic.add(msg);
      await AppDatabase.saveMessages([msg.toDbRow()]);
      i++;
    }
    final cached = MessageSessionCache.get(_myId, target.chatId);
    if (cached != null) {
      MessageSessionCache.save(_myId, target.chatId, [
        ...cached.messages,
        ...optimistic,
      ], reachedStart: cached.reachedStart);
    }
    if (optimistic.isNotEmpty) {
      final last = optimistic.last;
      unawaited(
        chats.applyOutgoing(
          _myId,
          target.chatId,
          messageId: last.id,
          time: last.time,
          text: MessagesModule.forwardPreviewText(last),
          status: 'sending',
        ),
      );
    }
    return optimistic;
  }

  Future<void> _runForwardRequest() async {
    final req = widget.forwardRequest;
    if (req == null || _forwardRequestDone) return;
    _forwardRequestDone = true;
    for (final opt in req.optimistic) {
      await _sendOneForward(opt, req.sourceChatId);
    }
  }

  Future<void> _sendOneForward(
    CachedMessage optimistic,
    int sourceChatId,
  ) async {
    final link = optimistic.payload?['link'];
    final rawWireId = link is Map ? link['messageId'] : null;
    final wireId = rawWireId is int ? rawWireId : null;
    if (wireId == null) return;
    try {
      final realId = await messagesModule.forwardMessage(
        widget.chatId,
        sourceChatId,
        wireId,
      );
      if (!mounted) return;
      final sent = MessagesModule.reidentifyMessage(
        optimistic,
        realId.isNotEmpty ? realId : optimistic.id,
        status: 'sent',
      );
      final index = _messages.indexWhere((m) => m.id == optimistic.id);
      if (index != -1) {
        _messages[index] = sent;
        _bumpMessages();
      }
      unawaited(_persistOutgoing(sent, removeId: optimistic.id));
      unawaited(
        chats.applyOutgoing(
          _myId,
          widget.chatId,
          messageId: sent.id,
          time: sent.time,
          text: MessagesModule.forwardPreviewText(sent),
          status: 'sent',
        ),
      );
    } catch (_) {
      final index = _messages.indexWhere((m) => m.id == optimistic.id);
      if (index != -1 && mounted) {
        _messages.removeAt(index);
        _bumpMessages();
      }
      unawaited(AppDatabase.deleteMessage(_myId, widget.chatId, optimistic.id));
      if (mounted) {
        Haptics.error();
        showCustomNotification(context, 'Не удалось переслать');
      }
    }
  }

  Widget _buildComposerArea(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
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
              ComposerInputBar(
                chatType: widget.chatType,
                chrome: _effectiveChrome,
                attachAnim: _attachAnim,
                replyTo: _replyTo,
                myId: _myId,
                hasText: _hasText,
                uploadStatus: _uploadStatus,
                messageController: _messageController,
                messageFocusNode: _messageFocusNode,
                voiceRec: _voiceRec,
                note: _note,
                onToggleStickerPanel: _toggleStickerPanel,
                onSendText: _sendMessage,
                onScheduleMessage: _scheduleMessage,
                onOpenAttach: _openAttachmentSheet,
                onOpenAttachScheduled: _openAttachmentSheetScheduled,
                onSendHistory: _sendHistoryFile,
                onCancelReply: _cancelReply,
                formatElapsed: formatVoiceElapsed,
                contextMenuBuilder: (ctx, state) =>
                    _formatContextMenu(_messageController, ctx, state),
                isMuted: chat?.isMuted ?? false,
                onToggleMute: _toggleChatMute,
              ),
              StickerPanelView(
                stickers: _stickers,
                onStickerTap: _sendSticker,
                onEmojiTap: _insertAnimoji,
              ),
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
            builder: (context, selected, _) => SelectionBottomBar(
              cs: cs,
              selected: selected,
              onReply: _replySelected,
              onForward: _forwardSelected,
            ),
          ),
        ),
      ],
    );
    Widget wrapChrome(Widget child) {
      if (_effectiveChrome != ChatChromeStyle.blur) return child;
      return _FrostedPanel(
        tint: cs.surfaceContainerHigh.withValues(alpha: 0.55),
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: child,
      );
    }

    final base = wrapChrome(content);
    return AnimatedBuilder(
      animation: _searchAnim,
      builder: (context, _) {
        final s = Curves.easeOut.transform(_searchAnim.value.clamp(0.0, 1.0));
        if (s == 0) return base;
        if (s >= 1) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - s,
            child: Opacity(
              opacity: 1 - s,
              child: IgnorePointer(child: base),
            ),
          ),
        );
      },
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
    final controller = RichMessageController(text: message.text ?? '')
      ..setFormatRanges(message.formatRanges);

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
              contextMenuBuilder: (ctx, state) =>
                  _formatContextMenu(controller, ctx, state),
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

    final content = controller.buildContent();
    final rawText = content.text;
    final newText = rawText.trim();
    final elements = _trimmedElements(content.elements, rawText, newText);
    controller.dispose();

    final oldElements = serializeFormatElements(
      message.formatRanges.where((r) => composerFormats.contains(r.format)),
    );
    if (newText == (message.text ?? '') &&
        _sameElements(elements, oldElements)) {
      return;
    }

    final ok = await messagesModule.editMessage(
      widget.chatId,
      message.id,
      text: newText,
      elements: elements,
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
      final newHistory = KometSettings.viewRedacted.value
          ? CachedMessage.appendEditHistory(
              old.editHistory,
              old.text,
              DateTime.now().millisecondsSinceEpoch,
            )
          : old.editHistory;
      final edited = CachedMessage(
        id: old.id,
        accountId: old.accountId,
        chatId: old.chatId,
        senderId: old.senderId,
        text: newText.isEmpty ? null : newText,
        time: old.time,
        status: 'EDITED',
        payload: {...?old.payload, 'elements': elements},
        attachments: old.attachments,
        isControl: old.isControl,
        editHistory: newHistory,
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

    final ok = await messagesModule.deleteMessages(widget.chatId, [
      message.id,
    ], forEveryone: forEveryone);
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
      await chats.reconcileLastMessage(_myId, widget.chatId);
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
                  onPressed: () =>
                      Navigator.pop(ctx, canForEveryone && alsoForEveryone),
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
        final nearBottom = _isNearBottom();
        _lastSentId = message.id;
        _messages.add(message);
        _bumpMessages();
        _clearTyping(message.senderId);
        Haptics.tap();
        if (nearBottom) {
          _scrollToBottom();
          _scheduleReadMarker();
        } else {
          _reapplyPinIfNeeded();
        }
        _prank.checkTrigger(message);
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
    if (!mounted) return;
    final otherId = _resolveOtherId();
    if (otherId == null) return;
    final p = PresenceFetch.live(otherId);
    if (p == null) return;
    _otherStatus = (p['status'] as int?) ?? 0;
    _otherSeenTime = p['seen'] as int?;
    _recomputeHeaderStatus();
  }

  void _onVisualStyleChanged() {
    if (mounted) {
      setState(() {});
      _bumpMessages();
    }
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    final glossy = AppVisualStyle.current.value == VisualStyle.glossy;
    final searchT = Curves.easeOut.transform(_searchAnim.value.clamp(0.0, 1.0));
    final height = glossy
        ? ui.lerpDouble(_glossyHeaderHeight, _glossySearchHeight, searchT)!
        : kToolbarHeight;
    final chrome = _effectiveChrome;
    return AppBar(
      backgroundColor: chrome == ChatChromeStyle.color
          ? (glossy ? Colors.transparent : cs.surfaceContainerHigh)
          : Colors.transparent,
      flexibleSpace: chrome == ChatChromeStyle.blur
          ? _FrostedPanel(
              tint: cs.surfaceContainerHigh.withValues(alpha: 0.55),
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  width: 0.5,
                ),
              ),
              child: const SizedBox.expand(),
            )
          : (chrome == ChatChromeStyle.none && !glossy)
          ? IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface,
                      cs.surface,
                      cs.surface.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.72, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            )
          : (chrome == ChatChromeStyle.transparent && !glossy)
          ? IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface.withValues(alpha: 0.72),
                      cs.surface.withValues(alpha: 0.45),
                      cs.surface.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.62, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            )
          : null,
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
          animation: Listenable.merge([_selectionAnim, _searchAnim]),
          builder: (context, _) {
            final t = Curves.easeOut.transform(
              _selectionAnim.value.clamp(0.0, 1.0),
            );
            final s = Curves.easeOut.transform(
              _searchAnim.value.clamp(0.0, 1.0),
            );
            return ValueListenableBuilder<Set<String>>(
              valueListenable: _selectedIds,
              builder: (context, selected, _) => Stack(
                fit: StackFit.expand,
                children: [
                  if (t < 1 && s < 1)
                    IgnorePointer(
                      ignoring: t > 0.5 || s > 0.5,
                      child: Opacity(
                        opacity: (1 - t) * (1 - s),
                        child: Transform.translate(
                          offset: Offset(0, -height * 0.4 * t),
                          child: ChatHeaderRow(
                            glossy: glossy,
                            cs: cs,
                            embedded: widget.embedded,
                            chatId: widget.chatId,
                            name: widget.name,
                            imageUrl: widget.imageUrl,
                            chatType: widget.chatType,
                            isOfficial: chat?.isOfficial ?? false,
                            myId: _myId,
                            headerStatus: _headerStatusNotifier,
                            scheduledCount: _scheduledCount,
                            otherUnread: _otherUnread,
                            showCall:
                                widget.chatType == 'DIALOG' && !_peerIsBot,
                            onClose: widget.onClose,
                            onOpenInfo: () {
                              final navigator = Navigator.of(context);
                              final chatRoute = ModalRoute.of(context);
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (context) => ChatInfoScreen(
                                    chatId: widget.chatId,
                                    name: widget.name,
                                    imageUrl: widget.imageUrl,
                                    chatType: widget.chatType,
                                    onJumpToMessage:
                                        (chatRoute == null || widget.embedded)
                                        ? null
                                        : (messageId, time) {
                                            navigator.popUntil(
                                              (r) => r == chatRoute,
                                            );
                                            _requestGoToMessage(
                                              messageId,
                                              time,
                                            );
                                          },
                                  ),
                                ),
                              );
                            },
                            onOpenScheduled: _openScheduledMessages,
                            onCall: _startCall,
                            onMenu: _openChatMenu,
                          ),
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
                          child: SelectionTopBar(
                            cs: cs,
                            selected: selected,
                            glossy: glossy,
                            copyMsg: _singleCopyableText(selected),
                            editMsg: _singleEditable(selected),
                            onClear: _clearSelection,
                            onCopy: _copySelected,
                            onEdit: _editSelected,
                            onDelete: _deleteSelected,
                          ),
                        ),
                      ),
                    ),
                  if (s > 0)
                    IgnorePointer(
                      ignoring: s < 0.5,
                      child: Opacity(
                        opacity: s,
                        child: SearchTopBar(
                          cs: cs,
                          glossy: glossy,
                          search: _search,
                          focusNode: _searchFocusNode,
                          onClose: _closeSearch,
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

  void _openChatMenu(BuildContext btnContext) {
    final box = btnContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final anchorRect = box.localToGlobal(Offset.zero) & box.size;
    showChatMenu(
      context: context,
      anchorRect: anchorRect,
      items: [
        ChatMenuItem(
          icon: (chat?.isMuted ?? false)
              ? Symbols.volume_off
              : Symbols.volume_up,
          label: (chat?.isMuted ?? false)
              ? 'Включить уведомления'
              : 'Отключить уведомления',
          dividerAfter: true,
          onTap: _toggleChatMute,
        ),
        ChatMenuItem(icon: Symbols.search, label: 'Поиск', onTap: _openSearch),
        ChatMenuItem(
          icon: Symbols.wallpaper,
          label: 'Изменить обои',
          onTap: _openWallpaperSheet,
        ),
        ChatMenuItem(
          icon: Symbols.mop,
          label: 'Очистить историю',
          onTap: _clearHistory,
        ),
        ChatMenuItem(
          icon: Symbols.delete,
          label: 'Удалить чат',
          onTap: _deleteChat,
        ),
      ],
    );
  }

  Future<void> _toggleChatMute() async {
    final current = chat;
    if (current == null) return;
    final muted = current.isMuted;
    final target = muted ? ChatsModule.muteOff : ChatsModule.muteForever;
    final error = await chats.setChatMute(
      api,
      chatId: widget.chatId,
      dontDisturbUntil: target,
    );
    if (!mounted) return;
    if (error != null) {
      showCustomNotification(context, error);
      return;
    }
    setState(() => chat = current.copyWith(dontDisturbUntil: target));
    showCustomNotification(
      context,
      muted ? 'Уведомления включены' : 'Уведомления отключены',
    );
  }

  bool _wallpaperListening = false;

  Future<void> _loadWallpaper() async {
    await ChatWallpaperStore.instance.load();
    if (!mounted) return;
    if (!_wallpaperListening) {
      _wallpaperListening = true;
      ChatWallpaperStore.instance.revision.addListener(_applyEffectiveWallpaper);
    }
    _applyEffectiveWallpaper();
  }

  void _applyEffectiveWallpaper() {
    if (!mounted) return;
    final store = ChatWallpaperStore.instance;
    final wp = store.get(_myId, widget.chatId) ??
        store.get(_myId, kGlobalWallpaperChatId);
    if (!identical(wp, _wallpaper)) setState(() => _wallpaper = wp);
  }

  Future<void> _openWallpaperSheet() async {
    if (_myId == 0) return;
    final pick = await showChatWallpaperSheet(context, current: _wallpaper);
    if (pick == null || !mounted) return;
    final store = ChatWallpaperStore.instance;
    switch (pick.type) {
      case WallpaperPickType.none:
        await store.clear(_myId, widget.chatId);
        _applyEffectiveWallpaper();
        break;
      case WallpaperPickType.theme:
        final theme = pick.theme;
        if (theme == null) break;
        await store.setTheme(_myId, widget.chatId, theme.id);
        _applyEffectiveWallpaper();
        break;
      case WallpaperPickType.gallery:
        await _pickWallpaperFromGallery();
        break;
    }
  }

  Future<void> _pickWallpaperFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) showCustomNotification(context, 'Не удалось прочитать файл');
      return;
    }
    if (!mounted) return;
    final settings = await Navigator.of(context).push<WallpaperImageSettings>(
      MaterialPageRoute(
        builder: (_) => ChatWallpaperPreviewScreen(imageBytes: bytes),
      ),
    );
    if (settings == null || !mounted) return;
    final wp = await ChatWallpaperStore.instance.setImage(
      _myId,
      widget.chatId,
      bytes,
      settings: settings,
    );
    if (!mounted) return;
    if (wp == null) {
      showCustomNotification(context, 'Не удалось сохранить обои');
      return;
    }
    _applyEffectiveWallpaper();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Очистить историю',
      message:
          'Все сообщения в этом чате будут удалены без возможности '
          'восстановления.',
      confirmLabel: 'Очистить',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final err = await chats.clearHistory(
      api,
      chatId: widget.chatId,
      lastEventTime: chat?.lastEventTime ?? 0,
    );
    if (!mounted) return;
    if (err != null) {
      showCustomNotification(context, err);
      return;
    }
    setState(() {
      _messages = [];
      _hasMoreHistory = false;
      _combinedItemsCache = null;
    });
    _messagesRev.value++;
  }

  Future<void> _deleteChat() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Удалить чат',
      message: 'Чат будет удалён вместе со всей перепиской.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final err = await chats.deleteChat(
      api,
      chatId: widget.chatId,
      lastEventTime: chat?.lastEventTime ?? 0,
      forAll: false,
    );
    if (!mounted) return;
    if (err != null) {
      showCustomNotification(context, err);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _startCall() async {
    if (widget.chatType != 'DIALOG' || _peerIsBot) {
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
      final serverMessages = await messagesModule.fetchHistory(
        _myId,
        widget.chatId,
      );
      if (KometSettings.viewDeleted.value) {
        await chats.reconcileDeletedFromFetch(
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
    } catch (e) {
      logger.w('Обновление после звонка не удалось: $e');
    }
  }

  void _seedPresenceFromChat() {
    if (_otherStatus != 0 || _otherSeenTime != null) return;
    final otherId = _resolveOtherId();
    if (otherId == null) return;
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
    final activity = ChatActivityStore.instance.activity(widget.chatId);
    if (activity != null) return activity.label;
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
    ChatActivityStore.instance.mark(
      widget.chatId,
      userId,
      chatActivityFromType(payload['type']),
    );
  }

  void _clearTyping(int userId) {
    ChatActivityStore.instance.clearUser(widget.chatId, userId);
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

  static String _formatLabel(TextFormat format) {
    switch (format) {
      case TextFormat.strong:
        return 'Жирный';
      case TextFormat.emphasized:
        return 'Курсив';
      case TextFormat.underline:
        return 'Подчёркнутый';
      case TextFormat.strikethrough:
        return 'Зачёркнутый';
      case TextFormat.monospaced:
        return 'Моноширинный';
      case TextFormat.quote:
        return 'Цитата';
      case TextFormat.link:
        return 'Ссылка';
      case TextFormat.animoji:
        return 'Animoji';
    }
  }

  Widget _formatContextMenu(
    RichMessageController controller,
    BuildContext context,
    EditableTextState editableState,
  ) {
    final selection = controller.selection;
    final buttonItems = <ContextMenuButtonItem>[];
    if (selection.isValid && !selection.isCollapsed) {
      for (final format in composerFormats) {
        final active = controller.isFormatActive(format);
        buttonItems.add(
          ContextMenuButtonItem(
            label: '${active ? '✓ ' : ''}${_formatLabel(format)}',
            onPressed: () {
              controller.toggleFormat(format);
              editableState.hideToolbar();
            },
          ),
        );
      }
    }
    buttonItems.addAll(editableState.contextMenuButtonItems);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  static bool _sameElements(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    String canon(List<Map<String, dynamic>> els) {
      final copy = [...els]
        ..sort((x, y) {
          final t = (x['type'] as String).compareTo(y['type'] as String);
          return t != 0 ? t : (x['from'] as int).compareTo(y['from'] as int);
        });
      return copy
          .map((e) => '${e['type']}:${e['from']}:${e['length']}')
          .join(',');
    }

    return canon(a) == canon(b);
  }

  List<Map<String, dynamic>> _trimmedElements(
    List<Map<String, dynamic>> raw,
    String rawText,
    String text,
  ) {
    if (raw.isEmpty) return const [];
    final leading = rawText.length - rawText.trimLeft().length;
    final result = <Map<String, dynamic>>[];
    for (final element in raw) {
      var from = (element['from'] as int) - leading;
      var length = element['length'] as int;
      if (from < 0) {
        length += from;
        from = 0;
      }
      if (from >= text.length || length <= 0) continue;
      if (from + length > text.length) length = text.length - from;
      if (length <= 0) continue;
      result.add({...element, 'from': from, 'length': length});
    }
    return result;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.buildContent();
    final rawText = content.text;
    final text = rawText.trim();
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

    final elements = _trimmedElements(content.elements, rawText, text);
    final Map<String, dynamic>? composedPayload =
        (replyPayload == null && elements.isEmpty)
        ? null
        : {...?replyPayload, if (elements.isNotEmpty) 'elements': elements};

    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: _myId,
      text: text,
      time: now,
      status: online ? 'sending' : 'pending',
      payload: composedPayload,
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
    unawaited(
      chats.applyOutgoing(
        _myId,
        widget.chatId,
        messageId: tempId,
        time: now,
        text: text,
        status: composed.status ?? 'sending',
        elements: elements,
      ),
    );

    // Instant tactile "whoosh" the moment the message leaves the composer,
    // not after the network round-trip — feedback must feel immediate.
    Haptics.send();

    _scrollToBottom();
    _prank.checkTrigger(composed);

    if (!online) return;

    try {
      final actualId = await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
        replyToMessageId: replyId,
        elements: elements,
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
          payload: composedPayload,
        );
        _messages[index] = sent;
        _bumpMessages();
        unawaited(_persistOutgoing(sent, removeId: tempId));
        unawaited(
          chats.applyOutgoing(
            _myId,
            widget.chatId,
            messageId: sent.id,
            time: now,
            text: text,
            status: 'sent',
            elements: elements,
          ),
        );
      }

      if (chat == null) {
        unawaited(
          chats.refreshChats(api, [widget.chatId]).then((list) {
            if (!mounted || list.isEmpty) return;
            setState(() => chat = list.first);
            _bumpMessages();
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
          payload: composedPayload,
        );
        _messages[index] = queued;
        _bumpMessages();
        unawaited(_persistOutgoing(queued));
        unawaited(
          chats.applyOutgoing(
            _myId,
            widget.chatId,
            messageId: tempId,
            time: now,
            text: text,
            status: 'pending',
            elements: elements,
          ),
        );
      }
    }
  }

  int? _resolveOtherId() {
    if (widget.chatType != 'DIALOG' || _myId == 0) return null;
    final id = widget.chatId ^ _myId;
    return id > 0 ? id : null;
  }

  int _complaintTypeId(String type) {
    switch (type) {
      case 'CHANNEL':
        return 5;
      case 'CHAT':
        return 4;
      default:
        return 3;
    }
  }

  Future<List<({int id, String title})>> _loadReportReasons(int typeId) async {
    final reasons = await ComplaintsModule.reasonsFor(api, typeId);
    return reasons.map((r) => (id: r.reasonId, title: r.reasonTitle)).toList();
  }

  Future<bool> _reportMessage(
    CachedMessage message,
    int typeId,
    int reasonId,
  ) async {
    final messageIdNum = int.tryParse(message.id);
    if (messageIdNum == null) {
      if (mounted) {
        showCustomNotification(context, 'Не удалось отправить жалобу');
      }
      return false;
    }
    final ok = await ComplaintsModule.sendComplaint(
      api,
      reasonId: reasonId,
      typeId: typeId,
      ids: [messageIdNum],
      parentId: widget.chatId,
    );
    if (!mounted) return ok;
    showCustomNotification(
      context,
      ok ? 'Жалоба отправлена' : 'Не удалось отправить жалобу',
    );
    return ok;
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
      editHistory: old.editHistory,
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
    unawaited(
      chats.applyOutgoing(
        _myId,
        widget.chatId,
        messageId: tempId,
        time: now,
        text: text,
        status: composed.status ?? 'sending',
      ),
    );
    if (!online) return tempId;
    try {
      final actualId = await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
      );
      final realId = actualId.isNotEmpty ? actualId : tempId;
      final i = _messages.indexWhere((m) => m.id == tempId);
      if (i != -1) {
        final sent = _replaceMessage(i, id: realId, status: 'sent');
        unawaited(_persistOutgoing(sent, removeId: tempId));
        unawaited(
          chats.applyOutgoing(
            _myId,
            widget.chatId,
            messageId: realId,
            time: now,
            text: text,
            status: 'sent',
          ),
        );
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
      _messages[i] = msg.copyWith(attachments: newAttaches);
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

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= 120;
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

  void _openStickerPack(StickerAttachment sticker) {
    final stickerId = int.tryParse(sticker.stickerId ?? '');
    if (stickerId == null) {
      showCustomNotification(context, 'Стикерпак недоступен');
      return;
    }
    showStickerPackSheet(
      context,
      stickerId: stickerId,
      knownSetId: int.tryParse(sticker.stickerPackId ?? ''),
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

    _highlightTimer?.cancel();
    _highlightMessageId.value = messageId;
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_highlightMessageId.value == messageId) {
        _highlightMessageId.value = null;
      }
    });
  }

  final Map<String, GlobalKey> _messageKeys = {};

  GlobalKey _keyForMessage(String messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  void _openSearch() {
    if (_search.searchMode.value || _selectionMode) return;
    _search.searchMode.value = true;
    _searchAnim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _search.searchMode.value) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    if (!_search.searchMode.value) return;
    _searchFocusNode.unfocus();
    _searchAnim.reverse();
    _search.reset();
  }

  Future<void> _navigateToInitialMessage() async {
    final id = widget.initialMessageId;
    if (id == null) {
      _finishTargetNavigation();
      return;
    }
    await _runGoToMessage(id, widget.initialMessageTime ?? 0);
  }

  Future<void> _runGoToMessage(String id, int targetTime) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (!_messages.any((m) => m.id == id)) {
      var guard = 0;
      while (mounted &&
          guard < 80 &&
          _hasMoreHistory &&
          !_messages.any((m) => m.id == id) &&
          (_messages.isEmpty || _messages.first.time > targetTime)) {
        guard++;
        final before = _messages.isEmpty ? 0 : _messages.first.time;
        await _loadMoreHistory();
        if (!mounted) return;
        final after = _messages.isEmpty ? 0 : _messages.first.time;
        if (after == before) break;
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (!_messages.any((m) => m.id == id)) {
      if (mounted) showCustomNotification(context, 'Сообщение не загружено');
      _finishTargetNavigation();
      return;
    }

    _highlightTimer?.cancel();
    _highlightMessageId.value = id;
    _highlightTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      if (_highlightMessageId.value == id) _highlightMessageId.value = null;
    });

    await _scrollToMessagePrecise(id);
    _finishTargetNavigation();
  }

  ({int min, int max})? _laidOutMessageRange(List<Object> items) {
    int? lo;
    int? hi;
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is! _MessageItem) continue;
      final ro = _keyForMessage(
        it.message.id,
      ).currentContext?.findRenderObject();
      if (ro is RenderBox && ro.attached) {
        lo ??= i;
        hi = i;
      }
    }
    if (lo == null) return null;
    return (min: lo, max: hi!);
  }

  Future<void> _scrollToMessagePrecise(
    String id, {
    double alignment = 0.32,
  }) async {
    if (!mounted || !_scrollController.hasClients) return;
    if (_messages.indexWhere((m) => m.id == id) == -1) return;

    _suppressHistoryAutoload = true;
    try {
      var stable = 0;
      for (var iter = 0; iter < 120; iter++) {
        if (!mounted || !_scrollController.hasClients) return;
        final listObj = _listKey.currentContext?.findRenderObject();
        final boxObj = _keyForMessage(id).currentContext?.findRenderObject();
        final p = _scrollController.position;

        if (listObj is RenderBox && boxObj is RenderBox && boxObj.attached) {
          final viewportH = listObj.size.height;
          final actualTop = boxObj
              .localToGlobal(Offset.zero, ancestor: listObj)
              .dy;
          final desiredTop = alignment * viewportH;
          final delta = desiredTop - actualTop;
          final target = (p.pixels + delta).clamp(
            p.minScrollExtent,
            p.maxScrollExtent,
          );

          if (delta.abs() <= 2.0 || (target - p.pixels).abs() <= 1.0) {
            stable++;
            if (stable >= 4) return;
            await Future.delayed(const Duration(milliseconds: 60));
            continue;
          }
          stable = 0;
          _scrollController.jumpTo(target);
          await WidgetsBinding.instance.endOfFrame;
          continue;
        }

        stable = 0;
        final items = _buildCombinedItems();
        final pos = items.indexWhere(
          (it) => it is _MessageItem && it.message.id == id,
        );
        if (pos == -1) return;

        final viewportH = listObj is RenderBox ? listObj.size.height : 600.0;
        var stepMag = viewportH * 0.8;
        if (stepMag > 700) stepMag = 700;

        final range = _laidOutMessageRange(items);
        final step = (range != null && pos > range.max) ? -stepMag : stepMag;

        final target = (p.pixels + step).clamp(
          p.minScrollExtent,
          p.maxScrollExtent,
        );
        if ((target - p.pixels).abs() < 1.0) return;
        _scrollController.jumpTo(target);
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _suppressHistoryAutoload = false;
    }
  }

  Future<void> _openSearchResult(MessageSearchResult result) async {
    _closeSearch();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    if (!_messages.any((m) => m.id == result.id)) {
      var guard = 0;
      while (mounted &&
          guard < 60 &&
          _hasMoreHistory &&
          !_messages.any((m) => m.id == result.id) &&
          (_messages.isEmpty || _messages.first.time > result.time)) {
        guard++;
        final before = _messages.isEmpty ? 0 : _messages.first.time;
        await _loadMoreHistory();
        if (!mounted) return;
        final after = _messages.isEmpty ? 0 : _messages.first.time;
        if (after == before) break;
      }
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    _scrollToLoadedMessage(result.id);
  }

  void _scrollToLoadedMessage(
    String messageId, {
    double alignment = 0.4,
    bool highlight = true,
    bool notifyIfMissing = true,
    VoidCallback? onSettled,
  }) {
    if (!_scrollController.hasClients) {
      onSettled?.call();
      return;
    }
    final items = _buildCombinedItems();
    final pos = items.indexWhere(
      (it) => it is _MessageItem && it.message.id == messageId,
    );
    if (pos == -1) {
      if (notifyIfMissing) {
        showCustomNotification(context, 'Сообщение не загружено');
      }
      onSettled?.call();
      return;
    }

    final laidOut = _keyForMessage(
      messageId,
    ).currentContext?.findRenderObject();
    if (laidOut is! RenderBox || !laidOut.attached) {
      var below = 0.0;
      for (var i = pos + 1; i < items.length; i++) {
        below += items[i] is _MessageItem ? _avgMessageHeight : 44.0;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(below.clamp(0.0, maxExtent).toDouble());
    }

    if (highlight) {
      _highlightTimer?.cancel();
      _highlightMessageId.value = messageId;
      _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        if (_highlightMessageId.value == messageId) {
          _highlightMessageId.value = null;
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _alignLoadedMessage(messageId, alignment, 0, onSettled: onSettled),
    );
  }

  void _alignLoadedMessage(
    String messageId,
    double alignment,
    int attempt, {
    VoidCallback? onSettled,
  }) {
    if (!mounted || !_scrollController.hasClients) {
      onSettled?.call();
      return;
    }
    final listBox = _listKey.currentContext?.findRenderObject();
    final box = _keyForMessage(messageId).currentContext?.findRenderObject();
    if (listBox is! RenderBox || box is! RenderBox || !box.attached) {
      if (attempt >= 8) {
        onSettled?.call();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _alignLoadedMessage(
          messageId,
          alignment,
          attempt + 1,
          onSettled: onSettled,
        ),
      );
      return;
    }

    final viewportHeight = listBox.size.height;
    final actualTop = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
    final desiredTop = alignment.clamp(0.0, 1.0) * viewportHeight;
    final delta = desiredTop - actualTop;
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );

    if (viewportHeight <= 0 ||
        delta.abs() <= 0.5 ||
        (target - pos.pixels).abs() <= 0.5 ||
        attempt >= 8) {
      onSettled?.call();
      return;
    }

    _scrollController.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _alignLoadedMessage(
        messageId,
        alignment,
        attempt + 1,
        onSettled: onSettled,
      ),
    );
  }

  String _searchSenderName(int senderId) {
    if (senderId == _myId) return 'Вы';
    final cached = ContactCache.get(senderId);
    if (cached != null && cached.isNotEmpty) return cached;
    if (widget.chatType == 'DIALOG') return widget.name;
    return 'Пользователь';
  }

  String? _searchSenderAvatar(int senderId) {
    final cached = ContactCache.getAvatar(senderId);
    if (cached != null && cached.isNotEmpty) return cached;
    if (senderId != _myId &&
        widget.chatType == 'DIALOG' &&
        widget.imageUrl.isNotEmpty) {
      return widget.imageUrl;
    }
    return null;
  }

  int _firstUnreadIndex() {
    final anchor = _unreadAnchorTime;
    if (anchor == null) return -1;
    return _messages.indexWhere((m) => m.time > anchor);
  }

  List<Object> _buildCombinedItems() {
    final key = Object.hash(
      _messagesRev.value,
      _messages.length,
      _unreadAnchorTime,
    );
    final cached = _combinedItemsCache;
    if (cached != null && _combinedItemsKey == key) return cached;

    final unreadIndex = _firstUnreadIndex();

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

      if (i == unreadIndex) {
        items.add(const _UnreadSeparatorItem());
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
      padding: EdgeInsets.symmetric(vertical: floating ? 2 : 8),
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

  Widget _buildUnreadSeparatorWidget(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Непрочитанные сообщения',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _prank.active
        ? _prank.pinkTheme(Theme.of(context))
        : Theme.of(context);
    final cs = theme.colorScheme;
    final underlap = _effectiveChrome != ChatChromeStyle.color;

    // TODO: Локализация
    // TODO: Cклонения
    final mq = MediaQuery.of(context);
    final bottomInset = _keyboardReserve > 0
        ? math.max(mq.viewInsets.bottom, _keyboardReserve)
        : mq.viewInsets.bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([_selectedIds, _search.searchMode]),
      builder: (context, child) => PopScope(
        canPop: _selectedIds.value.isEmpty && !_search.searchMode.value,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_search.searchMode.value) {
            _closeSearch();
          } else {
            _clearSelection();
          }
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
            key: _prank.captureKey,
            child: ValueListenableBuilder<bool>(
              valueListenable: AppSwipeBackDesktop.current,
              builder: (context, desktopSwipe, child) => SwipeToPop(
                enabled: widget.embedded && desktopSwipe,
                onPop: widget.onClose,
                child: child!,
              ),
              child: AnimatedBuilder(
                animation: _searchAnim,
                child: LottieHoldScope(
                  isHeld: _animojiHold,
                  child: underlap ? _buildUnderlapBody() : _buildColorBody(),
                ),
                builder: (context, body) => Scaffold(
                  backgroundColor: cs.surface,
                  extendBodyBehindAppBar: underlap,
                  appBar: _buildAppBar(cs),
                  body: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildPinnedBanner({required bool floating}) {
    final pinned = chat;
    if (pinned == null || !pinned.hasPinnedMessage) return null;
    return _PinnedMessageBanner(
      text: pinned.pinnedMsgText,
      isPreview: pinned.pinnedMsgIsPreview,
      floating: floating,
      onTap: _jumpToPinnedMessage,
      onUnpin: pinned.canPinMessages(_myId)
          ? () => unawaited(_unpinCurrentMessage())
          : null,
    );
  }

  Widget _buildColorBody() {
    final cs = Theme.of(context).colorScheme;
    final banner = _buildPinnedBanner(floating: false);
    return Column(
      children: [
        ?banner,
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_wallpaper != null)
                Positioned.fill(
                  child: ChatWallpaperView(wallpaper: _wallpaper!),
                ),
              Positioned.fill(child: _buildMessagesArea()),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CommandPanelView(commandPanel: _commandPanel),
              ),
              SearchOverlay(
                cs: cs,
                searchAnim: _searchAnim,
                search: _search,
                onOpenResult: _openSearchResult,
                senderName: _searchSenderName,
                senderAvatar: _searchSenderAvatar,
              ),
            ],
          ),
        ),
        _buildComposerArea(context),
      ],
    );
  }

  double _pinnedBannerTop() {
    final glossy = AppVisualStyle.current.value == VisualStyle.glossy;
    return MediaQuery.paddingOf(context).top +
        (glossy ? _glossyHeaderHeight : kToolbarHeight);
  }

  void _resetPinnedBannerHeight() {
    if (_pinnedBannerHeight.value == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && chat?.hasPinnedMessage != true) {
        _pinnedBannerHeight.value = 0;
      }
    });
  }

  Widget _buildUnderlapBody() {
    final cs = Theme.of(context).colorScheme;
    final vignette = _effectiveChrome == ChatChromeStyle.none;
    final bannerTop = _pinnedBannerTop();
    final banner = _buildPinnedBanner(floating: true);
    if (banner == null) _resetPinnedBannerHeight();
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_wallpaper != null)
          Positioned.fill(child: ChatWallpaperView(wallpaper: _wallpaper!)),
        Positioned.fill(child: _buildMessagesArea()),
        SearchOverlay(
          cs: cs,
          searchAnim: _searchAnim,
          search: _search,
          onOpenResult: _openSearchResult,
          senderName: _searchSenderName,
          senderAvatar: _searchSenderAvatar,
        ),
        if (vignette) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildEdgeVignette(cs, top: true),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _composerHeight,
            builder: (context, height, _) => Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildEdgeVignette(cs, top: false, height: height),
            ),
          ),
        ],
        if (banner != null)
          Positioned(
            top: bannerTop,
            left: 8,
            right: 8,
            child: _MeasureSize(
              onHeight: (value) => _pinnedBannerHeight.value = value,
              child: banner,
            ),
          ),
        ValueListenableBuilder<double>(
          valueListenable: _composerHeight,
          builder: (context, height, _) => Positioned(
            left: 0,
            right: 0,
            bottom: height,
            child: CommandPanelView(commandPanel: _commandPanel),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _MeasureSize(
                onHeight: (value) => _composerHeight.value = value,
                child: _buildComposerArea(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEdgeVignette(
    ColorScheme cs, {
    required bool top,
    double? height,
  }) {
    final double resolved;
    if (height != null) {
      resolved = height;
    } else {
      final glossy = AppVisualStyle.current.value == VisualStyle.glossy;
      resolved =
          MediaQuery.paddingOf(context).top +
          (glossy ? _glossyHeaderHeight : kToolbarHeight);
    }
    return IgnorePointer(
      child: Container(
        height: resolved,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesArea() {
    final showShimmer = _messages.isEmpty
        ? _isLoading
        : (_awaitingPosition || _navigatingToTarget);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: showShimmer ? 0.0 : 1.0,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _updateReadMarker();
              return false;
            },
            child: _buildMessagesList(),
          ),
        ),
        if (showShimmer)
          Positioned.fill(child: ShimmerLoading(shimmer: _shimmerController)),
      ],
    );
  }

  Widget _buildMessagesList() =>
      _messageListWidget ??= _ChatMessageList(this, key: _messageListKey);

  EdgeInsets _messagesListPadding(BuildContext context) {
    if (AppChatChrome.current.value == ChatChromeStyle.color) {
      return const EdgeInsets.symmetric(vertical: 8);
    }
    final topInset = MediaQuery.paddingOf(context).top;
    return EdgeInsets.only(top: topInset + 8, bottom: 8);
  }

  double _floatingDateTop(double pinnedHeight) {
    final glossy = AppVisualStyle.current.value == VisualStyle.glossy;
    if (AppChatChrome.current.value == ChatChromeStyle.color) {
      return glossy ? 2 : 4;
    }
    if (chat?.hasPinnedMessage == true && pinnedHeight > 0) {
      return _pinnedBannerTop() + pinnedHeight + 2;
    }
    return MediaQuery.paddingOf(context).top +
        (glossy ? _glossyHeaderHeight : kToolbarHeight) +
        2;
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
        ValueListenableBuilder<double>(
          valueListenable: AppCacheExtent.current,
          builder: (context, userCacheExtent, _) =>
              ValueListenableBuilder<double?>(
                valueListenable: _jumpCacheExtent,
                builder: (context, jumpExtent, _) {
                  final cacheExtent =
                      jumpExtent != null && jumpExtent < userCacheExtent
                      ? jumpExtent
                      : userCacheExtent;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: _messagesListPadding(context),
                    cacheExtent: cacheExtent,
                    itemCount: items.length + 1 + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _composerHeight,
                          builder: (context, height, _) => SizedBox(
                            height:
                                AppChatChrome.current.value ==
                                    ChatChromeStyle.color
                                ? 0
                                : height,
                          ),
                        );
                      }
                      if (index > items.length) {
                        return _buildLoadMoreIndicator();
                      }
                      final item = items[items.length - index];

                      if (item is _DateSeparatorItem) {
                        return _buildDateSeparatorWidget(
                          context,
                          item.date,
                          key: item.key,
                        );
                      }

                      if (item is _UnreadSeparatorItem) {
                        return _buildUnreadSeparatorWidget(context);
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
                        otherReadTime: _otherReadTime,
                        reactionsListenable: _reactionNotifierFor(message),
                        uploadProgress: _photoProgressFor(message),
                        onReplyTap: _jumpToMessage,
                        onAvatarTap: _openSenderProfile,
                        onStickerTap: _openStickerPack,
                        onReactionTap: message.isControl
                            ? null
                            : (emoji) => _reactToMessage(message, emoji),
                        peerName: widget.name,
                        peerAvatarUrl: widget.imageUrl,
                      );

                      final canReport = !isMe && !message.isControl;
                      final reportTypeId = _complaintTypeId(
                        chat?.type ?? widget.chatType,
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
                        onMarkUnread: message.isControl
                            ? null
                            : () => _markMessageUnread(message),
                        onPin: _canPinMessage(message)
                            ? () => _togglePinMessage(message)
                            : null,
                        isPinned: () =>
                            chat?.pinnedMsgId == int.tryParse(message.id),
                        loadReportReasons: canReport
                            ? () => _loadReportReasons(reportTypeId)
                            : null,
                        onReport: canReport
                            ? (reasonId) => _reportMessage(
                                message,
                                reportTypeId,
                                reasonId,
                              )
                            : null,
                        onReact: message.isControl
                            ? null
                            : (emoji) => _reactToMessage(message, emoji),
                        reactions: _reactionNotifierFor(message),
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
                      return message.id == _prank.bubbleId
                          ? KeyedSubtree(
                              key: _prank.bubbleKey,
                              child: builtItem,
                            )
                          : builtItem;
                    },
                  );
                },
              ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _pinnedBannerHeight,
          builder: (context, pinnedHeight, child) => Positioned(
            top: _floatingDateTop(pinnedHeight),
            left: 0,
            right: 0,
            child: child!,
          ),
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
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
      final real = CachedMessage.fromPushPayload(
        _myId,
        widget.chatId,
        serverMsg,
      );
      _messages[idx] = real;
      _bumpMessages();
      unawaited(_persistOutgoing(real, removeId: tempId));
    } catch (e) {
      if (!mounted) return;
      _updateFileMessageStatus(tempId, 'error');
      showCustomNotification(context, 'Ошибка: $e');
    }
  }

  void _toggleStickerPanel() {
    if (_stickers.showPanel.value) {
      _stickers.hide();
      if (_keyboardBeforeStickers) _messageFocusNode.requestFocus();
      return;
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    _keyboardBeforeStickers = keyboard > 120 || _messageFocusNode.hasFocus;
    if (keyboard > 120) _stickers.panelHeight = keyboard;
    FocusManager.instance.primaryFocus?.unfocus();
    _stickers.showPanel.value = true;
  }

  Future<void> _sendSticker(StickerItem sticker) async {
    _stickers.hide();
    await _sendAttachMessage([
      StickerAttachment(
        stickerId: sticker.id.toString(),
        baseUrl: sticker.url,
        lottieUrl: sticker.lottieUrl,
        width: sticker.width,
        height: sticker.height,
      ),
    ], () => messagesModule.sendStickerMessage(widget.chatId, sticker.id));
  }

  void _insertAnimoji(Animoji animoji) {
    _messageController.insertAnimoji(animoji);
    unawaited(animojiModule.noteUsed(animoji));
    Haptics.selection();
  }

  Future<void> _shareLocation() async {
    final position = await _resolveCurrentPosition();
    if (position == null || !mounted) return;
    final lat = position.latitude;
    final lon = position.longitude;
    await _sendAttachMessage([
      LocationAttachment(latitude: lat, longitude: lon, zoom: 15),
    ], () => messagesModule.sendLocationMessage(widget.chatId, lat, lon));
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
        if (mounted)
          showCustomNotification(context, 'Нет доступа к геолокации');
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (mounted)
        showCustomNotification(context, 'Не удалось получить геопозицию');
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
    _uploadStatus.value = UploadStatus(active: true, total: file.size);

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
                _uploadStatus.value = UploadStatus(
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
            _uploadStatus.value = const UploadStatus();
            _uploadSub = null;
          },
          onError: (Object e) {
            if (!mounted) return;
            stopNotif();
            showCustomNotification(context, 'Ошибка: $e');
            if (tempId != null) _updateFileMessageStatus(tempId, 'error');
            _uploadStatus.value = const UploadStatus();
            _uploadSub = null;
          },
        );
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
    _springBack =
        AnimationController(
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
          Transform.translate(offset: Offset(_dragX, 0), child: widget.child),
        ],
      ),
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  final String? text;
  final bool isPreview;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;
  final bool floating;

  const _PinnedMessageBanner({
    required this.text,
    required this.isPreview,
    required this.onTap,
    this.onUnpin,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Material(
      color: floating
          ? cs.surfaceContainerHigh.withValues(alpha: 0.92)
          : cs.surfaceContainerHigh,
      borderRadius: floating ? BorderRadius.circular(16) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.pinnedMessageTitle,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _PinnedMessageText(
                      text: text,
                      isPreview: isPreview,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (onUnpin != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  onPressed: onUnpin,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!floating) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        child: content,
      );
    }
    return content;
  }
}

class _PinnedMessageText extends StatefulWidget {
  final String? text;
  final bool isPreview;
  final Color color;

  const _PinnedMessageText({
    required this.text,
    required this.isPreview,
    required this.color,
  });

  @override
  State<_PinnedMessageText> createState() => _PinnedMessageTextState();
}

class _PinnedMessageTextState extends State<_PinnedMessageText> {
  late String? _primaryText;
  late bool _primaryIsPreview;
  late String? _secondaryText;
  late bool _secondaryIsPreview;
  bool _showSecondary = false;

  @override
  void initState() {
    super.initState();
    _primaryText = widget.text;
    _primaryIsPreview = widget.isPreview;
    _secondaryText = widget.text;
    _secondaryIsPreview = widget.isPreview;
  }

  @override
  void didUpdateWidget(covariant _PinnedMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text &&
        widget.isPreview == oldWidget.isPreview) {
      return;
    }
    if (_showSecondary) {
      _primaryText = widget.text;
      _primaryIsPreview = widget.isPreview;
    } else {
      _secondaryText = widget.text;
      _secondaryIsPreview = widget.isPreview;
    }
    _showSecondary = !_showSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedTextSwap(
        showAlternate: _showSecondary,
        alternate: _buildText(context, _secondaryText, _secondaryIsPreview),
        child: _buildText(context, _primaryText, _primaryIsPreview),
      ),
    );
  }

  Widget _buildText(BuildContext context, String? text, bool isPreview) {
    final label = text == null || text.isEmpty
        ? AppLocalizations.of(context)!.msgActionsNoText
        : text;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: widget.color,
        fontSize: 14,
        fontStyle: isPreview ? FontStyle.italic : null,
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
  final VoidCallback? onMarkUnread;
  final VoidCallback? onPin;
  final bool Function() isPinned;
  final Future<List<({int id, String title})>> Function()? loadReportReasons;
  final Future<bool> Function(int reasonId)? onReport;
  final void Function(String emoji)? onReact;
  final ValueListenable<Map<String, dynamic>?>? reactions;

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
    this.onMarkUnread,
    this.onPin,
    required this.isPinned,
    this.loadReportReasons,
    this.onReport,
    this.onReact,
    this.reactions,
  });

  @override
  State<_SelectableMessageRow> createState() => _SelectableMessageRowState();
}

class _SelectableMessageRowState extends State<_SelectableMessageRow> {
  static const double _gutterWidth = 40;

  final GlobalKey _boundaryKey = GlobalKey();
  Offset? _lastTapDown;
  Timer? _openTimer;

  bool _isPinnedNow() => widget.isPinned();

  @override
  void dispose() {
    _openTimer?.cancel();
    super.dispose();
  }

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
      editHistory: widget.message.editHistory,
      loadReportReasons: widget.loadReportReasons,
      onReport: widget.onReport,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onMarkUnread: widget.onMarkUnread,
      onPin: widget.onPin,
      isPinned: _isPinnedNow(),
      onReact: widget.onReact,
      selectedReaction: widget.reactions?.value?['yourReaction']?.toString(),
      quickReactions: _quickReactionEmojis(),
      loadReactionEmojis: () async {
        await animojiModule.ensureLoaded();
        return _animojiReactionEmojis();
      },
      onDispose: controller.dispose,
    );
  }

  List<ReactionEmoji> _quickReactionEmojis() {
    final quick = animojiModule.quickAnimojis;
    if (quick.isEmpty) {
      return AnimojiModule.fallbackReactions
          .map((e) => ReactionEmoji(emoji: e))
          .toList();
    }
    return quick.map(_toReactionEmoji).toList();
  }

  List<ReactionEmoji> _animojiReactionEmojis() {
    final list = animojiModule.animojis;
    if (list.isEmpty) {
      return AnimojiModule.fallbackReactions
          .map((e) => ReactionEmoji(emoji: e))
          .toList();
    }
    return list.map(_toReactionEmoji).toList();
  }

  ReactionEmoji _toReactionEmoji(Animoji a) => ReactionEmoji(
    emoji: a.emoji,
    animationUrl: a.lottieUrl,
    staticUrl: a.iconUrl,
  );

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
      editHistory: widget.message.editHistory,
      loadReportReasons: widget.loadReportReasons,
      onReport: widget.onReport,
      onDelete: widget.onDelete,
      onEdit: widget.onEdit,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onMarkUnread: widget.onMarkUnread,
      onPin: widget.onPin,
      isPinned: _isPinnedNow(),
      onDispose: controller.dispose,
    );
  }

  void _handleTap() {
    if (widget.isSelectionActive()) {
      widget.onToggleSelection();
      return;
    }
    final react = widget.onReact;
    if (react != null && (_openTimer?.isActive ?? false)) {
      _openTimer?.cancel();
      _openTimer = null;
      Haptics.tap();
      react('❤️');
      return;
    }
    _openTimer?.cancel();
    _openTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted && !widget.isSelectionActive()) _openMenu();
    });
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
          color: selected ? cs.primary : cs.mutedText,
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
    _opacity = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _scale = Tween<double>(
      begin: 1,
      end: 0.82,
    ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _collapse = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
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

class _ChatMessageList extends StatefulWidget {
  final _ChatScreenState host;
  const _ChatMessageList(this.host, {super.key});

  @override
  State<_ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<_ChatMessageList> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.host._messagesRev,
      builder: (context, _, _) => widget.host._buildMessagesListContent(),
    );
  }
}
