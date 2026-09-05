import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chat_preview.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/comments.dart';
import 'package:komet/backend/modules/upload_service.dart';
import 'package:komet/backend/modules/webapp.dart';
import 'package:komet/frontend/screens/webapp/open_mini_app.dart';
import 'package:komet/core/media/clipboard/clipboard_media.dart';
import 'package:komet/core/media/clipboard/pasted_attachment.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:komet/frontend/screens/contacts/open_contact_profile.dart';
import 'package:komet/frontend/screens/chats/chat_list_screen.dart';
import 'package:komet/frontend/screens/chats/poll_create_screen.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/chat_menu_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../l10n/app_localizations.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../backend/modules/contacts.dart';
import '../../../models/animoji.dart';
import '../../../backend/modules/complaints.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/media/rlottie/rlottie.dart';
import '../calls/call_screen.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/push/notification_bridge.dart';
import '../../../core/push/push_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/chat_activity_store.dart';
import '../../../core/storage/chat_members_store.dart';
import '../../../core/crypto/chat_crypto_service.dart';
import '../../../core/storage/chat_encryption_store.dart';
import '../../../core/storage/chat_wallpaper_store.dart';
import '../../../core/storage/draft_store.dart';
import '../../../core/storage/archived_chats_store.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/cache/message_session_cache.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/emoji_keyword_index.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/route_settle.dart';
import '../../../core/config/app_cache_extent.dart';
import '../../../core/config/app_swipe_back_desktop.dart';
import 'chat/chat_prank_controller.dart';
import 'chat/chat_controller.dart';
import 'chat/read_marker_gate.dart';
import 'chat/chat_scroll_navigator.dart';
import 'chat/voice_record_controller.dart';
import 'chat/video_note_controller.dart';
import 'chat/command_panel_controller.dart';
import 'chat/sticker_panel_controller.dart';
import 'chat/chat_search_controller.dart';
import 'chat/message_search_result.dart';
import 'chat/typing_label.dart';
import 'chat/upload_status.dart';
import 'chat/mention_panel_controller.dart';
import 'chat/chat_media_send_controller.dart';
import 'chat/chat_text_send_controller.dart';
import 'chat/view/message_list_decorations.dart';
import 'chat/view/message_row_widgets.dart';
import 'chat/view/scroll_down_button.dart';
import 'chat/view/throttled_message_scrollbar.dart';
import 'chat/view/chat_app_bar.dart';
import 'chat/view/composer_area.dart';
import 'chat/view/chat_body_layout.dart';
import 'chat/view/shimmer_loading.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import '../../../core/config/komet_settings.dart';
import '../../../models/attachment.dart';
import '../../../models/contact_info.dart';
import '../../commands/commands.dart';
import '../../widgets/rich_message_controller.dart';
import '../../../core/utils/text_format.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/photo_viewer.dart';
import '../../widgets/message_actions_overlay.dart';
import '../../widgets/lottie_image.dart';
import '../../widgets/attachment/attachment_sheet.dart';
import '../../widgets/attachment/paste_preview_sheet.dart';
import '../../widgets/sticker_pack_sheet.dart';
import '../../widgets/swipe_to_pop.dart';
import '../../widgets/swipe_route.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/schedule_time_picker.dart';
import '../../widgets/chat_wallpaper_sheet.dart';
import 'scheduled_messages_screen.dart';
import 'chat_encryption_screen.dart';
import 'chat_wallpaper_preview_screen.dart';
import 'profile_action_sheets.dart';
import '../../../core/media/media_playback.dart';
import '../../../core/config/app_shape.dart';

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

class ReplyRequest {
  final int sourceChatId;
  final CachedMessage message;

