import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/file_uploader.dart';
import 'package:komet/backend/modules/upload_notification_service.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/core/utils/logger.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:komet/frontend/screens/chats/poll_create_screen.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/calls/call_controller.dart';
import '../calls/call_screen.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/config/app_cache_extent.dart';
import '../../../core/config/app_message_actions_style.dart';
import '../../../core/config/app_swipe_back_desktop.dart';
import '../../../core/config/app_pranks.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../models/attachment.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/theme_reveal.dart';
import '../../widgets/message_actions_overlay.dart';
import '../../widgets/attachment_panel.dart';
import '../../widgets/attachment/attachment_sheet.dart';
import '../../widgets/swipe_to_pop.dart';

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
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
  final Map<String, ValueNotifier<Map<String, dynamic>?>> _reactionNotifiers =
      {};
  final Map<String, ValueNotifier<List<double>>> _photoUploadProgress = {};

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

  String _nextTempId() =>
      'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';
  late AnimationController _shimmerController;
  Timer? _shimmerStartTimer;
  bool _historyKickedOff = false;
  List<CachedMessage> _messages = [];
  final ValueNotifier<int> _messagesRev = ValueNotifier(0);
  final Set<String> _deletingIds = {};
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

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollForDate);
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
    _pushSub = api.pushStream
        .where(
          (p) => p.opcode == Opcode.notifMark || p.opcode == Opcode.notifTyping,
        )
        .listen(_onIncomingPush);
    _messageEventSub = ChatsModule.messageEvents
        .where((e) => e.chatId == widget.chatId)
        .listen(_onMessageEvent);
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

    ChatsModule.getChat(_myId, widget.chatId)
        .then((value) {
          if (mounted && value.isNotEmpty) {
            setState(() {
              chat = value.first;
            });
            _recomputeHeaderStatus();
            _syncOtherReadTime();
          }
        })
        .catchError((_) {});

    final firstRows = await AppDatabase.loadMessages(
      _myId,
      widget.chatId,
      limit: 20,
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
    await _loadRemainingHistory();
  }

  Future<void> _loadRemainingHistory() async {
    final fullRows = await AppDatabase.loadMessages(
      _myId,
      widget.chatId,
      limit: 100,
    );
    final fullDecoded = await CachedMessage.fromDbRowsAsync(fullRows);
    if (mounted && fullDecoded.length > _messages.length) {
      _applyMergedMessages(fullDecoded);
    }

    if (!ChatsModule.isChatDirty(widget.chatId) && fullRows.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _onLoadingFinished();
        });
      }
      _loadForwardedSenderNames();
      return;
    }

    try {
      await messagesModule.fetchHistory(_myId, widget.chatId);
      ChatsModule.markChatClean(widget.chatId);
      final updatedRows = await AppDatabase.loadMessages(
        _myId,
        widget.chatId,
        limit: 100,
      );
      final updatedDecoded = await CachedMessage.fromDbRowsAsync(updatedRows);
      if (mounted) {
        _applyMergedMessages(updatedDecoded, markLoaded: true);
      }
      unawaited(
        ChatsModule.reconcileLastMessageIfPlaceholder(_myId, widget.chatId),
      );
      _loadForwardedSenderNames();
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

  void _applyMergedMessages(
    List<CachedMessage> decodedDesc, {
    bool markLoaded = false,
  }) {
    final byId = <String, CachedMessage>{for (final m in _messages) m.id: m};
    final merged = <CachedMessage>[];
    for (final fresh in decodedDesc.reversed) {
      final old = byId[fresh.id];
      merged.add(old != null && _sameMessage(old, fresh) ? old : fresh);
    }

    final changed = !_listsEquivalent(_messages, merged);
    if (!changed && !markLoaded) return;
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
        a.senderId == b.senderId;
  }

  bool _listsEquivalent(List<CachedMessage> a, List<CachedMessage> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollForDate);
    AppVisualStyle.current.removeListener(_onVisualStyleChanged);
    _floatingDateTimer?.cancel();
    _floatingDateCurved.dispose();
    _floatingDateAnimController.dispose();
    _floatingDate.dispose();
    _hasText.dispose();
    _showAttachmentPanel.removeListener(_onAttachPanelToggle);
    _showAttachmentPanel.dispose();
    _uploadSub?.cancel();
    _pushSub?.cancel();
    _messageEventSub?.cancel();
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
    _headerStatusNotifier.dispose();
    _otherReadTime.dispose();
    _messagesRev.dispose();
    _finishPrankReveal();
    _uploadStatus.dispose();
    _attachAnim.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _shimmerStartTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText.value) {
      _hasText.value = newHasText;
    }
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
    }
  }

  void _bumpMessages() {
    _combinedItemsCache = null;
    _messagesRev.value++;
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
      case MessageEditedEvent(:final message):
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx == -1) return;
        _messages[idx] = message;
        _bumpMessages();
      case MessageRemovedEvent(:final messageId):
        final idx = _messages.indexWhere((m) => m.id == messageId);
        if (idx == -1) return;
        _messages.removeAt(idx);
        _bumpMessages();
        _reactionNotifiers.remove(messageId)?.dispose();
      case MessageReactionsChangedEvent(:final messageId, :final reactionInfo):
        _reactionNotifiers[messageId]?.value = reactionInfo;
    }
  }

  Future<void> _loadOtherPresence() async {
    if (_myId == 0) return;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return;
    try {
      final entry = await PresenceFetch.get(otherId);
      if (!mounted || entry == null) return;
      _otherStatus = (entry['status'] as int?) ?? 0;
      _otherSeenTime = entry['seen'] as int?;
      _recomputeHeaderStatus();
    } catch (_) {}
  }

  void _onVisualStyleChanged() {
    if (mounted) setState(() {});
  }

  PreferredSizeWidget _materialAppBar(ColorScheme cs) {
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
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
        child: AppBar(
          backgroundColor: cs.surfaceContainerHigh,
          foregroundColor: cs.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: cs.onSurface),
          leading: IconButton(
            icon: Icon(
              widget.embedded ? Symbols.close : Symbols.arrow_back,
              weight: 400,
            ),
            onPressed: () {
              if (widget.embedded) {
                widget.onClose?.call();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              if (widget.imageUrl.isNotEmpty)
                CircleAvatar(
                  radius: 18,
                  backgroundImage: CachedNetworkImageProvider(
                    widget.imageUrl,
                    maxWidth: 144,
                    maxHeight: 144,
                  ),
                )
              else
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
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
          actions: [
            IconButton(
              icon: const Icon(Symbols.call, weight: 400),
              onPressed: _startCall,
            ),
            IconButton(
              icon: const Icon(Symbols.more_vert, weight: 400),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCall() async {
    if (widget.chatType != 'DIALOG') {
      showCustomNotification(context, 'Звонки доступны только в диалогах');
      return;
    }
    // Звонок уже идёт (возможно, свёрнут) — просто открываем его экран снова.
    final active = CallController.instance.activeSession;
    if (active != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: widget.name,
            avatarUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            session: active,
          ),
        ),
      );
      return;
    }
    final peerId = widget.chatId ^ _myId;
    if (peerId <= 0) return;
    final navigator = Navigator.of(context);
    try {
      final session = await CallController.instance.startOutgoing(peerId);
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: widget.name,
            avatarUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            session: session,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showCustomNotification(context, 'Не удалось начать звонок');
    }
  }

  void _recomputeHeaderStatus() {
    _headerStatusNotifier.value = _headerStatus();
  }

  String _headerStatus() {
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
    if (_otherStatus == 3) return 'Был(-а) недавно';
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

    final tempId = _nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final tempMessage = CachedMessage(
        id: tempId,
        accountId: _myId,
        chatId: widget.chatId,
        senderId: _myId,
        text: text,
        time: now,
        status: 'sending',
      );

      _hasText.value = false;
      _lastSentId = tempId;
      _messages.add(tempMessage);
      _messageController.clear();
      _bumpMessages();
      unawaited(_persistOutgoing(tempMessage));

      // Instant tactile "whoosh" the moment the message leaves the composer,
      // not after the network round-trip — feedback must feel immediate.
      Haptics.send();

      _scrollToBottom();
      _checkPrankTrigger(tempMessage);

      final actualId = await messagesModule.sendMessage(
        _myId,
        widget.chatId,
        text,
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
        );
        _messages[index] = sent;
        _bumpMessages();
        unawaited(_persistOutgoing(sent, removeId: tempId));
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
      Haptics.error();
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        final failed = CachedMessage(
          id: tempId,
          accountId: _myId,
          chatId: widget.chatId,
          senderId: _myId,
          text: text,
          time: now,
          status: 'error',
        );
        _messages[index] = failed;
        _bumpMessages();
        unawaited(_persistOutgoing(failed));
      }
    }
  }

  Future<void> _persistOutgoing(CachedMessage msg, {String? removeId}) async {
    try {
      if (removeId != null && removeId != msg.id) {
        await AppDatabase.deleteMessage(_myId, widget.chatId, removeId);
      }
      await AppDatabase.saveMessages([msg.toDbRow()]);
    } catch (_) {}
  }

  Future<void> _loadForwardedSenderNames() async {
    final forwardIds = <int>{};
    for (final msg in _messages) {
      if (msg.attachments != null) {
        for (final a in msg.attachments!) {
          if (a is ForwardedMessageAttachment) {
            if (a.originalSenderName == null) {
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
    return MediaQuery(
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
              appBar: AppVisualStyle.current.value == VisualStyle.glossy
                  ? AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 76,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Row(
                    children: [
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
                              widget.embedded
                                  ? Symbols.close
                                  : Symbols.arrow_back,
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
                              if (widget.imageUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: CachedNetworkImageProvider(
                                    widget.imageUrl,
                                    maxWidth: 144,
                                    maxHeight: 144,
                                  ),
                                )
                              else
                                CircleAvatar(
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
                              IconButton(
                                icon: Icon(
                                  Symbols.call,
                                  weight: 500,
                                  color: cs.onSurface,
                                ),
                                onPressed: _startCall,
                              ),
                              IconButton(
                                icon: Icon(
                                  Symbols.more_vert,
                                  weight: 500,
                                  color: cs.onSurface,
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                  )
                  : _materialAppBar(cs),
              body: Column(
                children: [
                  Expanded(
                    child: _isLoading && _messages.isEmpty
                        ? _buildShimmerLoading()
                        : _buildMessagesList(),
                  ),
                  AnimatedBuilder(
                    animation: _attachAnim,
                    builder: (context, _) {
                      if (_attachAnim.value == 0)
                        return const SizedBox.shrink();
                      final curve =
                          _attachAnim.status == AnimationStatus.reverse
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
                                onClose: () =>
                                    _showAttachmentPanel.value = false,
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
              itemCount: items.length,
              itemBuilder: (context, index) {
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
                );

                final pressable = _LongPressBubble(
                  message: message,
                  isMe: isMe,
                  onDelete: () => _confirmDeleteMessage(message, isMe),
                  child: bubble,
                );

                final Widget child;
                if (_deletingIds.contains(message.id)) {
                  child = _DeletingMessageAnimation(
                    key: ValueKey('del_${message.id}'),
                    onComplete: () => _finalizeDelete(message.id),
                    child: IgnorePointer(child: pressable),
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
                    child: pressable,
                  );
                } else {
                  child = pressable;
                }

                final builtItem = RepaintBoundary(
                  key: ValueKey('msg_${message.id}'),
                  child: child,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                      builder: (context, hasText, _) => GlossyPill(
                        color: hasText
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(27),
                        onTap: hasText ? _sendMessage : null,
                        depth: 8,
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: Center(
                            child: Icon(
                              hasText ? Symbols.send : Symbols.mic,
                              color: hasText ? cs.onPrimary : cs.onSurface,
                              size: 24,
                              weight: 400,
                            ),
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

  Future<void> _openAttachmentSheet() async {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final hadKeyboard = keyboard > 0;
    if (hadKeyboard) {
      setState(() => _keyboardReserve = keyboard);
      FocusManager.instance.primaryFocus?.unfocus();
    }
    await showAttachmentSheet(
      context,
      title: widget.name,
      onSend: _sendPhotos,
      onPickFile: _pickAndUploadFile,
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
    final photos = picked.where((ph) => !ph.item.isVideo).toList();
    if (photos.isEmpty) {
      if (mounted)
        showCustomNotification(context, 'Видео пока нельзя отправить');
      return;
    }

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

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    _showAttachmentPanel.value = false;
    _uploadStatus.value = _UploadStatus(active: true, total: file.size);

    final tempId = _addOptimisticFileMessage(
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
                _updateFileMessageStatus(
                  tempId,
                  'sent',
                  attachment: FileAttachment(
                    fileId: fileId,
                    fileToken: token,
                    name: file.name,
                    size: file.size,
                  ),
                );
              case UploadError(:final message):
                stopNotif();
                showCustomNotification(context, 'Ошибка: $message');
                _updateFileMessageStatus(tempId, 'error');
            }
          },
          onDone: () {
            if (!mounted) return;
            stopNotif();
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
            _uploadStatus.value = const _UploadStatus();
            _uploadSub = null;
          },
          onError: (Object e) {
            if (!mounted) return;
            stopNotif();
            showCustomNotification(context, 'Ошибка: $e');
            _updateFileMessageStatus(tempId, 'error');
            _uploadStatus.value = const _UploadStatus();
            _uploadSub = null;
          },
        );
  }
}

class _AttachButton extends StatelessWidget {
  final ValueNotifier<bool> hasText;
  final VoidCallback onOpen;
  final ValueNotifier<_UploadStatus> uploadStatus;
  final Color mutedIcon;
  final ColorScheme cs;

  const _AttachButton({
    required this.hasText,
    required this.onOpen,
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
        final onTap = (isText || status.active) ? null : onOpen;
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

class _LongPressBubble extends StatefulWidget {
  final Widget child;
  final CachedMessage message;
  final bool isMe;
  final VoidCallback onDelete;

  const _LongPressBubble({
    required this.child,
    required this.message,
    required this.isMe,
    required this.onDelete,
  });

  @override
  State<_LongPressBubble> createState() => _LongPressBubbleState();
}

class _LongPressBubbleState extends State<_LongPressBubble> {
  final GlobalKey _boundaryKey = GlobalKey();
  MessageActionsController? _controller;

  @override
  void dispose() {
    _controller?.commit();
    _controller = null;
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
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

    Haptics.medium();

    final controller = MessageActionsController();
    controller.attach(details.globalPosition);
    _controller = controller;

    showMessageActions(
      context: ctx,
      snapshot: snapshot,
      originRect: rect,
      tapPoint: details.globalPosition,
      isMe: widget.isMe,
      messageText: widget.message.text,
      controller: controller,
      style: AppMessageActionsStyle.current.value,
      onDelete: widget.onDelete,
      onDispose: () {
        if (identical(_controller, controller)) {
          _controller = null;
        }
        controller.dispose();
      },
    );
  }

  void _onSecondaryTapDown(TapDownDetails details) {
    if (_controller != null) return;
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    final origin = renderObject.localToGlobal(Offset.zero);
    final rect = origin & renderObject.size;

    final controller = MessageActionsController();
    _controller = controller;

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
      onDispose: () {
        if (identical(_controller, controller)) {
          _controller = null;
        }
        controller.dispose();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerMove: (event) => _controller?.updatePointer(event.position),
      onPointerUp: (event) => _controller?.commit(),
      onPointerCancel: (event) => _controller?.commit(),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: (d) =>
            _controller?.updatePointer(d.globalPosition),
        onLongPressEnd: (_) => _controller?.commit(),
        onSecondaryTapDown: _onSecondaryTapDown,
        child: RepaintBoundary(key: _boundaryKey, child: widget.child),
      ),
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
