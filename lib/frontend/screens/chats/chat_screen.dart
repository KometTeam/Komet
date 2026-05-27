import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/file_uploader.dart';
import 'package:komet/backend/modules/upload_notification_service.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/config/app_cache_extent.dart';
import '../../../core/config/app_message_actions_style.dart';
import '../../../models/attachment.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/message_actions_overlay.dart';
import '../../widgets/attachment_panel.dart';

class _UploadStatus {
  final bool active;
  final int sent;
  final int total;

  const _UploadStatus({
    this.active = false,
    this.sent = 0,
    this.total = 0,
  });

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

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final ValueNotifier<bool> _hasText = ValueNotifier(false);
  bool _isLoading = true;
  final ValueNotifier<bool> _showAttachmentPanel = ValueNotifier(false);
  final ValueNotifier<_UploadStatus> _uploadStatus = ValueNotifier(const _UploadStatus());
  StreamSubscription<UploadEvent>? _uploadSub;
  StreamSubscription<Packet>? _pushSub;
  final Set<int> _typingUserIds = {};
  final Map<int, Timer> _typingTimers = {};
  int _otherStatus = 0;
  int? _otherSeenTime;
  final ValueNotifier<String> _headerStatusNotifier = ValueNotifier('');
  int _tempIdCounter = 0;
  late final AnimationController _attachAnim;

  String _nextTempId() => 'temp_${++_tempIdCounter}_${DateTime.now().microsecondsSinceEpoch}';
  late AnimationController _shimmerController;
  List<CachedMessage> _messages = [];
  int _myId = 0;
  CachedChat? chat;

