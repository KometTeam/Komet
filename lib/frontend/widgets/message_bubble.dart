import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../backend/modules/messages.dart';

enum MessageType { text, attachment, voice }

enum BubbleShape { singleTop, singleBottom, singleMiddle, groupedMiddle }

class MessageBubble extends StatelessWidget {
  final CachedMessage message;
  final bool isMe;
  final int myId;
  final CachedMessage? prevMessage;
  final CachedMessage? nextMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myId,
    this.prevMessage,
    this.nextMessage,
  });

  bool get isGroupedWithNext {
    if (nextMessage == null) return false;
    if (nextMessage!.senderId != message.senderId) return false;
    final timeDiff = nextMessage!.time - message.time;
    return timeDiff < 300000;
  }

  BubbleShape get shape {
    final hasPrevFromMe = prevMessage?.senderId == message.senderId;
    final prevTimeDiff = hasPrevFromMe
        ? message.time - prevMessage!.time
        : 999999999;

    final hasNextFromMe = nextMessage?.senderId == message.senderId;
    final nextTimeDiff = hasNextFromMe
        ? nextMessage!.time - message.time
        : 999999999;

    final bool groupedWithPrev = hasPrevFromMe && prevTimeDiff < 300000;
    final bool groupedWithNext = hasNextFromMe && nextTimeDiff < 300000;

    if (!groupedWithPrev && !groupedWithNext) return BubbleShape.singleMiddle;
    if (!groupedWithPrev && groupedWithNext) return BubbleShape.singleTop;
    if (groupedWithPrev && !groupedWithNext) return BubbleShape.singleBottom;

    return BubbleShape.groupedMiddle;
  }

  MessageType get contentType {
    final payload = message.payload;
    if (payload == null) return MessageType.text;

    final attachments = payload['attachments'];
    if (attachments is List && attachments.isNotEmpty)
      return MessageType.attachment;

    final voice = payload['voice'];
    if (voice != null) return MessageType.voice;

    return MessageType.text;
  }

  // скругление уже смешариков т.е сообщений, те которые isme ? .. Это наши, после : это чужие
  BorderRadius get _borderRadius {
    switch (shape) {
      case BubbleShape.singleTop:
        return BorderRadius.only(
          topLeft: isMe ? Radius.circular(20) : Radius.circular(4),
          topRight: isMe ? Radius.circular(4) : Radius.circular(20),
          bottomLeft: isMe ? Radius.circular(4) : Radius.circular(4),
          bottomRight: isMe ? Radius.circular(4) : Radius.circular(4),
        );
      case BubbleShape.singleBottom:
        return BorderRadius.only(
          topLeft: isMe ? Radius.circular(4) : Radius.circular(4),
          topRight: isMe ? Radius.circular(4) : Radius.circular(4),
          bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
          bottomRight: isMe ? Radius.circular(4) : Radius.circular(20),
        );
      case BubbleShape.singleMiddle:
        return BorderRadius.only(
          topLeft: isMe ? Radius.circular(20) : Radius.circular(20),
          topRight: isMe ? Radius.circular(20) : Radius.circular(20),
          bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
          bottomRight: isMe ? Radius.circular(4) : Radius.circular(20),
        );
      case BubbleShape.groupedMiddle:
        return BorderRadius.only(
          topLeft: isMe ? Radius.circular(20) : Radius.circular(4),
          topRight: isMe ? Radius.circular(4) : Radius.circular(4),
          bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
          bottomRight: isMe ? Radius.circular(4) : Radius.circular(4),
        );
    }
  }

  // ВРОДЕ отступы между сообщениями, если они выглядят адекватно не трогайте пж я ради них кишку на шею намотал
  // ОТСТУПЫ МЕЖДУ СООБЩЕНИЯМИ (top/bottom margin)
  // Зависит от shape (группировка) И contentType (тип контента)
  double get topMargin {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.singleTop:
            return 6;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.attachment:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 6;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.voice:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
    }
    return 4;
  }

  double get bottomMargin {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.attachment:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.voice:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
    }
    return 4;
  }

  // Внутренний отступ, размеры типа я хз
  EdgeInsets get padding {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.groupedMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
          case BubbleShape.singleTop:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleBottom:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
        }
      case MessageType.attachment:
        switch (shape) {
          case BubbleShape.groupedMiddle:
            return const EdgeInsets.all(0);
          case BubbleShape.singleTop:
            return const EdgeInsets.all(0);
          case BubbleShape.singleBottom:
            return const EdgeInsets.all(0);
          case BubbleShape.singleMiddle:
            return const EdgeInsets.all(0);
        }
      case MessageType.voice:
        switch (shape) {
          case BubbleShape.groupedMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
          case BubbleShape.singleTop:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleBottom:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
        }
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        top: topMargin,
        bottom: bottomMargin,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? (isDark ? const Color(0xFF2C5F8D) : const Color(0xFF007AFF))
                : (isDark
                      ? cs.surfaceContainerHighest
                      : const Color(0xFFE9E9EB)),
            borderRadius: _borderRadius,
          ),
          padding: padding,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (contentType) {
      case MessageType.attachment:
        return _buildAttachmentContent(context);
      case MessageType.voice:
        return _buildVoiceContent(context);
      case MessageType.text:
      default:
        return _buildTextContent(context);
    }
  }

  Widget _buildTextContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            message.text ?? '',
            style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            _formatTime(message.time),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ),
        if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(context)],
      ],
    );
  }

  Widget _buildAttachmentContent(BuildContext context) {
    final payload = message.payload;
    final attachments = payload?['attachments'] as List?;
    if (attachments == null || attachments.isEmpty) {
      return _buildTextContent(context);
    }

    final attachment = attachments.first as Map<String, dynamic>?;
    if (attachment == null) return _buildTextContent(context);

    final type = attachment['type'] as String?;
    final url = attachment['url'] ?? attachment['path'];
    final thumbnail = attachment['thumbnail'];

    if (type == 'image' || type == 'photo') {
      return _buildImageAttachment(context, url, thumbnail);
    } else if (type == 'video') {
      return _buildVideoAttachment(context, url, attachment['duration']);
    } else if (type == 'file') {
      return _buildFileAttachment(context, attachment['name'] ?? 'File', url);
    }

    return _buildTextContent(context);
  }

  Widget _buildImageAttachment(
    BuildContext ctx,
    dynamic url,
    dynamic thumbnail,
  ) {
    final cs = Theme.of(ctx).colorScheme;
    final imageUrl = url?.toString() ?? '';
    final thumbUrl = thumbnail?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              if (thumbUrl.isNotEmpty)
                Image.network(
                  thumbUrl,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(cs),
                )
              else if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildImagePlaceholder(cs),
                )
              else
                _buildImagePlaceholder(cs),
              if (imageUrl.isNotEmpty)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: () {}),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildMeta(ctx),
      ],
    );
  }

  Widget _buildImagePlaceholder(ColorScheme cs) {
    return Container(
      width: 200,
      height: 200,
      color: cs.surfaceContainerHighest,
      child: Icon(Symbols.image, size: 48, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildVideoAttachment(
    BuildContext ctx,
    dynamic url,
    dynamic duration,
  ) {
    final cs = Theme.of(ctx).colorScheme;
    final videoUrl = url?.toString() ?? '';
    final durationSec = duration as int? ?? 0;
    final durationStr = _formatDuration(durationSec);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Container(
                width: 200,
                height: 150,
                color: cs.surfaceContainerHighest,
                child: Icon(
                  Symbols.videocam,
                  size: 48,
                  color: cs.onSurfaceVariant,
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    durationStr,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              if (videoUrl.isNotEmpty)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: () {}),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildMeta(ctx),
      ],
    );
  }

  Widget _buildFileAttachment(BuildContext ctx, String fileName, dynamic url) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? Colors.white.withValues(alpha: 0.15)
                : (isDark ? cs.surface : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.3)
                  : cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Symbols.description,
                  color: isMe ? Colors.white : cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to download',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildMeta(ctx),
      ],
    );
  }

  Widget _buildVoiceContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));
    final payload = message.payload;
    final voice = payload?['voice'] as Map<String, dynamic>?;
    final duration = voice?['duration'] as int? ?? 0;
    final url = voice?['url']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _VoiceMessageBubble(
          duration: duration,
          url: url,
          textColor: textColor,
          isMe: isMe,
        ),
        const SizedBox(height: 6),
        _buildMeta(context),
      ],
    );
  }

  Widget _buildMeta(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final timeColor = isMe ? Colors.white70 : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.time),
            style: TextStyle(color: timeColor, fontSize: 11),
          ),
          if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(context)],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final status = message.status;
    IconData icon;
    Color color;

    if (status == null || status == 'sending' || status == 'pending') {
      icon = Symbols.check;
      color = Colors.white70;
    } else {
      switch (status) {
        case 'sent':
          icon = Symbols.check;
          color = Colors.white70;
        case 'delivered':
          icon = Symbols.done_all;
          color = Colors.white70;
        case 'read':
          icon = Symbols.done_all;
          color = const Color(0xFF34C759);
        case 'error':
          icon = Symbols.error;
          color = Colors.redAccent;
        default:
          icon = Symbols.check;
          color = Colors.white70;
      }
    }

    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  final int duration;
  final String url;
  final Color textColor;
  final bool isMe;

  const _VoiceMessageBubble({
    required this.duration,
    required this.url,
    required this.textColor,
    required this.isMe,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  bool _isPlaying = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Symbols.pause : Symbols.play_arrow,
                color: widget.isMe ? Colors.white : cs.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isDark
                                  ? cs.surfaceContainerHighest
                                  : const Color(0xFFD1D1D6)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.5)
                              : cs.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: Center(
                        child: Text(
                          _formatDuration(widget.duration),
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
