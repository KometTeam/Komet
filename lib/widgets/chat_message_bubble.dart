import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show File;
import 'dart:convert' show base64Decode, jsonDecode, jsonEncode;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:crypto/crypto.dart' as crypto;
import 'package:intl/intl.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gwid/screens/chat_screen.dart';
import 'package:gwid/services/avatar_cache_service.dart';
import 'package:gwid/widgets/user_profile_panel.dart';
import 'package:gwid/api/api_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:gwid/widgets/full_screen_video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:gwid/services/cache_service.dart';
import 'package:video_player/video_player.dart';
import 'package:gwid/services/music_player_service.dart';
import 'package:platform_info/platform_info.dart';
import 'package:gwid/utils/download_path_helper.dart';
import 'package:gwid/services/chat_encryption_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:gwid/widgets/message_bubble/models/message_read_status.dart';
import 'package:gwid/widgets/message_bubble/models/komet_segment.dart';
import 'package:gwid/widgets/message_bubble/services/file_download_service.dart';
import 'package:gwid/widgets/message_bubble/widgets/komet_animated_texts.dart';
import 'package:gwid/widgets/message_bubble/widgets/media/audio_player_widget.dart';
import 'package:gwid/widgets/message_bubble/utils/user_color_helper.dart';
import 'package:gwid/widgets/message_bubble/widgets/dialogs/custom_emoji_dialog.dart';

class DomainLinkifier extends Linkifier {
  const DomainLinkifier();

  @override
  List<LinkifyElement> parse(
    List<LinkifyElement> elements,
    LinkifyOptions options,
  ) {
    final List<LinkifyElement> list = [];

    for (final element in elements) {
      if (element is TextElement) {
        final text = element.text;
        final matches = RegExp(
          r'\b([a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+\.[a-zA-Z]{2,}\b',
        ).allMatches(text);

        if (matches.isNotEmpty) {
          var lastIndex = 0;
          for (final match in matches) {
            if (match.start > lastIndex) {
              list.add(TextElement(text.substring(lastIndex, match.start)));
            }

            final url = text.substring(match.start, match.end);
            final fullUrl = url.startsWith('http') ? url : 'https://$url';
            list.add(LinkableElement(url, fullUrl));

            lastIndex = match.end;
          }

          // Добавляем оставшийся текст
          if (lastIndex < text.length) {
            list.add(TextElement(text.substring(lastIndex)));
          }
        } else {
          list.add(element);
        }
      } else {
        list.add(element);
      }
    }

    return list;
  }
}

bool isMobile =
    Platform.instance.operatingSystem.iOS ||
    Platform.instance.operatingSystem.android;

class ChatMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final MessageReadStatus? readStatus;
  final bool deferImageLoading;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForAll;
  final Function(String)? onReaction;
  final VoidCallback? onRemoveReaction;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onComplain;
  final VoidCallback? onCancelSend;
  final VoidCallback? onRetrySend;
  final int? myUserId;
  final bool? canEditMessage;
  final bool isGroupChat;
  final bool isChannel;
  final String? senderName;
  final String? forwardedFrom;
  final String? forwardedFromAvatarUrl;
  final Map<int, Contact>? contactDetailsCache;
  final Function(String)? onReplyTap;
  final bool useAutoReplyColor;
  final Color? customReplyColor;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isGrouped;
  final double avatarVerticalOffset;
  final int? chatId;
  final bool isEncryptionPasswordSet;
  final String? decryptedText;

  final bool isReactionSending;
  final List<Map<String, dynamic>>? allPhotos;
  final Function(String)? onGoToMessage;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.readStatus,
    this.deferImageLoading = false,
    this.onEdit,
    this.onDelete,
    this.onDeleteForMe,
    this.onDeleteForAll,
    this.onReaction,
    this.onRemoveReaction,
    this.onReply,
    this.onForward,
    this.onComplain,
    this.onCancelSend,
    this.onRetrySend,
    this.myUserId,
    this.canEditMessage,
    this.isGroupChat = false,
    this.isChannel = false,
    this.senderName,
    this.forwardedFrom,
    this.forwardedFromAvatarUrl,
    this.contactDetailsCache,
    this.onReplyTap,
    this.useAutoReplyColor = true,
    this.customReplyColor,
    this.isFirstInGroup = false,
    this.isLastInGroup = false,
    this.isGrouped = false,
    this.avatarVerticalOffset = -35.0,
    this.chatId,
    this.isEncryptionPasswordSet = false,
    this.decryptedText,
    this.isReactionSending = false,
    this.allPhotos,
    this.onGoToMessage,
  });

  String _formatMessageTime(BuildContext context, int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final showSeconds = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).showSeconds;
    return DateFormat(showSeconds ? 'HH:mm:ss' : 'HH:mm').format(dt);
  }

  EdgeInsets _getMessageMargin(BuildContext context) {
    if (isLastInGroup) {
      return const EdgeInsets.only(bottom: 6);
    }
    if (isFirstInGroup) {
      return const EdgeInsets.only(bottom: 2);
    }
    return const EdgeInsets.only(bottom: 2);
  }

  Widget _buildForwardedMessage(
    BuildContext context,
    Map<String, dynamic> link,
    Color textColor,
    double messageTextOpacity,
    bool isUltraOptimized,
  ) {
    final forwardedMessage = link['message'] as Map<String, dynamic>?;
    if (forwardedMessage == null) return const SizedBox.shrink();

    final text = forwardedMessage['text'] as String? ?? '';
    final attaches =
        (forwardedMessage['attaches'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        [];

    String forwardedSenderName;
    String? forwardedSenderAvatarUrl = forwardedFromAvatarUrl;

    if (forwardedFrom != null) {
      forwardedSenderName = forwardedFrom!;
    } else {
      final chatName = link['chatName'] as String?;
      final chatIconUrl = link['chatIconUrl'] as String?;

      if (chatName != null) {
        forwardedSenderName = chatName;
        forwardedSenderAvatarUrl ??= chatIconUrl;
      } else {
        final originalSenderId = forwardedMessage['sender'] as int?;
        final cache = contactDetailsCache;
        if (originalSenderId != null && cache != null) {
          final originalSenderContact = cache[originalSenderId];
          forwardedSenderName =
              originalSenderContact?.name ?? 'ID $originalSenderId';
          forwardedSenderAvatarUrl ??= originalSenderContact?.photoBaseUrl;
        } else if (originalSenderId != null) {
          forwardedSenderName = 'ID $originalSenderId';
        } else {
          forwardedSenderName = 'Пользователь';
        }
      }
    }

    int? originalSenderId;
    if (forwardedMessage['sender'] is int) {
      originalSenderId = forwardedMessage['sender'] as int;
    }

    void handleTap() {
      final myId = myUserId ?? 0;
      if (originalSenderId == null || myId == 0) {
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => UserProfilePanel(
          userId: originalSenderId!,
          name: forwardedSenderName,
          firstName: null,
          lastName: null,
          avatarUrl: forwardedSenderAvatarUrl,
          description: null,
          myId: myId,
          currentChatId: chatId,
          contactData: null,
          dialogChatId: null,
        ),
      );
    }

    return InkWell(
      onTap: handleTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.08 * messageTextOpacity),
          border: Border(
            left: BorderSide(
              color: textColor.withValues(alpha: 0.3 * messageTextOpacity),
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forward,
                  size: 14,
                  color: textColor.withValues(alpha: 0.6 * messageTextOpacity),
                ),
                const SizedBox(width: 6),
                if (forwardedSenderAvatarUrl != null)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: textColor.withValues(
                          alpha: 0.2 * messageTextOpacity,
                        ),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        forwardedSenderAvatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: textColor.withValues(
                              alpha: 0.1 * messageTextOpacity,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 12,
                              color: textColor.withValues(
                                alpha: 0.5 * messageTextOpacity,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: textColor.withValues(
                        alpha: 0.1 * messageTextOpacity,
                      ),
                      border: Border.all(
                        color: textColor.withValues(
                          alpha: 0.2 * messageTextOpacity,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 12,
                      color: textColor.withValues(
                        alpha: 0.5 * messageTextOpacity,
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    forwardedSenderName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor.withValues(
                        alpha: 0.9 * messageTextOpacity,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (attaches.isNotEmpty) ...[
              ..._buildCallsWithCaption(
                context,
                attaches,
                textColor,
                isUltraOptimized,
                messageTextOpacity,
              ),
              Column(
                children: _buildAudioWithCaption(
                  context,
                  attaches,
                  textColor,
                  isUltraOptimized,
                  messageTextOpacity,
                ),
              ),
              ..._buildPhotosWithCaption(
                context,
                attaches,
                textColor,
                isUltraOptimized,
                messageTextOpacity,
              ),
              ..._buildVideosWithCaption(
                context,
                attaches,
                textColor,
                isUltraOptimized,
                messageTextOpacity,
              ),
              ..._buildStickersWithCaption(
                context,
                attaches,
                textColor,
                isUltraOptimized,
                messageTextOpacity,
              ),
              ..._buildFilesWithCaption(
                context,
                attaches,
                textColor,
                isUltraOptimized,
                messageTextOpacity,
                chatId,
              ),
              ..._buildContactsWithCaption(
                context,
                attaches,
                textColor,
                isUltraOptimized,
                messageTextOpacity,
                chatId,
              ),
              const SizedBox(height: 6),
            ],
            if (text.isNotEmpty) ...[
              FutureBuilder<ChatEncryptionConfig?>(
                future: isEncryptionPasswordSet && chatId != null
                    ? ChatEncryptionService.getConfigForChat(chatId!)
                    : Future.value(null),
                builder: (context, snapshot) {
                  final elements =
                      (forwardedMessage['elements'] as List?)
                          ?.map((e) => (e as Map).cast<String, dynamic>())
                          .toList() ??
                      [];

                  String displayText = text;
                  bool isEncrypted = ChatEncryptionService.isEncryptedMessage(
                    text,
                  );
                  String? decryptedForwardedText;

                  if (isEncrypted &&
                      snapshot.hasData &&
                      snapshot.data != null) {
                    decryptedForwardedText =
                        ChatEncryptionService.decryptWithPassword(
                          snapshot.data!.password,
                          text,
                        );
                    if (decryptedForwardedText != null) {
                      displayText = decryptedForwardedText;
                    }
                  }

                  final defaultTextStyle = TextStyle(
                    color: textColor.withValues(
                      alpha: 0.9 * messageTextOpacity,
                    ),
                    fontSize: 14,
                  );

                  final linkStyle = TextStyle(
                    color: textColor.withValues(
                      alpha: 0.9 * messageTextOpacity,
                    ),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  );

                  Future<void> onOpenLink(LinkableElement link) async {
                    final uri = Uri.parse(link.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Не удалось открыть ссылку: ${link.url}',
                            ),
                          ),
                        );
                      }
                    }
                  }

                  if (isEncrypted && !isEncryptionPasswordSet) {
                    return Text(
                      'это зашифрованное сообщение, для его отображения поставьте пароль шифрования на чат.',
                      style: TextStyle(
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    );
                  }

                  if (isEncrypted &&
                      isEncryptionPasswordSet &&
                      snapshot.hasData &&
                      snapshot.data != null &&
                      decryptedForwardedText == null) {
                    return Text(
                      'некорректный ключ расшифровки, пароль точно верен?',
                      style: TextStyle(
                        color: Colors.red,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    );
                  }

                  if (decryptedForwardedText != null) {
                    return Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0, top: 2.0),
                          child: Icon(
                            Icons.lock,
                            size: 14,
                            color: textColor.withValues(
                              alpha: 0.7 * messageTextOpacity,
                            ),
                          ),
                        ),
                        _buildMixedMessageContent(
                          displayText,
                          defaultTextStyle,
                          linkStyle,
                          onOpenLink,
                          elements: elements,
                        ),
                      ],
                    );
                  }

                  return _buildMixedMessageContent(
                    displayText,
                    defaultTextStyle,
                    linkStyle,
                    onOpenLink,
                    elements: elements,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCirclePlayer({
    required BuildContext context,
    required int videoId,
    required String messageId,
    String? highQualityUrl,
    Uint8List? lowQualityBytes,
  }) {
    return _VideoCirclePlayer(
      videoId: videoId,
      messageId: messageId,
      chatId: chatId!,
      highQualityUrl: highQualityUrl,
      lowQualityBytes: lowQualityBytes,
    );
  }

  Widget _buildVideoPreview({
    required BuildContext context,
    required int videoId,
    required String messageId,
    String? highQualityUrl,
    Uint8List? lowQualityBytes,
    int? videoType,
    bool showNameHeader = false,
  }) {
    void openFullScreenVideo() async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final videoUrl = await ApiService.instance.getVideoUrl(
          videoId,
          chatId!,
          messageId,
        );

        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить видео: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final isVideoCircle = videoType == 1;

    if (isVideoCircle) {
      return _buildVideoCirclePlayer(
        context: context,
        videoId: videoId,
        messageId: messageId,
        highQualityUrl: highQualityUrl,
        lowQualityBytes: lowQualityBytes,
      );
    }

    return _VideoPreviewWidget(
      videoId: videoId,
      messageId: messageId,
      highQualityUrl: highQualityUrl,
      lowQualityBytes: lowQualityBytes,
      showNameHeader: showNameHeader,
      onTap: openFullScreenVideo,
    );
  }

  Widget _buildReplyPreview(
    BuildContext context,
    Map<String, dynamic> link,
    Color textColor,
    double messageTextOpacity,
    bool isUltraOptimized,
    double messageBorderRadius,
  ) {
    final replyMessage = link['message'] as Map<String, dynamic>?;
    if (replyMessage == null) return const SizedBox.shrink();

    final replyText = replyMessage['text'] as String? ?? '';
    final replySenderId = replyMessage['sender'] as int?;
    final rawId = replyMessage['id'];
    final replyMessageId = rawId is int ? rawId.toString() : (rawId as String?);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color replyAccentColor;
    if (useAutoReplyColor) {
      replyAccentColor = getUserColor(replySenderId ?? 0, context);
    } else {
      replyAccentColor =
          customReplyColor ??
          (isDarkMode ? const Color(0xFF90CAF9) : const Color(0xFF1976D2));
    }

    final textLength = replyText.length;
    final minWidth = 120.0;

    double adaptiveWidth = minWidth;
    if (textLength > 0) {
      adaptiveWidth = (textLength * 8.0 + 32).clamp(minWidth, double.infinity);
    }

    return GestureDetector(
      onTap: () {
        if (replyMessageId != null && onReplyTap != null) {
          onReplyTap!(replyMessageId);
        }
      },
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 40),
        width: adaptiveWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode
              ? replyAccentColor.withValues(alpha: 0.15)
              : replyAccentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(
            (isUltraOptimized ? 4 : messageBorderRadius) * 0.3,
          ),
          border: Border(left: BorderSide(color: replyAccentColor, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply, size: 12, color: replyAccentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    replySenderId != null
                        ? (contactDetailsCache?[replySenderId]?.name ??
                              'ID $replySenderId')
                        : 'Пользователь',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: replyAccentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                replyText.isNotEmpty ? replyText : 'Фото',
                style: const TextStyle(fontSize: 11, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                textAlign: TextAlign.left,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageContextMenu(BuildContext context, Offset tapPosition) {
    final hasUserReaction = message.reactionInfo?['yourReaction'] != null;
    final bool isPendingMessage =
        isMe &&
        ((readStatus == MessageReadStatus.sending) ||
            message.id.startsWith('local_'));

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return _MessageContextMenu(
          message: message,
          position: tapPosition,
          onReply: onReply,
          onEdit: onEdit,
          onDeleteForMe: onDeleteForMe,
          onDeleteForAll: onDeleteForAll,
          onReaction: onReaction,
          onRemoveReaction: onRemoveReaction,
          onForward: onForward,
          onComplain: onComplain,
          canEditMessage: canEditMessage ?? false,
          hasUserReaction: hasUserReaction,
          isChannel: isChannel,
          isPending: isPendingMessage,
          onCancelSend: onCancelSend,
          onRetrySend: onRetrySend,
        );
      },
    );
  }

  Widget _buildReactionsWidget(BuildContext context, Color textColor) {
    if (message.reactionInfo == null ||
        message.reactionInfo!['counters'] == null) {
      return const SizedBox.shrink();
    }

    final counters = message.reactionInfo!['counters'] as List<dynamic>;
    if (counters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 0.0),
      child: Wrap(
        spacing: 4.0,
        runSpacing: 4.0,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: counters.map<Widget>((counter) {
          final emoji = counter['reaction'] as String;
          final count = counter['count'] as int;
          final isUserReaction = message.reactionInfo!['yourReaction'] == emoji;

          return GestureDetector(
            onTap: () {
              if (isUserReaction) {
                onRemoveReaction?.call();
              } else {
                onReaction?.call(emoji);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUserReaction
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3)
                    : textColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$emoji $count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isUserReaction
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isUserReaction
                          ? Theme.of(context).colorScheme.primary
                          : textColor.withValues(alpha: 0.9),
                    ),
                  ),
                  if (isUserReaction && isReactionSending) ...[
                    const SizedBox(width: 4),
                    _RotatingIcon(
                      icon: Icons.watch_later_outlined,
                      size: 12,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF9bb5c7)
                          : const Color(0xFF6b7280),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isUltraOptimized = themeProvider.ultraOptimizeChats;

    final isStickerOnly =
        message.attaches.length == 1 &&
        message.attaches.any((a) => a['_type'] == 'STICKER') &&
        message.text.isEmpty;
    if (isStickerOnly) {
      return _buildStickerOnlyMessage(context);
    }

    final isVideoCircle =
        message.attaches.length == 1 &&
        message.attaches.any(
          (a) => a['_type'] == 'VIDEO' && (a['videoType'] as int?) == 1,
        ) &&
        message.text.isEmpty;
    if (isVideoCircle) {
      return _buildVideoCircleOnlyMessage(context);
    }

    final isPhotoOnly =
        message.attaches.isNotEmpty &&
        message.attaches.every((a) => a['_type'] == 'PHOTO') &&
        message.text.isEmpty &&
        !message.isReply &&
        !message.isForwarded;
    if (isPhotoOnly) {
      return _buildPhotoOnlyMessage(context);
    }

    final isVideoOnly =
        message.attaches.isNotEmpty &&
        message.attaches.every((a) => a['_type'] == 'VIDEO') &&
        message.attaches.every((a) => (a['videoType'] as int?) != 1) &&
        message.text.isEmpty &&
        !message.isReply &&
        !message.isForwarded;
    if (isVideoOnly) {
      return _buildVideoOnlyMessage(context);
    }

    final isFileOnly =
        message.attaches.isNotEmpty &&
        message.attaches.every((a) => a['_type'] == 'FILE') &&
        message.text.isEmpty &&
        !message.isReply &&
        !message.isForwarded;
    if (isFileOnly) {
      return _buildFileOnlyMessage(context);
    }

    final hasUnsupportedContent = _hasUnsupportedMessageTypes();

    final messageOpacity = themeProvider.messageBubbleOpacity;
    final messageTextOpacity = themeProvider.messageTextOpacity;
    final messageShadowIntensity = themeProvider.messageShadowIntensity;
    final messageBorderRadius = themeProvider.messageBorderRadius;

    final bubbleColor = _getBubbleColor(
      isMe,
      themeProvider,
      messageOpacity,
      context,
    );
    final textColor = _getTextColor(
      isMe,
      bubbleColor,
      messageTextOpacity,
      context,
    );

    BoxDecoration bubbleDecoration = _createBubbleDecoration(
      bubbleColor,
      messageBorderRadius,
      messageShadowIntensity,
    );

    if (hasUnsupportedContent) {
      return _buildUnsupportedMessage(
        context,
        bubbleColor,
        textColor,
        bubbleDecoration,
      );
    }

    final baseTextStyle =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final defaultTextStyle = baseTextStyle.copyWith(color: textColor);
    final linkColor = _getLinkColor(bubbleColor, isMe);
    final linkStyle = baseTextStyle.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    Future<void> onOpenLink(LinkableElement link) async {
      final uri = Uri.parse(link.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть ссылку: ${link.url}')),
          );
        }
      }
    }

    void onSenderNameTap() {
      openUserProfileById(context, message.senderId);
    }

    final messageContentChildren = _buildMessageContentChildren(
      context,
      textColor,
      messageTextOpacity,
      isUltraOptimized,
      linkStyle,
      defaultTextStyle,
      messageBorderRadius,
      onOpenLink,
      onSenderNameTap,
    );

    Widget messageContent = _buildMessageContentInner(
      context,
      bubbleDecoration,
      messageContentChildren,
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        messageContent = _LongPressContextMenuWrapper(
          child: messageContent,
          onShowMenu: (offset) => _showMessageContextMenu(context, offset),
        );
      } else {
        messageContent = GestureDetector(
          onSecondaryTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: messageContent,
        );
      }
    }

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && isGroupChat && !isChannel) ...[
              SizedBox(
                width: 40,
                child: isLastInGroup
                    ? Transform.translate(
                        offset: Offset(0, avatarVerticalOffset),
                        child: _buildSenderAvatar(),
                      )
                    : null,
              ),
            ],
            Flexible(child: messageContent),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildInlineKeyboard(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
  ) {
    final keyboardAttach = attaches.firstWhere(
      (a) => a['_type'] == 'INLINE_KEYBOARD',
      orElse: () => <String, dynamic>{},
    );

    if (keyboardAttach.isEmpty) {
      return [];
    }

    final keyboardData = keyboardAttach['keyboard'] as Map<String, dynamic>?;
    final buttonRows = keyboardData?['buttons'] as List<dynamic>?;

    if (buttonRows == null || buttonRows.isEmpty) {
      return [];
    }

    final List<Widget> rows = [];

    for (final row in buttonRows) {
      if (row is List<dynamic> && row.isNotEmpty) {
        final List<Widget> buttonsInRow = [];

        for (final buttonData in row) {
          if (buttonData is Map<String, dynamic>) {
            final String? text = buttonData['text'] as String?;
            final String? type = buttonData['type'] as String?;
            final String? url = buttonData['url'] as String?;

            if (text != null && type == 'LINK' && url != null) {
              buttonsInRow.add(
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: FilledButton(
                      onPressed: () => _launchURL(context, url),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),

                        backgroundColor: textColor.withValues(alpha: 0.1),
                        foregroundColor: textColor.withValues(alpha: 0.9),
                      ),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }

        if (buttonsInRow.isNotEmpty) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: buttonsInRow,
              ),
            ),
          );
        }
      }
    }

    if (rows.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(children: rows),
        ),
      ];
    }

    return [];
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть ссылку: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _hasUnsupportedMessageTypes() {
    final hasUnsupportedAttachments = message.attaches.any((attach) {
      final type = attach['_type']?.toString().toUpperCase();
      return type == 'VOICE' || type == 'GIF' || type == 'LOCATION';
    });

    return hasUnsupportedAttachments;
  }

  Widget _buildUnsupportedMessage(
    BuildContext context,
    Color bubbleColor,
    Color textColor,
    BoxDecoration bubbleDecoration,
  ) {
    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && isGroupChat && !isChannel) ...[
              SizedBox(
                width: 40,
                child: isLastInGroup
                    ? Transform.translate(
                        offset: Offset(0, avatarVerticalOffset),
                        child: _buildSenderAvatar(),
                      )
                    : null,
              ),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),

                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4.5,
                ),
                margin: _getMessageMargin(context),
                decoration: bubbleDecoration,
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isGroupChat && !isMe && senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2.0, bottom: 0.0),
                        child: Text(
                          senderName!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: getUserColor(
                              message.senderId,
                              context,
                            ).withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (isGroupChat && !isMe && senderName != null)
                      const SizedBox(height: 2),

                    Text(
                      'Это сообщение не поддерживается в Вашей версии Komet. '
                      'Пожалуйста, обновитесь до последней версии. '
                      'Если Вы уже используете свежую версию приложения, '
                      'возможно, в сообщении используется нововведение, '
                      'которое пока не поддерживается.',
                      style: TextStyle(
                        color: textColor,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.left,
                    ),

                    const SizedBox(height: 0.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMe) ...[
                          if (message.isEdited) ...[
                            Text(
                              '(изменено)',
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _formatMessageTime(context, message.time),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF9bb5c7)
                                  : const Color(0xFF6b7280),
                            ),
                          ),
                        ],
                        if (!isMe) ...[
                          Text(
                            _formatMessageTime(context, message.time),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF9bb5c7)
                                  : const Color(0xFF6b7280),
                            ),
                          ),
                          if (message.isEdited) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(изменено)',
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.5),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<bool> _isMusicTrackRegistered(int fileId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicMetadataJson = prefs.getString('music_metadata') ?? '{}';
      final musicMetadata =
          jsonDecode(musicMetadataJson) as Map<String, dynamic>;
      return musicMetadata.containsKey(fileId.toString());
    } catch (_) {
      return false;
    }
  }

  Widget _buildStickerOnlyMessage(BuildContext context) {
    final sticker = message.attaches.firstWhere((a) => a['_type'] == 'STICKER');
    final stickerSize = 170.0;

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    return Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && isGroupChat && !isChannel) ...[
              SizedBox(
                width: 40,
                child: isLastInGroup
                    ? Transform.translate(
                        offset: Offset(0, avatarVerticalOffset),
                        child: _buildSenderAvatar(),
                      )
                    : null,
              ),
            ],
            Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openPhotoViewer(context, sticker),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: stickerSize,
                      maxHeight: stickerSize,
                    ),
                    child: _buildStickerImage(context, sticker),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 0, right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(context, message.time),
                        style: TextStyle(fontSize: 12, color: timeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoCircleOnlyMessage(BuildContext context) {
    final video = message.attaches.firstWhere((a) => a['_type'] == 'VIDEO');
    final videoId = video['videoId'] as int?;
    final previewDataRaw = video['previewData'];
    final previewData = previewDataRaw is String ? previewDataRaw : null;
    final thumbnailUrlRaw = video['url'] ?? video['baseUrl'];
    final thumbnailUrl = thumbnailUrlRaw is String ? thumbnailUrlRaw : null;

    Uint8List? previewBytes;
    if (previewDataRaw is List<int>) {
      previewBytes = Uint8List.fromList(previewDataRaw);
    } else if (previewData != null && previewData.startsWith('data:')) {
      final idx = previewData.indexOf('base64,');
      if (idx != -1) {
        final b64 = previewData.substring(idx + 7);
        try {
          previewBytes = base64Decode(b64);
        } catch (_) {}
      }
    }

    String? highQualityThumbnailUrl;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      highQualityThumbnailUrl = thumbnailUrl;
      if (!thumbnailUrl.contains('?')) {
        highQualityThumbnailUrl =
            '$thumbnailUrl?size=medium&quality=high&format=jpeg';
      } else {
        highQualityThumbnailUrl =
            '$thumbnailUrl&size=medium&quality=high&format=jpeg';
      }
    }

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    Widget videoContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (videoId != null && chatId != null)
                    _buildVideoCirclePlayer(
                      context: context,
                      videoId: videoId,
                      messageId: message.id,
                      highQualityUrl: highQualityThumbnailUrl,
                      lowQualityBytes: previewBytes,
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTime(context, message.time),
                          style: TextStyle(fontSize: 12, color: timeColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        videoContent = _LongPressContextMenuWrapper(
          child: videoContent,
          onShowMenu: (offset) => _showMessageContextMenu(context, offset),
        );
      } else {
        videoContent = GestureDetector(
          onSecondaryTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: videoContent,
        );
      }
    }

    return videoContent;
  }

  Widget _buildNameHeaderWithReply({
    required BuildContext context,
    required String name,
    required Color bubbleColor,
    required bool isUltraOptimized,
    required int senderId,
  }) {
    final nameColor = getUserColor(senderId, context).withValues(alpha: 0.8);
    final canReply = onReply != null && !isChannel;
    final screenWidth = MediaQuery.of(context).size.width;
    final hasSpaceForReply = screenWidth > 280;
    const replyColor = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isUltraOptimized ? 4 : 12),
          topRight: Radius.circular(isUltraOptimized ? 4 : 12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: nameColor,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canReply) ...[
            const SizedBox(width: 8),
            if (hasSpaceForReply)
              GestureDetector(
                onTap: onReply,
                child: const Text(
                  'ответить',
                  style: TextStyle(fontSize: 12, color: replyColor),
                ),
              )
            else
              GestureDetector(
                onTap: onReply,
                child: const Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: replyColor,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoOnlyMessage(BuildContext context) {
    final photos = message.attaches
        .where((a) => a['_type'] == 'PHOTO')
        .toList();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isUltraOptimized = themeProvider.ultraOptimizeChats;
    final messageOpacity = themeProvider.messageBubbleOpacity;
    final bubbleColor = _getBubbleColor(
      isMe,
      themeProvider,
      messageOpacity,
      context,
    );
    final textColor = _getTextColor(
      isMe,
      bubbleColor,
      themeProvider.messageTextOpacity,
      context,
    );

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    Widget photoContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && isGroupChat && !isChannel) ...[
                SizedBox(
                  width: 40,
                  child: isLastInGroup
                      ? Transform.translate(
                          offset: Offset(0, avatarVerticalOffset),
                          child: _buildSenderAvatar(),
                        )
                      : null,
                ),
              ],
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (photos.length == 1 &&
                        isGroupChat &&
                        !isMe &&
                        senderName != null)
                      _buildNameHeaderWithReply(
                        context: context,
                        name: senderName!,
                        bubbleColor: bubbleColor,
                        isUltraOptimized: isUltraOptimized,
                        senderId: message.senderId,
                      ),
                    _buildSmartPhotoGroup(
                      context,
                      photos,
                      textColor,
                      isUltraOptimized,
                      showNameHeader:
                          photos.length == 1 &&
                          isGroupChat &&
                          !isMe &&
                          senderName != null,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(context, message.time),
                            style: TextStyle(fontSize: 12, color: timeColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        photoContent = _LongPressContextMenuWrapper(
          child: photoContent,
          onShowMenu: (offset) => _showMessageContextMenu(context, offset),
        );
      } else {
        photoContent = GestureDetector(
          onSecondaryTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: photoContent,
        );
      }
    }

    return photoContent;
  }

  Widget _buildVideoOnlyMessage(BuildContext context) {
    final videos = message.attaches
        .where((a) => a['_type'] == 'VIDEO')
        .toList();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isUltraOptimized = themeProvider.ultraOptimizeChats;
    final messageOpacity = themeProvider.messageBubbleOpacity;
    final bubbleColor = _getBubbleColor(
      isMe,
      themeProvider,
      messageOpacity,
      context,
    );

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    final showNameHeader =
        videos.length == 1 && isGroupChat && !isMe && senderName != null;

    Widget videoContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ...videos.asMap().entries.map((entry) {
            final index = entry.key;
            final video = entry.value;
            final videoId = video['videoId'] as int?;
            final videoType = video['videoType'] as int?;
            final previewDataRaw = video['previewData'];
            final previewData = previewDataRaw is String
                ? previewDataRaw
                : null;
            final thumbnailUrlRaw = video['url'] ?? video['baseUrl'];
            final thumbnailUrl = thumbnailUrlRaw is String
                ? thumbnailUrlRaw
                : null;

            Uint8List? previewBytes;
            if (previewData != null && previewData.startsWith('data:')) {
              final idx = previewData.indexOf('base64,');
              if (idx != -1) {
                final b64 = previewData.substring(idx + 7);
                try {
                  previewBytes = base64Decode(b64);
                } catch (_) {}
              }
            }

            String? highQualityThumbnailUrl;
            if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
              highQualityThumbnailUrl = thumbnailUrl;
              if (!thumbnailUrl.contains('?')) {
                highQualityThumbnailUrl =
                    '$thumbnailUrl?size=medium&quality=high&format=jpeg';
              } else {
                highQualityThumbnailUrl =
                    '$thumbnailUrl&size=medium&quality=high&format=jpeg';
              }
            }

            return Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe && isGroupChat && !isChannel && index == 0) ...[
                      SizedBox(
                        width: 40,
                        child: isLastInGroup
                            ? Transform.translate(
                                offset: Offset(0, avatarVerticalOffset),
                                child: _buildSenderAvatar(),
                              )
                            : null,
                      ),
                    ],
                    IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showNameHeader && index == 0)
                            _buildNameHeaderWithReply(
                              context: context,
                              name: senderName!,
                              bubbleColor: bubbleColor,
                              isUltraOptimized: isUltraOptimized,
                              senderId: message.senderId,
                            ),
                          if (videoId != null && chatId != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 300,
                                ),
                                child: RepaintBoundary(
                                  key: ValueKey(
                                    'video_preview_${message.cid ?? message.id}_$videoId',
                                  ),
                                  child: _buildVideoPreview(
                                    context: context,
                                    videoId: videoId,
                                    messageId: message.id,
                                    highQualityUrl: highQualityThumbnailUrl,
                                    lowQualityBytes: previewBytes,
                                    videoType: videoType,
                                    showNameHeader: showNameHeader,
                                  ),
                                ),
                              ),
                            ),
                          if (index == videos.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatMessageTime(context, message.time),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: timeColor,
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
              ],
            );
          }),
        ],
      ),
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        videoContent = _LongPressContextMenuWrapper(
          child: videoContent,
          onShowMenu: (offset) => _showMessageContextMenu(context, offset),
        );
      } else {
        videoContent = GestureDetector(
          onSecondaryTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: videoContent,
        );
      }
    }

    return videoContent;
  }

  Widget _buildFileOnlyMessage(BuildContext context) {
    final files = message.attaches.where((a) => a['_type'] == 'FILE').toList();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isUltraOptimized = themeProvider.ultraOptimizeChats;
    final messageOpacity = themeProvider.messageBubbleOpacity;
    final messageTextOpacity = themeProvider.messageTextOpacity;
    final bubbleColor = _getBubbleColor(
      isMe,
      themeProvider,
      messageOpacity,
      context,
    );
    final textColor = _getTextColor(
      isMe,
      bubbleColor,
      messageTextOpacity,
      context,
    );

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    final showNameHeader =
        files.length == 1 && isGroupChat && !isMe && senderName != null;

    Widget fileContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && isGroupChat && !isChannel) ...[
                SizedBox(
                  width: 40,
                  child: isLastInGroup
                      ? Transform.translate(
                          offset: Offset(0, avatarVerticalOffset),
                          child: _buildSenderAvatar(),
                        )
                      : null,
                ),
              ],
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showNameHeader)
                      _buildNameHeaderWithReply(
                        context: context,
                        name: senderName!,
                        bubbleColor: bubbleColor,
                        isUltraOptimized: isUltraOptimized,
                        senderId: message.senderId,
                      ),
                    ...files.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      final fileName = file['name'] ?? 'Файл';
                      final fileSize = file['size'] as int? ?? 0;
                      final preview = file['preview'] as Map<String, dynamic>?;
                      final isMusic =
                          preview != null && preview['_type'] == 'MUSIC';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isMusic)
                            _buildMusicFileWidget(
                              context,
                              fileName,
                              fileSize,
                              file,
                              textColor,
                              isUltraOptimized,
                              chatId,
                              showNameHeader: showNameHeader && index == 0,
                            )
                          else
                            _buildFileWidget(
                              context,
                              fileName,
                              fileSize,
                              file,
                              textColor,
                              isUltraOptimized,
                              chatId,
                              showNameHeader: showNameHeader && index == 0,
                            ),
                          if (index < files.length - 1)
                            const SizedBox(height: 6),
                        ],
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatMessageTime(context, message.time),
                            style: TextStyle(fontSize: 12, color: timeColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        fileContent = _LongPressContextMenuWrapper(
          child: fileContent,
          onShowMenu: (offset) => _showMessageContextMenu(context, offset),
        );
      } else {
        fileContent = GestureDetector(
          onSecondaryTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: fileContent,
        );
      }
    }

    return fileContent;
  }

  Widget _buildStickerImage(
    BuildContext context,
    Map<String, dynamic> sticker,
  ) {
    final url = sticker['url'] ?? sticker['baseUrl'];

    if (url is String && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      } else {
        return Image.network(
          url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return _imagePlaceholder();
          },
        );
      }
    }

    return _imagePlaceholder();
  }

  String? _extractFirstPhotoUrl(List<Map<String, dynamic>> attaches) {
    for (final a in attaches) {
      if (a['_type'] == 'PHOTO') {
        final dynamic maybe = a['url'] ?? a['baseUrl'];
        if (maybe is String && maybe.isNotEmpty) return maybe;
      }
    }
    return null;
  }

  List<Widget> _buildPhotosWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final photos = attaches.where((a) => a['_type'] == 'PHOTO').toList();
    final List<Widget> widgets = [];

    if (photos.isEmpty) return widgets;

    widgets.add(
      _buildSmartPhotoGroup(context, photos, textColor, isUltraOptimized),
    );

    widgets.add(const SizedBox(height: 6));

    return widgets;
  }

  List<Widget> _buildVideosWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final videos = attaches.where((a) => a['_type'] == 'VIDEO').toList();
    final List<Widget> widgets = [];

    if (videos.isEmpty) return widgets;

    for (final video in videos) {
      final videoId = video['videoId'] as int?;
      final videoType = video['videoType'] as int?;
      final previewDataRaw = video['previewData'];
      final previewData = previewDataRaw is String ? previewDataRaw : null;
      final thumbnailUrlRaw = video['url'] ?? video['baseUrl'];
      final thumbnailUrl = thumbnailUrlRaw is String ? thumbnailUrlRaw : null;

      Uint8List? previewBytes;
      if (previewData is String && previewData.startsWith('data:')) {
        final idx = previewData.indexOf('base64,');
        if (idx != -1) {
          final b64 = previewData.substring(idx + 7);
          try {
            previewBytes = base64Decode(b64);
          } catch (_) {}
        }
      } else if (previewDataRaw is List<dynamic>) {
        try {
          previewBytes = Uint8List.fromList(List<int>.from(previewDataRaw));
        } catch (_) {}
      }

      String? highQualityThumbnailUrl;
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        highQualityThumbnailUrl = thumbnailUrl;
        if (!thumbnailUrl.contains('?')) {
          highQualityThumbnailUrl =
              '$thumbnailUrl?size=medium&quality=high&format=jpeg';
        } else {
          highQualityThumbnailUrl =
              '$thumbnailUrl&size=medium&quality=high&format=jpeg';
        }
      }

      if (videoId != null && chatId != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: RepaintBoundary(
              key: ValueKey(
                'video_preview_${message.cid ?? message.id}_$videoId',
              ),
              child: _buildVideoPreview(
                context: context,
                videoId: videoId,
                messageId: message.id,
                highQualityUrl: highQualityThumbnailUrl,
                lowQualityBytes: previewBytes,
                videoType: videoType,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black12,
            child: Row(
              children: [
                Icon(Icons.videocam_off, color: textColor),
                const SizedBox(width: 8),
                Text(
                  'Видео повреждено (нет ID)',
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
          ),
        );
      }
    }

    widgets.add(const SizedBox(height: 6));
    return widgets;
  }

  List<Widget> _buildStickersWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final stickers = attaches.where((a) => a['_type'] == 'STICKER').toList();
    final List<Widget> widgets = [];

    if (stickers.isEmpty) return widgets;

    for (final sticker in stickers) {
      widgets.add(
        _buildStickerWidget(context, sticker, textColor, isUltraOptimized),
      );
      widgets.add(const SizedBox(height: 6));
    }

    return widgets;
  }

  Widget _buildStickerWidget(
    BuildContext context,
    Map<String, dynamic> sticker,
    Color textColor,
    bool isUltraOptimized,
  ) {
    final stickerSize = 170.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: stickerSize,
        maxHeight: stickerSize,
      ),
      child: GestureDetector(
        onTap: () => _openPhotoViewer(context, sticker),
        onLongPressStart: (details) =>
            _showMessageContextMenu(context, details.globalPosition),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isUltraOptimized ? 8 : 12),
          child: _buildPhotoWidget(context, sticker),
        ),
      ),
    );
  }

  Widget _buildStickerWithCache(
    BuildContext context,
    int stickerId,
    String url,
  ) {
    return FutureBuilder<Uint8List?>(
      future: _loadStickerImage(stickerId, url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 170,
            height: 170,
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: 170,
            height: 170,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, _, __) => _imagePlaceholder(),
          );
        } else {
          return _ProgressiveNetworkImage(
            url: url,
            previewBytes: null,
            width: 170,
            height: 170,
            fit: BoxFit.cover,
            keepAlive: true,
            startDownloadNextFrame: deferImageLoading,
          );
        }
      },
    );
  }

  Future<Uint8List?> _loadStickerImage(int stickerId, String url) async {
    try {
      final cacheService = CacheService();

      final cachedBytes = await cacheService.getCachedStickerFileBytes(
        stickerId,
        url: url,
      );
      if (cachedBytes != null) {
        print('✅ Sticker loaded from cache: $stickerId');
        return cachedBytes;
      }

      print('📥 Downloading sticker: $stickerId');
      final cachedPath = await cacheService.cacheStickerFile(url, stickerId);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          print('✅ Sticker cached and loaded: $stickerId');
          return bytes;
        }
      }

      return null;
    } catch (e) {
      print('❌ Error loading sticker $stickerId: $e');
      return null;
    }
  }

  List<Widget> _buildCallsWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final calls = attaches.where((a) {
      final type = a['_type'];
      return type == 'CALL' || type == 'call';
    }).toList();
    final List<Widget> widgets = [];

    if (calls.isEmpty) return widgets;

    for (final call in calls) {
      widgets.add(
        _buildCallWidget(
          context,
          call,
          textColor,
          isUltraOptimized,
          messageTextOpacity,
        ),
      );
      widgets.add(const SizedBox(height: 6));
    }

    return widgets;
  }

  Widget _buildCallWidget(
    BuildContext context,
    Map<String, dynamic> callData,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final hangupType = callData['hangupType'] as String? ?? '';
    final callType = callData['callType'] as String? ?? 'AUDIO';
    final duration = callData['duration'] as int? ?? 0;
    final borderRadius = BorderRadius.circular(isUltraOptimized ? 8 : 12);

    String callText;
    IconData callIcon;
    Color callColor;

    switch (hangupType) {
      case 'HUNGUP':
        final minutes = duration ~/ 60000;
        final seconds = (duration % 60000) ~/ 1000;
        final durationText = minutes > 0
            ? '$minutes:${seconds.toString().padLeft(2, '0')}'
            : '$seconds сек';

        final callTypeText = callType == 'VIDEO' ? 'Видеозвонок' : 'Звонок';
        callText = '$callTypeText, $durationText';
        callIcon = callType == 'VIDEO' ? Icons.videocam : Icons.call;
        callColor = Theme.of(context).colorScheme.primary;
        break;

      case 'MISSED':
        final callTypeText = callType == 'VIDEO'
            ? 'Пропущенный видеозвонок'
            : 'Пропущенный звонок';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_missed;
        callColor = Theme.of(context).colorScheme.error;
        break;

      case 'CANCELED':
        final callTypeText = callType == 'VIDEO'
            ? 'Видеозвонок отменен'
            : 'Звонок отменен';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_end;
        callColor = textColor.withValues(alpha: 0.6);
        break;

      case 'REJECTED':
        final callTypeText = callType == 'VIDEO'
            ? 'Видеозвонок отклонен'
            : 'Звонок отклонен';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_end;
        callColor = textColor.withValues(alpha: 0.6);
        break;

      default:
        callText = callType == 'VIDEO' ? 'Видеозвонок' : 'Звонок';
        callIcon = callType == 'VIDEO' ? Icons.videocam : Icons.call;
        callColor = textColor.withValues(alpha: 0.6);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: callColor.withValues(alpha: 0.1),
        borderRadius: borderRadius,
        border: Border.all(color: callColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: callColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(callIcon, color: callColor, size: 24),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    callText,
                    style: TextStyle(
                      color: callColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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

  List<Widget> _buildFilesWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
    int? chatId,
  ) {
    final files = attaches.where((a) => a['_type'] == 'FILE').toList();
    final List<Widget> widgets = [];

    if (files.isEmpty) return widgets;

    for (final file in files) {
      final fileName = file['name'] ?? 'Файл';
      final fileSize = file['size'] as int? ?? 0;

      final preview = file['preview'] as Map<String, dynamic>?;
      final isMusic = preview != null && preview['_type'] == 'MUSIC';

      if (isMusic) {
        widgets.add(
          _buildMusicFileWidget(
            context,
            fileName,
            fileSize,
            file,
            textColor,
            isUltraOptimized,
            chatId,
          ),
        );
      } else {
        widgets.add(
          _buildFileWidget(
            context,
            fileName,
            fileSize,
            file,
            textColor,
            isUltraOptimized,
            chatId,
          ),
        );
      }
      widgets.add(const SizedBox(height: 6));
    }

    return widgets;
  }

  List<Widget> _buildContactsWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
    int? chatId,
  ) {
    final contacts = attaches.where((a) => a['_type'] == 'CONTACT').toList();
    final List<Widget> widgets = [];

    if (contacts.isEmpty) return widgets;

    for (final contactAttach in contacts) {
      widgets.add(
        _buildContactWidget(
          context,
          contactAttach,
          textColor,
          isUltraOptimized,
          messageTextOpacity,
          chatId,
        ),
      );
      widgets.add(const SizedBox(height: 6));
    }

    return widgets;
  }

  Widget _buildContactWidget(
    BuildContext context,
    Map<String, dynamic> contactAttach,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
    int? chatId,
  ) {
    final contactIdValue = contactAttach['contactId'];
    final int? contactId = contactIdValue is int
        ? contactIdValue
        : (contactIdValue is String ? int.tryParse(contactIdValue) : null);
    final contactName =
        contactAttach['name'] as String? ??
        contactAttach['firstName'] as String? ??
        'Контакт';
    final photoUrl =
        contactAttach['photoUrl'] as String? ??
        contactAttach['baseUrl'] as String?;

    // Сначала проверяем кэш синхронно
    final cachedContact = contactId != null
        ? ApiService.instance.getCachedContact(contactId)
        : null;

    // Если контакт есть в кэше - показываем сразу
    if (cachedContact != null) {
      return _buildContactContent(
        context,
        cachedContact,
        textColor,
        isUltraOptimized,
        messageTextOpacity,
        contactId,
      );
    }

    // Если нет в кэше - используем FutureBuilder для загрузки
    return FutureBuilder<Contact?>(
      key: ValueKey('contact_$contactId'),
      future: contactId != null
          ? ApiService.instance
                .fetchContactsByIds([contactId])
                .then((contacts) => contacts.isNotEmpty ? contacts.first : null)
          : Future.value(null),
      builder: (context, snapshot) {
        // Если контакт загрузился - проверяем кэш еще раз (на случай если он был загружен параллельно)
        final contact =
            snapshot.data ??
            (contactId != null
                ? ApiService.instance.getCachedContact(contactId)
                : null);
        return _buildContactContent(
          context,
          contact,
          textColor,
          isUltraOptimized,
          messageTextOpacity,
          contactId,
          fallbackName: contactName,
          fallbackPhotoUrl: photoUrl,
        );
      },
    );
  }

  Widget _buildContactContent(
    BuildContext context,
    Contact? contact,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
    int? contactId, {
    String? fallbackName,
    String? fallbackPhotoUrl,
  }) {
    final displayName = contact?.name ?? fallbackName ?? 'Контакт';
    final displayPhotoUrl = contact?.photoBaseUrl ?? fallbackPhotoUrl;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContactWidth = screenWidth < 400 ? screenWidth * 0.7 : 300.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxContactWidth),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.1 * messageTextOpacity),
        borderRadius: BorderRadius.circular(isUltraOptimized ? 8 : 12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.2 * messageTextOpacity),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: contactId != null
                ? () => openUserProfileById(context, contactId)
                : null,
            child: displayPhotoUrl != null && displayPhotoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      displayPhotoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: contactId != null
                  ? () => openUserProfileById(context, contactId)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: textColor.withValues(alpha: messageTextOpacity),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (contact?.description != null &&
                      contact!.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      contact.description!,
                      style: TextStyle(
                        color: textColor.withValues(
                          alpha: 0.7 * messageTextOpacity,
                        ),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileWidget(
    BuildContext context,
    String fileName,
    int fileSize,
    Map<String, dynamic> fileData,
    Color textColor,
    bool isUltraOptimized,
    int? chatId, {
    bool showNameHeader = false,
  }) {
    final borderRadius = showNameHeader
        ? BorderRadius.only(
            bottomLeft: Radius.circular(isUltraOptimized ? 8 : 12),
            bottomRight: Radius.circular(isUltraOptimized ? 8 : 12),
          )
        : BorderRadius.circular(isUltraOptimized ? 8 : 12);

    final extension = _getFileExtension(fileName);
    final iconData = _getFileIcon(extension);

    final sizeStr = _formatFileSize(fileSize);

    final fileId = fileData['fileId'] as int?;
    final token = fileData['token'] as String?;
    final progressNotifier = fileId != null
        ? FileDownloadProgressService().getProgress(fileId.toString())
        : null;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxFileWidth = screenWidth < 400 ? screenWidth * 0.7 : 300.0;

    Widget buildContent(double progress) {
      final bool isDownloading = progress >= 0 && progress < 1.0;

      return GestureDetector(
        onTap: isDownloading
            ? null
            : () =>
                  _handleFileDownload(context, fileId, token, fileName, chatId),
        child: AbsorbPointer(
          absorbing: isDownloading,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxFileWidth),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.05),
              borderRadius: borderRadius,
              border: Border.all(
                color: textColor.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      iconData,
                      color: textColor.withValues(alpha: 0.8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (fileId != null)
                          Builder(
                            builder: (context) {
                              if (progress < 0) {
                                return Text(
                                  sizeStr,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                );
                              } else if (progress < 1.0) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 3,
                                      backgroundColor: textColor.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: textColor.withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 12,
                                      color: Colors.green.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Загружено',
                                      style: TextStyle(
                                        color: Colors.green.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          )
                        else
                          Text(
                            sizeStr,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (fileId != null)
                    Builder(
                      builder: (context) {
                        if (progress >= 0 && progress < 1.0) {
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        return Icon(
                          Icons.download_outlined,
                          color: textColor.withValues(alpha: 0.6),
                          size: 20,
                        );
                      },
                    )
                  else
                    Icon(
                      Icons.download_outlined,
                      color: textColor.withValues(alpha: 0.6),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (progressNotifier != null) {
      return ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, _) => buildContent(progress),
      );
    }

    return buildContent(-1);
  }

  Widget _buildMusicFileWidget(
    BuildContext context,
    String fileName,
    int fileSize,
    Map<String, dynamic> fileData,
    Color textColor,
    bool isUltraOptimized,
    int? chatId, {
    bool showNameHeader = false,
  }) {
    final borderRadius = showNameHeader
        ? BorderRadius.only(
            bottomLeft: Radius.circular(isUltraOptimized ? 8 : 12),
            bottomRight: Radius.circular(isUltraOptimized ? 8 : 12),
          )
        : BorderRadius.circular(isUltraOptimized ? 8 : 12);
    final preview = fileData['preview'] as Map<String, dynamic>?;
    final fileId = fileData['fileId'] as int?;
    final token = fileData['token'] as String?;

    final title = preview?['title'] as String? ?? fileName;
    final artist = preview?['artistName'] as String? ?? 'Unknown Artist';
    final album = preview?['albumName'] as String?;
    final albumArtUrl = preview?['baseUrl'] as String?;
    final durationSeconds = preview?['duration'] as int?;
    final duration = durationSeconds != null ? durationSeconds * 1000 : null;

    String durationText = '';
    if (durationSeconds != null) {
      final minutes = durationSeconds ~/ 60;
      final seconds = durationSeconds % 60;
      durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    final sizeStr = _formatFileSize(fileSize);

    if (fileId == null) {
      return GestureDetector(
        onTap: () async {
          await _handleFileDownload(
            context,
            fileId,
            token,
            fileName,
            chatId,
            preview: preview,
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width < 400
                ? MediaQuery.of(context).size.width * 0.7
                : 300.0,
          ),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.05),
            borderRadius: borderRadius,
            border: Border.all(
              color: textColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: textColor.withValues(alpha: 0.1),
                    child: albumArtUrl != null
                        ? Image.network(
                            albumArtUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.music_note,
                              color: textColor.withValues(alpha: 0.8),
                              size: 24,
                            ),
                          )
                        : Icon(
                            Icons.music_note,
                            color: textColor.withValues(alpha: 0.8),
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (album != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          album,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (durationText.isNotEmpty) ...[
                            Text(
                              durationText,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            sizeStr,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.download_outlined,
                  color: textColor.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progressNotifier = FileDownloadProgressService().getProgress(
      fileId.toString(),
    );

    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      builder: (context, progress, _) {
        final bool isDownloading = progress >= 0 && progress < 1.0;

        Future<void> handleTap() async {
          if (isDownloading) return;

          final prefs = await SharedPreferences.getInstance();
          final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
          final fileIdString = fileId.toString();

          bool isDownloaded = false;
          String? filePath;

          for (final mapping in fileIdMap) {
            if (mapping.startsWith('$fileIdString:')) {
              filePath = mapping.substring(fileIdString.length + 1);
              final file = io.File(filePath);
              if (await file.exists()) {
                isDownloaded = true;
                break;
              }
            }
          }

          if (!isDownloaded) {
            await _handleFileDownload(
              context,
              fileId,
              token,
              fileName,
              chatId,
              preview: preview,
            );
            await Future.delayed(const Duration(seconds: 1));
            final updatedFileIdMap =
                prefs.getStringList('file_id_to_path_map') ?? [];
            for (final mapping in updatedFileIdMap) {
              if (mapping.startsWith('$fileIdString:')) {
                filePath = mapping.substring(fileIdString.length + 1);
                final file = io.File(filePath);
                if (await file.exists()) {
                  isDownloaded = true;
                  break;
                }
              }
            }
          }

          if (isDownloaded && filePath != null) {
            final track = MusicTrack(
              id: fileId.toString(),
              title: title,
              artist: artist,
              album: album,
              albumArtUrl: albumArtUrl,
              duration: duration,
              filePath: filePath,
              fileId: fileId,
              token: token,
              chatId: chatId,
            );

            final musicMetadataJson = prefs.getString('music_metadata') ?? '{}';
            final musicMetadata =
                jsonDecode(musicMetadataJson) as Map<String, dynamic>;
            musicMetadata[fileIdString] = track.toJson();
            await prefs.setString('music_metadata', jsonEncode(musicMetadata));
          }
        }

        return GestureDetector(
          onTap: isDownloading ? null : handleTap,
          child: AbsorbPointer(
            absorbing: isDownloading,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width < 400
                    ? MediaQuery.of(context).size.width * 0.7
                    : 300.0,
              ),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.05),
                borderRadius: borderRadius,
                border: Border.all(
                  color: textColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: textColor.withValues(alpha: 0.1),
                        child: albumArtUrl != null
                            ? Image.network(
                                albumArtUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.music_note,
                                      color: textColor.withValues(alpha: 0.8),
                                      size: 24,
                                    ),
                              )
                            : Icon(
                                Icons.music_note,
                                color: textColor.withValues(alpha: 0.8),
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            artist,
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (album != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              album,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          if (progress < 0)
                            Row(
                              children: [
                                if (durationText.isNotEmpty) ...[
                                  Text(
                                    durationText,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  sizeStr,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          else if (isDownloading)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: textColor.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Загружено',
                                  style: TextStyle(
                                    color: Colors.green.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            onPressed: handleTap,
                            icon: Icon(
                              Icons.download_outlined,
                              color: textColor.withValues(alpha: 0.6),
                              size: 20,
                            ),
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

  String _getFileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'txt':
      case 'log':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  List<Widget> _buildAudioWithCaption(
    BuildContext context,
    List<Map<String, dynamic>> attaches,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final audioMessages = attaches.where((a) => a['_type'] == 'AUDIO').toList();
    final List<Widget> widgets = [];

    if (audioMessages.isEmpty) return widgets;

    for (final audio in audioMessages) {
      widgets.add(
        _buildAudioWidget(
          context,
          audio,
          textColor,
          isUltraOptimized,
          messageTextOpacity,
        ),
      );
      widgets.add(const SizedBox(height: 6));
    }

    return widgets;
  }

  Widget _buildAudioWidget(
    BuildContext context,
    Map<String, dynamic> audioData,
    Color textColor,
    bool isUltraOptimized,
    double messageTextOpacity,
  ) {
    final borderRadius = BorderRadius.circular(isUltraOptimized ? 8 : 12);
    final url = audioData['url'] as String?;
    final duration = audioData['duration'] as int? ?? 0;

    final waveRaw = audioData['wave'];
    final wave = waveRaw is String ? waveRaw : null;
    Uint8List? waveBytes;
    if (waveRaw is List<dynamic>) {
      try {
        waveBytes = Uint8List.fromList(List<int>.from(waveRaw));
      } catch (_) {}
    }

    final audioId = audioData['audioId'] as int?;

    final durationSeconds = (duration / 1000).round();
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return AudioPlayerWidget(
      url: url ?? '',
      duration: duration,
      durationText: durationText,
      wave: wave,
      waveBytes: waveBytes,
      audioId: audioId,
      textColor: textColor,
      borderRadius: borderRadius,
      messageTextOpacity: messageTextOpacity,
    );
  }

  Future<void> _handleFileDownload(
    BuildContext context,
    int? fileId,
    String? token,
    String fileName,
    int? chatId, {
    Map<String, dynamic>? preview,
  }) async {
    if (fileId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось загрузить информацию о файле (нет fileId)',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
      final fileIdString = fileId.toString();

      final mapping = fileIdMap.firstWhere(
        (m) => m.startsWith('$fileIdString:'),
        orElse: () => '',
      );

      if (mapping.isNotEmpty) {
        final filePath = mapping.substring(fileIdString.length + 1);
        final file = io.File(filePath);

        if (await file.exists()) {
          print(
            'Файл $fileName (ID: $fileId) найден локально: $filePath. Открываем...',
          );

          final result = await OpenFile.open(filePath);

          if (result.type != ResultType.done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Не удалось открыть файл: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } else {
          print(
            'Файл $fileName (ID: $fileId) был в SharedPreferences, но удален. Начинаем загрузку.',
          );
          fileIdMap.remove(mapping);
          await prefs.setStringList('file_id_to_path_map', fileIdMap);
        }
      }
    } catch (e) {
      print('Ошибка при проверке локального файла: $e. Продолжаем загрузку...');
    }

    print(
      'Файл $fileName (ID: $fileId) не найден. Запрашиваем URL у сервера...',
    );

    if (token == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось загрузить информацию о файле (нет token)',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (chatId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось определить чат'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final messageId = message.id;

      final seq = await ApiService.instance.sendRawRequest(88, {
        "fileId": fileId,
        "chatId": chatId,
        "messageId": int.tryParse(messageId) ?? 0,
      });

      if (seq == -1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось отправить запрос на получение файла'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await ApiService.instance.messages
          .firstWhere(
            (msg) => msg['seq'] == seq && msg['opcode'] == 88,
            orElse: () => <String, dynamic>{},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'Превышено время ожидания ответа от сервера',
            ),
          );

      if (response.isEmpty || response['payload'] == null) {
        throw Exception('Не получен ответ от сервера');
      }

      final downloadUrl = response['payload']['url'] as String?;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('Не получена ссылка на файл');
      }

      await _downloadFile(
        downloadUrl,
        fileName,
        fileId.toString(),
        context,
        preview: preview,
        fileIdInt: fileId,
        token: token,
        chatId: chatId,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при скачивании файла: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(
    String url,
    String fileName,
    String fileId,
    BuildContext context, {
    Map<String, dynamic>? preview,
    int? fileIdInt,
    String? token,
    int? chatId,
  }) async {
    _startBackgroundDownload(
      url,
      fileName,
      fileId,
      context,
      preview: preview,
      fileIdInt: fileIdInt,
      token: token,
      chatId: chatId,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Начато скачивание файла...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startBackgroundDownload(
    String url,
    String fileName,
    String fileId,
    BuildContext context, {
    Map<String, dynamic>? preview,
    int? fileIdInt,
    String? token,
    int? chatId,
  }) async {
    try {
      FileDownloadProgressService().updateProgress(fileId, 0.0);

      final downloadDir = await DownloadPathHelper.getDownloadDirectory();

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('Downloads directory not found');
      }

      final filePath = '${downloadDir.path}/$fileName';
      final file = io.File(filePath);

      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw Exception(
          'Failed to download file: ${streamedResponse.statusCode}',
        );
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        received += chunk.length;

        if (contentLength > 0) {
          final progress = received / contentLength;
          FileDownloadProgressService().updateProgress(fileId, progress);
        }
      }

      final data = Uint8List.fromList(bytes);
      await file.writeAsBytes(data);

      FileDownloadProgressService().updateProgress(fileId, 1.0);

      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedFiles =
          prefs.getStringList('downloaded_files') ?? [];
      if (!downloadedFiles.contains(file.path)) {
        downloadedFiles.add(file.path);
        await prefs.setStringList('downloaded_files', downloadedFiles);
      }

      final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
      final mappingKey = '$fileId:${file.path}';
      if (!fileIdMap.contains(mappingKey)) {
        fileIdMap.add(mappingKey);
        await prefs.setStringList('file_id_to_path_map', fileIdMap);
      }

      if (preview != null && fileIdInt != null) {
        final extension = fileName.split('.').last.toLowerCase();
        if (['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'].contains(extension)) {
          final title = preview['title'] as String? ?? fileName;
          final artist = preview['artistName'] as String? ?? 'Unknown Artist';
          final album = preview['albumName'] as String?;
          final albumArtUrl = preview['baseUrl'] as String?;
          final durationSeconds = preview['duration'] as int?;
          final duration = durationSeconds != null
              ? durationSeconds * 1000
              : null;

          final track = MusicTrack(
            id: fileId,
            title: title,
            artist: artist,
            album: album,
            albumArtUrl: albumArtUrl,
            duration: duration,
            filePath: file.path,
            fileId: fileIdInt,
            token: token,
            chatId: chatId,
          );

          final musicMetadataJson = prefs.getString('music_metadata') ?? '{}';
          final musicMetadata =
              jsonDecode(musicMetadataJson) as Map<String, dynamic>;
          musicMetadata[fileId] = track.toJson();
          await prefs.setString('music_metadata', jsonEncode(musicMetadata));
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл сохранен: $fileName'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      FileDownloadProgressService().clearProgress(fileId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при скачивании: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSmartPhotoGroup(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    Color textColor,
    bool isUltraOptimized, {
    bool showNameHeader = false,
  }) {
    final borderRadius = BorderRadius.circular(isUltraOptimized ? 4 : 12);

    final screenWidth = MediaQuery.of(context).size.width;
    final maxMessageWidth = screenWidth * 0.65;

    final maxPhotoWidth = maxMessageWidth - 24;

    switch (photos.length) {
      case 1:
        return _buildSinglePhoto(
          context,
          photos[0],
          showNameHeader
              ? BorderRadius.only(
                  bottomLeft: Radius.circular(isUltraOptimized ? 4 : 12),
                  bottomRight: Radius.circular(isUltraOptimized ? 4 : 12),
                )
              : borderRadius,
          maxPhotoWidth,
        );
      case 2:
        return _buildTwoPhotos(context, photos, borderRadius, maxPhotoWidth);
      case 3:
        return _buildThreePhotos(context, photos, borderRadius, maxPhotoWidth);
      case 4:
        return _buildFourPhotos(context, photos, borderRadius, maxPhotoWidth);
      default:
        return _buildManyPhotos(context, photos, borderRadius, maxPhotoWidth);
    }
  }

  Widget _buildSinglePhoto(
    BuildContext context,
    Map<String, dynamic> photo,
    BorderRadius borderRadius,
    double maxWidth,
  ) {
    return _SinglePhotoWidget(
      photo: photo,
      maxWidth: maxWidth,
      borderRadius: borderRadius,
      onTap: () => _openPhotoViewer(context, photo),
    );
  }

  Widget _buildTwoPhotos(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    BorderRadius borderRadius,
    double maxWidth,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 180, maxWidth: maxWidth),
      child: Row(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: GestureDetector(
                onTap: () => _openPhotoViewer(context, photos[0]),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: _buildPhotoWidget(context, photos[0]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: RepaintBoundary(
              child: GestureDetector(
                onTap: () => _openPhotoViewer(context, photos[1]),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: _buildPhotoWidget(context, photos[1]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreePhotos(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    BorderRadius borderRadius,
    double maxWidth,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 180, maxWidth: maxWidth),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: RepaintBoundary(
              child: GestureDetector(
                onTap: () => _openPhotoViewer(context, photos[0]),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: _buildPhotoWidget(context, photos[0]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),

          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[1]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[1]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[2]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[2]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPhotos(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    BorderRadius borderRadius,
    double maxWidth,
  ) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 180, maxWidth: maxWidth),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[0]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[0]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[1]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[1]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[2]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[2]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[3]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[3]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManyPhotos(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    BorderRadius borderRadius,
    double maxWidth,
  ) {
    const double rowHeight = 89.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 180, maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[0]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[0]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[1]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[1]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                Expanded(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTap: () => _openPhotoViewer(context, photos[2]),
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: _buildPhotoWidget(context, photos[2]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    children: [
                      RepaintBoundary(
                        child: GestureDetector(
                          onTap: () => _openPhotoViewer(context, photos[3]),
                          child: ClipRRect(
                            borderRadius: borderRadius,
                            child: _buildPhotoWidget(context, photos[3]),
                          ),
                        ),
                      ),
                      if (photos.length > 4)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _openPhotoGallery(context, photos, 3),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: borderRadius,
                              ),
                              child: Center(
                                child: Text(
                                  '+${photos.length - 3}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, Map<String, dynamic> attach) {
    List<Map<String, dynamic>>? galleryPhotos = allPhotos;

    if (galleryPhotos != null && galleryPhotos.isNotEmpty) {
      final initialIndex = galleryPhotos.indexWhere(
        (p) =>
            (p['url'] ?? p['baseUrl']) == (attach['url'] ?? attach['baseUrl']),
      );
      if (initialIndex != -1) {
        _openPhotoGallery(context, galleryPhotos, initialIndex);
        return;
      }

      // If the forwarded photo is not in the cached list, avoid opening
      // unrelated images from the gallery by falling back to a single view.
      galleryPhotos = null;
    }

    final url = attach['url'] ?? attach['baseUrl'];
    final preview = attach['previewData'];

    Widget child;
    if (url is String && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        child = Image.file(
          File(path),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      } else {
        String fullQualityUrl = url;
        if (!url.contains('?')) {
          fullQualityUrl = '$url?size=original&quality=high&format=original';
        } else {
          fullQualityUrl = '$url&size=original&quality=high&format=original';
        }
        child = _ProgressiveNetworkImage(
          url: fullQualityUrl,
          previewBytes: null,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          fit: BoxFit.contain,
        );
      }
    } else if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          final bytes = base64Decode(b64);
          child = Image.memory(bytes, fit: BoxFit.contain);
        } catch (_) {
          child = _imagePlaceholder();
        }
      } else {
        child = _imagePlaceholder();
      }
    } else {
      child = _imagePlaceholder();
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (BuildContext context, _, __) {
          return FullScreenPhotoViewer(
            imageChild: child,
            attach: attach,
            allPhotos: galleryPhotos,
            onGoToMessage: onGoToMessage,
            messageId: message.id,
            onOpenGallery: _openPhotoGallery,
          );
        },
        transitionsBuilder: (_, animation, __, page) {
          return FadeTransition(opacity: animation, child: page);
        },
      ),
    );
  }

  void _openPhotoGallery(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    int initialIndex,
  ) {
    final messageIds = photos
        .map((p) => p['_messageId'] as String?)
        .whereType<String>()
        .toList();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (BuildContext context, _, __) {
          return FullScreenPhotoGallery(
            photos: photos,
            initialIndex: initialIndex,
            onGoToMessage: onGoToMessage,
            messageIds: messageIds.isNotEmpty ? messageIds : null,
          );
        },
        transitionsBuilder: (_, animation, __, page) {
          return FadeTransition(opacity: animation, child: page);
        },
      ),
    );
  }

  Widget _buildPhotoWidget(BuildContext context, Map<String, dynamic> attach) {
    if (attach['_type'] == 'STICKER' && attach['id'] is int) {
      final stickerId = attach['id'] as int;
      final url = attach['url'] ?? attach['baseUrl'];

      if (url is String && url.isNotEmpty) {
        return _buildStickerWithCache(context, stickerId, url);
      }
    }

    Uint8List? previewBytes;
    final preview = attach['previewData'];
    if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          previewBytes = base64Decode(b64);
        } catch (_) {}
      }
    }

    final url = attach['url'] ?? attach['baseUrl'];
    if (url is String && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: 220,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _imagePlaceholder(),
        );
      }

      String previewQualityUrl = url;
      if (!url.contains('?')) {
        previewQualityUrl = '$url?size=medium&quality=high&format=jpeg';
      } else {
        previewQualityUrl = '$url&size=medium&quality=high&format=jpeg';
      }

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final optimize =
          themeProvider.optimizeChats || themeProvider.ultraOptimizeChats;

      return _ProgressiveNetworkImage(
        key: ValueKey(previewQualityUrl),
        url: previewQualityUrl,
        previewBytes: previewBytes,
        width: 220,
        height: 160,
        fit: BoxFit.cover,
        keepAlive: !optimize,
        startDownloadNextFrame: deferImageLoading,
      );
    }

    if (previewBytes != null) {
      return Image.memory(previewBytes, fit: BoxFit.cover, width: 180);
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 220,
      height: 160,
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.black38),
    );
  }

  Color _getBubbleColor(
    bool isMe,
    ThemeProvider themeProvider,
    double messageOpacity,
    BuildContext context,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final bool useMaterialYou = themeProvider.appTheme == AppTheme.system;

    final baseColor = useMaterialYou
        ? (isMe ? scheme.primaryContainer : scheme.secondaryContainer)
        : (isMe
              ? (themeProvider.myBubbleColor ?? const Color(0xFF2b5278))
              : (themeProvider.theirBubbleColor ??
                    (isDark
                        ? const Color(0xFF182533)
                        : const Color(0xFF464646))));
    return baseColor.withValues(alpha: 1.0 - messageOpacity);
  }

  Color _getTextColor(
    bool isMe,
    Color bubbleColor,
    double messageTextOpacity,
    BuildContext context,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = context.read<ThemeProvider>();

    final bool useMaterialYou = themeProvider.appTheme == AppTheme.system;

    final Color base = useMaterialYou
        ? (isMe ? scheme.onPrimaryContainer : scheme.onSecondaryContainer)
        : (isDarkMode ? Colors.white : Colors.black);

    return base.withValues(alpha: messageTextOpacity.clamp(0.0, 1.0));
  }

  List<Widget> _buildMessageContentChildren(
    BuildContext context,
    Color textColor,
    double messageTextOpacity,
    bool isUltraOptimized,
    TextStyle linkStyle,
    TextStyle defaultTextStyle,
    double messageBorderRadius,
    Future<void> Function(LinkableElement) onOpenLink,
    VoidCallback onSenderNameTap,
  ) {
    return [
      if (isGroupChat && !isMe && senderName != null)
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onSenderNameTap,

            child: Padding(
              padding: const EdgeInsets.only(left: 2.0, bottom: 0.0),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: getUserColor(
                    message.senderId,
                    context,
                  ).withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),

      if (isGroupChat && !isMe && senderName != null) const SizedBox(height: 2),
      if (message.isForwarded && message.link != null) ...[
        if (message.link is Map<String, dynamic>)
          _buildForwardedMessage(
            context,
            message.link as Map<String, dynamic>,
            textColor,
            messageTextOpacity,
            isUltraOptimized,
          ),
      ] else ...[
        if (message.isReply && message.link != null) ...[
          if (message.link is Map<String, dynamic>)
            _buildReplyPreview(
              context,
              message.link as Map<String, dynamic>,
              textColor,
              messageTextOpacity,
              isUltraOptimized,
              messageBorderRadius,
            ),
          const SizedBox(height: 8),
        ],
        if (message.attaches.isNotEmpty) ...[
          ..._buildCallsWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
          ),
          ..._buildAudioWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
          ),
          ..._buildPhotosWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
          ),
          ..._buildVideosWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
          ),
          ..._buildStickersWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
          ),
          ..._buildFilesWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
            chatId,
          ),
          ..._buildContactsWithCaption(
            context,
            message.attaches,
            textColor,
            isUltraOptimized,
            messageTextOpacity,
            chatId,
          ),
          const SizedBox(height: 6),
        ],
        if (message.text.isNotEmpty) ...[
          if (ChatEncryptionService.isEncryptedMessage(message.text) &&
              message.text.length > 1 &&
              !isEncryptionPasswordSet)
            Text(
              'это зашифрованное сообщение, для его отображение поставьте пароль шифрования на чат.',
              style: TextStyle(
                color: Colors.red,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            )
          else if (ChatEncryptionService.isEncryptedMessage(message.text) &&
              message.text.length > 1 &&
              isEncryptionPasswordSet &&
              decryptedText == null)
            Text(
              'некорректный ключ расшифровки, пароль точно верен?',
              style: TextStyle(
                color: Colors.red,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            )
          else if (decryptedText != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6.0, top: 2.0),
                  child: Icon(
                    Icons.lock,
                    size: 14,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                _buildMixedMessageContent(
                  decryptedText!,
                  defaultTextStyle,
                  linkStyle,
                  onOpenLink,
                  elements: message.elements,
                ),
              ],
            )
          else if (message.text.contains("welcome.saved.dialog.message"))
            Linkify(
              text:
                  'Привет! Это твои избранные. Все написанное сюда попадёт прямиком к дяде Майору.',
              style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
              linkStyle: linkStyle,
              onOpen: onOpenLink,
              options: const LinkifyOptions(humanize: false),
              linkifiers: const [
                UrlLinkifier(),
                EmailLinkifier(),
                DomainLinkifier(),
              ],
              textAlign: TextAlign.left,
            )
          else if (message.text.contains("komet.cosmetic.") ||
              message.text.contains("komet.color_"))
            _buildMixedMessageContent(
              message.text,
              defaultTextStyle,
              linkStyle,
              onOpenLink,
              elements: message.elements,
            )
          else
            _buildMixedMessageContent(
              message.text,
              defaultTextStyle,
              linkStyle,
              onOpenLink,
              elements: message.elements,
            ),
          if (message.reactionInfo != null) const SizedBox(height: 4),
        ],
      ],
      ..._buildInlineKeyboard(context, message.attaches, textColor),
      _buildReactionsWidget(context, textColor),
      const SizedBox(height: 8.0),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe) ...[
            if (message.attaches.any((a) => a['_type'] == 'PHOTO')) ...[
              Builder(
                builder: (context) {
                  final url = _extractFirstPhotoUrl(message.attaches);
                  if (url == null || url.startsWith('file://')) {
                    return const SizedBox.shrink();
                  }
                  final notifier = GlobalImageStore.progressFor(url);
                  return ValueListenableBuilder<double?>(
                    valueListenable: notifier,
                    builder: (context, value, _) {
                      if (value == null || value <= 0 || value >= 1) {
                        return const SizedBox.shrink();
                      }
                      return SizedBox(
                        width: 24,
                        height: 12,
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.transparent,
                          color: textColor.withValues(
                            alpha: 0.7 * messageTextOpacity,
                          ),
                          minHeight: 3,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            if (message.isEdited) ...[
              Text(
                '(изменено)',
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.5 * messageTextOpacity),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              _formatMessageTime(context, message.time),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9bb5c7)
                    : const Color(0xFF6b7280),
              ),
            ),
            if (readStatus != null) ...[
              const SizedBox(width: 4),
              Builder(
                builder: (context) {
                  final bool isRead = readStatus == MessageReadStatus.read;
                  final Color iconColor = isRead
                      ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.lightBlueAccent[100]!
                            : Colors.blue[600]!)
                      : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF9bb5c7)
                            : const Color(0xFF6b7280));
                  if (readStatus == MessageReadStatus.sending) {
                    return _RotatingIcon(
                      icon: Icons.watch_later_outlined,
                      size: 16,
                      color: iconColor,
                    );
                  } else if (readStatus == MessageReadStatus.sent) {
                    return Icon(Icons.done, size: 16, color: iconColor);
                  } else {
                    return Icon(Icons.done_all, size: 16, color: iconColor);
                  }
                },
              ),
            ],
          ],
          if (!isMe) ...[
            Text(
              _formatMessageTime(context, message.time),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9bb5c7)
                    : const Color(0xFF6b7280),
              ),
            ),
            if (message.isEdited) ...[
              const SizedBox(width: 6),
              Text(
                '(изменено)',
                style: TextStyle(
                  fontSize: 10,
                  color: textColor.withValues(alpha: 0.5 * messageTextOpacity),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    ];
  }

  List<KometSegment> _parseMixedMessageSegments(String text) {
    final segments = <KometSegment>[];
    int index = 0;

    while (index < text.length) {
      int nextPulse = text.indexOf("komet.cosmetic.pulse#", index);
      int nextGalaxy = text.indexOf("komet.cosmetic.galaxy'", index);
      int nextColor = text.indexOf("komet.color_", index);

      int nextMarker = text.length;
      String? markerType;
      if (nextPulse != -1 && nextPulse < nextMarker) {
        nextMarker = nextPulse;
        markerType = "pulse";
      }
      if (nextGalaxy != -1 && nextGalaxy < nextMarker) {
        nextMarker = nextGalaxy;
        markerType = "galaxy";
      }
      if (nextColor != -1 && nextColor < nextMarker) {
        nextMarker = nextColor;
        markerType = "color";
      }

      if (markerType == null) {
        if (index < text.length) {
          segments.add(
            KometSegment(text.substring(index), KometSegmentType.normal),
          );
        }
        break;
      }

      if (nextMarker > index) {
        segments.add(
          KometSegment(
            text.substring(index, nextMarker),
            KometSegmentType.normal,
          ),
        );
      }

      if (markerType == "pulse") {
        const prefix = "komet.cosmetic.pulse#";
        final afterHash = text.substring(nextMarker + prefix.length);
        final quoteIndex = afterHash.indexOf("'");
        if (quoteIndex != -1 && quoteIndex > 0) {
          final hexStr = afterHash.substring(0, quoteIndex).trim();
          final textStart = quoteIndex + 1;
          final secondQuote = afterHash.indexOf("'", textStart);
          if (secondQuote != -1) {
            final segmentText = afterHash.substring(textStart, secondQuote);
            final color = _parseKometHexColor(hexStr, null);
            segments.add(
              KometSegment(segmentText, KometSegmentType.pulse, color: color),
            );
            index = nextMarker + prefix.length + secondQuote + 2;
            continue;
          }
        }
        final safeEnd = (nextMarker + prefix.length + 10 < text.length)
            ? nextMarker + prefix.length + 10
            : text.length;
        segments.add(
          KometSegment(
            text.substring(nextMarker, safeEnd),
            KometSegmentType.normal,
          ),
        );
        index = safeEnd;
      } else if (markerType == "galaxy") {
        const prefix = "komet.cosmetic.galaxy'";
        final textStart = nextMarker + prefix.length;
        final quoteIndex = text.indexOf("'", textStart);
        if (quoteIndex != -1) {
          final segmentText = text.substring(textStart, quoteIndex);
          segments.add(KometSegment(segmentText, KometSegmentType.galaxy));
          index = quoteIndex + 1;
          continue;
        }

        segments.add(
          KometSegment(
            text.substring(nextMarker, textStart + 10),
            KometSegmentType.normal,
          ),
        );
        index = textStart + 10;
      } else if (markerType == "color") {
        const marker = 'komet.color_';
        final colorStart = nextMarker + marker.length;
        final firstQuote = text.indexOf("'", colorStart);
        if (firstQuote != -1) {
          final colorStr = text.substring(colorStart, firstQuote);
          final textStart = firstQuote + 1;
          final secondQuote = text.indexOf("'", textStart);
          if (secondQuote != -1) {
            final segmentText = text.substring(textStart, secondQuote);
            final color = _parseKometHexColor(colorStr, null);
            segments.add(
              KometSegment(segmentText, KometSegmentType.colored, color: color),
            );
            index = secondQuote + 1;
            continue;
          }
        }

        segments.add(
          KometSegment(
            text.substring(nextMarker, colorStart + 10),
            KometSegmentType.normal,
          ),
        );
        index = colorStart + 10;
      }
    }

    return segments;
  }

  Widget _buildMixedMessageContent(
    String text,
    TextStyle baseStyle,
    TextStyle linkStyle,
    Future<void> Function(LinkableElement) onOpenLink, {
    List<Map<String, dynamic>> elements = const [],
  }) {
    final segments = _parseMixedMessageSegments(text);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: segments.map((seg) {
        switch (seg.type) {
          case KometSegmentType.normal:
          case KometSegmentType.colored:
            final baseForSeg = seg.type == KometSegmentType.colored
                ? baseStyle.copyWith(color: seg.color)
                : baseStyle;

            if (elements.isEmpty) {
              return Linkify(
                text: seg.text,
                style: baseForSeg,
                linkStyle: linkStyle,
                onOpen: onOpenLink,
                options: const LinkifyOptions(humanize: false),
                linkifiers: const [
                  UrlLinkifier(),
                  EmailLinkifier(),
                  DomainLinkifier(),
                ],
              );
            } else {
              return _buildFormattedRichText(seg.text, baseForSeg, elements);
            }
          case KometSegmentType.galaxy:
            return GalaxyAnimatedText(text: seg.text);
          case KometSegmentType.pulse:
            final hexStr = seg.color!.value
                .toRadixString(16)
                .padLeft(8, '0')
                .substring(2)
                .toUpperCase();
            return PulseAnimatedText(
              text: "komet.cosmetic.pulse#$hexStr'${seg.text}'",
            );
        }
      }).toList(),
    );
  }

  Widget _buildFormattedRichText(
    String text,
    TextStyle baseStyle,
    List<Map<String, dynamic>> elements,
  ) {
    if (text.isEmpty || elements.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final bold = List<bool>.filled(text.length, false);
    final italic = List<bool>.filled(text.length, false);
    final underline = List<bool>.filled(text.length, false);
    final strike = List<bool>.filled(text.length, false);

    for (final el in elements) {
      final type = el['type'] as String?;
      final from = (el['from'] as int?) ?? 0;
      final length = (el['length'] as int?) ?? 0;
      if (type == null || length <= 0) continue;
      final start = from.clamp(0, text.length);
      final end = (from + length).clamp(0, text.length);
      for (int i = start; i < end; i++) {
        switch (type) {
          case 'STRONG':
            bold[i] = true;
            break;
          case 'EMPHASIZED':
            italic[i] = true;
            break;
          case 'UNDERLINE':
            underline[i] = true;
            break;
          case 'STRIKETHROUGH':
            strike[i] = true;
            break;
        }
      }
    }

    final spans = <TextSpan>[];
    int start = 0;

    TextStyle styleForIndex(int i) {
      var s = baseStyle;
      if (bold[i]) s = s.copyWith(fontWeight: FontWeight.w600);
      if (italic[i]) s = s.copyWith(fontStyle: FontStyle.italic);
      final line = <TextDecoration>[];
      if (underline[i]) line.add(TextDecoration.underline);
      if (strike[i]) line.add(TextDecoration.lineThrough);
      if (line.isNotEmpty) {
        s = s.copyWith(decoration: TextDecoration.combine(line));
      }
      return s;
    }

    while (start < text.length) {
      int end = start + 1;
      final style = styleForIndex(start);
      while (end < text.length && styleForIndex(end) == style) {
        end++;
      }
      spans.add(TextSpan(text: text.substring(start, end), style: style));
      start = end;
    }

    return Text.rich(
      TextSpan(children: spans, style: baseStyle),
      textAlign: TextAlign.left,
    );
  }

  Color _parseKometHexColor(String raw, Color? fallbackColor) {
    String hex = raw.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }

    final isValidChars = RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
    if (!isValidChars || hex.isEmpty) {
      return fallbackColor ?? const Color(0xFFFF0000);
    }

    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    } else if (hex.length == 4) {
      hex =
          '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
    } else if (hex.length == 5) {
      hex = '0$hex';
    } else if (hex.length == 6) {
    } else if (hex.length == 8) {
    } else {
      if (hex.length < 6) {
        hex = hex.padRight(6, '0');
      } else {
        hex = hex.substring(0, 6);
      }
    }

    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    try {
      final value = int.parse(hex, radix: 16);
      return Color(value);
    } catch (_) {
      return fallbackColor ?? const Color(0xFFFF0000);
    }
  }

  BoxDecoration _createBubbleDecoration(
    Color bubbleColor,
    double messageBorderRadius,
    double messageShadowIntensity,
  ) {
    return BoxDecoration(
      color: bubbleColor,
      borderRadius: BorderRadius.circular(messageBorderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: messageShadowIntensity),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildMessageContentInner(
    BuildContext context,
    BoxDecoration? decoration,
    List<Widget> children,
  ) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
      margin: _getMessageMargin(context),
      decoration: decoration,
      child: SelectionArea(
        contextMenuBuilder: (context, selectableRegionState) {
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: selectableRegionState.contextMenuAnchors,
            buttonItems: [],
          );
        },
        child: content,
      ),
    );
  }

  Color _getLinkColor(Color bubbleColor, bool isMe) {
    final isDark = BrightnessExtension(
      ThemeData.estimateBrightnessForColor(bubbleColor),
    ).isDark;
    if (isMe) {
      return isDark ? Colors.white : Colors.blue[700]!;
    }
    return Colors.blue[700]!;
  }

  Widget _buildSenderAvatar() {
    final senderContact = contactDetailsCache?[message.senderId];
    final avatarUrl = senderContact?.photoBaseUrl;
    final contactName = senderContact?.name ?? 'Участник ${message.senderId}';

    return RepaintBoundary(
      key: ValueKey('avatar_${message.senderId}'),
      child: Builder(
        builder: (context) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => openUserProfileById(context, message.senderId),
            child: AvatarCacheService().getAvatarWidget(
              avatarUrl,
              userId: message.senderId,
              size: 32,
              fallbackText: contactName,
              backgroundColor: getUserColor(message.senderId, context),
              textColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendingMessageContextMenu extends StatefulWidget {
  final Message message;
  final Offset position;
  final VoidCallback? onRetrySend;
  final VoidCallback? onCancelSend;

  const _SendingMessageContextMenu({
    required this.message,
    required this.position,
    this.onRetrySend,
    this.onCancelSend,
  });

  @override
  State<_SendingMessageContextMenu> createState() =>
      _SendingMessageContextMenuState();
}

class _SendingMessageContextMenuState
    extends State<_SendingMessageContextMenu> {
  Timer? _statusCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMessageStatus();
    });

    _statusCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkMessageStatus();
    });
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _checkMessageStatus() {
    // Если сообщение больше не в состоянии sending, закрываем диалог
    if (!widget.message.id.startsWith('local_') && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Дополнительная проверка при каждом rebuild
    if (!widget.message.id.startsWith('local_')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }
    final screenSize = MediaQuery.of(context).size;

    double left = widget.position.dx - 75;
    if (left + 150 > screenSize.width - 10) {
      left = screenSize.width - 160;
    }
    if (left < 10) {
      left = 10;
    }

    double top = widget.position.dy - 60;
    if (top < 10) {
      top = widget.position.dy + 20;
    }
    if (top + 100 > screenSize.height - 10) {
      top = screenSize.height - 110;
    }

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.1),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: top,
            left: left,
            child: Container(
              width: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onRetrySend?.call();
                    },
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Повторить',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onCancelSend?.call();
                    },
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.close,
                            size: 20,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Отменить',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
}

class _LongPressContextMenuWrapper extends StatefulWidget {
  final Widget child;
  final void Function(Offset globalPosition) onShowMenu;

  const _LongPressContextMenuWrapper({
    required this.child,
    required this.onShowMenu,
  });

  @override
  State<_LongPressContextMenuWrapper> createState() =>
      _LongPressContextMenuWrapperState();
}

class _LongPressContextMenuWrapperState
    extends State<_LongPressContextMenuWrapper> {
  static const Duration _longPressDuration = Duration(milliseconds: 350);
  static const double _maxMovementDistance = 15.0;

  Timer? _timer;
  Offset? _initialPosition;

  void _onPointerDown(PointerDownEvent event) {
    _initialPosition = event.position;
    _timer?.cancel();
    _timer = Timer(_longPressDuration, () {
      if (_initialPosition != null) {
        widget.onShowMenu(_initialPosition!);
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_initialPosition != null) {
      final distance = (event.position - _initialPosition!).distance;

      if (distance > _maxMovementDistance) {
        _timer?.cancel();
        _initialPosition = null;
      }
    }
  }

  void _onPointerUpOrCancel(PointerEvent event) {
    _timer?.cancel();
    _initialPosition = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUpOrCancel,
      onPointerCancel: _onPointerUpOrCancel,
      child: widget.child,
    );
  }
}

class GlobalImageStore {
  static final Map<String, Uint8List> _memory = {};
  static final Map<String, ValueNotifier<double?>> _progress = {};

  static Uint8List? getData(String url) => _memory[url];
  static void setData(String url, Uint8List bytes) {
    _memory[url] = bytes;
    progressFor(url).value = null;
  }

  static ValueNotifier<double?> progressFor(String url) {
    return _progress.putIfAbsent(url, () => ValueNotifier<double?>(null));
  }

  static void setProgress(String url, double? value) {
    progressFor(url).value = value;
  }
}

class _VideoPreviewWidget extends StatefulWidget {
  final int videoId;
  final String messageId;
  final String? highQualityUrl;
  final Uint8List? lowQualityBytes;
  final bool showNameHeader;
  final Function() onTap;

  const _VideoPreviewWidget({
    required this.videoId,
    required this.messageId,
    this.highQualityUrl,
    this.lowQualityBytes,
    this.showNameHeader = false,
    required this.onTap,
  });

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      key: ValueKey(
        'video_preview_boundary_${widget.messageId}_${widget.videoId}',
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: widget.showNameHeader
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  )
                : BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: [
                (widget.highQualityUrl != null &&
                            widget.highQualityUrl!.isNotEmpty) ||
                        (widget.lowQualityBytes != null)
                    ? _ProgressiveNetworkImage(
                        key: ValueKey(
                          'video_preview_image_${widget.messageId}_${widget.videoId}',
                        ),
                        url: widget.highQualityUrl ?? '',
                        previewBytes: widget.lowQualityBytes,
                        width: 220,
                        height: 160,
                        fit: BoxFit.cover,
                        keepAlive: true,
                      )
                    : Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    Icons.play_circle_filled_outlined,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 50,
                    shadows: const [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressiveNetworkImage extends StatefulWidget {
  final String url;
  final Uint8List? previewBytes;
  final double width;
  final double height;
  final BoxFit fit;
  final bool startDownloadNextFrame;
  final bool keepAlive;
  const _ProgressiveNetworkImage({
    super.key,
    required this.url,
    required this.previewBytes,
    required this.width,
    required this.height,
    required this.fit,
    this.startDownloadNextFrame = false,
    this.keepAlive = true,
  });

  @override
  State<_ProgressiveNetworkImage> createState() =>
      _ProgressiveNetworkImageState();
}

class _ProgressiveNetworkImageState extends State<_ProgressiveNetworkImage>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, Uint8List> _memoryCache = {};
  Uint8List? _fullBytes;
  double _progress = 0.0;
  bool _error = false;
  String? _diskPath;

  @override
  void initState() {
    super.initState();

    if (widget.url.isEmpty) {
      return;
    }

    if (_memoryCache.containsKey(widget.url)) {
      _fullBytes = _memoryCache[widget.url];
    } else {
      final cached = GlobalImageStore.getData(widget.url);
      if (cached != null) {
        _fullBytes = cached;
        _memoryCache[widget.url] = cached;
      }
    }

    if (_fullBytes == null) {
      if (widget.startDownloadNextFrame) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryLoadFromDiskThenDownload();
        });
      } else {
        _tryLoadFromDiskThenDownload();
      }
    }
  }

  Future<void> _tryLoadFromDiskThenDownload() async {
    if (widget.url.isEmpty || _fullBytes != null) {
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final name = crypto.md5.convert(widget.url.codeUnits).toString();
      final filePath = '${dir.path}/imgcache_$name';
      _diskPath = filePath;
      final f = io.File(filePath);
      if (await f.exists()) {
        final data = await f.readAsBytes();
        _memoryCache[widget.url] = data;
        GlobalImageStore.setData(widget.url, data);
        if (mounted && _fullBytes == null) {
          setState(() => _fullBytes = data);
        }
        return;
      }
    } catch (_) {}
    if (_fullBytes == null) {
      await _download();
    }
  }

  Future<void> _download() async {
    if (_fullBytes != null) {
      return;
    }
    try {
      final req = http.Request('GET', Uri.parse(widget.url));
      req.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      final resp = await req.send();
      if (resp.statusCode != 200) {
        if (mounted) setState(() => _error = true);
        return;
      }
      final contentLength = resp.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;
      await for (final chunk in resp.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final p = received / contentLength;
          _progress = p;
          GlobalImageStore.setProgress(widget.url, _progress);
        }
      }
      final data = Uint8List.fromList(bytes);
      _memoryCache[widget.url] = data;
      GlobalImageStore.setData(widget.url, data);

      try {
        final path = _diskPath;
        if (path != null) {
          final f = io.File(path);
          await f.writeAsBytes(data, flush: true);
        }
      } catch (_) {}
      if (mounted && _fullBytes == null) {
        setState(() => _fullBytes = data);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = widget.width;
    final height = widget.height;
    if (_error) {
      return Container(
        width: width,
        height: height,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.black38),
      );
    }

    final hasPreview = widget.previewBytes != null;
    final hasFullImage = _fullBytes != null;

    if (!hasPreview && !hasFullImage) {
      return SizedBox(
        width: width,
        height: height,
        child: Container(color: Colors.black12),
      );
    }

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasFullImage)
                Image.memory(
                  _fullBytes!,
                  fit: widget.fit,
                  filterQuality: FilterQuality.high,
                  key: ValueKey('full_${widget.url}'),
                )
              else if (hasPreview)
                Image.memory(
                  widget.previewBytes!,
                  fit: widget.fit,
                  filterQuality: FilterQuality.none,
                  key: ValueKey('preview_${widget.url}'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
  @override
  void didUpdateWidget(covariant _ProgressiveNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
    if (oldWidget.url != widget.url) {
      _fullBytes = null;
      _error = false;
      _progress = 0.0;
      final cached = GlobalImageStore.getData(widget.url);
      if (cached != null) {
        _fullBytes = cached;
      }
      if (_memoryCache.containsKey(widget.url)) {
        _fullBytes = _memoryCache[widget.url];
      }
      if (widget.url.isNotEmpty && _fullBytes == null) {
        _tryLoadFromDiskThenDownload();
      }
    }
  }
}

extension BrightnessExtension on Brightness {
  bool get isDark => this == Brightness.dark;
}

class _CustomEmojiButton extends StatefulWidget {
  final Function(String) onCustomEmoji;

  const _CustomEmojiButton({required this.onCustomEmoji});

  @override
  State<_CustomEmojiButton> createState() => _CustomEmojiButtonState();
}

class _CustomEmojiButtonState extends State<_CustomEmojiButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });

    _showCustomEmojiDialog();
  }

  void _showCustomEmojiDialog() {
    showDialog(
      context: context,
      builder: (context) => CustomEmojiDialog(
        onEmojiSelected: (emoji) {
          widget.onCustomEmoji(emoji);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),

              child: Icon(
                Icons.add_reaction_outlined,
                size: 24,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageContextMenu extends StatefulWidget {
  final Message message;
  final Offset position;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onDeleteForAll;
  final Function(String)? onReaction;
  final VoidCallback? onRemoveReaction;
  final VoidCallback? onForward;
  final VoidCallback? onComplain;
  final bool canEditMessage;
  final bool hasUserReaction;
  final bool isChannel;
  final bool isPending;
  final VoidCallback? onCancelSend;
  final VoidCallback? onRetrySend;

  const _MessageContextMenu({
    required this.message,
    required this.position,
    this.onReply,
    this.onEdit,
    this.onDeleteForMe,
    this.onDeleteForAll,
    this.onReaction,
    this.onRemoveReaction,
    this.onForward,
    this.onComplain,
    required this.canEditMessage,
    required this.hasUserReaction,
    this.isChannel = false,
    required this.isPending,
    this.onCancelSend,
    this.onRetrySend,
  });

  @override
  _MessageContextMenuState createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<_MessageContextMenu>
    with SingleTickerProviderStateMixin {
  bool _isEmojiListExpanded = false;

  final GlobalKey _menuKey = GlobalKey();
  Size? _lastLoggedSize;

  double? _overrideLeft;
  double? _overrideTop;
  double _safeLeft = 0;
  double _safeRight = 0;
  double _safeTop = 0;
  double _safeBottom = 0;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  static const List<String> _quickReactions = [
    '👍',
    '❤️',
    '😂',
    '🔥',
    '👏',
    '🤔',
  ];

  static const List<String> _allReactions = [
    '👍',
    '❤️',
    '😂',
    '🔥',
    '👏',
    '👌',
    '🎉',
    '🥰',
    '😍',
    '🙏',
    '🤔',
    '🤯',
    '💯',
    '⚡️',
    '🤟',
    '🌚',
    '🌝',
    '🥱',
    '🤣',
    '🫠',
    '🫡',
    '🐱',
    '💋',
    '😘',
    '🐶',
    '🤝',
    '⭐️',
    '🍷',
    '🍑',
    '😁',
    '🤷‍♀️',
    '🤷‍♂️',
    '👩‍❤️‍👨',
    '🦄',
    '👻',
    '🗿',
    '❤️‍🩹',
    '🛑',
    '⛄️',
    '❓',
    '🙄',
    '❗️',
    '😉',
    '😳',
    '🥳',
    '😎',
    '💪',
    '👀',
    '🤞',
    '🤤',
    '🤪',
    '🤩',
    '😴',
    '😐',
    '😇',
    '🖤',
    '👑',
    '👋',
    '👁️',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _logMenuBoxGeometry() {
    final box = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final size = box.size;
    if (_lastLoggedSize == size) return;
    _lastLoggedSize = size;

    final offset = box.localToGlobal(Offset.zero);

    debugPrint(
      '[CtxMenuBox] ACTUAL: pos=(${offset.dx.toStringAsFixed(1)},${offset.dy.toStringAsFixed(1)}) '
      'size=(${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}) '
      'safeBounds=(L:$_safeLeft, R:$_safeRight, T:$_safeTop, B:$_safeBottom)',
    );

    // Если меню вышло за границы, повторно спозиционируем с учетом фактического размера.
    double newLeft = offset.dx;
    double newTop = offset.dy;
    bool needsAdjust = false;

    if (offset.dx < _safeLeft) {
      newLeft = _safeLeft;
      needsAdjust = true;
    } else if (offset.dx + size.width > _safeRight) {
      newLeft = _safeRight - size.width;
      needsAdjust = true;
    }

    if (offset.dy < _safeTop) {
      newTop = _safeTop;
      needsAdjust = true;
    } else if (offset.dy + size.height > _safeBottom) {
      newTop = _safeBottom - size.height;
      needsAdjust = true;
    }

    if (needsAdjust) {
      debugPrint('[CtxMenuBox] ADJUSTING to: ($newLeft, $newTop)');
      setState(() {
        _overrideLeft = newLeft;
        _overrideTop = newTop;
      });
    }
  }

  bool _hasAudioOrVideoCircle() {
    final attaches = widget.message.attaches;

    final hasAudio = attaches.any((a) => a['_type'] == 'AUDIO');
    final hasVideoCircle = attaches.any(
      (a) => a['_type'] == 'VIDEO' && (a['videoType'] as int?) == 1,
    );

    if (hasAudio || hasVideoCircle) {
      return true;
    }

    if (widget.message.isForwarded &&
        widget.message.link is Map<String, dynamic>) {
      final link = widget.message.link as Map<String, dynamic>;
      final forwardedMessage = link['message'] as Map<String, dynamic>?;
      if (forwardedMessage != null) {
        final forwardedAttaches =
            (forwardedMessage['attaches'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            [];

        final forwardedHasAudio = forwardedAttaches.any(
          (a) => a['_type'] == 'AUDIO',
        );
        final forwardedHasVideoCircle = forwardedAttaches.any(
          (a) => a['_type'] == 'VIDEO' && (a['videoType'] as int?) == 1,
        );

        return forwardedHasAudio || forwardedHasVideoCircle;
      }
    }

    return false;
  }

  Future<void> _onSaveToDevice() async {
    Navigator.of(context).pop();

    try {
      List<Map<String, dynamic>> attaches = widget.message.attaches;

      if (widget.message.isForwarded &&
          widget.message.link is Map<String, dynamic>) {
        final link = widget.message.link as Map<String, dynamic>;
        final forwardedMessage = link['message'] as Map<String, dynamic>?;
        if (forwardedMessage != null) {
          attaches =
              (forwardedMessage['attaches'] as List?)
                  ?.map((e) => (e as Map).cast<String, dynamic>())
                  .toList() ??
              [];
        }
      }

      final audioAttach = attaches.firstWhere(
        (a) => a['_type'] == 'AUDIO',
        orElse: () => <String, dynamic>{},
      );

      final videoCircleAttach = attaches.firstWhere(
        (a) => a['_type'] == 'VIDEO' && (a['videoType'] as int?) == 1,
        orElse: () => <String, dynamic>{},
      );

      String? fileUrl;
      String fileName;
      Uint8List? fileBytes;

      if (audioAttach.isNotEmpty) {
        fileUrl = audioAttach['url'] as String?;
        final audioId = audioAttach['audioId'] as int?;
        fileName =
            'audio_${audioId ?? DateTime.now().millisecondsSinceEpoch}.m4a';

        if (fileUrl != null && fileUrl.isNotEmpty) {
          final cacheService = CacheService();
          final cachedFile = await cacheService.getCachedAudioFile(
            fileUrl,
            customKey: audioId?.toString(),
          );

          if (cachedFile != null && await cachedFile.exists()) {
            fileBytes = await cachedFile.readAsBytes();
          }
        }
      } else if (videoCircleAttach.isNotEmpty) {
        final videoId = videoCircleAttach['videoId'] as int?;
        final chatId = widget.message.cid;

        if (videoId != null && chatId != null) {
          try {
            fileUrl = await ApiService.instance.getVideoUrl(
              videoId,
              chatId,
              widget.message.id,
            );
            fileName =
                'video_${videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Не удалось получить URL видео: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось определить параметры видео'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        return;
      }

      if (fileUrl == null || fileUrl.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('URL файла не найден'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      String? savedPath;

      if (fileBytes != null) {
        savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Сохранить файл',
          fileName: fileName,
          bytes: fileBytes,
        );
      } else {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          savedPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Сохранить файл',
            fileName: fileName,
            bytes: Uint8List.fromList(bytes),
          );
        } else {
          throw Exception('Failed to download: ${response.statusCode}');
        }
      }

      if (savedPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл сохранен: $savedPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранение отменено'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при сохранении: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onCopy() {
    String textToCopy = widget.message.text;

    if (textToCopy.isEmpty &&
        widget.message.isForwarded &&
        widget.message.link is Map<String, dynamic>) {
      final link = widget.message.link as Map<String, dynamic>;
      final forwardedMessage = link['message'] as Map<String, dynamic>?;
      final forwardedText = forwardedMessage?['text'] as String? ?? '';
      textToCopy = forwardedText;
    }

    if (textToCopy.isEmpty) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет текста для копирования'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Сообщение скопировано'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final viewInsets = mediaQuery.viewInsets; // keyboard
    final viewPadding = mediaQuery.viewPadding; // status bar / notch

    const menuWidth = 250.0;
    const padding = 10.0;

    final double availableHeight =
        screenSize.height - viewInsets.vertical - viewPadding.vertical;
    final double maxMenuHeight = (availableHeight - padding * 2).clamp(
      180.0,
      availableHeight,
    );

    final double estimatedMenuHeight = widget.isPending
        ? 180.0
        : (_isEmojiListExpanded ? 550.0 : 480.0);

    final double menuHeightForPosition = estimatedMenuHeight.clamp(
      180.0,
      maxMenuHeight,
    );

    double left;
    double top;

    if (widget.isPending) {
      left = widget.position.dx - (menuWidth / 2);
      top = widget.position.dy - (menuHeightForPosition / 2);
    } else {
      // Если тап в правой части экрана, меню открывается влево от тапа
      if (widget.position.dx > screenSize.width / 2) {
        left = widget.position.dx - menuWidth + 10;
      } else {
        // Если в левой — вправо
        left = widget.position.dx - 10;
      }
      top = widget.position.dy - 40;
    }

    _safeLeft = padding;
    _safeRight = screenSize.width - padding;
    _safeTop = viewPadding.top + padding;
    _safeBottom =
        screenSize.height -
        viewInsets.bottom -
        viewPadding.bottom -
        padding -
        30;

    if (left + menuWidth > _safeRight) left = _safeRight - menuWidth;
    if (left < _safeLeft) left = _safeLeft;
    if (top + menuHeightForPosition > _safeBottom)
      top = _safeBottom - menuHeightForPosition;
    if (top < _safeTop) top = _safeTop;

    if (_overrideLeft != null) left = _overrideLeft!;
    if (_overrideTop != null) top = _overrideTop!;

    debugPrint(
      '[CtxMenu] CALC: tap=${widget.position.dx.toInt()},${widget.position.dy.toInt()} pos=${left.toInt()},${top.toInt()}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _logMenuBoxGeometry());

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.black.withValues(alpha: 0.1)),
            ),
          ),
          Positioned(
            top: top,
            left: left,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: widget.position.dx > screenSize.width / 2
                  ? Alignment.topRight
                  : Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: menuWidth,
                  maxHeight: maxMenuHeight,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: themeProvider.messageMenuBlur,
                      sigmaY: themeProvider.messageMenuBlur,
                    ),
                    child: Card(
                      key: _menuKey,
                      elevation: 8,
                      margin: EdgeInsets.zero,
                      color: theme.colorScheme.surface.withValues(
                        alpha: themeProvider.messageMenuOpacity,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!widget.isPending) ...[
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: _buildEmojiSection(),
                              ),
                              const Divider(height: 12),
                            ],
                            _buildActionsSection(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiSection() {
    if (_isEmojiListExpanded) {
      return SizedBox(
        height: 150,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _allReactions.length,
          itemBuilder: (context, index) {
            final emoji = _allReactions[index];
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onReaction?.call(emoji);
              },
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            );
          },
        ),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          ..._quickReactions.map(
            (emoji) => GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onReaction?.call(emoji);
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => setState(() => _isEmojiListExpanded = true),
            tooltip: 'Больше реакций',
          ),
        ],
      );
    }
  }

  Widget _buildActionsSection(ThemeData theme) {
    if (widget.isPending) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButton(
            icon: Icons.cancel_rounded,
            text: 'Отменить отправку',
            color: theme.colorScheme.error,
            onTap: widget.onCancelSend == null
                ? null
                : () {
                    Navigator.pop(context);
                    widget.onCancelSend!();
                  },
          ),
          _buildActionButton(
            icon: Icons.refresh_rounded,
            text: 'Повторить отправку',
            onTap: widget.onRetrySend == null
                ? null
                : () {
                    Navigator.pop(context);
                    widget.onRetrySend!();
                  },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message.text.isNotEmpty || widget.message.isForwarded)
          _buildActionButton(
            icon: Icons.copy_rounded,
            text: 'Копировать',
            onTap: _onCopy,
          ),
        if (widget.onReply != null && !widget.isChannel)
          _buildActionButton(
            icon: Icons.reply_rounded,
            text: 'Ответить',
            onTap: () {
              Navigator.pop(context);
              widget.onReply!();
            },
          ),
        if (widget.onForward != null)
          _buildActionButton(
            icon: Icons.forward_rounded,
            text: 'Переслать',
            onTap: () {
              Navigator.pop(context);
              widget.onForward!();
            },
          ),
        if (widget.onEdit != null)
          _buildActionButton(
            icon: widget.canEditMessage
                ? Icons.edit_rounded
                : Icons.edit_off_rounded,
            text: 'Редактировать',
            onTap: widget.canEditMessage
                ? () {
                    Navigator.pop(context);
                    widget.onEdit!();
                  }
                : null,
            color: widget.canEditMessage ? null : Colors.grey,
          ),
        if (widget.hasUserReaction && widget.onRemoveReaction != null)
          _buildActionButton(
            icon: Icons.remove_circle_outline_rounded,
            text: 'Убрать реакцию',
            color: theme.colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              widget.onRemoveReaction!();
            },
          ),
        if (widget.onDeleteForMe != null)
          _buildActionButton(
            icon: Icons.person_remove_rounded,
            text: 'Удалить у меня',
            color: theme.colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              widget.onDeleteForMe!();
            },
          ),
        if (widget.onDeleteForAll != null)
          _buildActionButton(
            icon: Icons.delete_forever_rounded,
            text: 'Удалить у всех',
            color: theme.colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              widget.onDeleteForAll!();
            },
          ),
        if (_hasAudioOrVideoCircle())
          _buildActionButton(
            icon: Icons.download_rounded,
            text: 'Сохранить на устройстве',
            onTap: _onSaveToDevice,
          ),
        if (widget.onComplain != null)
          _buildActionButton(
            icon: Icons.report_rounded,
            text: 'Пожаловаться',
            color: theme.colorScheme.error,
            onTap: () {
              Navigator.pop(context);
              widget.onComplain!();
            },
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: color ?? Theme.of(context).iconTheme.color,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: onTap == null ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenPhotoViewer extends StatefulWidget {
  final Widget imageChild;
  final Map<String, dynamic>? attach;
  final List<Map<String, dynamic>>? allPhotos;
  final Function(String)? onGoToMessage;
  final String? messageId;
  final void Function(BuildContext, List<Map<String, dynamic>>, int)?
  onOpenGallery;

  const FullScreenPhotoViewer({
    super.key,
    required this.imageChild,
    this.attach,
    this.allPhotos,
    this.onGoToMessage,
    this.messageId,
    this.onOpenGallery,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final PageController _pageController;
  late final ScrollController _thumbnailsScrollController;
  final Map<int, TransformationController> _transformationControllers = {};
  final Map<int, bool> _isPanEnabled = {};

  bool _showLeftArrow = false;
  bool _showRightArrow = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _thumbnailsScrollController = ScrollController();

    _thumbnailsScrollController.addListener(_updateArrowsVisibility);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrentPage();
      _scrollToCurrentPhoto();
      _updateArrowsVisibility();
    });
  }

  void _initializeCurrentPage() {
    if (widget.allPhotos != null &&
        widget.allPhotos!.isNotEmpty &&
        widget.attach != null) {
      final currentUrl = widget.attach!['url'] ?? widget.attach!['baseUrl'];
      for (int i = 0; i < widget.allPhotos!.length; i++) {
        final photoUrl =
            widget.allPhotos![i]['url'] ?? widget.allPhotos![i]['baseUrl'];
        if (photoUrl == currentUrl) {
          _currentPage = i;
          _pageController = PageController(initialPage: i);
          break;
        }
      }
    }

    for (int i = 0; i < (widget.allPhotos?.length ?? 1); i++) {
      _transformationControllers[i] = TransformationController();
      _isPanEnabled[i] = false;
      _transformationControllers[i]!.addListener(() => _onTransformChanged(i));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailsScrollController.dispose();
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scrollToCurrentPhoto() {
    if (widget.allPhotos == null || widget.allPhotos!.isEmpty) return;
    if (!_thumbnailsScrollController.hasClients) return;

    const itemWidth = 80.0;
    const itemMargin = 4.0;
    const itemSpacing = itemWidth + (itemMargin * 2);
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset =
        (_currentPage * itemSpacing) - (screenWidth / 2) + (itemWidth / 2);

    _thumbnailsScrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _thumbnailsScrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _updateArrowsVisibility() {
    if (!_thumbnailsScrollController.hasClients) {
      setState(() {
        _showLeftArrow = false;
        _showRightArrow = false;
      });
      return;
    }

    final position = _thumbnailsScrollController.position;
    setState(() {
      _showLeftArrow = position.pixels > 0;
      _showRightArrow = position.pixels < position.maxScrollExtent;
    });
  }

  void _scrollLeft() {
    if (!_thumbnailsScrollController.hasClients) return;
    final target = _thumbnailsScrollController.offset - 200;
    _thumbnailsScrollController.animateTo(
      target.clamp(0.0, _thumbnailsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    if (!_thumbnailsScrollController.hasClients) return;
    final target = _thumbnailsScrollController.offset + 200;
    _thumbnailsScrollController.animateTo(
      target.clamp(0.0, _thumbnailsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onTransformChanged(int pageIndex) {
    final controller = _transformationControllers[pageIndex];
    if (controller == null) return;

    final currentScale = controller.value.getMaxScaleOnAxis();
    final shouldPan = currentScale > 1.0;

    if (shouldPan != _isPanEnabled[pageIndex]) {
      setState(() {
        _isPanEnabled[pageIndex] = shouldPan;
      });
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });

    final controller = _transformationControllers[page];
    if (controller != null) {
      controller.value = Matrix4.identity();
      _isPanEnabled[page] = false;
    }

    _scrollToCurrentPhoto();
  }

  Future<void> _downloadPhoto() async {
    if (widget.attach == null) return;

    try {
      final downloadDir = await DownloadPathHelper.getDownloadDirectory();

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('Downloads directory not found');
      }

      final url = widget.attach!['url'] ?? widget.attach!['baseUrl'];
      if (url == null || url.isEmpty) {
        throw Exception('Photo URL not found');
      }

      String extension = 'jpg';
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(lastSegment);
        if (extMatch != null) {
          extension = extMatch.group(1)!;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.$extension';
      final filePath = '${downloadDir.path}/$fileName';
      final file = io.File(filePath);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        final prefs = await SharedPreferences.getInstance();
        final List<String> downloadedFiles =
            prefs.getStringList('downloaded_files') ?? [];
        if (!downloadedFiles.contains(filePath)) {
          downloadedFiles.add(filePath);
          await prefs.setStringList('downloaded_files', downloadedFiles);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Фото сохранено: $fileName'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to download photo: ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при скачивании фото: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildPhotoWidget(Map<String, dynamic> photo) {
    final url = photo['url'] ?? photo['baseUrl'];
    if (url == null) return const SizedBox();

    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.error, color: Colors.white, size: 48),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (widget.allPhotos != null && widget.allPhotos!.isNotEmpty)
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.allPhotos!.length,
              itemBuilder: (context, index) {
                final photo = widget.allPhotos![index];
                final controller = _transformationControllers[index];

                return GestureDetector(
                  onTap: () {
                    final scale = controller?.value.getMaxScaleOnAxis() ?? 1.0;
                    if (scale <= 1.1) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: InteractiveViewer(
                    transformationController: controller,
                    panEnabled: _isPanEnabled[index] ?? false,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Center(child: _buildPhotoWidget(photo)),
                  ),
                );
              },
            )
          else
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
              },
              child: InteractiveViewer(
                transformationController: _transformationControllers[0],
                panEnabled: _isPanEnabled[0] ?? false,
                boundaryMargin: EdgeInsets.zero,
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(child: widget.imageChild),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  if (widget.attach != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.grey[900],
                      onSelected: (value) {
                        if (value == 'save') {
                          _downloadPhoto();
                        } else if (value == 'goto' &&
                            widget.onGoToMessage != null &&
                            widget.messageId != null) {
                          Navigator.of(context).pop();
                          widget.onGoToMessage!(widget.messageId!);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'save',
                          child: Row(
                            children: [
                              Icon(Icons.save, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Сохранить фото',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onGoToMessage != null &&
                            widget.messageId != null)
                          const PopupMenuItem(
                            value: 'goto',
                            child: Row(
                              children: [
                                Icon(Icons.message, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Перейти к сообщению',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (widget.allPhotos != null && widget.allPhotos!.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                color: Colors.black.withValues(alpha: 0.7),
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _thumbnailsScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 40,
                      ),
                      itemCount: widget.allPhotos!.length,
                      itemBuilder: (context, index) {
                        final photo = widget.allPhotos![index];
                        final isCurrent = index == _currentPage;
                        return GestureDetector(
                          onTap: () {
                            if (widget.onOpenGallery != null) {
                              Navigator.of(context).pop();
                              widget.onOpenGallery!(
                                context,
                                widget.allPhotos!,
                                index,
                              );
                            } else {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              border: isCurrent
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildThumbnail(photo),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_showLeftArrow)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _scrollLeft,
                          ),
                        ),
                      ),
                    if (_showRightArrow)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _scrollRight,
                          ),
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

  Widget _buildThumbnail(Map<String, dynamic> attach) {
    final url = attach['url'] ?? attach['baseUrl'];
    final preview = attach['previewData'];

    if (url is String && url.isNotEmpty) {
      String thumbnailUrl = url;
      if (!url.contains('?')) {
        thumbnailUrl = '$url?size=small&quality=medium';
      } else {
        thumbnailUrl = '$url&size=small&quality=medium';
      }
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[800],
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    } else if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          final bytes = base64Decode(b64);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
    }
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}

class FullScreenPhotoGallery extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  final Function(String)? onGoToMessage;
  final List<String>? messageIds;

  const FullScreenPhotoGallery({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onGoToMessage,
    this.messageIds,
  });

  @override
  State<FullScreenPhotoGallery> createState() => _FullScreenPhotoGalleryState();
}

class _FullScreenPhotoGalleryState extends State<FullScreenPhotoGallery> {
  late PageController _pageController;
  late ScrollController _thumbnailsScrollController;
  late int _currentIndex;
  bool _showControls = true;
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailsScrollController = ScrollController();
    _thumbnailsScrollController.addListener(_updateArrowsVisibility);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailsToCurrent();
      _updateArrowsVisibility();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailsScrollController.removeListener(_updateArrowsVisibility);
    _thumbnailsScrollController.dispose();
    super.dispose();
  }

  void _updateArrowsVisibility() {
    if (!_thumbnailsScrollController.hasClients) {
      setState(() {
        _showLeftArrow = false;
        _showRightArrow = false;
      });
      return;
    }

    final position = _thumbnailsScrollController.position;
    setState(() {
      _showLeftArrow = position.pixels > 0;
      _showRightArrow = position.pixels < position.maxScrollExtent;
    });
  }

  void _scrollLeft() {
    if (!_thumbnailsScrollController.hasClients) return;
    const itemSpacing = 60.0 + 12.0;
    final target = _thumbnailsScrollController.offset - (itemSpacing * 3);
    _thumbnailsScrollController.animateTo(
      target.clamp(0.0, _thumbnailsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    if (!_thumbnailsScrollController.hasClients) return;
    const itemSpacing = 60.0 + 12.0;
    final target = _thumbnailsScrollController.offset + (itemSpacing * 3);
    _thumbnailsScrollController.animateTo(
      target.clamp(0.0, _thumbnailsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollThumbnailsToCurrent() {
    if (_thumbnailsScrollController.hasClients && widget.photos.length > 1) {
      const normalWidth = 60.0;
      const currentWidth = 80.0;
      const margin = 6.0;

      final screenWidth = MediaQuery.of(context).size.width;

      double startPosition = 0.0;
      for (int i = 0; i < _currentIndex; i++) {
        startPosition += normalWidth + (margin * 2);
      }

      final currentCenter = startPosition + (currentWidth / 2);
      final targetOffset = currentCenter - (screenWidth / 2);

      _thumbnailsScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _thumbnailsScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildPhotoWidget(Map<String, dynamic> attach) {
    final url = attach['url'] ?? attach['baseUrl'];
    final preview = attach['previewData'];

    Widget child;
    if (url is String && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        child = Image.file(
          File(path),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      } else {
        String fullQualityUrl = url;
        if (!url.contains('?')) {
          fullQualityUrl = '$url?size=original&quality=high&format=original';
        } else {
          fullQualityUrl = '$url&size=original&quality=high&format=original';
        }
        child = Image.network(
          fullQualityUrl,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _imagePlaceholder();
          },
        );
      }
    } else if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          final bytes = base64Decode(b64);
          child = Image.memory(bytes, fit: BoxFit.contain);
        } catch (_) {
          child = _imagePlaceholder();
        }
      } else {
        child = _imagePlaceholder();
      }
    } else {
      child = _imagePlaceholder();
    }

    return InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: child);
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 64,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Future<void> _downloadPhoto() async {
    if (_currentIndex < 0 || _currentIndex >= widget.photos.length) return;

    final attach = widget.photos[_currentIndex];

    try {
      final downloadDir = await DownloadPathHelper.getDownloadDirectory();

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('Downloads directory not found');
      }

      final url = attach['url'] ?? attach['baseUrl'];
      if (url == null || url.isEmpty) {
        throw Exception('Photo URL not found');
      }

      String extension = 'jpg';
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(lastSegment);
        if (extMatch != null) {
          extension = extMatch.group(1)!;
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.$extension';
      final filePath = '${downloadDir.path}/$fileName';
      final file = io.File(filePath);

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        final prefs = await SharedPreferences.getInstance();
        final List<String> downloadedFiles =
            prefs.getStringList('downloaded_files') ?? [];
        if (!downloadedFiles.contains(filePath)) {
          downloadedFiles.add(filePath);
          await prefs.setStringList('downloaded_files', downloadedFiles);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Фото сохранено: $fileName'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Failed to download photo: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при скачивании фото: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });

              _scrollThumbnailsToCurrent();
              _updateArrowsVisibility();
            },
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                  });
                },
                child: Center(child: _buildPhotoWidget(widget.photos[index])),
              );
            },
          ),

          if (_showControls)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

          if (_showControls)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.photos.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.photos.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    if (widget.photos.length > 1) const SizedBox(height: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                      color: Colors.grey[900],
                      onSelected: (value) {
                        if (value == 'save') {
                          _downloadPhoto();
                        } else if (value == 'goto' &&
                            widget.onGoToMessage != null &&
                            widget.messageIds != null &&
                            _currentIndex < widget.messageIds!.length) {
                          Navigator.of(context).pop();
                          widget.onGoToMessage!(
                            widget.messageIds![_currentIndex],
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'save',
                          child: Row(
                            children: [
                              Icon(Icons.save, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Сохранить фото',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onGoToMessage != null &&
                            widget.messageIds != null &&
                            _currentIndex < widget.messageIds!.length)
                          const PopupMenuItem(
                            value: 'goto',
                            child: Row(
                              children: [
                                Icon(Icons.message, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Перейти к сообщению',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (_showControls && widget.photos.length > 1)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: _buildThumbnailsList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnailsList() {
    return Stack(
      children: [
        ListView.builder(
          controller: _thumbnailsScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          itemCount: widget.photos.length,
          itemBuilder: (context, index) {
            final isCurrent = index == _currentIndex;
            final attach = widget.photos[index];
            final url = attach['url'] ?? attach['baseUrl'];
            final preview = attach['previewData'];

            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: isCurrent ? 80 : 60,
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    width: isCurrent ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: _buildThumbnailImage(url, preview),
                ),
              ),
            );
          },
        ),
        if (_showLeftArrow)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _scrollLeft,
              ),
            ),
          ),
        if (_showRightArrow)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _scrollRight,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailImage(dynamic url, dynamic preview) {
    if (url is String && url.isNotEmpty) {
      String thumbnailUrl = url;
      if (!url.startsWith('file://')) {
        if (!url.contains('?')) {
          thumbnailUrl = '$url?size=small&quality=medium';
        } else {
          thumbnailUrl = '$url&size=small&quality=medium';
        }
      }

      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } else {
        return Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[800],
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[800],
              child: const Icon(Icons.image, color: Colors.grey, size: 24),
            );
          },
        );
      }
    } else if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        } catch (_) {
          return _thumbnailPlaceholder();
        }
      }
    }
    return _thumbnailPlaceholder();
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.image, color: Colors.grey, size: 24),
    );
  }
}

class _RotatingIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const _RotatingIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final int duration;
  final String durationText;
  final String wave;
  final int audioId;
  final Color textColor;
  final BorderRadius borderRadius;
  final double messageTextOpacity;

  const _AudioPlayerWidget({
    required this.url,
    required this.duration,
    required this.durationText,
    required this.wave,
    required this.audioId,
    required this.textColor,
    required this.borderRadius,
    required this.messageTextOpacity,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isCompleted = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<int>? _waveformData;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(milliseconds: widget.duration);

    if (widget.wave.isNotEmpty) {
      _decodeWaveform(widget.wave);
    }

    if (widget.url.isNotEmpty) {
      _preCacheAudio();
    }

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        final wasCompleted = _isCompleted;
        setState(() {
          _isPlaying = state.playing;
          _isLoading =
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          _isCompleted = state.processingState == ProcessingState.completed;
        });

        if (state.processingState == ProcessingState.completed &&
            !wasCompleted) {
          _audioPlayer.pause();
        }
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        final reachedEnd =
            _totalDuration.inMilliseconds > 0 &&
            position.inMilliseconds >= _totalDuration.inMilliseconds - 50 &&
            _isPlaying;

        if (reachedEnd) {
          _audioPlayer.pause();
        }

        setState(() {
          _position = position;
          if (reachedEnd) {
            _isPlaying = false;
            _isCompleted = true;
          }
        });
      }
    });

    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null && duration.inMilliseconds > 0) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  void _decodeWaveform(String waveBase64) {
    try {
      String base64Data = waveBase64;
      if (waveBase64.contains(',')) {
        base64Data = waveBase64.split(',')[1];
      }

      final bytes = base64Decode(base64Data);
      _waveformData = bytes.toList();
    } catch (e) {
      print('Error decoding waveform: $e');
      _waveformData = null;
    }
  }

  Future<void> _preCacheAudio() async {
    try {
      final cacheService = CacheService();
      final hasCached = await cacheService.hasCachedAudioFile(
        widget.url,
        customKey: widget.audioId.toString(),
      );
      if (!hasCached) {
        print('Pre-caching audio: ${widget.url}');
        final cachedPath = await cacheService.cacheAudioFile(
          widget.url,
          customKey: widget.audioId.toString(),
        );
        if (cachedPath != null) {
          print('Audio pre-cached successfully: $cachedPath');
        } else {
          print('Failed to pre-cache audio (no internet?): ${widget.url}');
        }
      } else {
        print('Audio already cached: ${widget.url}');
      }
    } catch (e) {
      print('Error pre-caching audio: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      } else {
        if (_isCompleted ||
            (_totalDuration.inMilliseconds > 0 &&
                _position.inMilliseconds >=
                    _totalDuration.inMilliseconds - 100)) {
          await _audioPlayer.stop();
          await _audioPlayer.seek(Duration.zero);
          if (mounted) {
            setState(() {
              _isCompleted = false;
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
          await Future.delayed(const Duration(milliseconds: 150));
        }

        if (_audioPlayer.processingState == ProcessingState.idle) {
          if (widget.url.isNotEmpty) {
            final cacheService = CacheService();
            var cachedFile = await cacheService.getCachedAudioFile(
              widget.url,
              customKey: widget.audioId.toString(),
            );

            if (cachedFile != null && await cachedFile.exists()) {
              print('Using cached audio file: ${cachedFile.path}');
              await _audioPlayer.setFilePath(cachedFile.path);
            } else {
              print('Audio not cached, checking if already downloading...');
              final hasCached = await cacheService.hasCachedAudioFile(
                widget.url,
                customKey: widget.audioId.toString(),
              );

              if (!hasCached) {
                print('Audio not cached, playing from URL: ${widget.url}');
                try {
                  await _audioPlayer.setUrl(widget.url);

                  cacheService
                      .cacheAudioFile(
                        widget.url,
                        customKey: widget.audioId.toString(),
                      )
                      .then((cachedPath) {
                        if (cachedPath != null) {
                          print('Audio cached in background: $cachedPath');
                        } else {
                          print('Failed to cache audio in background');
                        }
                      })
                      .catchError((e) {
                        print('Error caching audio in background: $e');
                      });
                } catch (e) {
                  print('Error setting audio URL: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Не удалось загрузить аудио: ${e.toString()}',
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
              } else {
                print('Audio is being cached, playing from URL: ${widget.url}');
                await _audioPlayer.setUrl(widget.url);
              }
            }
          }
        }
        await _audioPlayer.play();
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _seek(Duration position) async {
    if (_audioPlayer.processingState == ProcessingState.idle) {
      if (widget.url.isNotEmpty) {
        final cacheService = CacheService();
        var cachedFile = await cacheService.getCachedAudioFile(
          widget.url,
          customKey: widget.audioId.toString(),
        );

        if (cachedFile != null && await cachedFile.exists()) {
          await _audioPlayer.setFilePath(cachedFile.path);
        } else {
          await _audioPlayer.setUrl(widget.url);
        }
      }
    }
    await _audioPlayer.seek(position);
    if (mounted) {
      setState(() {
        _isCompleted = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inMilliseconds > 0
        ? _position.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onLongPress: () {},
      child: Container(
        decoration: BoxDecoration(
          color: widget.textColor.withValues(alpha: 0.05),
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: widget.textColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),

        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.textColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: widget.textColor.withValues(
                            alpha: 0.8 * widget.messageTextOpacity,
                          ),
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_waveformData != null && _waveformData!.isNotEmpty)
                      SizedBox(
                        height: 30,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            waveform: _waveformData!,
                            progress: progress,
                            color: widget.textColor.withValues(
                              alpha: 0.6 * widget.messageTextOpacity,
                            ),
                            progressColor: widget.textColor.withValues(
                              alpha: 0.9 * widget.messageTextOpacity,
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final tapProgress =
                                      details.localPosition.dx /
                                      constraints.maxWidth;
                                  final clampedProgress = tapProgress.clamp(
                                    0.0,
                                    1.0,
                                  );
                                  final newPosition = Duration(
                                    milliseconds:
                                        (_totalDuration.inMilliseconds *
                                                clampedProgress)
                                            .round(),
                                  );
                                  _seek(newPosition);
                                },
                                onLongPress: () {},
                              );
                            },
                          ),
                        ),
                      )
                    else
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: widget.textColor.withValues(
                            alpha: 0.8 * widget.messageTextOpacity,
                          ),
                          inactiveTrackColor: widget.textColor.withValues(
                            alpha: 0.1,
                          ),
                          thumbColor: widget.textColor.withValues(
                            alpha: 0.9 * widget.messageTextOpacity,
                          ),
                          overlayColor: widget.textColor.withValues(alpha: 0.1),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: progress.clamp(0.0, 1.0),
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (_totalDuration.inMilliseconds * value)
                                      .round(),
                            );
                            _seek(newPosition);
                          },
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: TextStyle(
                            color: widget.textColor.withValues(
                              alpha: 0.7 * widget.messageTextOpacity,
                            ),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _totalDuration.inMilliseconds > 0
                              ? _formatDuration(_totalDuration)
                              : widget.durationText,
                          style: TextStyle(
                            color: widget.textColor.withValues(
                              alpha: 0.7 * widget.messageTextOpacity,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<int> waveform;
  final double progress;
  final Color color;
  final Color progressColor;

  _WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.color,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / waveform.length;
    final maxAmplitude = waveform.reduce((a, b) => a > b ? a : b).toDouble();

    for (int i = 0; i < waveform.length; i++) {
      final amplitude = waveform[i].toDouble();
      final normalizedAmplitude = maxAmplitude > 0
          ? amplitude / maxAmplitude
          : 0.0;
      final barHeight = normalizedAmplitude * size.height * 0.8;
      final x = i * barWidth + barWidth / 2;
      final isPlayed = i / waveform.length < progress;

      paint.color = isPlayed ? progressColor : color;

      canvas.drawLine(
        Offset(x, size.height / 2 - barHeight / 2),
        Offset(x, size.height / 2 + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waveform != waveform;
  }
}

class _VideoCirclePlayer extends StatefulWidget {
  final int videoId;
  final String messageId;
  final int chatId;
  final String? highQualityUrl;
  final Uint8List? lowQualityBytes;

  const _VideoCirclePlayer({
    required this.videoId,
    required this.messageId,
    required this.chatId,
    this.highQualityUrl,
    this.lowQualityBytes,
  });

  @override
  State<_VideoCirclePlayer> createState() => _VideoCirclePlayerState();
}

class _VideoCirclePlayerState extends State<_VideoCirclePlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isUserTapped = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final videoUrl = await ApiService.instance.getVideoUrl(
        widget.videoId,
        widget.chatId,
        widget.messageId,
      );

      if (!mounted) return;

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      );

      await _controller!.initialize();

      if (!mounted) return;

      _controller!.setLooping(true);
      _controller!.setVolume(0.0);
      _controller!.play();

      setState(() {
        _isLoading = false;
        _isPlaying = true;
        _isUserTapped = false;
      });
    } catch (e) {
      print('❌ [VideoCirclePlayer] Error loading video: $e');
      if (e is UnimplementedError &&
          e.message?.contains('init() has not been implemented') == true) {
        print(
          '⚠️ [VideoCirclePlayer] Video playback not supported on this platform',
        );
      }
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !_isUserTapped) return;

    if (_controller!.value.position >= _controller!.value.duration &&
        _controller!.value.duration > Duration.zero) {
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    if (!_isUserTapped) {
      _controller!.addListener(_videoListener);
      _controller!.setLooping(false);
      _controller!.setVolume(1.0);

      _controller!.seekTo(Duration.zero);

      setState(() {
        _isUserTapped = true;
        _isPlaying = true;
      });

      _controller!.play();
      return;
    }

    if (_isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (_controller!.value.position >= _controller!.value.duration) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: SizedBox(
        width: 200,
        height: 200,
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              if (_isLoading ||
                  _hasError ||
                  _controller == null ||
                  !_controller!.value.isInitialized)
                (widget.highQualityUrl != null &&
                            widget.highQualityUrl!.isNotEmpty) ||
                        (widget.lowQualityBytes != null)
                    ? _ProgressiveNetworkImage(
                        url: widget.highQualityUrl ?? '',
                        previewBytes: widget.lowQualityBytes,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        keepAlive: false,
                      )
                    : Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      )
              else
                VideoPlayer(_controller!),

              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),

              if (!_isLoading &&
                  !_hasError &&
                  _controller != null &&
                  _controller!.value.isInitialized)
                AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 0.8,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 50,
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

class _SinglePhotoWidget extends StatefulWidget {
  final Map<String, dynamic> photo;
  final double maxWidth;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const _SinglePhotoWidget({
    required this.photo,
    required this.maxWidth,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  State<_SinglePhotoWidget> createState() => _SinglePhotoWidgetState();
}

class _SinglePhotoWidgetState extends State<_SinglePhotoWidget> {
  double? _imageWidth;
  double? _imageHeight;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  @override
  void dispose() {
    _imageStreamListener = null;
    super.dispose();
  }

  void _loadImageDimensions() {
    final url = widget.photo['url'] ?? widget.photo['baseUrl'];
    if (url is String && url.isNotEmpty && !url.startsWith('file://')) {
      final imageProvider = NetworkImage(url);
      _imageStreamListener = ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        }
      }, onError: (_, __) {});
      imageProvider
          .resolve(const ImageConfiguration())
          .addListener(_imageStreamListener!);
    }
  }

  @override
  Widget build(BuildContext context) {
    double displayWidth = widget.maxWidth.clamp(150.0, 300.0);
    double displayHeight = 180.0;

    if (_imageWidth != null &&
        _imageHeight != null &&
        _imageWidth! > 0 &&
        _imageHeight! > 0) {
      final aspectRatio = _imageWidth! / _imageHeight!;

      if (_imageWidth! >= _imageHeight!) {
        displayWidth = widget.maxWidth.clamp(200.0, 300.0);
        displayHeight = displayWidth / aspectRatio;
        if (displayHeight > 400) {
          displayHeight = 400;
          displayWidth = displayHeight * aspectRatio;
        }
      } else {
        displayWidth = widget.maxWidth.clamp(150.0, 250.0);
        displayHeight = displayWidth / aspectRatio;
        if (displayHeight > 350) {
          displayHeight = 350;
          displayWidth = displayHeight * aspectRatio;
        }
      }
    }

    if (displayHeight > 350) {
      displayHeight = 350;
      if (_imageWidth != null &&
          _imageHeight != null &&
          _imageWidth! > 0 &&
          _imageHeight! > 0) {
        final aspectRatio = _imageWidth! / _imageHeight!;
        displayWidth = displayHeight * aspectRatio;
      }
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: SizedBox(
          width: displayWidth,
          height: displayHeight,
          child: _buildPhotoWidgetForSingle(
            context,
            widget.photo,
            displayWidth,
            displayHeight,
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoWidgetForSingle(
    BuildContext context,
    Map<String, dynamic> attach,
    double width,
    double height,
  ) {
    Uint8List? previewBytes;
    final preview = attach['previewData'];
    if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          previewBytes = base64Decode(b64);
        } catch (_) {}
      }
    }

    final url = attach['url'] ?? attach['baseUrl'];
    if (url is String && url.isNotEmpty) {
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          width: width,
          height: height,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _imagePlaceholder(),
        );
      }

      String previewQualityUrl = url;
      if (!url.contains('?')) {
        previewQualityUrl = '$url?size=medium&quality=high&format=jpeg';
      } else {
        previewQualityUrl = '$url&size=medium&quality=high&format=jpeg';
      }

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final optimize =
          themeProvider.optimizeChats || themeProvider.ultraOptimizeChats;

      return _ProgressiveNetworkImage(
        key: ValueKey(previewQualityUrl),
        url: previewQualityUrl,
        previewBytes: previewBytes,
        width: width,
        height: height,
        fit: BoxFit.contain,
        keepAlive: !optimize,
        startDownloadNextFrame: false,
      );
    }

    if (previewBytes != null) {
      return Image.memory(
        previewBytes,
        fit: BoxFit.contain,
        width: width,
        height: height,
      );
    }

    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 220,
      height: 160,
      color: Colors.grey[300],
      child: const Icon(Icons.image_outlined, color: Colors.black38),
    );
  }
}