  final ValueNotifier<DateTime?> _floatingDate = ValueNotifier(null);
  Timer? _floatingDateTimer;
  late final AnimationController _floatingDateAnimController;
  late final CurvedAnimation _floatingDateCurved;
  final Map<int, GlobalKey> _separatorKeys = {};
  double _lastScrollOffset = 0;
  String? _lastSentId;
  
  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScrollForDate);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _attachAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _showAttachmentPanel.addListener(_onAttachPanelToggle);
    _pushSub = api.pushStream
        .where((p) =>
            p.opcode == Opcode.notifMessage ||
            p.opcode == Opcode.notifMark ||
            p.opcode == Opcode.notifTyping)
        .listen(_onIncomingPush);
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

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final activeProfile = await AppDatabase.loadActiveProfile();
    _myId = activeProfile?.id ?? 0;
    ChatsModule.getChat(_myId, widget.chatId).then((value) {
      if (mounted && value.isNotEmpty) {
        setState(() { chat = value.first; });
        _recomputeHeaderStatus();
      }
    }).catchError((_) {});
    if (widget.chatType == 'DIALOG') {
      unawaited(_loadOtherPresence());
    }

    final cachedRows = await AppDatabase.loadMessages(
      _myId,
      widget.chatId,
      limit: 100,
    );
    if (mounted && cachedRows.isNotEmpty) {
      setState(() {
        _messages = cachedRows.map((r) => CachedMessage.fromDbRow(r)).toList();
        _messages.sort((a, b) => a.time.compareTo(b.time));
        if (api.state == SessionState.online) {
          _isLoading = false;
        }
      });
    }

    try {
      await messagesModule.fetchHistory(_myId, widget.chatId);
      final updatedRows = await AppDatabase.loadMessages(
        _myId,
        widget.chatId,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _messages = updatedRows
              .map((r) => CachedMessage.fromDbRow(r))
              .toList();
          _messages.sort((a, b) => a.time.compareTo(b.time));
          _isLoading = false;
        });
      }
      _loadForwardedSenderNames();
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScrollForDate);
    _floatingDateTimer?.cancel();
    _floatingDateCurved.dispose();
    _floatingDateAnimController.dispose();
    _floatingDate.dispose();
    _hasText.dispose();
    _showAttachmentPanel.removeListener(_onAttachPanelToggle);
    _showAttachmentPanel.dispose();
    _uploadSub?.cancel();
    _pushSub?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    _headerStatusNotifier.dispose();
    _uploadStatus.dispose();
    _attachAnim.dispose();
    _messageController.dispose();
    _scrollController.dispose();
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

  String? _effectiveStatus(CachedMessage msg) {
    if (msg.senderId != _myId) return null;
    if (msg.status == 'sending' || msg.status == 'error') return msg.status;
    final c = chat;
    if (c == null) return 'sent';
    int otherReadTime = 0;
    for (final entry in c.participants.entries) {
      if (entry.key != _myId && entry.value > otherReadTime) {
        otherReadTime = entry.value;
      }
    }
    if (otherReadTime > 0 && otherReadTime >= msg.time) return 'read';
    return 'sent';
  }

  void _onIncomingPush(Packet packet) {
    if (!mounted) return;
    switch (packet.opcode) {
      case Opcode.notifMessage:
        _onIncomingMessage(packet);
      case Opcode.notifMark:
        _onMessageRead(packet);
      case Opcode.notifTyping:
        _onTyping(packet);
    }
  }

  Future<void> _loadOtherPresence() async {
    if (_myId == 0) return;
    final otherId = widget.chatId ^ _myId;
    if (otherId <= 0) return;
    try {
      final p = await api.sendRequest(
        Opcode.contactPresence,
        {'contactIds': [otherId]},
      );
      if (!mounted) return;
      final presence = (p.payload as Map?)?['presence'] as Map?;
      final entry = presence?[otherId.toString()] ?? presence?[otherId];
      if (entry is Map) {
        _otherStatus = (entry['status'] as int?) ?? 0;
        _otherSeenTime = entry['seen'] as int?;
        _recomputeHeaderStatus();
      }
    } catch (_) {}
  }

  String _formatLastSeen(int secondsSinceEpoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Был(-а) только что';
    if (diff.inMinutes < 60) return 'Был(-а) ${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return 'Был(-а) ${diff.inHours} ч назад';
    if (diff.inDays < 7) return 'Был(-а) ${diff.inDays} дн назад';
    const months = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    return 'Был(-а) ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _recomputeHeaderStatus() {
    _headerStatusNotifier.value = _headerStatus();
  }

  String _headerStatus() {
    if (_typingUserIds.isNotEmpty) return 'Печатает...';
    if (widget.chatType == 'CHAT') {
      return '${chat?.participants.length ?? 0} участников';
    }
    if (widget.chatType == 'CHANNEL') {
      return '${chat?.participants.length ?? 0} подписчиков';
    }
    if (_otherStatus == 1) return 'В сети';
    if (_otherStatus == 3) return 'Был(-а) недавно';
    final s = _otherSeenTime;
    if (s != null && s > 0) return _formatLastSeen(s);
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
    setState(() {
      c.participants[userId] = mark;
    });
  }

  void _onIncomingMessage(Packet packet) {
    if (!mounted) return;
    final payload = packet.payload;
    if (payload is! Map) return;
    final chatId = payload['chatId'];
    if (chatId != widget.chatId) return;
    final msg = payload['message'];
    if (msg is! Map) return;

    final senderId = msg['sender'];
    if (senderId is! int) return;
    if (senderId == _myId) return;

    final msgId = msg['id']?.toString();
    if (msgId == null || msgId.isEmpty) return;
    if (_messages.any((m) => m.id == msgId)) return;

    List<MessageAttachment>? attachments;
    final attaches = msg['attaches'];
    if (attaches is List && attaches.isNotEmpty) {
      attachments = attaches
          .whereType<Map>()
          .map((a) => MessageAttachment.fromMap(Map<String, dynamic>.from(a)))
          .toList();
    }

    final cached = CachedMessage(
      id: msgId,
      accountId: _myId,
      chatId: widget.chatId,
      senderId: senderId,
      text: msg['text'] as String?,
      time: (msg['time'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      status: 'sent',
      payload: Map<String, dynamic>.from(msg),
      attachments: attachments,
    );

    setState(() {
      _lastSentId = msgId;
      _messages.add(cached);
    });
    _clearTyping(senderId);
    Haptics.tap();
    _scrollToBottom();
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
      setState(() {
        _lastSentId = tempId;
        _messages.add(tempMessage);
        _messageController.clear();
      });

      // Instant tactile "whoosh" the moment the message leaves the composer,
      // not after the network round-trip — feedback must feel immediate.
      Haptics.send();

      _scrollToBottom();

      final actualId = await messagesModule.sendMessage(_myId, widget.chatId, text);

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        setState(() {
          _messages[index] = CachedMessage(
            id: actualId.isNotEmpty ? actualId : tempId,
            accountId: _myId,
            chatId: widget.chatId,
            senderId: _myId,
            text: text,
            time: now,
            status: 'sent',
          );
        });
      }

      if (chat == null) {
        unawaited(
          ChatsModule.refreshChats(api, [widget.chatId]).then((list) {
            if (!mounted || list.isEmpty) return;
            setState(() => chat = list.first);
          }),
        );
      }
    } catch (e) {
      Haptics.error();
      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        setState(() {
          _messages[index] = CachedMessage(
            id: tempId,
            accountId: _myId,
            chatId: widget.chatId,
            senderId: _myId,
            text: text,
            time: now,
            status: 'error',
          );
        });
      }
    }
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

    for (final id in forwardIds) {
      final name = await messagesModule.searchContactById(id);
      final avatar = ContactCache.getAvatar(id);
      if (name != null && mounted) {
        setState(() {
          for (var i = 0; i < _messages.length; i++) {
            final msg = _messages[i];
            if (msg.attachments != null) {
              final newAttaches = msg.attachments!.map((a) {
                if (a is ForwardedMessageAttachment &&
                    a.originalSenderId == id &&
                    a.originalSenderName == null) {
                  return ForwardedMessageAttachment(
                    originalSenderId: id,
                    originalSenderName: name,
                    originalSenderAvatar: avatar,
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
          }
        });
      }
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
    final List<Object> items = [];
    final Set<int> usedDates = {};

    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.time);
      final dayMillis = DateTime(msgDate.year, msgDate.month, msgDate.day)
          .millisecondsSinceEpoch;

      bool needSeparator = i == 0;
      if (!needSeparator) {
        final prevDate =
            DateTime.fromMillisecondsSinceEpoch(_messages[i - 1].time);
        final prevDayMillis =
            DateTime(prevDate.year, prevDate.month, prevDate.day)
                .millisecondsSinceEpoch;
        needSeparator = dayMillis != prevDayMillis;
      }

      if (needSeparator) {
        _separatorKeys.putIfAbsent(dayMillis, () => GlobalKey());
        usedDates.add(dayMillis);
        items.add(_DateSeparatorItem(
          DateTime.fromMillisecondsSinceEpoch(dayMillis),
          _separatorKeys[dayMillis]!,
        ));
      }

      items.add(_MessageItem(msg, i));
    }

    _separatorKeys.removeWhere((k, _) => !usedDates.contains(k));
    return items;
  }

  void _onScrollForDate() {
    if (!_scrollController.hasClients) return;
    final currentOffset = _scrollController.position.pixels;
    final scrollingUp = currentOffset > _lastScrollOffset;
    _lastScrollOffset = currentOffset;

    _floatingDateTimer?.cancel();

    if (!scrollingUp) {
      _floatingDateAnimController.reverse();
      return;
    }

    _floatingDateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _floatingDateAnimController.reverse();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFloatingDate());
  }

  void _updateFloatingDate() {
    if (!mounted) return;
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
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildDateSeparatorWidget(BuildContext context, DateTime date,
      {Key? key, bool floating = false}) {
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
    final cs = Theme.of(context).colorScheme;
    
    // TODO: Локализация
    // TODO: Cклонения
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatInfoScreen(
              chatId: widget.chatId,
              name: widget.name,
              imageUrl: widget.imageUrl,
              chatType: widget.chatType)
            )
          ),
          child: AppBar(
            backgroundColor: cs.surfaceContainerHigh,
            foregroundColor: cs.onSurface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: cs.onSurface),
            leading: IconButton(
              icon: const Icon(Symbols.arrow_back, weight: 400),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                if (widget.imageUrl.isNotEmpty)
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: CachedNetworkImageProvider(widget.imageUrl, maxWidth: 144, maxHeight: 144),
                  )
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                      style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12),
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
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Symbols.more_vert, weight: 400),
                onPressed: () {},
              ),
            ],
          ),
        )),
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
              if (_attachAnim.value == 0) return const SizedBox.shrink();
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
    );
  }

  Widget _buildMessagesList() {
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
          builder: (context, cacheExtent, _) => ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          cacheExtent: cacheExtent,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[items.length - 1 - index];

            if (item is _DateSeparatorItem) {
              return _buildDateSeparatorWidget(context, item.date,
                  key: item.key);
            }

            final msgItem = item as _MessageItem;
            final message = msgItem.message;
            final msgIndex = msgItem.index;
            final isMe = message.senderId == _myId;
            final prevMessage =
                msgIndex > 0 ? _messages[msgIndex - 1] : null;
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
            );

            final pressable = _LongPressBubble(
              message: message,
              isMe: isMe,
              child: bubble,
            );

            if (message.id == _lastSentId) {
              return _SentMessageAnimation(
                key: ValueKey('anim_${message.id}'),
                onComplete: () {
                  if (mounted) setState(() => _lastSentId = null);
                },
                child: pressable,
              );
            }
            return pressable;
          },
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
                  child: _buildDateSeparatorWidget(context, date, floating: true),
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
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.surfaceContainerHighest.withValues(alpha: 0.92),
                  cs.surface,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
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
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    cs.surfaceContainerHighest.withValues(alpha: 0.92),
                    cs.surface,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _attachAnim,
                      builder: (context, child) {
                        final t = _attachAnim.value;
                        return IgnorePointer(
                          ignoring: t > 0.5,
                          child: Opacity(opacity: (1 - t).clamp(0.0, 1.0), child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Symbols.face, color: mutedIcon, size: 24, weight: 400),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Focus(
                                onKeyEvent: (node, event) {
                                  if (event is KeyDownEvent &&
                                      event.logicalKey == LogicalKeyboardKey.enter &&
                                      !HardwareKeyboard.instance.isShiftPressed) {
                                    if (_hasText.value) _sendMessage();
                                    return KeyEventResult.handled;
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  controller: _messageController,
                                  style: TextStyle(color: cs.onSurface, fontSize: 16),
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
                              panelOpen: _showAttachmentPanel,
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
                              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
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
                      builder: (context, hasText, _) => Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hasText ? cs.primary : cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: GestureDetector(
                          onTap: hasText ? _sendMessage : null,
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
    setState(() {
      _lastSentId = tempId;
      _messages.add(msg);
    });
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
    setState(() {
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
    });
  }

  Future<void> _sendHistoryFile(FileHistoryEntry entry) async {
    final tempId = _addOptimisticFileMessage(FileAttachment(
      fileId: entry.fileId,
      fileToken: entry.token,
      name: entry.filename,
      size: entry.size,
    ));
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
        FileHistoryCache.add(FileHistoryEntry(
          fileId: fileId,
          sentAt: DateTime.now(),
        ));
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

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    _showAttachmentPanel.value = false;
    _uploadStatus.value = _UploadStatus(active: true, total: file.size);

    final tempId = _addOptimisticFileMessage(FileAttachment(
      name: file.name,
      size: file.size,
    ));

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
            _uploadStatus.value = _UploadStatus(active: true, sent: sent, total: total);
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final elapsed = nowMs - notifLastMs;
            if (elapsed >= 500) {
              notifSpeedBps = ((sent - notifLastSent) * 1000 / elapsed).round();
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
            FileHistoryCache.add(FileHistoryEntry(
              fileId: fileId,
              url: url,
              token: token,
              filename: file.name,
              size: file.size,
              sentAt: DateTime.now(),
            ));
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
            id: '', accountId: 0, chatId: 0, senderId: 0, time: 0,
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
  final ValueNotifier<bool> panelOpen;
  final ValueNotifier<_UploadStatus> uploadStatus;
  final Color mutedIcon;
  final ColorScheme cs;

  const _AttachButton({
    required this.hasText,
    required this.panelOpen,
    required this.uploadStatus,
    required this.mutedIcon,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hasText, panelOpen, uploadStatus]),
      builder: (context, _) {
        final isText = hasText.value;
        final open = panelOpen.value;
        final status = uploadStatus.value;
        final iconColor = status.awaitingResponse
            ? cs.primary
            : (status.active || open
                ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                : mutedIcon);
        final onTap = (isText || status.active || open)
            ? null
            : () => panelOpen.value = true;
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
            final raw = ((anim.value - startInterval) / 0.45).clamp(0.0, 1.0);
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
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Stack(children: [
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
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          _labelForEntry(e),
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 9),
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
            ]),
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

  const _LongPressBubble({
    required this.child,
    required this.message,
    required this.isMe,
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
        child: RepaintBoundary(
          key: _boundaryKey,
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
    _slide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
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
