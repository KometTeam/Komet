import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/frontend/screens/chats/chat_info_screen.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/haptics.dart';
import '../../../models/attachment.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../widgets/message_bubble.dart';
import '../../widgets/attachment_panel.dart';

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
  bool _hasText = false;
  bool _isLoading = true;
  bool _showAttachmentPanel = false;
  late AnimationController _shimmerController;
  List<CachedMessage> _messages = [];
  int _myId = 0;
  CachedChat? chat;

  DateTime? _floatingDate;
  DateTime? _lastFloatingDate;
  Timer? _floatingDateTimer;
  late final AnimationController _floatingDateAnimController;
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
    _floatingDateAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 380),
    );

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final activeProfile = await AppDatabase.loadActiveProfile();
    _myId = activeProfile?.id ?? 0;
    ChatsModule.getChat(_myId, widget.chatId).then((value) {
      if (mounted && value.isNotEmpty) {
        setState(() { chat = value.first; });
      }
    }).catchError((_) {});

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
    _floatingDateAnimController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final bool newHasText = _messageController.text.trim().isNotEmpty;
    if (newHasText != _hasText) {
      setState(() {
        _hasText = newHasText;
      });
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == 0) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
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

      setState(() {
        _lastSentId = tempId;
        _messages.add(tempMessage);
        _messageController.clear();
        _hasText = false;
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

    final bool dateChanged = result != _lastFloatingDate;
    _lastFloatingDate = result;

    if (result != _floatingDate) {
      setState(() => _floatingDate = result);
    }

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
      {Key? key}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontStyle: FontStyle.italic,
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
    final String status = chat?.type == "CHAT" ? "${chat?.participants.length ?? 0} участников" : "last seen recently";
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
                    backgroundImage: CachedNetworkImageProvider(widget.imageUrl),
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
                      Text(
                        status,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _isLoading && _messages.isEmpty
                    ? _buildShimmerLoading()
                    : _buildMessagesList(),
              ),
              _buildInputArea(context),
            ],
          ),
          if (_showAttachmentPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AttachmentPanel(
                chatId: widget.chatId,
                onClose: () => setState(() => _showAttachmentPanel = false),
              ),
            ),
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
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          cacheExtent: 9999,
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

            if (isMe && message.id == _lastSentId) {
              return _SentMessageAnimation(
                key: ValueKey('anim_${message.id}'),
                onComplete: () {
                  if (mounted) setState(() => _lastSentId = null);
                },
                child: bubble,
              );
            }
            return bubble;
          },
        ),
        if (_lastFloatingDate != null)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _floatingDateAnimController,
                builder: (context, child) {
                  final t = CurvedAnimation(
                    parent: _floatingDateAnimController,
                    curve: Curves.easeOut,
                    reverseCurve: Curves.easeIn,
                  ).value;
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * t,
                      child: child,
                    ),
                  );
                },
                child: _buildDateSeparatorWidget(context, _lastFloatingDate!),
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
                            if (_hasText) _sendMessage();
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _hasText ? 0 : 36,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hasText ? 0 : 1,
                        child: _hasText
                            ? const SizedBox.shrink()
                            : GestureDetector(
                                onTap: _showAttachmentPanel ? null : () => setState(() => _showAttachmentPanel = true),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_showAttachmentPanel)
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.primary,
                                          ),
                                        ),
                                      Icon(
                                        Symbols.attachment,
                                        color: _showAttachmentPanel
                                            ? cs.onSurfaceVariant.withValues(alpha: 0.3)
                                            : mutedIcon,
                                        size: 24,
                                        weight: 400,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hasText ? cs.primary : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: GestureDetector(
                onTap: _hasText ? _sendMessage : null,
                child: Icon(
                  _hasText ? Symbols.send : Symbols.mic,
                  color: _hasText ? cs.onPrimary : cs.onSurface,
                  size: 24,
                  weight: 400,
                ),
              ),
            ),
          ],
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
