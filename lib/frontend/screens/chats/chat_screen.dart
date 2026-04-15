import 'dart:async';
import 'package:flutter/material.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../main.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/messages.dart';
import '../../../core/storage/app_database.dart';
import '../../../models/attachment.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  bool _isLoading = true;
  bool _isSending = false;
  late AnimationController _shimmerController;
  List<CachedMessage> _messages = [];
  int _myId = 0;
  CachedChat? chat;
  
  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final activeProfile = await AppDatabase.loadActiveProfile();
    _myId = activeProfile?.id ?? 0;
    ChatsModule.getChat(_myId, widget.chatId).then((value) {
      chat = value[0];
    }).catchError((error) {

    });

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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == 0) return;

    setState(() {
      _isSending = true;
    });

    try {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now().millisecondsSinceEpoch;

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
        _messages.add(tempMessage);
        _messageController.clear();
        _hasText = false;
      });

      _scrollToBottom();

      await messagesModule.sendMessage(_myId, widget.chatId, text);

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        setState(() {
          _messages[index] = CachedMessage(
            id: tempId,
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
      debugPrint('Error sending message: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // TODO: Локализация
    // TODO: Cклонения
    String? status = chat?.type == "CHAT" ? "${chat?.participants.length.toString()} участников" : "last seen recently";
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
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
                backgroundImage: NetworkImage(widget.imageUrl),
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
                  Text(
                    widget.name,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(
                    status ?? "",
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
      body: Column(
        children: [
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? _buildShimmerLoading()
                : _buildMessagesList(),
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

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final isMe = message.senderId == _myId;
        final prevMessage = index < _messages.length - 1
            ? _messages[_messages.length - 2 - index]
            : null;
        final nextMessage = index > 0
            ? _messages[_messages.length - index]
            : null;

        return MessageBubble(
          message: message,
          isMe: isMe,
          myId: _myId,
          prevMessage: prevMessage,
          nextMessage: nextMessage,
          chatType: chat!.type,
        );
      },
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
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _hasText ? 0 : 36,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hasText ? 0 : 1,
                        child: _hasText
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Icon(
                                  Symbols.attachment,
                                  color: mutedIcon,
                                  size: 24,
                                  weight: 400,
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