  const ReplyRequest({required this.sourceChatId, required this.message});
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool? channelSubscribed;
  final bool embedded;
  final VoidCallback? onClose;
  final ForwardRequest? forwardRequest;
  final ReplyRequest? replyRequest;
  final String? initialMessageId;
  final int? initialMessageTime;
  final String? commentPostId;
  final CachedMessage? postMessage;
  final String? botStartPayload;
  final String? initialText;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.channelSubscribed,
    this.embedded = false,
    this.onClose,
    this.forwardRequest,
    this.replyRequest,
    this.initialMessageId,
    this.initialMessageTime,
    this.commentPostId,
    this.postMessage,
    this.botStartPayload,
    this.initialText,
  });

  static final List<_ChatScreenState> _open = [];

  static bool startBotInVisibleChat(int chatId, String startPayload) {
    for (final screen in _open.reversed) {
      if (screen.widget.chatId != chatId) continue;
      if (!screen.mounted || !screen._isRouteCurrent) continue;
      unawaited(screen._sendBotStart(startPayload));
      return true;
    }
    return false;
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, ReloadOnReconnect {
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
  bool _initialPositionDone = false;
  bool _positioningInFlight = false;
  int _historyAutoloadSuppressCount = 0;
  bool get _historyAutoloadSuppressed => _historyAutoloadSuppressCount > 0;
  int _readMarkTime = 0;
  late final ReadMarkerGate _readMarker = ReadMarkerGate(
    onFlush: _updateReadMarker,
  );
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _unreadSeparatorKey = GlobalKey();
  final Object _profileHeroTag = UniqueKey();
  final ValueNotifier<bool> _hasText = ValueNotifier(false);
  SlashCommand? _selectedCommand;
  bool _commandExecuting = false;
  Map<String, TextEditingController> _commandArgumentControllers = {};
  Map<String, FocusNode> _commandArgumentFocusNodes = {};
  bool _isLoading = true;
  bool _encryptionEnabled = false;
  final ValueNotifier<bool> _showAttachmentPanel = ValueNotifier(false);
  bool _pastePending = false;
  late final StickerPanelController _stickers;
  final ValueNotifier<UploadStatus> _uploadStatus = ValueNotifier(
    const UploadStatus(),
  );
  late final ChatMediaSendController _mediaSend;
  StreamSubscription<Packet>? _pushSub;
  StreamSubscription<MessageEvent>? _messageEventSub;
  StreamSubscription<Map<String, CommentsInfo>>? _commentsInfoSub;
  StreamSubscription<CommentAddedEvent>? _commentSub;
  final Map<String, int> _commentCounts = {};
  final Set<String> _commentCountsRequested = {};
  bool get _commentsMode => widget.commentPostId != null;
  bool _commentsLoadingMore = false;
  bool _commentsHasMore = true;
  StreamSubscription<SessionState>? _connSub;
  final Map<String, ValueNotifier<Map<String, dynamic>?>> _reactionNotifiers =
      {};
  final ValueNotifier<ReactionAnimationEvent?> _reactionAnimation =
      ValueNotifier(null);
  int _reactionAnimationToken = 0;
  final ValueNotifier<int> _scheduledCount = ValueNotifier(0);

  late final VoiceRecordController _voiceRec = VoiceRecordController(
    contextOf: () => context,
    isMounted: () => mounted,
    myId: () => _myId,
    onRecorded: _mediaSend.sendVoice,
  );

  late final VideoNoteController _note = VideoNoteController(
    contextOf: () => context,
    isMounted: () => mounted,
    onRecorded: _mediaSend.sendVideoNote,
    formatElapsed: formatVoiceElapsed,
    bottomInset: () => _composerHeight.value,
  );

  StreamSubscription<UploadJobEvent>? _uploadEventSub;

  ValueListenable<List<double>>? _photoProgressFor(CachedMessage m) =>
      UploadService.instance.progressFor(m.id);

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
    final appliedReaction = result.info?['yourReaction']?.toString();
    if (!isToggleOff &&
        appliedReaction != null &&
        EmojiKeywordIndex.normalize(appliedReaction) ==
            EmojiKeywordIndex.normalize(emoji)) {
      final event = ReactionAnimationEvent(
        messageId: message.id,
        emoji: appliedReaction,
        token: ++_reactionAnimationToken,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reactionAnimation.value = event;
      });
    }
  }

  void _applyReactionInfoToMessage(
    String messageId,
    Map<String, dynamic>? info,
  ) {
    final idx = _chatController.indexOfId(messageId);
    if (idx == -1) return;
    final payload = <String, dynamic>{...?_messages[idx].payload};
    if (info == null) {
      payload.remove('reactionInfo');
    } else {
      payload['reactionInfo'] = info;
    }
    _chatController.setMessageAt(idx, _messages[idx].copyWith(payload: payload));
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
        EmojiKeywordIndex.normalize(prev) ==
            EmojiKeywordIndex.normalize(emoji)) {
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

  final ValueNotifier<CachedMessage?> _replyTo = ValueNotifier(null);
  final ValueNotifier<List<CachedMessage>> _pendingForwards = ValueNotifier(
    const [],
  );
  static const bool _crossChatReplySupported = false;
  late final ChatTextSendController _textSend;

  late final RouteSettle _routeSettle = RouteSettle(isMounted: () => mounted);

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
  late final AnimationController _attachAnim;
  late final CommandPanelController _commandPanel;
  late final MentionPanelController _mentionPanel;

  late AnimationController _shimmerController;
  Timer? _shimmerStartTimer;
  bool _previewChat = false;
  // #***! чат ещё не в списке (первое сообщение новому диалогу/каналу без
  // подписки) — сброшено в true по умолчанию, чтобы не мешать обычным
  // чатам; настоящее состояние узнаём асинхронно в _fastPreloadCache.
  bool _chatInList = true;
  bool _subscribing = false;
  String? _channelLink;
  final ChatController _chatController = ChatController();
  late final ChatScrollNavigator _scrollNav;

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
  static const double _pinnedBannerLift = 6.0;
  static const double _unreadSeparatorHeight = 30.0;
  static const double _unreadSeparatorInset = 72.0;
  static const double _unreadAnchorFallbackAlignment = 0.3;

  final BackdropKey _barBackdrop = BackdropKey();
  final BackdropKey _pillBackdrop = BackdropKey();
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
  bool _botStartRequested = false;
  ChatWallpaper? _wallpaper;

  bool get _composerFrosted =>
      AppComposerBackground.current.value != ComposerBackground.standard;

  bool get _composerUnderlap =>
      AppChatChrome.current.value != ChatChromeStyle.color || _composerFrosted;

  bool get _materialComposer =>
      !ComposerChrome.isGlossy(AppComposerStyle.current.value);

  bool get _composerPaintsSurface {
    if (!_commentsMode &&
        widget.chatType == 'CHANNEL' &&
        _pendingForwards.value.isEmpty) {
      return false;
    }
    return _materialComposer && !_composerFrosted;
  }

  bool get _liquidChrome =>
      AppVisualStyle.current.value.glossyChrome &&
      ChatChromeMaterial.isLiquid(AppChatChrome.current.value);

  ChatChromeStyle get _effectiveChrome {
    final chrome = AppChatChrome.current.value;
    if (chrome == ChatChromeStyle.liquidGlass) {
      return ChatChromeStyle.transparent;
    }
    return chrome;
  }

  bool get _chromeVignette =>
      _effectiveChrome == ChatChromeStyle.none && _wallpaper == null;

  final ValueNotifier<double> _composerHeight = ValueNotifier(96);
  final ValueNotifier<double> _pinnedBannerHeight = ValueNotifier(0);

  final ValueNotifier<DateTime?> _floatingDate = ValueNotifier(null);
  Timer? _floatingDateTimer;
  late final AnimationController _floatingDateAnimController;
  late final CurvedAnimation _floatingDateCurved;
  late final AnimationController _scrollDownAnimController;
  late final CurvedAnimation _scrollDownCurved;
  final Set<String> _deferredIds = <String>{};
  final Map<int, GlobalKey> _separatorKeys = {};
  String? _lastSentId;
  final ValueNotifier<int> _otherUnread = ValueNotifier(0);
  final ValueNotifier<bool> _animojiHold = ValueNotifier(true);

  final ValueNotifier<Set<String>> _selectedIds = ValueNotifier(const {});
  final ValueNotifier<Offset?> _textSelectionDrag = ValueNotifier(null);
  final ValueNotifier<({String id, Offset pos})?> _textSelection =
      ValueNotifier(null);
  late final AnimationController _selectionAnim;

  bool get _selectionMode => _selectedIds.value.isNotEmpty;

  void _prewarmQuickReactions() {
    if (!mounted || !RlottieEngine.instance.available) return;
    final dpr = (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0).clamp(
      1.0,
      2.0,
    );
    final px = ((44.0 * dpr).clamp(96.0, 512.0) / 32).ceil() * 32;
    for (final a in animojiModule.quickAnimojis) {
      for (final url in [a.lottieUrl, a.lottiePlayUrl]) {
        if (url != null && url.isNotEmpty) {
          unawaited(RlottieEngine.instance.prewarm(url, px));
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _previewChat = widget.channelSubscribed == false;
    _chatController.chatId = widget.chatId;
    _chatController.isMounted = () => mounted;
    _mediaSend = ChatMediaSendController(
      chatController: _chatController,
      showAttachmentPanel: _showAttachmentPanel,
      uploadStatus: _uploadStatus,
      bumpMessages: _bumpMessages,
      scrollToBottom: () => _scrollNav.scrollToBottom(),
      setLastSentId: (id) => _lastSentId = id,
      notify: (msg) {
        if (mounted) showCustomNotification(context, msg);
      },
      isMounted: () => mounted,
      encryptionEnabled: () => _encryptionEnabled,
      encryptOutgoing: _encryptOutgoing,
      markHasScheduled: _markHasScheduled,
    );
    if (!_commentsMode) ChatScreen._open.add(this);
    unawaited(PushService.clearChatNotification(widget.chatId));
    if (!_commentsMode) {
      unawaited(NotificationBridge.instance.pushActiveChat(widget.chatId));
    }
    unawaited(
      animojiModule
          .ensureLoaded()
          .then((_) {
            _prewarmQuickReactions();
            if (mounted) _bumpMessages();
          })
          .catchError((_) {}),
    );
    WidgetsBinding.instance.addObserver(this);
    _uploadEventSub = UploadService.instance.events.listen(
      _mediaSend.onUploadEvent,
    );
    _mediaSend.syncUploadStatus();
    chats.chatsChanged.addListener(_onChatsBump);
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollForDate);
    _scrollController.addListener(_maybeLoadMoreHistory);
    _scrollController.addListener(_recordScrollPixels);
    _scrollController.addListener(_scheduleReadMarker);
    MediaPlayback.instance.enterChat(widget.chatId);
    AppVisualStyle.current.addListener(_onVisualStyleChanged);
    AppChatChrome.current.addListener(_onVisualStyleChanged);
    AppComposerStyle.current.addListener(_onVisualStyleChanged);
    AppComposerBackground.current.addListener(_onVisualStyleChanged);
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
    _mentionPanel = MentionPanelController(
      vsync: this,
      chatId: widget.chatId,
      enabled: _mentionsAvailable,
      selfId: () => _myId,
      valueOf: () => _messageController.value,
      onSelected: _onMentionSelected,
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
    _textSend = ChatTextSendController(
      chatController: _chatController,
      messageController: _messageController,
      hasText: _hasText,
      replyTo: _replyTo,
      pendingForwards: _pendingForwards,
      commentsMode: _commentsMode,
      commentPostId: widget.commentPostId,
      bumpMessages: _bumpMessages,
      scrollToBottom: () => _scrollNav.scrollToBottom(),
      focusComposer: _messageFocusNode.requestFocus,
      setLastSentId: (id) => _lastSentId = id,
      notify: (msg) {
        if (mounted) showCustomNotification(context, msg);
      },
      isMounted: () => mounted,
      contextOf: () => context,
      chatOf: () => chat,
      setChat: (value) {
        if (mounted) setState(() => chat = value);
      },
      isChatListed: () => _chatInList,
      markChatListed: () {
        if (mounted) setState(() => _chatInList = true);
      },
      encryptOutgoing: _encryptOutgoing,
      executeCommand: _executeCommand,
      checkPrankTrigger: _prank.checkTrigger,
      syncOtherReadTime: _syncOtherReadTime,
    );
    final incomingReply = widget.replyRequest;
    if (incomingReply != null) {
      _replyTo.value = incomingReply.message;
      _textSend.replySourceChatId =
          incomingReply.sourceChatId == widget.chatId
          ? null
          : incomingReply.sourceChatId;
    }
    final incomingForward = widget.forwardRequest;
    if (incomingForward != null) {
      _textSend.forwardRequest = incomingForward;
      _pendingForwards.value = incomingForward.messages;
    }
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
    if (_commentsMode) {
      _commentSub = commentsModule.commentStream
          .where(
            (e) =>
                e.chatId == widget.chatId && e.postId == widget.commentPostId,
          )
          .listen(_onLiveComment);
    } else if (widget.chatType == 'CHANNEL') {
      _commentsInfoSub = commentsModule.infoStream.listen(_onCommentsInfo);
    }
    ChatActivityStore.instance
        .listenable(widget.chatId)
        .addListener(_recomputeHeaderStatus);
    ChatMembersStore.instance
        .listenable(widget.chatId)
        .addListener(_recomputeHeaderStatus);
    _connSub = api.stateStream.listen((_) {
      if (mounted) _recomputeHeaderStatus();
    });
    debugForceOffline.addListener(_recomputeHeaderStatus);
    PresenceFetch.revision.addListener(_onPresenceChanged);
    ContactsModule.revision.addListener(_onContactsChanged);
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
    _scrollDownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scrollDownCurved = CurvedAnimation(
      parent: _scrollDownAnimController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scrollNav = ChatScrollNavigator(
      scrollController: _scrollController,
      chatController: _chatController,
      shimmerController: _shimmerController,
      scrollDownAnimController: _scrollDownAnimController,
      scrollDownCurved: _scrollDownCurved,
      readMarker: _readMarker,
      listKey: _listKey,
      keyForMessage: _keyForMessage,
      buildCombinedItems: _buildCombinedItems,
      messageIdOf: _messageIdOfItem,
      messageOffsetInList: _messageOffsetInList,
      loadMessageWindow: _loadMessageWindow,
      flushDeferredMessages: _flushDeferredMessages,
      isDeferred: (id) => _deferredIds.contains(id),
      hasDeferredMessages: () => _deferredIds.isNotEmpty,
      bumpMessages: _bumpMessages,
      clearPinnedMessage: () => _pinnedMessageId = null,
      isMounted: () => mounted,
      notifyState: setState,
      showNotification: (message) => showCustomNotification(context, message),
      initialMessageIdOf: () => widget.initialMessageId,
      initialMessageTimeOf: () => widget.initialMessageTime,
    );
    _scrollController.addListener(_scrollNav.updateScrollDownVisible);

    unawaited(_fastPreloadCache());
    unawaited(_loadParticipantsCount());
    WidgetsBinding.instance.addPostFrameCallback(_onFirstFrameRendered);
  }

  @override
  void reloadAfterReconnect() {
    if (!_historyKickedOff) return;
    unawaited(_loadHistory());
    unawaited(_loadParticipantsCount());
  }

  Future<void> _loadParticipantsCount() async {
    if (_commentsMode) return;
    if (widget.chatType != 'CHAT' && widget.chatType != 'CHANNEL') return;
    final info = await chats.getChatInfo(api, widget.chatId);
    if (!mounted) return;
    if (widget.chatType == 'CHANNEL') {
      final link = info?['link'];
      if (link is String && link.isNotEmpty) _channelLink = link;
    }
  }

  Future<void> _loadPeerKind() async {
    if (widget.chatType != 'DIALOG' || _myId == 0) return;
    final peerId = widget.chatId ^ _myId;
    if (peerId <= 0) return;
    final cached = ContactInfoFetch.peek(peerId);
    if (cached != null) _applyPeerInfo(peerId, cached);
    final info = await ContactInfoFetch.get(peerId);
    if (info != null) _applyPeerInfo(peerId, info);
    if ((info ?? cached)?.isBot ?? false) {
      unawaited(BotInfoFetch.get(peerId));
    }
  }

  void _applyPeerInfo(int peerId, ContactInfo info) {
    if (!mounted) return;
    final avatar = info.avatarUrl;
    final avatarIsNew =
        avatar != null &&
        avatar.isNotEmpty &&
        ContactCache.getAvatar(peerId) != avatar;
    if (avatarIsNew) ContactCache.putAvatar(peerId, avatar);
    if (_peerIsBot == info.isBot && !avatarIsNew) return;
    setState(() => _peerIsBot = info.isBot);
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
    if (_commentsMode) return;
    _restoreDraft();
    unawaited(_loadPeerKind());
    unawaited(_loadWallpaper());
    unawaited(_loadEncryption());
    unawaited(_refreshBadge());

    try {
      final chatRows = await chats.getChat(_myId, widget.chatId);
      if (!mounted) return;
      final inList = await AppDatabase.isChatInList(_myId, widget.chatId);
      if (!mounted) return;
      if (inList != _chatInList) setState(() => _chatInList = inList);
      if (widget.chatType == 'CHANNEL') {
        final preview = !inList;
        if (preview != _previewChat) setState(() => _previewChat = preview);
      }
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
        _deferredIds.clear();
        _hasMoreHistory = !cached.reachedStart;
        _messagesRev.value++;
      });
      _mediaSend.mergePendingMedia();
      _syncReactionNotifiersFromMessages();
      _requestCommentCounts();
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
        _deferredIds.clear();
        _messagesRev.value++;
      });
      _mediaSend.mergePendingMedia();
      _requestCommentCounts();
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
    if (!_commentsMode) unawaited(_loadLocalHistoryFast());
    if (widget.embedded) {
      _routeSettle.settleNow();
    } else {
      _routeSettle.bind(context);
    }
    _routeSettle.run(_kickoffHistory);
  }

  List<CachedMessage>? _fastLocalDecoded;
  bool _fastLocalStarted = false;

  // #***! читаем сообщения из локальной БД сразу, не дожидаясь конца
  // анимации перехода (её ждёт только сетевая часть в _loadHistory)
  Future<void> _loadLocalHistoryFast() async {
    if (_fastLocalStarted) return;
    _fastLocalStarted = true;
    if (_myId == 0) {
      final activeProfile = await AppDatabase.loadActiveProfile();
      if (!mounted) return;
      _myId = activeProfile?.id ?? 0;
    }
    if (!mounted) return;
    _fastLocalDecoded = await _chatController.loadLocalHistory(
      onApplyMerged: _applyMergedMessages,
    );
  }

  void _kickoffHistory() {
    _animojiHold.value = false;
    if (_historyKickedOff) return;
    _historyKickedOff = true;
    _shimmerStartTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_isLoading) return;
      _shimmerController.repeat();
    });
    unawaited(_loadHistory().then((_) => _sendPendingBotStart()));
  }

  bool get _isRouteCurrent {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _sendPendingBotStart() async {
    final payload = widget.botStartPayload;
    if (payload == null || _botStartRequested || !mounted) return;
    _botStartRequested = true;
    await _sendBotStart(payload);
  }

  Future<void> _sendBotStart(String startPayload) async {
    if (_myId == 0) {
      final profile = await AppDatabase.loadActiveProfile();
      if (!mounted) return;
      _myId = profile?.id ?? 0;
    }
    try {
      final sent = await messagesModule.sendBotStart(
        widget.chatId,
        startPayload,
      );
      if (!mounted) return;
      if (sent == null) {
        showCustomNotification(context, 'Не удалось запустить бота');
        return;
      }
      await _chatController.persistOutgoing(
        CachedMessage.fromPushPayload(_myId, widget.chatId, sent),
      );
    } catch (_) {
      if (mounted) showCustomNotification(context, 'Не удалось запустить бота');
    }
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

  double _unreadAnchorAlignment() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || listBox.size.height <= 0) {
      return _unreadAnchorFallbackAlignment;
    }
    final separator =
        _unreadSeparatorKey.currentContext?.size?.height ??
        _unreadSeparatorHeight;
    final glossy = AppVisualStyle.current.value.glossyChrome;
    final chromeBottom = _effectiveChrome == ChatChromeStyle.color
        ? 0.0
        : MediaQuery.paddingOf(context).top +
              (glossy ? _glossyHeaderHeight : kToolbarHeight) +
              _pinnedBannerHeight.value;
    final desiredTop = chromeBottom + separator + _unreadSeparatorInset;
    return (desiredTop / listBox.size.height).clamp(0.0, 0.5);
  }

  void _positionToMessage(String messageId) {
    _pinnedMessageId = messageId;
    _scrollNav.jumpCacheExtent.value = ChatScrollNavigator.jumpCacheExtentPx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pinnedAlignment = _unreadAnchorAlignment();
      _scrollNav.scrollToLoadedMessage(
        messageId,
        alignment: _pinnedAlignment,
        highlight: false,
        notifyIfMissing: false,
        onSettled: () {
          if (!mounted) return;
          setState(_markPositioned);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollNav.jumpCacheExtent.value = null;
            _reapplyPinIfNeeded();
          });
        },
      );
    });
  }

  void _reapplyPinIfNeeded() {
    final id = _pinnedMessageId;
    if (id == null || _userDidScroll || !_scrollController.hasClients) return;
    _holdReadMarker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pinnedMessageId != id || _userDidScroll) {
        _releaseReadMarker();
        return;
      }
      _scrollNav.alignLoadedMessage(
        id,
        _pinnedAlignment,
        0,
        onSettled: _releaseReadMarker,
      );
    });
  }

  void _applyInitialPositioning() {
    if (_initialPositionDone) {
      if (_shimmerController.isAnimating) _shimmerController.stop();
      _scheduleReadMarker();
      return;
    }
    if (_positioningInFlight) return;
    if (_commentsMode) {
      _initialPositionDone = true;
      _markPositioned();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
      return;
    }
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
        _positionToMessage(_messages[firstUnread].id);
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
    _scrollNav.maybeRunInitialTarget();
  }

  void _openChatInfo({ChatInfoTab? initialTab}) {
    final navigator = Navigator.of(context);
    final chatRoute = ModalRoute.of(context);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          chatId: widget.chatId,
          name: _headerName(),
          imageUrl: _headerAvatarUrl(),
          chatType: widget.chatType,
          heroTag: _profileHeroTag,
          initialTab: initialTab,
          openedFromChat: true,
          onJumpToMessage: (chatRoute == null || widget.embedded)
              ? null
              : (messageId, time) {
                  navigator.popUntil((r) => r == chatRoute);
                  _requestGoToMessage(messageId, time);
                },
        ),
      ),
    );
  }

  late final PhotoViewerActions _photoActions = PhotoViewerActions(
    goToMessage: _requestGoToMessage,
    forward: _forwardMessageById,
    delete: (messageId, senderId) =>
        _confirmDeleteMessage(messageId, senderId == _myId),
    viewAllMedia: () => _openChatInfo(initialTab: ChatInfoTab.media),
  );

  void _forwardMessageById(String messageId) {
    final message = _chatController.byId(messageId);
    if (message == null) {
      showCustomNotification(context, 'Сообщение не загружено');
      return;
    }
    unawaited(_forwardMessages([message]));
  }

  void _requestGoToMessage(String id, int time) {
    _scrollNav.requestGoToMessage(id, time);
  }

  Future<void> _loadUntilUnreadReady() async {
    await _walkHistoryBack(
      reached: () {
        if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
        final ua = _unreadAnchorTime;
        return ua != null && _messages.indexWhere((m) => m.time > ua) > 0;
      },
      maxPages: 15,
    );
    if (!mounted) return;
    if (_unreadAnchorTime == null) _resolveCountBasedAnchor();
    final ua = _unreadAnchorTime;
    final idx = ua == null ? -1 : _messages.indexWhere((m) => m.time > ua);
    _positioningInFlight = false;
    _initialPositionDone = true;
    if (idx >= 0) {
      _positionToMessage(_messages[idx].id);
    } else {
      setState(_markPositioned);
    }
  }

  void _scheduleReadMarker() => _readMarker.schedule();

  void _holdReadMarker() => _readMarker.hold();

  void _releaseReadMarker() => _readMarker.release();

  void _updateReadMarker() {
    if (_commentsMode) return;
    if (!mounted || _myId == 0 || _messages.isEmpty) return;
    if (_awaitingPosition || !_initialPositionDone) return;
    if (_readMarker.held) return;
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
        _userDidScroll &&
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

  bool _canShowReadBy(CachedMessage message) {
    if (message.isControl || message.deleted) return false;
    if (int.tryParse(message.id) == null) return false;
    final type = chat?.type ?? widget.chatType;
    return type == 'CHAT' || type == 'GROUP';
  }

  Future<List<MessageReader>> _loadReadBy(CachedMessage message) async {
    final marks = await chats.getReadMarks(api, _myId, widget.chatId);
    final reactions = await messagesModule.getDetailedReactions(
      widget.chatId,
      message.id,
    );

    final readerIds = <int>{
      ...marks.entries.where((e) => e.value >= message.time).map((e) => e.key),
      ...reactions.keys,
    }..removeAll({_myId, message.senderId});
    if (readerIds.isEmpty || !mounted) return const [];

    await messagesModule.ensureContactNames(readerIds);
    await animojiModule.ensureLoaded();
    if (!mounted) return const [];

    final animojiByEmoji = {
      for (final animoji in animojiModule.animojis)
        EmojiKeywordIndex.normalize(animoji.emoji): animoji,
    };
    final unknownName = AppLocalizations.of(
      context,
    )!.msgActionsReadByUnknownUser;

    final readers = readerIds.map((id) {
      final emoji = reactions[id];
      final animoji = emoji == null
          ? null
          : animojiByEmoji[EmojiKeywordIndex.normalize(emoji)];
      final name = ContactCache.get(id);
      return MessageReader(
        id: id,
        name: name == null || name.isEmpty ? unknownName : name,
        avatarUrl: ContactCache.getAvatar(id),
        reaction: emoji == null
            ? null
            : ReactionEmoji(
                emoji: emoji,
                animationUrl: animoji?.lottieUrl,
                staticUrl: animoji?.iconUrl,
              ),
      );
    }).toList();

    readers.sort((a, b) {
      final aReacted = a.reaction != null;
      final bReacted = b.reaction != null;
      if (aReacted != bReacted) return aReacted ? -1 : 1;
      return (marks[b.id] ?? 0).compareTo(marks[a.id] ?? 0);
    });
    return readers;
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
    _scrollNav.jumpToPinnedMessage(
      pinnedMsgId: chat?.pinnedMsgId,
      pinnedMsgTime: chat?.pinnedMsgTime,
    );
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
    if (_commentsMode) {
      await _loadCommentsHistory();
      return;
    }
    if (widget.chatType == 'DIALOG') {
      unawaited(_loadOtherPresence());
    }
    unawaited(_refreshScheduledCount());
    final localDecoded =
        _fastLocalDecoded ??
        await _chatController.loadLocalHistory(
          onApplyMerged: _applyMergedMessages,
        );
    if (!mounted) return;
    await _chatController.loadRemainingHistory(
      localDecoded: localDecoded,
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
    if (_historyAutoloadSuppressed) return;
    if (_isLoading) return;
    if (_commentsMode) {
      if (_commentsLoadingMore || !_commentsHasMore || _messages.isEmpty) {
        return;
      }
      final pos = _scrollController.position;
      if (pos.pixels - pos.minScrollExtent <= _historyPrefetchExtent) {
        unawaited(_loadMoreComments());
      }
      return;
    }
    _maybeFillGap();
    if (_isLoadingMore || !_hasMoreHistory) return;
    if (_messages.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.maxScrollExtent - pos.pixels <= _historyPrefetchExtent) {
      unawaited(_loadMoreHistory());
    }
  }

  void _maybeFillGap() {
    final controller = _chatController;
    if (!controller.hasGap || controller.loadingGap) return;
    final oldestRendered = _oldestRenderedMessageTime();
    for (final gap in controller.gaps) {
      if (!ChatController.gapFillLeavesViewportInPlace(gap, oldestRendered)) {
        continue;
      }
      unawaited(_fillGapForward(gap));
      return;
    }
  }

  int? _oldestRenderedMessageTime() {
    for (final message in _messages) {
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached) return message.time;
    }
    return null;
  }

  Future<void> _fillGapForward(HistoryGap gap) async {
    String? anchorId;
    double? anchorAt;
    double? anchorAlignment;
    final added = await _chatController.fillGapForward(
      gap,
      beforeApply: () {
        final id = _viewportAnchorId();
        anchorId = id;
        if (id == null) return;
        anchorAt = _messageContentOffset(id);
        anchorAlignment = _messageAlignmentInList(id);
      },
    );
    if (!mounted || added == 0) return;

    _syncReactionNotifiersFromMessages();
    _holdReadMarker();
    _bumpMessages();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _releaseReadMarker();
      return;
    }

    final id = anchorId;
    final at = anchorAt;
    final alignment = anchorAlignment;
    if (id != null && at != null && !_restoreContentOffset(id, at)) {
      _historyAutoloadSuppressCount++;
      _scrollNav.alignLoadedMessage(
        id,
        alignment ?? 0,
        0,
        epoch: _scrollNav.gestureEpoch,
        onSettled: () {
          _historyAutoloadSuppressCount--;
          _releaseReadMarker();
        },
      );
    } else {
      _releaseReadMarker();
    }
    _loadForwardedSenderNames();
    _loadGroupSenderNames();
  }

  int get _visibleMessageCount {
    if (_deferredIds.isEmpty) return _messages.length;
    var visible = _messages.length;
    while (visible > 0 && _deferredIds.contains(_messages[visible - 1].id)) {
      visible--;
    }
    return visible;
  }

  void _flushDeferredMessages() {
    if (_deferredIds.isEmpty) return;
    _deferredIds.clear();
    _bumpMessages();
  }

  String? _viewportAnchorId() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.attached) return null;
    final height = listBox.size.height;
    String? newest;
    for (final message in _messages) {
      final box = _messageKeys[message.id]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
      if (dy >= 0 && dy <= height) newest = message.id;
    }
    return newest;
  }

  double? _messageOffsetInList(String messageId) {
    final listBox = _listKey.currentContext?.findRenderObject();
    final box = _keyForMessage(messageId).currentContext?.findRenderObject();
    if (listBox is! RenderBox || box is! RenderBox || !box.attached) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: listBox).dy;
  }

  double? _messageContentOffset(String messageId) {
    if (!_scrollController.hasClients) return null;
    final dy = _messageOffsetInList(messageId);
    if (dy == null) return null;
    return dy - _scrollController.position.pixels;
  }

  double? _messageAlignmentInList(String messageId) {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || listBox.size.height <= 0) return null;
    final dy = _messageOffsetInList(messageId);
    if (dy == null) return null;
    return (dy / listBox.size.height).clamp(0.0, 1.0);
  }

  bool _restoreContentOffset(String messageId, double before) {
    if (!_scrollController.hasClients) return false;
    final after = _messageContentOffset(messageId);
    if (after == null) return false;
    final delta = before - after;
    if (delta.abs() <= 0.5) return true;
    final pos = _scrollController.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() <= 0.5) return true;
    _scrollController.jumpTo(target);
    return true;
  }

  Future<void> _loadMessageWindow(String messageId, int targetTime) async {
    if (targetTime <= 0) {
      await _walkHistoryBack(
        reached: () => _chatController.containsId(messageId),
        maxPages: 10,
      );
      return;
    }

    _historyAutoloadSuppressCount++;
    try {
      await _chatController.loadMessageWindow(
        targetId: messageId,
        targetTime: targetTime,
      );
    } finally {
      _historyAutoloadSuppressCount--;
    }
    if (!mounted) return;
    _syncReactionNotifiersFromMessages();
    _bumpMessages();
    _loadForwardedSenderNames();
    _loadGroupSenderNames();
  }

  Future<void> _walkHistoryBack({
    required bool Function() reached,
    required int maxPages,
    int targetTime = 0,
  }) async {
    if (reached()) return;
    _historyAutoloadSuppressCount++;
    try {
      var page = 0;
      while (mounted &&
          page < maxPages &&
          _hasMoreHistory &&
          !reached() &&
          (_messages.isEmpty || _messages.first.time > targetTime)) {
        page++;
        final before = _messages.isEmpty ? 0 : _messages.first.time;
        await _loadMoreHistory(
          resolveSenderNames: false,
          pageSize: ChatController.historyWalkPageSize,
          persist: false,
        );
        if (!mounted) return;
        final after = _messages.isEmpty ? 0 : _messages.first.time;
        if (after == before) break;
      }
    } finally {
      _historyAutoloadSuppressCount--;
    }
    if (!mounted) return;
    _chatController.persistSessionCache();
    _loadForwardedSenderNames();
    _loadGroupSenderNames();
  }

  Future<void> _loadMoreHistory({
    bool resolveSenderNames = true,
    int? pageSize,
    bool persist = true,
  }) async {
    await _chatController.loadMoreHistory(
      pageSize: pageSize,
      persist: persist,
      onLoadingStarted: _bumpMessages,
      onLoaded: (added) {
        if (added > 0) _syncReactionNotifiersFromMessages();
        _bumpMessages();
        if (resolveSenderNames) {
          _loadForwardedSenderNames();
          _loadGroupSenderNames();
        }
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
    final anchor = _captureViewportAnchor();
    final changed = _chatController.mergeMessages(decodedDesc);
    _requestCommentCounts();

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
      _restoreViewportAfterMerge(anchor);
      _reapplyPinIfNeeded();
    }
  }

  ({String id, double at, double alignment})? _captureViewportAnchor() {
    if (_pinnedMessageId != null && !_userDidScroll) return null;
    if (!_scrollController.hasClients || _scrollNav.isNearBottom()) return null;
    final id = _viewportAnchorId();
    if (id == null) return null;
    final at = _messageContentOffset(id);
    final alignment = _messageAlignmentInList(id);
    if (at == null || alignment == null) return null;
    return (id: id, at: at, alignment: alignment);
  }

  void _restoreViewportAfterMerge(
    ({String id, double at, double alignment})? anchor,
  ) {
    _holdReadMarker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || anchor == null) {
        _releaseReadMarker();
        return;
      }
      if (_restoreContentOffset(anchor.id, anchor.at)) {
        _releaseReadMarker();
        return;
      }
      _historyAutoloadSuppressCount++;
      _scrollNav.alignLoadedMessage(
        anchor.id,
        anchor.alignment,
        0,
        epoch: _scrollNav.gestureEpoch,
        onSettled: () {
          _historyAutoloadSuppressCount--;
          _releaseReadMarker();
        },
      );
    });
  }

  void _requestCommentCounts() {
    if (_commentsMode) return;
    if ((chat?.type ?? widget.chatType) != 'CHANNEL') return;
    final pending = <String>[];
    for (final m in _messages) {
      if (m.isControl) continue;
      if (_commentCountsRequested.contains(m.id)) continue;
      _commentCountsRequested.add(m.id);
      pending.add(m.id);
    }
    if (pending.isEmpty) return;
    unawaited(
      commentsModule.fetchInfo(
        accountId: _myId,
        chatId: widget.chatId,
        postIds: pending,
      ),
    );
  }

  void _onCommentsInfo(Map<String, CommentsInfo> info) {
    if (!mounted) return;
    var changed = false;
    for (final m in _messages) {
      final count = info[m.id]?.totalCount;
      if (count == null) continue;
      if (_commentCounts[m.id] != count) {
        _commentCounts[m.id] = count;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  String _commentsLabelFor(String postId) {
    final l10n = AppLocalizations.of(context)!;
    final count = _commentCounts[postId];
    if (count == null || count == 0) return l10n.commentsWrite;
    return l10n.commentsCount(count);
  }

  void _openComments(CachedMessage post) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: widget.chatId,
              name: widget.name,
              imageUrl: widget.imageUrl,
              chatType: 'CHANNEL',
              commentPostId: post.id,
              postMessage: _stripInlineKeyboard(post),
            ),
          ),
        )
        .then((_) => _refreshCommentCount(post.id));
  }

  void _refreshCommentCount(String postId) {
    if (!mounted) return;
    _commentCountsRequested.remove(postId);
    _requestCommentCounts();
  }

  CachedMessage _stripInlineKeyboard(CachedMessage post) {
    final attaches = post.attachments;
    if (attaches == null || attaches.isEmpty) return post;
    final filtered = attaches
        .where((a) => a.type != AttachmentType.inlineKeyboard)
        .toList();
    if (filtered.length == attaches.length) return post;
    return post.copyWith(attachments: filtered);
  }

  Future<void> _loadCommentsHistory() async {
    final post = widget.postMessage;
    final loaded = await commentsModule.fetchHistory(
      _myId,
      widget.chatId,
      widget.commentPostId!,
      fromTime: post?.time ?? DateTime.now().millisecondsSinceEpoch,
      forward: 30,
      backward: 0,
    );
    if (!mounted) return;
    final comments = [...loaded]..sort((a, b) => a.time.compareTo(b.time));
    _messages = post != null ? [post, ...comments] : comments;
    _deferredIds.clear();
    _commentsHasMore = comments.isNotEmpty;
    _syncReactionNotifiersFromMessages();
    unawaited(_resolveCommentNames(comments));
    _bumpMessages();
    setState(() {
      _isLoading = false;
      _onLoadingFinished();
    });
  }

  Future<void> _loadMoreComments() async {
    if (_commentsLoadingMore || !_commentsHasMore || _messages.isEmpty) return;
    _commentsLoadingMore = true;
    final newest = _messages.last;
    try {
      final more = await commentsModule.fetchHistory(
        _myId,
        widget.chatId,
        widget.commentPostId!,
        fromTime: newest.time,
        forward: 30,
        backward: 0,
      );
      if (!mounted) return;
      final existing = _messages.map((m) => m.id).toSet();
      final fresh = more.where((c) => !existing.contains(c.id)).toList();
      if (fresh.isEmpty) {
        _commentsHasMore = false;
      } else {
        _messages = [..._messages, ...fresh]
          ..sort((a, b) => a.time.compareTo(b.time));
        _syncReactionNotifiersFromMessages();
        unawaited(_resolveCommentNames(fresh));
        _bumpMessages();
      }
    } finally {
      _commentsLoadingMore = false;
    }
  }

  void _onLiveComment(CommentAddedEvent event) {
    if (!mounted) return;
    final comment = event.comment;
    if (comment.senderId == _myId) return;
    if (_chatController.containsId(comment.id)) return;
    final nearBottom = _isNearListBottom();
    if (!nearBottom) _deferredIds.add(comment.id);
    _chatController.addMessage(comment);
    _syncReactionNotifiersFromMessages();
    _bumpMessages();
    unawaited(_resolveCommentNames([comment]));
    if (nearBottom) {
      _scrollNav.scrollToBottom();
    } else {
      _scrollNav.noteMissedMessage();
    }
  }

  bool _isNearListBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= _historyPrefetchExtent;
  }

  Future<void> _resolveCommentNames(List<CachedMessage> list) async {
    final ids = list
        .map((m) => m.senderId)
        .where((id) => id != 0 && ContactCache.get(id) == null)
        .toSet();
    if (ids.isEmpty) return;
    final resolved = await messagesModule.ensureContactNames(ids);
    if (resolved && mounted) _bumpMessages();
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
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_voiceRec.isRecording.value) {
        unawaited(_voiceRec.stop(cancel: true));
      }
      if (_note.isRecording.value) {
        unawaited(_note.stop(cancel: true));
      }
    }
    if (state != AppLifecycleState.resumed) _saveDraft();
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
    ChatScreen._open.remove(this);
    if (!_commentsMode) {
      unawaited(NotificationBridge.instance.popActiveChat(widget.chatId));
    }
    _chatController.persistSessionCache();
    if (_previewChat) {
      unawaited(chats.subscribeChat(api, widget.chatId, subscribe: false));
    }
    WidgetsBinding.instance.removeObserver(this);
    _uploadEventSub?.cancel();
    chats.chatsChanged.removeListener(_onChatsBump);
    _otherUnread.dispose();
    _animojiHold.dispose();
    _saveDraft();
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollForDate);
    _scrollController.removeListener(_maybeLoadMoreHistory);
    _scrollController.removeListener(_recordScrollPixels);
    _scrollController.removeListener(_scheduleReadMarker);
    _scrollController.removeListener(_scrollNav.updateScrollDownVisible);
    _readMarker.dispose();
    AppVisualStyle.current.removeListener(_onVisualStyleChanged);
    MediaPlayback.instance.leaveChat(widget.chatId);
    AppChatChrome.current.removeListener(_onVisualStyleChanged);
    AppComposerStyle.current.removeListener(_onVisualStyleChanged);
    AppComposerBackground.current.removeListener(_onVisualStyleChanged);
    _composerHeight.dispose();
    _pinnedBannerHeight.dispose();
    _floatingDateTimer?.cancel();
    _floatingDateCurved.dispose();
    _floatingDateAnimController.dispose();
    _floatingDate.dispose();
    _scrollDownCurved.dispose();
    _scrollDownAnimController.dispose();
    _hasText.dispose();
    _scheduledCount.dispose();
    _showAttachmentPanel.removeListener(_onAttachPanelToggle);
    _showAttachmentPanel.dispose();
    _mediaSend.dispose();
    _pushSub?.cancel();
    _messageEventSub?.cancel();
    _commentsInfoSub?.cancel();
    _commentSub?.cancel();
    _connSub?.cancel();
    _voiceRec.dispose();
    _note.dispose();
    debugForceOffline.removeListener(_recomputeHeaderStatus);
    for (final n in _reactionNotifiers.values) {
      n.dispose();
    }
    _reactionNotifiers.clear();
    _reactionAnimation.dispose();
    ChatActivityStore.instance
        .listenable(widget.chatId)
        .removeListener(_recomputeHeaderStatus);
    ChatMembersStore.instance
        .listenable(widget.chatId)
        .removeListener(_recomputeHeaderStatus);
    PresenceFetch.revision.removeListener(_onPresenceChanged);
    ContactsModule.revision.removeListener(_onContactsChanged);
    if (_wallpaperListening) {
      ChatWallpaperStore.instance.revision.removeListener(
        _applyEffectiveWallpaper,
      );
    }
    if (_encryptionListening) {
      ChatEncryptionStore.instance.revision.removeListener(_applyEncryption);
    }
    _headerStatusNotifier.dispose();
    _otherReadTime.dispose();
    _chatController.dispose();
    _prank.dispose();
    _uploadStatus.dispose();
    _attachAnim.dispose();
    _commandPanel.dispose();
    _mentionPanel.dispose();
    _selectionAnim.dispose();
    _searchAnim.dispose();
    _searchFocusNode.dispose();
    _search.dispose();
    _selectedIds.dispose();
    _textSelection.dispose();
    _textSelectionDrag.dispose();
    _disposeCommandArguments();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _stickers.dispose();
    _scrollController.dispose();
    _shimmerStartTimer?.cancel();
    _shimmerController.dispose();
    _replyTo.dispose();
    _pendingForwards.dispose();
    _scrollNav.dispose();
    _routeSettle.dispose();
    _messageKeys.clear();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText.value) {
      _hasText.value = newHasText;
    }
    _commandPanel.update();
    _mentionPanel.update();
  }

  bool _mentionsAvailable() =>
      !_commentsMode && (chat?.type ?? widget.chatType) == 'CHAT';

  void _onMentionSelected(MentionCandidate candidate, MentionQuery query) {
    _messageController.insertMention(
      userId: candidate.id,
      name: candidate.name,
      start: query.start,
      end: query.end,
    );
    _mentionPanel.update();
    _messageFocusNode.requestFocus();
  }

  void _onCommandSelected(SlashCommand c) {
    final oldControllers = _commandArgumentControllers;
    final oldFocusNodes = _commandArgumentFocusNodes;
    _commandArgumentControllers = {};
    _commandArgumentFocusNodes = {};
    for (final argument in c.arguments) {
      _commandArgumentControllers[argument.name] = TextEditingController();
      _commandArgumentFocusNodes[argument.name] = FocusNode();
    }
    _messageController.clear();
    _hasText.value = false;
    setState(() => _selectedCommand = c);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disposeCommandArgumentMaps(oldControllers, oldFocusNodes);
      if (!mounted) return;
      if (c.arguments.isEmpty) {
        _messageFocusNode.unfocus();
      } else {
        _commandArgumentFocusNodes[c.arguments.first.name]?.requestFocus();
      }
    });
  }

  void _cancelSelectedCommand() {
    if (_selectedCommand == null) return;
    _closeSelectedCommand(focusMessage: true);
  }

  void _disposeCommandArguments() {
    _disposeCommandArgumentMaps(
      _commandArgumentControllers,
      _commandArgumentFocusNodes,
    );
    _commandArgumentControllers = {};
    _commandArgumentFocusNodes = {};
  }

  void _closeSelectedCommand({bool focusMessage = false}) {
    final controllers = _commandArgumentControllers;
    final focusNodes = _commandArgumentFocusNodes;
    _commandArgumentControllers = {};
    _commandArgumentFocusNodes = {};
    setState(() => _selectedCommand = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disposeCommandArgumentMaps(controllers, focusNodes);
      if (focusMessage && mounted) _messageFocusNode.requestFocus();
    });
  }

  void _disposeCommandArgumentMaps(
    Map<String, TextEditingController> controllers,
    Map<String, FocusNode> focusNodes,
  ) {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    for (final node in focusNodes.values) {
      node.dispose();
    }
  }

  Map<String, dynamic> _selectedCommandArguments() => Map.unmodifiable({
    for (final entry in _commandArgumentControllers.entries)
      entry.key: entry.value.text.trim(),
  });

  void _restoreDraft() {
    if (_myId == 0 || _commentsMode || _messageController.text.isNotEmpty) {
      return;
    }
    final shared = widget.initialText?.trim();
    final draft = (shared != null && shared.isNotEmpty)
        ? shared
        : DraftStore.instance.get(_myId, widget.chatId);
    if (draft == null || draft.isEmpty) return;
    _messageController.text = draft;
    _messageController.selection = TextSelection.collapsed(
      offset: draft.length,
    );
  }

  void _saveDraft() {
    if (_myId == 0 || _commentsMode) return;
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
    if (msg.status == 'sending' ||
        msg.status == 'pending' ||
        msg.status == 'error') {
      return msg.status;
    }
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
    if (!next.contains(message.id)) _exitTextSelection(message.id);
    _syncSelectionAnim();
  }

  void _clearSelection() {
    _exitTextSelection();
    if (_selectedIds.value.isEmpty) return;
    _selectedIds.value = const {};
    _syncSelectionAnim();
  }

  void _startTextSelection(CachedMessage message, Offset globalPosition) {
    if (message.isControl || message.selectableText == null) return;
    _textSelectionDrag.value = null;
    _textSelection.value = (id: message.id, pos: globalPosition);
  }

  void _exitTextSelection([String? onlyId]) {
    final current = _textSelection.value;
    if (current == null) return;
    if (onlyId != null && current.id != onlyId) return;
    _textSelection.value = null;
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

  List<CachedMessage> _copyableSelection(Set<String> ids) => [
    for (final m in _messages)
      if (ids.contains(m.id) && (m.selectableText ?? '').isNotEmpty) m,
  ];

  CachedMessage? _singleEditable(Set<String> ids) {
    if (ids.length != 1) return null;
    final list = _selectedMessages(ids);
    if (list.isEmpty) return null;
    return _canEditMessage(list.first) ? list.first : null;
  }

  void _copySelected(List<CachedMessage> messages) {
    if (messages.isEmpty) return;
    final text = messages.map((m) => m.selectableText!).join('\n\n');
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
    _textSend.startReply(message);
  }

  void _forwardSelected() {
    final msgs = _selectedMessages(_selectedIds.value);
    _clearSelection();
    unawaited(_forwardMessages(msgs));
  }

  Future<void> _forwardMessages(List<CachedMessage> msgs) async {
    final forwardable = msgs
        .where((message) => int.tryParse(message.id) != null)
        .toList();
    if (forwardable.isEmpty) {
      showCustomNotification(context, 'Нечего пересылать');
      return;
    }

    final target = await openForwardScreen(
      context: context,
      messageCount: forwardable.length,
    );
    if (target == null || !mounted) return;

    final ordered = [...forwardable]..sort((a, b) => a.time.compareTo(b.time));
    final request = ForwardRequest(
      sourceChatId: widget.chatId,
      sourceChatName: widget.name,
      sourceChatIconUrl: widget.imageUrl,
      sourceChatType: widget.chatType,
      messages: ordered,
    );

    if (target.chatId == widget.chatId) {
      _textSend.setForwardRequest(request);
      return;
    }

    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: target.chatId,
        name: target.name,
        imageUrl: target.imageUrl,
        chatType: target.chatType,
        forwardRequest: request,
      ),
    );
  }

  Widget _composerAreaWidget() {
    return ComposerArea(
      selectionAnim: _selectionAnim,
      searchAnim: _searchAnim,
      attachAnim: _attachAnim,
      stickers: _stickers,
      selectedCommand: _selectedCommand,
      commandArgumentControllers: _commandArgumentControllers,
      commandArgumentFocusNodes: _commandArgumentFocusNodes,
      onCancelSelectedCommand: _cancelSelectedCommand,
      onSendMessage: _sendMessage,
      showAttachmentPanel: _showAttachmentPanel,
      onPickFile: _pickAndUploadFile,
      onSendFileById: _mediaSend.sendFileById,
      commentsMode: _commentsMode,
      chatType: widget.chatType,
      chrome: _effectiveChrome,
      chromeVignette: _chromeVignette,
      pillBackdrop: _pillBackdrop,
      barBackdrop: _barBackdrop,
      replyTo: _replyTo,
      forwardMessages: _pendingForwards,
      myId: _myId,
      hasText: _hasText,
      uploadStatus: _uploadStatus,
      messageController: _messageController,
      messageFocusNode: _messageFocusNode,
      voiceRec: _voiceRec,
      note: _note,
      onToggleStickerPanel: _toggleStickerPanel,
      onScheduleMessage: _scheduleMessage,
      onOpenAttach: _openAttachmentSheet,
      onOpenAttachScheduled: _openAttachmentSheetScheduled,
      onSendHistory: _mediaSend.sendHistoryFile,
      onCancelReply: _textSend.cancelReply,
      onCancelForward: _textSend.cancelForward,
      crossChatReplySupported: _crossChatReplySupported,
      onPickReplyChat: _pickReplyChat,
      formatElapsed: formatVoiceElapsed,
      formatContextMenu: _formatContextMenu,
      pasteMenuItems: _pasteMenuItems,
      onPasteMedia: ClipboardMedia.supported ? _handlePasteMedia : null,
      isMuted: chat?.isMuted ?? false,
      onToggleMute: _toggleChatMute,
      channelSubscribed: !_previewChat,
      channelSubscribing: _subscribing,
      onSubscribe: _subscribeChannel,
      onStickerTap: _mediaSend.sendSticker,
      onEmojiTap: _insertAnimoji,
      selectedIds: _selectedIds,
      onReplySelected: _replySelected,
      onForwardSelected: _forwardSelected,
      forwardDisabled: chat?.forwardDisabled ?? false,
      composerFrosted: _composerFrosted,
    );
  }

  bool _canEditMessage(CachedMessage message) {
    if (message.senderId != _myId) return false;
    if (message.id.startsWith('temp_')) return false;
    if (message.isControl) return false;
    if (message.forwardedAttachment != null) return false;
    final status = message.status;
    if (status == 'sending' || status == 'error') return false;
    return true;
  }

  Future<void> _startEditMessage(CachedMessage message) async {
    final cs = Theme.of(context).colorScheme;

    final content =
        await showModalBottomSheet<
          ({String text, List<Map<String, dynamic>> elements})
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: cs.surfaceContainerHigh,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => EditMessageSheet(
            text: message.text ?? '',
            formatRanges: message.formatRanges,
            contextMenuBuilder: _formatContextMenu,
          ),
        );

    if (content == null || !mounted) return;

    final rawText = content.text;
    final newText = rawText.trim();
    final elements = trimmedElements(content.elements, rawText, newText);

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

    final idx = _chatController.indexOfId(message.id);
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
      _chatController.setMessageAt(idx, edited);
      _bumpMessages();
      unawaited(_chatController.persistOutgoing(edited));
    }
    Haptics.send();
  }

  Future<void> _confirmDeleteMessage(String messageId, bool isMe) async {
    final isLocalOnly = messageId.startsWith('temp_');
    final canForEveryone = isMe && !isLocalOnly;

    if (isLocalOnly) {
      _startDeleteAnimation(messageId);
      return;
    }

    final forEveryone = await _showDeleteMessageDialog(canForEveryone);
    if (forEveryone == null || !mounted) return;

    final ok = await messagesModule.deleteMessages(widget.chatId, [
      messageId,
    ], forEveryone: forEveryone);
    if (!mounted) return;
    if (!ok) {
      Haptics.error();
      showCustomNotification(context, 'Не удалось удалить сообщение');
      return;
    }
    _startDeleteAnimation(messageId);
  }

  void _startDeleteAnimation(String messageId) {
    if (!_deletingIds.add(messageId)) return;
    Haptics.tap();
    _bumpMessages();
  }

  Future<void> _finalizeDelete(String messageId) async {
    if (!mounted) return;
    _deletingIds.remove(messageId);
    final idx = _chatController.indexOfId(messageId);
    if (idx != -1) {
      _chatController.removeMessageAt(idx);
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
              shape: AppShape.dialogBorder,
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
    if (_commentsMode) return;
    switch (event) {
      case MessageAddedEvent(:final message):
        // #***! в Избранном senderId всегда == _myId, дедуп только по id
        if (widget.chatId != 0 &&
            message.senderId == _myId &&
            !message.isControl) {
          return;
        }
        if (_chatController.containsId(message.id)) return;
        final nearBottom = _scrollNav.isNearBottom();
        if (!nearBottom) _deferredIds.add(message.id);
        _lastSentId = message.id;
        _chatController.addMessage(message);
        _bumpMessages();
        _clearTyping(message.senderId);
        Haptics.tap();
        if (nearBottom) {
          _scrollNav.scrollToBottom();
          _scheduleReadMarker();
        } else {
          _scrollNav.noteMissedMessage();
          _reapplyPinIfNeeded();
        }
        _prank.checkTrigger(message);
      case MessageEditedEvent(:final message):
        final idx = _chatController.indexOfId(message.id);
        if (idx == -1) return;
        _chatController.setMessageAt(idx, message);
        _bumpMessages();
      case MessageSentEvent(:final tempId, :final message):
        final idx = _chatController.indexOfId(tempId);
        if (idx == -1) return;
        _lastSentId = message.id;
        _chatController.setMessageAt(idx, message);
        _bumpMessages();
      case MessageRemovedEvent(:final messageId):
        final idx = _chatController.indexOfId(messageId);
        if (idx == -1) return;
        _chatController.removeMessageAt(idx);
        _bumpMessages();
        _reactionNotifiers.remove(messageId)?.dispose();
      case MessageMarkedDeletedEvent(:final messageId):
        final idx = _chatController.indexOfId(messageId);
        if (idx == -1) return;
        if (_messages[idx].deleted) return;
        _chatController.setMessageAt(idx, _messages[idx].copyWith(deleted: true));
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

  void _onContactsChanged() {
    if (mounted) setState(() {});
  }

  String _headerAvatarUrl() {
    if (!_commentsMode && widget.chatType == 'DIALOG') {
      final otherId = _resolveOtherId();
      if (otherId != null) {
        final cached = ContactCache.getAvatar(otherId);
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }
    return widget.imageUrl;
  }

  String _headerName() {
    if (_commentsMode) return AppLocalizations.of(context)!.commentsTitle;
    if (widget.chatType == 'DIALOG') {
      final otherId = _resolveOtherId();
      if (otherId != null) {
        final cached = ContactCache.get(otherId);
        if (cached != null && cached.isNotEmpty) return cached;
      }
    }
    return widget.name;
  }

  bool get _hasMiniApp {
    if (widget.chatType != 'DIALOG' || _commentsMode) return false;
    final peerId = _resolveOtherId();
    if (peerId == null) return false;
    if (hasMiniAppOption(ContactCache.getOptions(peerId))) return true;
    return hasMiniAppOption(chat?.options);
  }

  Future<void> _openMiniApp() async {
    final peerId = _resolveOtherId();
    if (peerId == null) return;
    await openMiniApp(
      context,
      botId: peerId,
      chatId: widget.chatId,
      title: _headerName(),
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
        if (_hasMiniApp)
          ChatMenuItem(
            icon: Symbols.apps,
            label: AppLocalizations.of(context)!.miniAppOpen,
            dividerAfter: true,
            onTap: () => unawaited(_openMiniApp()),
          ),
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
          icon: _encryptionEnabled ? Symbols.lock : Symbols.lock_open,
          label: 'Шифрование сообщений',
          onTap: _openEncryptionSettings,
        ),
        ChatMenuItem(
          icon: Symbols.delete,
          label: 'Удалить чат',
          onTap: _deleteChat,
        ),
      ],
    );
  }

  Future<void> _subscribeChannel() async {
    if (_subscribing) return;
    setState(() => _subscribing = true);
    try {
      var link = _channelLink;
      if (link == null || link.isEmpty) {
        final info = await chats.getChatInfo(api, widget.chatId);
        link = info?['link'] as String?;
      }
      if (link == null || link.isEmpty) {
        throw const PacketError('Не удалось получить ссылку чата');
      }
      final result = await chats.joinChannel(api, link, _myId);
      if (!mounted) return;
      setState(() {
        _previewChat = false;
        _subscribing = false;
        chat = result.chat;
      });
      ChatMembersStore.instance.setCount(
        widget.chatId,
        result.subscribersCount,
      );
      _recomputeHeaderStatus();
      showCustomNotification(
        context,
        widget.chatType == 'CHANNEL'
            ? 'Вы подписались на канал'
            : 'Вы вступили в группу',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subscribing = false);
      showCustomNotification(
        context,
        e is PacketError
            ? e.message
            : (widget.chatType == 'CHANNEL'
                  ? 'Не удалось подписаться'
                  : 'Не удалось вступить'),
      );
    }
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

  bool _encryptionListening = false;

  Future<void> _loadEncryption() async {
    await ChatEncryptionStore.instance.load();
    if (!mounted) return;
    if (!_encryptionListening) {
      _encryptionListening = true;
      ChatEncryptionStore.instance.revision.addListener(_applyEncryption);
    }
    _applyEncryption();
  }

  void _applyEncryption() {
    if (!mounted) return;
    final enabled = ChatEncryptionStore.instance.isEnabled(
      _myId,
      widget.chatId,
    );
    if (enabled != _encryptionEnabled) {
      setState(() => _encryptionEnabled = enabled);
    }
    if (enabled && _myId != 0) {
      unawaited(ChatCryptoService.instance.warmKey(_myId, widget.chatId));
    }
  }

  Future<void> _openEncryptionSettings() async {
    if (_myId == 0) return;
    await pushSwipeable(
      context,
      (context) =>
          ChatEncryptionScreen(accountId: _myId, chatId: widget.chatId),
    );
    if (!mounted) return;
    _applyEncryption();
  }

  bool _wallpaperListening = false;

  Future<void> _loadWallpaper() async {
    await ChatWallpaperStore.instance.load();
    if (!mounted) return;
    if (!_wallpaperListening) {
      _wallpaperListening = true;
      ChatWallpaperStore.instance.revision.addListener(
        _applyEffectiveWallpaper,
      );
    }
    _applyEffectiveWallpaper();
  }

  void _applyEffectiveWallpaper() {
    if (!mounted) return;
    final store = ChatWallpaperStore.instance;
    final wp =
        store.get(_myId, widget.chatId) ??
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
      case WallpaperPickType.gradient:
        final colors = pick.gradientColors;
        if (colors == null || colors.isEmpty) break;
        await store.setGradient(
          _myId,
          widget.chatId,
          colors,
          animated: pick.gradientAnimated,
          rotation: pick.gradientRotation,
        );
        _applyEffectiveWallpaper();
        break;
    }
  }

  Future<void> _pickWallpaperFromGallery() async {
    final bytes = await pickWallpaperBytes(context);
    if (bytes == null || !mounted) return;
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
    final current = chat;
    final canClearForAll =
        (widget.chatType == 'CHAT' || widget.chatType == 'CHANNEL') &&
        (current?.iAmAdmin(_myId) ?? false);
    final choice = await showBlurredConfirm(
      context,
      title: 'Очистить историю',
      message:
          'Все сообщения в этом чате будут удалены без возможности '
          'восстановления.',
      confirmLabel: 'Очистить',
      cancelLabel: 'Отмена',
      destructive: true,
      checkboxLabel: canClearForAll ? 'Для всех' : null,
    );
    if (!mounted || !choice.confirmed) return;
    final err = await chats.clearHistory(
      api,
      chatId: widget.chatId,
      lastEventTime: current?.lastEventTime ?? 0,
      forAll: canClearForAll && choice.checked,
    );
    if (!mounted) return;
    if (err != null) {
      showCustomNotification(context, err);
      return;
    }
    setState(() {
      _messages = [];
      _deferredIds.clear();
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
    if (_commentsMode) {
      _headerStatusNotifier.value = '';
      return;
    }
    _headerStatusNotifier.value = _headerStatus();
  }

  int get _memberCount =>
      ChatMembersStore.instance.count(widget.chatId) ??
      chat?.participants.length ??
      0;

  bool get _isGroupChat =>
      widget.chatType == 'CHAT' || widget.chatType == 'CHANNEL';

  String _headerStatus() {
    final conn = connectionStatusLabel(api.state);
    if (conn != null) return conn;
    final activity = ChatActivityStore.instance.snapshot(widget.chatId);
    if (activity != null) {
      return chatActivityLabel(activity, withNames: _isGroupChat);
    }
    if (widget.chatType == 'CHAT') {
      final count = _memberCount;
      return '$count участников';
    }
    if (widget.chatType == 'CHANNEL') {
      final count = _memberCount;
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
    unawaited(_ensureTypingName(userId));
  }

  Future<void> _ensureTypingName(int userId) async {
    if (!_isGroupChat) return;
    if (ContactCache.get(userId) != null) return;
    final resolved = await messagesModule.ensureContactNames({userId});
    if (resolved && mounted) _recomputeHeaderStatus();
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
      case TextFormat.heading:
        return 'Заголовок';
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
      case TextFormat.userMention:
        return 'Упоминание';
    }
  }

  Widget _formatContextMenu(
    RichMessageController controller,
    BuildContext context,
    EditableTextState editableState, {
    List<ContextMenuButtonItem> extraItems = const [],
  }) {
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
    buttonItems.addAll(extraItems);
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

  int? _resolveOtherId() {
    if (widget.chatType != 'DIALOG' || _myId == 0) return null;
    if (widget.chatId == 0) return null;
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

  Future<String?> _encryptOutgoing(String text, {bool notify = true}) async {
    if (!_encryptionEnabled || _myId == 0) return text;
    final result = await ChatCryptoService.instance.encrypt(
      _myId,
      widget.chatId,
      text,
    );
    if (result.isOk) {
      if (result.text!.length > kMaxEncryptedMessageLength) {
        if (mounted && notify) {
          showCustomNotification(
            context,
            'Слишком длинное сообщение. Разделите на несколько',
          );
        }
        return null;
      }
      return result.text;
    }
    if (mounted && notify) {
      showCustomNotification(
        context,
        result.failure == CryptoFailure.noKey
            ? 'Не задан ключ шифрования'
            : 'Не удалось зашифровать сообщение',
      );
    }
    return null;
  }

  Future<void> _sendMessage() async {
    final selectedCommand = _selectedCommand;
    if (selectedCommand != null) {
      await _executeSelectedCommand(selectedCommand);
      return;
    }
    await _textSend.sendMessage();
  }

  PluginCommandContext _commandContext(
    SlashCommand command,
    String args, {
    Map<String, dynamic>? arguments,
  }) => PluginCommandContext(
    args: args,
    arguments: arguments ?? parseCommandArguments(args, command.arguments),
    replyMessage: _pluginReplyMessage(),
    onlineCheck: () => api.state == SessionState.online,
    activeCheck: () => mounted,
    sendTextCallback: _textSend.postCommandMessage,
    editTextCallback: _textSend.updateCommandMessage,
    sendPhotoCallback: _sendPluginPhoto,
    sendFileCallback: _sendPluginFile,
    notifyCallback: (message) async {
      if (mounted) showCustomNotification(context, message);
    },
    getPeerCallback: _pluginPeer,
  );

  Map<String, dynamic>? _pluginReplyMessage() {
    final message = _replyTo.value;
    if (message == null) return null;
    return {
      'id': message.id,
      'senderId': message.senderId,
      'text': message.text,
      'time': message.time,
      'attachments': [
        for (final attachment in message.attachments ?? const [])
          {'type': attachment.type.name},
      ],
    };
  }

  Future<void> _sendPluginPhoto(
    Uint8List bytes,
    String filename,
    String caption,
  ) async {
    final file = await _pluginTempFile(bytes, filename);
    try {
      await _mediaSend.sendPhotos(
        [PickedPhoto(item: GalleryItem.fromFile(file))],
        caption,
        waitForUpload: true,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _sendPluginFile(Uint8List bytes, String filename) async {
    if (_encryptionEnabled) {
      throw StateError('Файлы плагинов пока нельзя зашифровать');
    }
    final file = await _pluginTempFile(bytes, filename);
    try {
      await _mediaSend.uploadAsFile(
        source: file,
        filename: filename,
        size: bytes.length,
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<File> _pluginTempFile(Uint8List bytes, String filename) async {
    final directory = await getTemporaryDirectory();
    final extension = p.extension(filename);
    final file = File(
      p.join(
        directory.path,
        'komet_plugin_${DateTime.now().microsecondsSinceEpoch}$extension',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _executeCommand(SlashCommand command, String args) async {
    try {
      final commandContext = _commandContext(command, args);
      final missing = command.missingArgument(commandContext.arguments);
      if (missing != null) {
        showCustomNotification(
          context,
          'Не указан аргумент ${missing.name}. Формат: ${command.usage}',
        );
        return;
      }
      await command.execute(commandContext);
      if (!mounted) return;
      _replyTo.value = null;
      _textSend.replySourceChatId = null;
    } catch (error) {
      if (!mounted) return;
      showCustomNotification(context, 'Ошибка плагина: $error');
    }
  }

  Future<void> _executeSelectedCommand(SlashCommand command) async {
    if (_commandExecuting) return;
    final arguments = _selectedCommandArguments();
    final missing = command.missingArgument(arguments);
    if (missing != null) {
      showCustomNotification(context, 'Заполните поле ${missing.name}');
      _commandArgumentFocusNodes[missing.name]?.requestFocus();
      return;
    }
    final args = serializeCommandArguments(command.arguments, arguments);
    setState(() => _commandExecuting = true);
    try {
      await command.execute(
        _commandContext(command, args, arguments: arguments),
      );
      if (!mounted) return;
      _replyTo.value = null;
      _textSend.replySourceChatId = null;
      _closeSelectedCommand();
    } catch (error) {
      if (!mounted) return;
      showCustomNotification(context, 'Ошибка плагина: $error');
    } finally {
      if (mounted) setState(() => _commandExecuting = false);
    }
  }

  Future<Map<String, dynamic>?> _pluginPeer() async {
    final id = _resolveOtherId();
    if (id == null) return null;
    final contact = await ContactInfoFetch.get(id, forceRefresh: true);
    if (contact == null) return null;
    return {
      'id': contact.id ?? id,
      'displayName': contact.displayName,
      'country': contact.raw['country']?.toString(),
      'registrationTime': contact.raw['registrationTime'],
      'updateTime': contact.raw['updateTime'],
      'options': contact.options,
    };
  }

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
            if (a.originalSenderId != 0 &&
                a.originalSenderName == null &&
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
            originalType: a.originalType,
            originalMessageId: a.originalMessageId,
            originalTime: a.originalTime,
            originalText: a.originalText,
            originalChatId: a.originalChatId,
            originalFormatRanges: a.originalFormatRanges,
            originalAttachments: a.originalAttachments,
            originalContact: a.originalContact,
          );
        }
        return a;
      }).toList();

      if (!msgChanged) continue;
      anyChanged = true;
      _chatController.setMessageAt(i, msg.copyWith(attachments: newAttaches));
    }

    if (anyChanged) {
      _bumpMessages();
    }
  }


  Future<void> _pickReplyChat() async {
    final reply = _replyTo.value;
    if (reply == null) return;
    if (reply.id.startsWith('temp_')) {
      showCustomNotification(context, 'Сообщение ещё не отправлено');
      return;
    }

    final sourceChatId = _textSend.replySourceChatId ?? widget.chatId;
    final target = await openForwardScreen(context: context);
    if (target == null || !mounted) return;

    if (target.chatId == widget.chatId) {
      _textSend.replySourceChatId = sourceChatId == widget.chatId ? null : sourceChatId;
      _messageFocusNode.requestFocus();
      return;
    }

    await chats.ensureChatCached(api, _myId, target.chatId);
    if (!mounted) return;
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: target.chatId,
        name: target.name,
        imageUrl: target.imageUrl,
        chatType: target.chatType,
        replyRequest: ReplyRequest(sourceChatId: sourceChatId, message: reply),
      ),
    );
  }

  void _openSenderProfile(int senderId) {
    if (senderId == 0 || senderId == _myId) return;
    unawaited(
      openContactDialogProfile(
        context,
        contactId: senderId,
        name: ContactCache.get(senderId) ?? 'User #$senderId',
        avatarUrl: ContactCache.getAvatar(senderId),
      ),
    );
  }

  void _openForwardedSource(ForwardedMessageAttachment forwarded) {
    if (forwarded.isChannel) {
      unawaited(_openForwardedChannel(forwarded));
      return;
    }
    final senderId = forwarded.originalSenderId;
    if (senderId == 0 || senderId == _myId) return;
    unawaited(
      openContactDialogProfile(
        context,
        contactId: senderId,
        name:
            forwarded.originalSenderName ??
            ContactCache.get(senderId) ??
            'User #$senderId',
        avatarUrl:
            forwarded.originalSenderAvatar ?? ContactCache.getAvatar(senderId),
      ),
    );
  }

  Future<void> _openForwardedChannel(
    ForwardedMessageAttachment forwarded,
  ) async {
    final sourceChatId = forwarded.originalChatId;
    if (sourceChatId == null) {
      showCustomNotification(context, 'Канал недоступен');
      return;
    }
    final sourceMessageId = forwarded.originalMessageId;
    if (sourceChatId == widget.chatId) {
      if (sourceMessageId == null) return;
      _scrollNav.beginTargetNavigation();
      await _scrollNav.runGoToMessage(
        sourceMessageId,
        forwarded.originalTime ?? 0,
      );
      return;
    }

    await chats.ensureChatCached(api, _myId, sourceChatId);
    if (!mounted) return;
    final cached = await chats.getChat(_myId, sourceChatId);
    if (!mounted) return;
    final channel = cached.isEmpty ? null : cached.first;
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: sourceChatId,
        name: channel?.title ?? forwarded.originalSenderName ?? 'Канал',
        imageUrl: channel?.iconUrl ?? forwarded.originalSenderAvatar ?? '',
        chatType: channel?.type ?? 'CHANNEL',
        initialMessageId: sourceMessageId,
        initialMessageTime: forwarded.originalTime,
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

  final Map<String, GlobalKey> _messageKeys = {};

  GlobalKey _keyForMessage(String messageId) =>
      _messageKeys.putIfAbsent(messageId, () => GlobalKey());

  String? _messageIdOfItem(Object item) =>
      item is _MessageItem ? item.message.id : null;

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

  Future<void> _openSearchResult(MessageSearchResult result) async {
    _closeSearch();
    if (_chatController.containsId(result.id)) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _scrollNav.scrollToLoadedMessage(result.id);
      return;
    }
    setState(_scrollNav.beginTargetNavigation);
    await _scrollNav.runGoToMessage(result.id, result.time);
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
    final visible = _visibleMessageCount;
    final key = Object.hash(
      _messagesRev.value,
      _messages.length,
      visible,
      _unreadAnchorTime,
    );
    final cached = _combinedItemsCache;
    if (cached != null && _combinedItemsKey == key) return cached;

    final unreadIndex = _firstUnreadIndex();

    final List<Object> items = [];
    final Set<int> usedDates = {};

    for (int i = 0; i < visible; i++) {
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

  @override
  Widget build(BuildContext context) {
    final theme = _prank.active
        ? _prank.pinkTheme(Theme.of(context))
        : Theme.of(context);
    final cs = theme.colorScheme;
    final underlap = _effectiveChrome != ChatChromeStyle.color;

    // TODO: Локализация
    // TODO: Cклонения
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bottomInset = _keyboardReserve > 0
        ? math.max(viewInsets.bottom, _keyboardReserve)
        : viewInsets.bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _selectedIds,
        _search.searchMode,
        _textSelection,
      ]),
      builder: (context, child) => PopScope(
        canPop:
            _selectedIds.value.isEmpty &&
            !_search.searchMode.value &&
            _textSelection.value == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_search.searchMode.value) {
            _closeSearch();
          } else if (_textSelection.value != null) {
            _exitTextSelection();
          } else {
            _clearSelection();
          }
        },
        child: child!,
      ),
      child: MediaQuery(
        data:
            context
                .getInheritedWidgetOfExactType<MediaQuery>()!
                .data
                .copyWith(
                  viewInsets: viewInsets.copyWith(bottom: bottomInset),
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
                  child: ChatBodyLayout(
                    underlap: underlap,
                    cs: cs,
                    chat: chat,
                    effectiveChrome: _effectiveChrome,
                    liquidChrome: _liquidChrome,
                    pillBackdrop: _pillBackdrop,
                    myId: _myId,
                    onJumpToPinnedMessage: _jumpToPinnedMessage,
                    onUnpinCurrentMessage: _unpinCurrentMessage,
                    composerFrosted: _composerFrosted,
                    composerHeight: _composerHeight,
                    pinnedBannerHeight: _pinnedBannerHeight,
                    composerAreaBuilder: (context) => _composerAreaWidget(),
                    messagesArea: _buildMessagesArea(),
                    mentionPanel: _mentionPanel,
                    commandPanel: _commandPanel,
                    note: _note,
                    searchAnim: _searchAnim,
                    search: _search,
                    onOpenSearchResult: _openSearchResult,
                    searchSenderName: _searchSenderName,
                    searchSenderAvatar: _searchSenderAvatar,
                    chromeVignette: _chromeVignette,
                    composerPaintsSurface: _composerPaintsSurface,
                    pinnedBannerTop: _pinnedBannerTop(),
                    defaultEdgeVignetteHeight: _defaultEdgeVignetteHeight(),
                    wallpaper: _wallpaper,
                  ),
                ),
                builder: (context, body) => Scaffold(
                  backgroundColor: cs.surface,
                  extendBodyBehindAppBar: underlap,
                  appBar: ChatAppBar(
                    cs: cs,
                    searchAnim: _searchAnim,
                    selectionAnim: _selectionAnim,
                    chrome: _effectiveChrome,
                    chromeVignette: _chromeVignette,
                    liquidChrome: _liquidChrome,
                    barBackdrop: _barBackdrop,
                    pillBackdrop: _pillBackdrop,
                    glossyChrome: AppVisualStyle.current.value.glossyChrome,
                    embedded: widget.embedded,
                    chatId: widget.chatId,
                    heroTag: _profileHeroTag,
                    name: _headerName(),
                    imageUrl: _headerAvatarUrl(),
                    chatType: widget.chatType,
                    isOfficial: chat?.isOfficial ?? false,
                    encrypted: _encryptionEnabled,
                    myId: _myId,
                    headerStatus: _headerStatusNotifier,
                    scheduledCount: _scheduledCount,
                    otherUnread: _otherUnread,
                    showCall:
                        !_commentsMode &&
                        widget.chatType == 'DIALOG' &&
                        widget.chatId != 0 &&
                        !_peerIsBot,
                    onClose: widget.onClose,
                    onOpenInfo: _commentsMode ? () {} : _openChatInfo,
                    onOpenScheduled: _openScheduledMessages,
                    onCall: _startCall,
                    onMenu: _commentsMode ? (_) {} : _openChatMenu,
                    selectedIds: _selectedIds,
                    copyableSelection: _copyableSelection,
                    singleEditable: _singleEditable,
                    onClearSelection: _clearSelection,
                    onCopySelected: _copySelected,
                    onEditSelected: _editSelected,
                    onDeleteSelected: _deleteSelected,
                    search: _search,
                    searchFocusNode: _searchFocusNode,
                    onCloseSearch: _closeSearch,
                  ),
                  body: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _pinnedBannerTop() {
    final glossy = AppVisualStyle.current.value.glossyChrome;
    return MediaQuery.paddingOf(context).top +
        (glossy ? _glossyHeaderHeight : kToolbarHeight) -
        _pinnedBannerLift;
  }

  double _defaultEdgeVignetteHeight() {
    final glossy = AppVisualStyle.current.value.glossyChrome;
    return MediaQuery.paddingOf(context).top +
        (glossy ? _glossyHeaderHeight : kToolbarHeight);
  }

  Widget _buildMessagesArea() {
    final showShimmer = _messages.isEmpty
        ? _isLoading
        : (_awaitingPosition || _scrollNav.navigatingToTarget);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: showShimmer ? 0.0 : 1.0,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _scrollNav.bumpGestureEpoch();
              } else if (notification is ScrollEndNotification) {
                _readMarker.flush();
              }
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
    if (AppChatChrome.current.value == ChatChromeStyle.color) {
      final glossy = AppVisualStyle.current.value.glossyChrome;
      return glossy ? 2 : 4;
    }
    if (chat?.hasPinnedMessage == true && pinnedHeight > 0) {
      return _pinnedBannerTop() + pinnedHeight + 2;
    }
    return _pinnedBannerTop() + 2;
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
    final visibleCount = _visibleMessageCount;

    return LayoutBuilder(
      builder: (context, listConstraints) =>
          _buildMessagesStack(items, visibleCount, listConstraints.maxWidth),
    );
  }

  Widget _buildMessagesStack(
    List<Object> items,
    int visibleCount,
    double listWidth,
  ) {
    return Stack(
      key: _listKey,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: AppCacheExtent.current,
          builder: (context, userCacheExtent, _) =>
              ValueListenableBuilder<double?>(
                valueListenable: _scrollNav.jumpCacheExtent,
                builder: (context, jumpExtent, _) {
                  final cacheExtent =
                      jumpExtent != null && jumpExtent < userCacheExtent
                      ? jumpExtent
                      : userCacheExtent;
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: CustomScrollView(
                    controller: _scrollController,
                    reverse: true,
                    scrollCacheExtent: ScrollCacheExtent.pixels(cacheExtent),
                    slivers: [
                      SliverPadding(
                        padding: _messagesListPadding(context),
                        sliver: SliverList(
                          key: ValueKey(_scrollNav.listEpoch),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == 0) {
                                return ValueListenableBuilder<double>(
                                  valueListenable: _composerHeight,
                                  builder: (context, height, _) => SizedBox(
                                    height: _composerUnderlap ? height : 0,
                                  ),
                                );
                              }
                              if (index > items.length) {
                                return const MessageListLoadMoreIndicator();
                              }
                              final item = items[items.length - index];

                              if (item is _DateSeparatorItem) {
                                return DateSeparatorLabel(
                                  key: item.key,
                                  date: item.date,
                                );
                              }

                              if (item is _UnreadSeparatorItem) {
                                return UnreadSeparatorBar(
                                  key: _unreadSeparatorKey,
                                );
                              }

                              final msgItem = item as _MessageItem;
                              final message = msgItem.message;
                              final msgIndex = msgItem.index;
                              final isMe = message.senderId == _myId;
                              final prevMessage = msgIndex > 0
                                  ? _messages[msgIndex - 1]
                                  : null;
                              final nextMessage = msgIndex < visibleCount - 1
                                  ? _messages[msgIndex + 1]
                                  : null;

                              final bool isChannelPost =
                                  !_commentsMode &&
                                  (chat?.type ?? widget.chatType) ==
                                      'CHANNEL' &&
                                  !message.isControl;
                              final bool isCommentedPost =
                                  _commentsMode &&
                                  message.id == widget.commentPostId;

                              final bubble = MessageBubble(
                                message: message,
                                isMe: isMe,
                                myId: _myId,
                                prevMessage: prevMessage,
                                nextMessage: nextMessage,
                                chatType: _commentsMode
                                    ? 'CHAT'
                                    : (chat?.type ?? 'CHAT'),
                                chatId: widget.chatId,
                                photoActions: _photoActions,
                                overrideStatus: _effectiveStatus(message),
                                otherReadTime: _otherReadTime,
                                reactionsListenable: _reactionNotifierFor(
                                  message,
                                ),
                                reactionAnimation: _reactionAnimation,
                                uploadProgress: _photoProgressFor(message),
                                onReplyTap: (id) => _scrollNav.jumpToMessage(
                                  id,
                                  fromId: message.id,
                                ),
                                resolveLocalMessage: _chatController.byId,
                                listWidth: listWidth,
                                onAvatarTap: _openSenderProfile,
                                onForwardedSourceTap: _openForwardedSource,
                                onStickerTap: _openStickerPack,
                                onReactionTap: message.isControl
                                    ? null
                                    : (emoji) =>
                                          _reactToMessage(message, emoji),
                                peerName: widget.name,
                                peerAvatarUrl: widget.imageUrl,
                                senderNameOverride: isCommentedPost
                                    ? widget.name
                                    : null,
                                senderAvatarOverride: isCommentedPost
                                    ? widget.imageUrl
                                    : null,
                                textSelection: _textSelection,
                                textSelectionDrag: _textSelectionDrag,
                                onExitTextSelection: _exitTextSelection,
                                commentsLabel: isChannelPost
                                    ? _commentsLabelFor(message.id)
                                    : null,
                                onCommentsTap: isChannelPost
                                    ? () => _openComments(message)
                                    : null,
                              );

                              final canReport = !isMe && !message.isControl;
                              final reportTypeId = _complaintTypeId(
                                chat?.type ?? widget.chatType,
                              );

                              final pressable = SelectableMessageRow(
                                message: message,
                                isMe: isMe,
                                composerHeight: _composerHeight,
                                selectedIds: _selectedIds,
                                selectionAnim: _selectionAnim,
                                isSelectionActive: () => _selectionMode,
                                onToggleSelection: () =>
                                    _toggleSelection(message),
                                onEnterSelection: () =>
                                    _enterSelection(message),
                                onStartTextSelection: (pos) =>
                                    _startTextSelection(message, pos),
                                onDragTextSelection: (pos) =>
                                    _textSelectionDrag.value = pos,
                                onDelete: () =>
                                    _confirmDeleteMessage(message.id, isMe),
                                allowDelete:
                                    !message.isControl &&
                                    (isMe ||
                                        chat?.type != 'CHANNEL' ||
                                        (chat?.iAmAdmin(_myId) ?? false)),
                                onEdit: _canEditMessage(message)
                                    ? () => _startEditMessage(message)
                                    : null,
                                onReply: message.isControl
                                    ? null
                                    : () => _textSend.startReply(message),
                                onForward:
                                    message.isControl ||
                                        (chat?.forwardDisabled ?? false)
                                    ? null
                                    : () => _forwardMessages([message]),
                                allowCopy: !(chat?.copyDisabled ?? false),
                                onMarkUnread: message.isControl
                                    ? null
                                    : () => _markMessageUnread(message),
                                onPin: _canPinMessage(message)
                                    ? () => _togglePinMessage(message)
                                    : null,
                                isPinned: () =>
                                    chat?.pinnedMsgId ==
                                    int.tryParse(message.id),
                                loadReadBy: _canShowReadBy(message)
                                    ? () => _loadReadBy(message)
                                    : null,
                                onReaderTap: _openSenderProfile,
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
                                    : (emoji) =>
                                          _reactToMessage(message, emoji),
                                reactions: _reactionNotifierFor(message),
                                child: bubble,
                              );

                              final isChannel =
                                  (chat?.type ?? widget.chatType) == 'CHANNEL';
                              final swipeable = (message.isControl || isChannel)
                                  ? pressable
                                  : SwipeToReply(
                                      isMe: isMe,
                                      onReply: () => _textSend.startReply(message),
                                      child: pressable,
                                    );

                              final Widget child;
                              if (_deletingIds.contains(message.id)) {
                                child = DeletingMessageAnimation(
                                  key: ValueKey('del_${message.id}'),
                                  onComplete: () => _finalizeDelete(message.id),
                                  child: IgnorePointer(child: swipeable),
                                );
                              } else if (message.id == _lastSentId) {
                                child = SentMessageAnimation(
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

                              final highlightable =
                                  ValueListenableBuilder<String?>(
                                    valueListenable: _scrollNav.highlightMessageId,
                                    builder: (context, hl, c) =>
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          color: hl == message.id
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.12)
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
                            childCount:
                                items.length + 1 + (_isLoadingMore ? 1 : 0),
                          ),
                        ),
                      ),
                    ],
                    ),
                  );
                },
              ),
        ),
        ThrottledMessageScrollbar(
          controller: _scrollController,
          itemCountOf: () => _messages.length,
          jumpCacheExtent: _scrollNav.jumpCacheExtent,
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
                  child: DateSeparatorLabel(date: date, floating: true),
                );
              },
            ),
          ),
        ),
        ScrollDownButton(
          composerHeight: _composerHeight,
          materialComposer: _materialComposer,
          composerUnderlap: _composerUnderlap,
          frosted: _effectiveChrome == ChatChromeStyle.transparent,
          liquidChrome: _liquidChrome,
          pillBackdrop: _pillBackdrop,
          scrollDownCurved: _scrollDownCurved,
          newMessageCount: _scrollNav.newMessageCount,
          onTap: _scrollNav.onScrollDownTap,
        ),
      ],
    );
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
          ? _mediaSend.sendPhotos
          : (picked, caption) =>
                _mediaSend.sendScheduledPhotos(picked, caption, scheduledTime),
      onPickFile: _encryptionEnabled
          ? () => _refuseUnencrypted('Файлы')
          : (scheduledTime == null
                ? _pickAndUploadFile
                : () => _pickAndUploadFile(scheduledTime: scheduledTime)),
      onShareLocation: _encryptionEnabled
          ? () => _refuseUnencrypted('Геолокацию')
          : _mediaSend.shareLocation,
      onCreatePoll: _encryptionEnabled
          ? () => _refuseUnencrypted('Опросы')
          : _createPoll,
      onSendContact: _encryptionEnabled
          ? (_) => _refuseUnencrypted('Контакты')
          : _mediaSend.sendContact,
    );
    if (!mounted || !hadKeyboard) return;
    _messageFocusNode.requestFocus();
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _keyboardReserve = 0);
  }

  void _toggleStickerPanel() {
    if (_stickers.showPanel.value) {
      _stickers.hide();
      if (_keyboardBeforeStickers) _messageFocusNode.requestFocus();
      return;
    }
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    _keyboardBeforeStickers = keyboard > 120 || _messageFocusNode.hasFocus;
    if (keyboard > 120) _stickers.setBaseHeight(keyboard);
    FocusManager.instance.primaryFocus?.unfocus();
    _stickers.showPanel.value = true;
  }

  void _insertAnimoji(Animoji animoji) {
    _messageController.insertAnimoji(animoji);
    unawaited(animojiModule.noteUsed(animoji));
    Haptics.selection();
  }

  Future<void> _createPoll() async {
    final draft = await showCreatePollSheet(context);
    if (draft == null || !mounted) return;
    await _mediaSend.sendAttachMessage(
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

  void _refuseUnencrypted(String what) {
    if (!mounted) return;
    _showAttachmentPanel.value = false;
    showCustomNotification(context, '$what пока нельзя зашифровать');
  }

  List<ContextMenuButtonItem> _pasteMenuItems(
    BuildContext context,
    EditableTextState editableState,
  ) {
    if (!ClipboardMedia.supported) return const [];
    return [
      ContextMenuButtonItem(
        label: AppLocalizations.of(context)!.composerPasteAttachment,
        onPressed: () {
          editableState.hideToolbar();
          unawaited(_pasteClipboardMedia());
        },
      ),
    ];
  }

  Future<bool> _handlePasteMedia() async {
    if (!await ClipboardMedia.hasMedia()) return false;
    unawaited(_pasteClipboardMedia());
    return true;
  }

  Future<void> _pasteClipboardMedia() async {
    if (_myId == 0 || _pastePending) return;
    _pastePending = true;
    try {
      final payload = await ClipboardMedia.read();
      if (!mounted) return;
      final items = payload == null
          ? const <PastedAttachment>[]
          : await materializeClipboardMedia(payload);
      if (!mounted) return;
      if (items.isEmpty) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.pasteAttachFailed,
        );
        return;
      }

      final media = items.where((it) => it.isMedia).toList();
      final documents = items.where((it) => !it.isMedia).toList();
      if (_encryptionEnabled && documents.isNotEmpty) {
        _refuseUnencrypted('Файлы');
        if (media.isEmpty) return;
        documents.clear();
      }

      final caption = await showPastePreviewSheet(
        context,
        items: [...media, ...documents],
      );
      if (caption == null || !mounted) return;

      if (media.isNotEmpty) {
        await _mediaSend.sendPhotos(
          media
              .map((it) => PickedPhoto(item: GalleryItem.fromFile(it.file)))
              .toList(),
          caption,
        );
      }
      for (final document in documents) {
        if (!mounted) return;
        await _mediaSend.uploadAsFile(
          source: document.file,
          filename: document.name,
          size: document.size,
        );
      }
    } finally {
      _pastePending = false;
    }
  }

  Future<void> _pickAndUploadFile({int? scheduledTime}) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;
    await _mediaSend.uploadAsFile(
      source: File(picked.path!),
      filename: picked.name,
      size: picked.size,
      scheduledTime: scheduledTime,
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

