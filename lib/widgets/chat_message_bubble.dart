import 'package:flutter/material.dart';
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

bool _currentIsDark = false;

bool isMobile =
    Platform.instance.operatingSystem.iOS ||
    Platform.instance.operatingSystem.android;

enum MessageReadStatus {
  sending, // Отправляется (часы)
  sent, // Отправлено (1 галочка)
  read, // Прочитано (2 галочки)
}

// Service для отслеживания прогресса загрузки файлов
class FileDownloadProgressService {
  static final FileDownloadProgressService _instance =
      FileDownloadProgressService._internal();
  factory FileDownloadProgressService() => _instance;
  FileDownloadProgressService._internal();

  final Map<String, ValueNotifier<double>> _progressNotifiers = {};
  bool _initialized = false;

  // Initialize on first access to load saved download status
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load fileId -> filePath mappings
      final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];

      // Mark all downloaded files as completed (progress = 1.0)
      for (final mapping in fileIdMap) {
        final parts = mapping.split(':');
        if (parts.length >= 2) {
          final fileId = parts[0];
          final filePath = parts.skip(1).join(':'); // In case path contains ':'

          final file = io.File(filePath);
          if (await file.exists()) {
            if (!_progressNotifiers.containsKey(fileId)) {
              _progressNotifiers[fileId] = ValueNotifier<double>(1.0);
            } else {
              _progressNotifiers[fileId]!.value = 1.0;
            }
          }
        }
      }

      _initialized = true;
    } catch (e) {
      print('Error initializing download status: $e');
      _initialized = true; // Mark as initialized to avoid retrying indefinitely
    }
  }

  ValueNotifier<double> getProgress(String fileId) {
    _ensureInitialized(); // Ensure initialization
    if (!_progressNotifiers.containsKey(fileId)) {
      _progressNotifiers[fileId] = ValueNotifier<double>(-1);
    }
    return _progressNotifiers[fileId]!;
  }

  void updateProgress(String fileId, double progress) {
    if (!_progressNotifiers.containsKey(fileId)) {
      _progressNotifiers[fileId] = ValueNotifier<double>(progress);
    } else {
      _progressNotifiers[fileId]!.value = progress;
    }
  }

  void clearProgress(String fileId) {
    _progressNotifiers.remove(fileId);
  }
}

Color _getUserColor(int userId, BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  if (isDark != _currentIsDark) {
    _currentIsDark = isDark;
  }

  final List<Color> materialYouColors = isDark
      ? [
          // Темная тема
          const Color(0xFFEF5350), // Красный
          const Color(0xFFEC407A), // Розовый
          const Color(0xFFAB47BC), // Фиолетовый
          const Color(0xFF7E57C2), // Глубокий фиолетовый
          const Color(0xFF5C6BC0), // Индиго
          const Color(0xFF42A5F5), // Синий
          const Color(0xFF29B6F6), // Голубой
          const Color(0xFF26C6DA), // Бирюзовый
          const Color(0xFF26A69A), // Теal
          const Color(0xFF66BB6A), // Зеленый
          const Color(0xFF9CCC65), // Светло-зеленый
          const Color(0xFFD4E157), // Лаймовый
          const Color(0xFFFFEB3B), // Желтый
          const Color(0xFFFFCA28), // Янтарный
          const Color(0xFFFFA726), // Оранжевый
          const Color(0xFFFF7043), // Глубокий оранжевый
          const Color(0xFF8D6E63), // Коричневый
          const Color(0xFF78909C), // Сине-серый
          const Color(0xFFB39DDB), // Лавандовый
          const Color(0xFF80CBC4), // Аквамариновый
          const Color(0xFFC5E1A5), // Светло-зеленый пастельный
        ]
      : [
          // Светлая тема
          const Color(0xFFF44336), // Красный
          const Color(0xFFE91E63), // Розовый
          const Color(0xFF9C27B0), // Фиолетовый
          const Color(0xFF673AB7), // Глубокий фиолетовый
          const Color(0xFF3F51B5), // Индиго
          const Color(0xFF2196F3), // Синий
          const Color(0xFF03A9F4), // Голубой
          const Color(0xFF00BCD4), // Бирюзовый
          const Color(0xFF009688), // Теal
          const Color(0xFF4CAF50), // Зеленый
          const Color(0xFF8BC34A), // Светло-зеленый
          const Color(0xFFCDDC39), // Лаймовый
          const Color(0xFFFFEE58), // Желтый
          const Color(0xFFFFC107), // Янтарный
          const Color(0xFFFF9800), // Оранжевый
          const Color(0xFFFF5722), // Глубокий оранжевый
          const Color(0xFF795548), // Коричневый
          const Color(0xFF607D8B), // Сине-серый
          const Color(0xFF9575CD), // Лавандовый
          const Color(0xFF4DB6AC), // Бирюзовый светлый
          const Color(0xFFAED581), // Зеленый пастельный
        ];

  final colorIndex = userId % materialYouColors.length;
  final color = materialYouColors[colorIndex];

  return color;
}

class _KometColoredSegment {
  final String text;
  final Color? color;

  _KometColoredSegment(this.text, this.color);
}

enum _KometSegmentType {
  normal,
  colored,
  galaxy,
  pulse,
}

class _KometSegment {
  final String text;
  final _KometSegmentType type;
  final Color? color; // Для colored и pulse

  _KometSegment(this.text, this.type, {this.color});
}

class _GalaxyAnimatedText extends StatefulWidget {
  final String text;

  const _GalaxyAnimatedText({required this.text});

  @override
  State<_GalaxyAnimatedText> createState() => _GalaxyAnimatedTextState();
}

class _GalaxyAnimatedTextState extends State<_GalaxyAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final color = Color.lerp(Colors.black, Colors.white, t)!;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                Color.lerp(Colors.white, Colors.black, t)!,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}

class _PulseAnimatedText extends StatefulWidget {
  final String text;

  const _PulseAnimatedText({required this.text});

  @override
  State<_PulseAnimatedText> createState() => _PulseAnimatedTextState();
}

class _PulseAnimatedTextState extends State<_PulseAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Color? _pulseColor;

  @override
  void initState() {
    super.initState();
    _parseColor();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _parseColor() {
    final text = widget.text;
    const prefix = "komet.cosmetic.pulse#";
    if (!text.startsWith(prefix)) {
      _pulseColor = Colors.red;
      return;
    }

    final afterHash = text.substring(prefix.length);
    final quoteIndex = afterHash.indexOf("'");
    if (quoteIndex == -1) {
      _pulseColor = Colors.red;
      return;
    }

    final hexStr = afterHash.substring(0, quoteIndex).trim();
    _pulseColor = _parseHexColor(hexStr);
  }

  Color _parseHexColor(String hex) {
    String hexClean = hex.trim();
    if (hexClean.startsWith('#')) {
      hexClean = hexClean.substring(1);
    }
    if (hexClean.length == 6) {
      try {
        return Color(int.parse('FF$hexClean', radix: 16));
      } catch (e) {
        return Colors.red;
      }
    }
    return Colors.red;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    const prefix = "komet.cosmetic.pulse#";
    if (!text.startsWith(prefix) || !text.endsWith("'")) {
      return Text(text);
    }
    
    final afterHash = text.substring(prefix.length);
    final quoteIndex = afterHash.indexOf("'");
    if (quoteIndex == -1 || quoteIndex + 1 >= afterHash.length) {
      return Text(text);
    }

    final messageText = afterHash.substring(quoteIndex + 1, afterHash.length - 1);
    final baseColor = _pulseColor ?? Colors.red;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final opacity = 0.5 + (t * 0.5);
        final color = baseColor.withOpacity(opacity);

        return Text(
          messageText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
      },
    );
  }
}

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
    this.avatarVerticalOffset =
        -35.0, // выше ниже аватарку бля как хотите я жрать хочу
    this.chatId,
    this.isEncryptionPasswordSet = false,
    this.decryptedText,
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
      return const EdgeInsets.only(bottom: 12);
    }
    if (isFirstInGroup) {
      return const EdgeInsets.only(bottom: 3);
    }
    return const EdgeInsets.only(bottom: 3);
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.08 * messageTextOpacity),
        border: Border(
          left: BorderSide(
            color: textColor.withOpacity(0.3 * messageTextOpacity),
            width: 3, // Делаем рамку жирнее для отличия от ответа
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Заголовок" с именем автора и аватаркой
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forward,
                size: 14,
                color: textColor.withOpacity(0.6 * messageTextOpacity),
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
                      color: textColor.withOpacity(0.2 * messageTextOpacity),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      forwardedSenderAvatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: textColor.withOpacity(
                            0.1 * messageTextOpacity,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 12,
                            color: textColor.withOpacity(
                              0.5 * messageTextOpacity,
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
                    color: textColor.withOpacity(0.1 * messageTextOpacity),
                    border: Border.all(
                      color: textColor.withOpacity(0.2 * messageTextOpacity),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 12,
                    color: textColor.withOpacity(0.5 * messageTextOpacity),
                  ),
                ),
              Flexible(
                child: Text(
                  forwardedSenderName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor.withOpacity(0.9 * messageTextOpacity),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Содержимое пересланного сообщения (фото и/или текст)
          if (attaches.isNotEmpty) ...[
            ..._buildPhotosWithCaption(
              context,
              attaches, // Передаем вложения из вложенного сообщения
              textColor,
              isUltraOptimized,
              messageTextOpacity,
            ),
            const SizedBox(height: 6),
          ],
          if (text.isNotEmpty)
            Text(
              text,
              style: TextStyle(
                color: textColor.withOpacity(0.9 * messageTextOpacity),
                fontSize: 14,
              ),
            ),
        ],
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
  }) {
    // Логика открытия плеера
    void openFullScreenVideo() async {
      // Показываем индикатор загрузки, пока получаем URL
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final videoUrl = await ApiService.instance.getVideoUrl(
          videoId,
          chatId!, // chatId из `build`
          messageId,
        );

        if (!context.mounted) return; // [!code ++] Проверка правильным способом
        Navigator.pop(context); // Убираем индикатор
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      } catch (e) {
        if (!context.mounted) return; // [!code ++] Проверка правильным способом
        Navigator.pop(context); // Убираем индикатор
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

    return GestureDetector(
      onTap: openFullScreenVideo,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              // Если у нас есть ХОТЬ ЧТО-ТО (блюр или URL), показываем ProgressiveImage
              (highQualityUrl != null && highQualityUrl.isNotEmpty) ||
                      (lowQualityBytes != null)
                  ? _ProgressiveNetworkImage(
                      url: highQualityUrl ?? '',
                      previewBytes: lowQualityBytes,
                      width: 220,
                      height: 160,
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
                    ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.play_circle_filled_outlined,
                  color: Colors.white.withOpacity(0.95),
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
    final replyMessageId = replyMessage['id'] as String?;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color replyAccentColor;
    if (useAutoReplyColor) {
      replyAccentColor = _getUserColor(replySenderId ?? 0, context);
    } else {
      replyAccentColor =
          customReplyColor ??
          (isDarkMode ? const Color(0xFF90CAF9) : const Color(0xFF1976D2));
    }

    // Вычисляем оптимальную ширину на основе длины текста
    final textLength = replyText.length;
    final minWidth = 120.0; // Минимальная ширина для коротких сообщений

    // Адаптивная ширина: минимум 120px, растет в зависимости от длины текста
    double adaptiveWidth = minWidth;
    if (textLength > 0) {
      // Базовый расчет: примерно 8px на символ + отступы
      adaptiveWidth = (textLength * 8.0 + 32).clamp(minWidth, double.infinity);
    }

    return GestureDetector(
      onTap: () {
        // Вызываем callback для прокрутки к оригинальному сообщению
        if (replyMessageId != null && onReplyTap != null) {
          onReplyTap!(replyMessageId);
        }
      },
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: 40),
        width: adaptiveWidth, // Используем адаптивную ширину
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode
              ? replyAccentColor.withOpacity(
                  0.15,
                ) // Полупрозрачный фон для темной темы
              : replyAccentColor.withOpacity(
                  0.08,
                ), // Более прозрачный для светлой
          borderRadius: BorderRadius.circular(
            (isUltraOptimized ? 4 : messageBorderRadius) * 0.3,
          ),
          border: Border(
            left: BorderSide(
              color: replyAccentColor, // Цвет левой границы
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ник автора сообщения
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
            // Текст сообщения
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
  /*
  void _showMessageContextMenu(BuildContext context) {
    // Список реакций, отсортированный по популярности
    const reactions = [
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

    // Проверяем, есть ли уже реакция от пользователя
    final hasUserReaction =
        message.reactionInfo != null &&
        message.reactionInfo!['yourReaction'] != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors
          .transparent, // Фон делаем прозрачным, чтобы скругление было видно
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Реакции
              if (onReaction != null) ...[
                // Контейнер для прокручиваемого списка эмодзи
                SizedBox(
                  height: 80, // Задаем высоту для ряда с реакциями
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: [
                        ...reactions.map(
                          (emoji) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                onReaction!(emoji);
                              },
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Кнопка удаления реакции, если есть реакция от пользователя
                if (hasUserReaction && onRemoveReaction != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onRemoveReaction!();
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Убрать реакцию'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.errorContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const Divider(height: 1),
              ],
              // Действия с сообщением (остаются без изменений)
              if (onReply != null && !isChannel)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Ответить'),
                  onTap: () {
                    Navigator.pop(context);
                    onReply!();
                  },
                ),
              if (onEdit != null)
                ListTile(
                  leading: Icon(
                    canEditMessage == false ? Icons.edit_off : Icons.edit,
                    color: canEditMessage == false ? Colors.grey : null,
                  ),
                  title: Text(
                    canEditMessage == false
                        ? 'Редактировать (недоступно)'
                        : 'Редактировать',
                    style: TextStyle(
                      color: canEditMessage == false ? Colors.grey : null,
                    ),
                  ),
                  onTap: canEditMessage == false
                      ? null
                      : () {
                          Navigator.pop(context);
                          onEdit!();
                        },
                ),
              if (onDeleteForMe != null ||
                  onDeleteForAll != null ||
                  onDelete != null) ...[
                if (onEdit != null) const Divider(height: 1),
                if (onDeleteForMe != null)
                  ListTile(
                    leading: const Icon(
                      Icons.person_remove,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Удалить у меня',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onDeleteForMe?.call();
                    },
                  ),
                if (onDeleteForAll != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Удалить у всех',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onDeleteForAll?.call();
                    },
                  ),
                if (onDelete != null &&
                    onDeleteForMe == null &&
                    onDeleteForAll == null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text(
                      'Удалить',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onDelete!.call();
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  */

  void _showMessageContextMenu(BuildContext context, Offset tapPosition) {
    final hasUserReaction = message.reactionInfo?['yourReaction'] != null;

    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Делаем фон прозрачным
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
      padding: const EdgeInsets.only(top: 8.0),
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
                // Если это наша реакция - удаляем
                onRemoveReaction?.call();
              } else {
                // Если это чужая реакция - добавляем такую же
                onReaction?.call(emoji);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isUserReaction
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                    : textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$emoji $count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isUserReaction
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: isUserReaction
                      ? Theme.of(context).colorScheme.primary
                      : textColor.withOpacity(0.9),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

    final hasUnsupportedContent = _hasUnsupportedMessageTypes();

    final messageOpacity = themeProvider.messageBubbleOpacity;
    final messageTextOpacity = themeProvider.messageTextOpacity;
    final messageShadowIntensity = themeProvider.messageShadowIntensity;
    final messageBorderRadius = themeProvider.messageBorderRadius;

    // Сообщение только с файлами (без текста и без reply/forward)
    final isFileOnly =
        message.attaches.isNotEmpty &&
        message.attaches.every((a) => a['_type'] == 'FILE') &&
        message.text.isEmpty &&
        !message.isReply &&
        !message.isForwarded;

    final bubbleColor = _getBubbleColor(isMe, themeProvider, messageOpacity);
    final textColor = _getTextColor(
      isMe,
      bubbleColor,
      messageTextOpacity,
      context,
    );

    // Обычный пузырь, но для сообщений только с файлами делаем фон прозрачным,
    // чтобы визуально не было "бабла" вокруг карточек файлов.
    BoxDecoration bubbleDecoration;
    if (isFileOnly) {
      bubbleDecoration = const BoxDecoration(color: Colors.transparent);
    } else {
      bubbleDecoration = _createBubbleDecoration(
        bubbleColor,
        messageBorderRadius,
        messageShadowIntensity,
      );
    }

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

    Future<void> _onOpenLink(LinkableElement link) async {
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

    void _onSenderNameTap() {
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
      _onOpenLink,
      _onSenderNameTap,
    );

    Widget messageContent = _buildMessageContentInner(
      context,
      bubbleDecoration,
      messageContentChildren,
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        messageContent = GestureDetector(
          onTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: messageContent,
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
    // 1. Ищем вложение с клавиатурой
    final keyboardAttach = attaches.firstWhere(
      (a) => a['_type'] == 'INLINE_KEYBOARD',
      orElse: () =>
          <String, dynamic>{}, // Возвращаем пустую карту, если не найдено
    );

    if (keyboardAttach.isEmpty) {
      return []; // Нет клавиатуры
    }

    // 2. Парсим структуру кнопок
    final keyboardData = keyboardAttach['keyboard'] as Map<String, dynamic>?;
    final buttonRows = keyboardData?['buttons'] as List<dynamic>?;

    if (buttonRows == null || buttonRows.isEmpty) {
      return []; // Нет кнопок
    }

    final List<Widget> rows = [];

    // 3. Создаем виджеты для каждого ряда кнопок
    for (final row in buttonRows) {
      if (row is List<dynamic> && row.isNotEmpty) {
        final List<Widget> buttonsInRow = [];

        // 4. Создаем виджеты для каждой кнопки в ряду
        for (final buttonData in row) {
          if (buttonData is Map<String, dynamic>) {
            final String? text = buttonData['text'] as String?;
            final String? type = buttonData['type'] as String?;
            final String? url = buttonData['url'] as String?;

            // Нас интересуют только кнопки-ссылки (как в вашем JSON)
            if (text != null && type == 'LINK' && url != null) {
              buttonsInRow.add(
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: FilledButton(
                      onPressed: () =>
                          _launchURL(context, url), // Открываем ссылку
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        // Стилизуем под цвет сообщения
                        backgroundColor: textColor.withOpacity(0.1),
                        foregroundColor: textColor.withOpacity(0.9),
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

        // Добавляем готовый ряд кнопок
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

    // Возвращаем Column с рядами кнопок
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

  // Helper-метод для открытия ссылок
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
      return type == 'VOICE' ||
          type == 'GIF' ||
          type == 'LOCATION' ||
          type == 'CONTACT';
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
              //шлем в пезду аватарку если это я, анал.
              SizedBox(
                width: 40,
                child:
                    isLastInGroup //Если это соо в группе, и оно последнее в группе соо
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
                  vertical: 8,
                ),
                margin: _getMessageMargin(context),
                decoration: bubbleDecoration,
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Имя отправителя
                    if (isGroupChat && !isMe && senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
                        child: Text(
                          senderName!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getUserColor(
                              message.senderId,
                              context,
                            ).withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (isGroupChat && !isMe && senderName != null)
                      const SizedBox(height: 4),

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

                    const SizedBox(height: 8.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMe) ...[
                          if (message.isEdited) ...[
                            Text(
                              '(изменено)',
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withOpacity(0.5),
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
                                color: textColor.withOpacity(0.5),
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
                  padding: const EdgeInsets.only(top: 4, right: 6),
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
    final previewData = video['previewData'] as String?;
    final thumbnailUrl = video['url'] ?? video['baseUrl'] as String?;

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

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    Widget videoContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
                    padding: const EdgeInsets.only(top: 4, right: 6),
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
        videoContent = GestureDetector(
          onTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: videoContent,
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

  Widget _buildPhotoOnlyMessage(BuildContext context) {
    final photos = message.attaches
        .where((a) => a['_type'] == 'PHOTO')
        .toList();
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isUltraOptimized = themeProvider.ultraOptimizeChats;
    final messageOpacity = themeProvider.messageBubbleOpacity;
    final bubbleColor = _getBubbleColor(isMe, themeProvider, messageOpacity);
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
              Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _buildSmartPhotoGroup(
                    context,
                    photos,
                    textColor,
                    isUltraOptimized,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 6),
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
        photoContent = GestureDetector(
          onTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: photoContent,
        );
      } else {
        photoContent = GestureDetector(
          onTapDown: (TapDownDetails details) {
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

    final timeColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9bb5c7)
        : const Color(0xFF6b7280);

    Widget videoContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
            final previewData = video['previewData'] as String?;
            final thumbnailUrl = video['url'] ?? video['baseUrl'] as String?;

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
                    Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (videoId != null && chatId != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
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
                        if (index == videos.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 6),
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
                  ],
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );

    if (onReaction != null || (isMe && (onEdit != null || onDelete != null))) {
      if (isMobile) {
        videoContent = GestureDetector(
          onTapDown: (TapDownDetails details) {
            _showMessageContextMenu(context, details.globalPosition);
          },
          child: videoContent,
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

    // Умная группировка фотографий
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
      // 1. Извлекаем все, что нам нужно
      final videoId = video['videoId'] as int?;
      final videoType = video['videoType'] as int?;
      final previewData = video['previewData'] as String?; // Блюр-превью
      final thumbnailUrl =
          video['url'] ?? video['baseUrl'] as String?; // HQ-превью URL

      // 2. Декодируем блюр-превью
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

      // 3. Формируем URL для HQ-превью (как для фото)
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

      // 4. Создаем виджет
      if (videoId != null && chatId != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _buildVideoPreview(
              context: context,
              videoId: videoId,
              messageId: message.id,
              highQualityUrl: highQualityThumbnailUrl,
              lowQualityBytes: previewBytes,
              videoType: videoType,
            ),
          ),
        );
      } else {
        // Заглушка, если вложение есть, а ID не найдены
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
    // Стикеры обычно квадратные, около 200-250px
    final stickerSize = 170.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: stickerSize,
        maxHeight: stickerSize,
      ),
      child: GestureDetector(
        onTap: () => _openPhotoViewer(context, sticker),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isUltraOptimized ? 8 : 12),
          child: _buildPhotoWidget(context, sticker),
        ),
      ),
    );
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

    // Определяем текст, иконку и цвет в зависимости от типа завершения звонка
    switch (hangupType) {
      case 'HUNGUP':
        // Звонок был завершен успешно
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
        // Пропущенный звонок
        final callTypeText = callType == 'VIDEO'
            ? 'Пропущенный видеозвонок'
            : 'Пропущенный звонок';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_missed;
        callColor = Theme.of(context).colorScheme.error;
        break;

      case 'CANCELED':
        // Звонок отменен
        final callTypeText = callType == 'VIDEO'
            ? 'Видеозвонок отменен'
            : 'Звонок отменен';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_end;
        callColor = textColor.withOpacity(0.6);
        break;

      case 'REJECTED':
        // Звонок отклонен
        final callTypeText = callType == 'VIDEO'
            ? 'Видеозвонок отклонен'
            : 'Звонок отклонен';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_end;
        callColor = textColor.withOpacity(0.6);
        break;

      default:
        // Неизвестный тип завершения
        callText = callType == 'VIDEO' ? 'Видеозвонок' : 'Звонок';
        callIcon = callType == 'VIDEO' ? Icons.videocam : Icons.call;
        callColor = textColor.withOpacity(0.6);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: callColor.withOpacity(0.1),
        borderRadius: borderRadius,
        border: Border.all(color: callColor.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Call icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: callColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(callIcon, color: callColor, size: 24),
            ),
            const SizedBox(width: 12),
            // Call info
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

  Widget _buildFileWidget(
    BuildContext context,
    String fileName,
    int fileSize,
    Map<String, dynamic> fileData,
    Color textColor,
    bool isUltraOptimized,
    int? chatId,
  ) {
    final borderRadius = BorderRadius.circular(isUltraOptimized ? 8 : 12);

    // Get file extension
    final extension = _getFileExtension(fileName);
    final iconData = _getFileIcon(extension);

    // Format file size
    final sizeStr = _formatFileSize(fileSize);

    // Extract file data
    final fileId = fileData['fileId'] as int?;
    final token = fileData['token'] as String?;

    return GestureDetector(
      onTap: () =>
          _handleFileDownload(context, fileId, token, fileName, chatId),
      child: Container(
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.05),
          borderRadius: borderRadius,
          border: Border.all(color: textColor.withOpacity(0.1), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // File icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  iconData,
                  color: textColor.withOpacity(0.8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // File info with progress
              Expanded(
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
                      ValueListenableBuilder<double>(
                        valueListenable: FileDownloadProgressService()
                            .getProgress(fileId.toString()),
                        builder: (context, progress, child) {
                          if (progress < 0) {
                            // Not downloading
                            return Text(
                              sizeStr,
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            );
                          } else if (progress < 1.0) {
                            // Downloading
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: textColor.withOpacity(0.1),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Completed
                            return Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Загружено',
                                  style: TextStyle(
                                    color: Colors.green.withOpacity(0.8),
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
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Download icon
              if (fileId != null)
                ValueListenableBuilder<double>(
                  valueListenable: FileDownloadProgressService().getProgress(
                    fileId.toString(),
                  ),
                  builder: (context, progress, child) {
                    if (progress >= 0 && progress < 1.0) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Icon(
                      Icons.download_outlined,
                      color: textColor.withOpacity(0.6),
                      size: 20,
                    );
                  },
                )
              else
                Icon(
                  Icons.download_outlined,
                  color: textColor.withOpacity(0.6),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusicFileWidget(
    BuildContext context,
    String fileName,
    int fileSize,
    Map<String, dynamic> fileData,
    Color textColor,
    bool isUltraOptimized,
    int? chatId,
  ) {
    final borderRadius = BorderRadius.circular(isUltraOptimized ? 8 : 12);
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

    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
        final fileIdString = fileId?.toString();

        bool isDownloaded = false;
        String? filePath;

        if (fileIdString != null) {
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
          if (fileIdString != null) {
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
        }

        if (isDownloaded && filePath != null) {
          final track = MusicTrack(
            id:
                fileId?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
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
          musicMetadata[fileIdString ?? ''] = track.toJson();
          await prefs.setString('music_metadata', jsonEncode(musicMetadata));

          final musicPlayer = MusicPlayerService();
          await musicPlayer.playTrack(track);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: textColor.withOpacity(0.05),
          borderRadius: borderRadius,
          border: Border.all(color: textColor.withOpacity(0.1), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  color: textColor.withOpacity(0.1),
                  child: albumArtUrl != null
                      ? Image.network(
                          albumArtUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.music_note,
                            color: textColor.withOpacity(0.8),
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.music_note,
                          color: textColor.withOpacity(0.8),
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
                        color: textColor.withOpacity(0.7),
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
                          color: textColor.withOpacity(0.6),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (fileId != null)
                      ValueListenableBuilder<double>(
                        valueListenable: FileDownloadProgressService()
                            .getProgress(fileId.toString()),
                        builder: (context, progress, child) {
                          if (progress < 0) {
                            return Row(
                              children: [
                                if (durationText.isNotEmpty) ...[
                                  Text(
                                    durationText,
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  sizeStr,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          } else if (progress < 1.0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: textColor.withOpacity(0.1),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.6),
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
                                  color: Colors.green.withOpacity(0.8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Загружено',
                                  style: TextStyle(
                                    color: Colors.green.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      )
                    else
                      Row(
                        children: [
                          if (durationText.isNotEmpty) ...[
                            Text(
                              durationText,
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            sizeStr,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (fileId != null)
                ValueListenableBuilder<double>(
                  valueListenable: FileDownloadProgressService().getProgress(
                    fileId.toString(),
                  ),
                  builder: (context, progress, child) {
                    if (progress >= 0 && progress < 1.0) {
                      return const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return IconButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final fileIdMap =
                            prefs.getStringList('file_id_to_path_map') ?? [];
                        final fileIdString = fileId.toString();

                        bool isDownloaded = false;
                        String? filePath;

                        for (final mapping in fileIdMap) {
                          if (mapping.startsWith('$fileIdString:')) {
                            filePath = mapping.substring(
                              fileIdString.length + 1,
                            );
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
                              filePath = mapping.substring(
                                fileIdString.length + 1,
                              );
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

                          final musicMetadataJson =
                              prefs.getString('music_metadata') ?? '{}';
                          final musicMetadata =
                              jsonDecode(musicMetadataJson)
                                  as Map<String, dynamic>;
                          musicMetadata[fileIdString] = track.toJson();
                          await prefs.setString(
                            'music_metadata',
                            jsonEncode(musicMetadata),
                          );

                          final musicPlayer = MusicPlayerService();
                          await musicPlayer.playTrack(track);
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      style: IconButton.styleFrom(
                        backgroundColor: textColor.withOpacity(0.1),
                        foregroundColor: textColor,
                      ),
                    );
                  },
                )
              else
                IconButton(
                  onPressed: () async {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Не удалось загрузить файл'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: textColor.withOpacity(0.1),
                    foregroundColor: textColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  IconData _getFileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
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
    final wave = audioData['wave'] as String?;
    final audioId = audioData['audioId'] as int?;

    // Format duration
    final durationSeconds = (duration / 1000).round();
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return _AudioPlayerWidget(
      url: url ?? '',
      duration: duration,
      durationText: durationText,
      wave: wave,
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
    // 1. Проверяем fileId, он нужен в любом случае
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

      // Ищем запись для нашего fileId
      final mapping = fileIdMap.firstWhere(
        (m) => m.startsWith('$fileIdString:'),
        orElse: () => '', // Возвращаем пустую строку, если не найдено
      );

      if (mapping.isNotEmpty) {
        // Извлекаем путь из 'fileId:path/to/file'
        final filePath = mapping.substring(fileIdString.length + 1);
        final file = io.File(filePath);

        // Проверяем, существует ли файл физически
        if (await file.exists()) {
          print(
            'Файл $fileName (ID: $fileId) найден локально: $filePath. Открываем...',
          );
          // Файл существует, открываем его
          final result = await OpenFile.open(filePath);

          if (result.type != ResultType.done && context.mounted) {
            // Показываем ошибку, если не удалось открыть (например, нет приложения)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Не удалось открыть файл: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return; // Важно: выходим из функции, чтобы не скачивать заново
        } else {
          // Файл был в списке, но удален. Очистим некорректную запись.
          print(
            'Файл $fileName (ID: $fileId) был в SharedPreferences, но удален. Начинаем загрузку.',
          );
          fileIdMap.remove(mapping);
          await prefs.setStringList('file_id_to_path_map', fileIdMap);
        }
      }
    } catch (e) {
      print('Ошибка при проверке локального файла: $e. Продолжаем загрузку...');
      // Если при проверке что-то пошло не так, просто продолжаем и скачиваем файл.
    }

    // Если файл не найден локально, продолжаем стандартную процедуру скачивания
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
      // Request file URL from server using opcode 88
      final messageId = message.id;

      // Send request for file URL via WebSocket
      final seq = ApiService.instance.sendRawRequest(88, {
        "fileId": fileId,
        "chatId": chatId,
        "messageId": messageId,
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

      // Wait for response with opcode 88
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

      // Download file to Downloads folder with progress
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
    // Download in background without blocking dialog
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

    // Show immediate success snackbar
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
    // Initialize progress
    FileDownloadProgressService().updateProgress(fileId, 0.0);

    try {
      // Get Downloads directory
      io.Directory? downloadDir;

      if (io.Platform.isAndroid) {
        downloadDir = await getExternalStorageDirectory();
      } else if (io.Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        downloadDir = directory;
      } else if (io.Platform.isWindows || io.Platform.isLinux) {
        // For desktop platforms, use Downloads directory
        final homeDir =
            io.Platform.environment['HOME'] ??
            io.Platform.environment['USERPROFILE'] ??
            '';
        downloadDir = io.Directory('$homeDir/Downloads');
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('Downloads directory not found');
      }

      // Create the file path
      final filePath = '${downloadDir.path}/$fileName';
      final file = io.File(filePath);

      // Download the file with progress tracking
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

        // Update progress if content length is known
        if (contentLength > 0) {
          final progress = received / contentLength;
          FileDownloadProgressService().updateProgress(fileId, progress);
        }
      }

      // Write file to disk
      final data = Uint8List.fromList(bytes);
      await file.writeAsBytes(data);

      // Mark as completed
      FileDownloadProgressService().updateProgress(fileId, 1.0);

      // Save file path and fileId mapping to SharedPreferences for tracking
      final prefs = await SharedPreferences.getInstance();
      final List<String> downloadedFiles =
          prefs.getStringList('downloaded_files') ?? [];
      if (!downloadedFiles.contains(file.path)) {
        downloadedFiles.add(file.path);
        await prefs.setStringList('downloaded_files', downloadedFiles);
      }

      // Also save fileId -> filePath mapping to track downloaded files by fileId
      final fileIdMap = prefs.getStringList('file_id_to_path_map') ?? [];
      final mappingKey = '$fileId:${file.path}';
      if (!fileIdMap.contains(mappingKey)) {
        fileIdMap.add(mappingKey);
        await prefs.setStringList('file_id_to_path_map', fileIdMap);
      }

      // Save music metadata if preview is available and file is a music file
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

      // Show success message
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
      // Clear progress on error
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
    bool isUltraOptimized,
  ) {
    final borderRadius = BorderRadius.circular(isUltraOptimized ? 4 : 12);

    switch (photos.length) {
      case 1:
        return _buildSinglePhoto(context, photos[0], borderRadius);
      case 2:
        return _buildTwoPhotos(context, photos, borderRadius);
      case 3:
        return _buildThreePhotos(context, photos, borderRadius);
      case 4:
        return _buildFourPhotos(context, photos, borderRadius);
      default:
        return _buildManyPhotos(context, photos, borderRadius);
    }
  }

  Widget _buildSinglePhoto(
    BuildContext context,
    Map<String, dynamic> photo,
    BorderRadius borderRadius,
  ) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _openPhotoViewer(context, photo),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180, maxWidth: 250),
            child: _buildPhotoWidget(context, photo),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoPhotos(
    BuildContext context,
    List<Map<String, dynamic>> photos,
    BorderRadius borderRadius,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
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
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: Row(
        children: [
          // Левая большая фотка
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
          // Правая колонка с двумя маленькими
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
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: Column(
        children: [
          // Верхний ряд
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
          // Нижний ряд
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
  ) {
    // Для 5+ фотографий показываем сетку 2x2 + счетчик
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
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

    // Используем навигатор для перехода на новый полноэкранный виджет
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false, // Делаем страницу прозрачной для красивого перехода
        barrierColor: Colors.black,
        pageBuilder: (BuildContext context, _, __) {
          // Возвращаем наш новый экран просмотра
          return FullScreenPhotoViewer(imageChild: child, attach: attach);
        },
        // Добавляем плавное появление
        transitionsBuilder: (_, animation, __, page) {
          return FadeTransition(opacity: animation, child: page);
        },
      ),
    );
  }

  Widget _buildPhotoWidget(BuildContext context, Map<String, dynamic> attach) {
    // Сначала обрабатываем локальные данные (base64), если они есть.
    // Это обеспечивает мгновенный показ размытого превью.
    Uint8List? previewBytes;
    final preview = attach['previewData'];
    if (preview is String && preview.startsWith('data:')) {
      final idx = preview.indexOf('base64,');
      if (idx != -1) {
        final b64 = preview.substring(idx + 7);
        try {
          previewBytes = base64Decode(b64);
        } catch (_) {
          // Ошибка декодирования, ничего страшного
        }
      }
    }

    final url = attach['url'] ?? attach['baseUrl'];
    if (url is String && url.isNotEmpty) {
      // Обработка локальных файлов (если фото отправляется с устройства)
      if (url.startsWith('file://')) {
        final path = url.replaceFirst('file://', '');
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          width: 220,
          filterQuality:
              FilterQuality.medium, // Используем среднее качество для превью
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _imagePlaceholder(),
        );
      }

      // Формируем специальный URL для предпросмотра в чате:
      // средний размер, высокое качество, формат JPEG для эффективности.
      String previewQualityUrl = url;
      if (!url.contains('?')) {
        previewQualityUrl = '$url?size=medium&quality=high&format=jpeg';
      } else {
        previewQualityUrl = '$url&size=medium&quality=high&format=jpeg';
      }

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final optimize =
          themeProvider.optimizeChats || themeProvider.ultraOptimizeChats;

      // Используем наш новый URL для загрузки качественного превью
      return _ProgressiveNetworkImage(
        key: ValueKey(previewQualityUrl), // Ключ по новому URL
        url: previewQualityUrl, // Передаем новый URL
        previewBytes:
            previewBytes, // Передаем размытую заглушку для мгновенного отображения
        width: 220,
        height: 160,
        fit: BoxFit.cover,
        keepAlive: !optimize,
        startDownloadNextFrame: deferImageLoading,
      );
    }

    // Если URL нет, но есть base64 данные, покажем их
    if (previewBytes != null) {
      return Image.memory(previewBytes, fit: BoxFit.cover, width: 180);
    }

    // В самом крайнем случае показываем стандартный плейсхолдер
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

  // Лёгкий прогрессивный загрузчик: показывает превью, тянет оригинал с прогрессом и кэширует в памяти процесса

  Color _getBubbleColor(
    bool isMe,
    ThemeProvider themeProvider,
    double messageOpacity,
  ) {
    final baseColor = isMe
        ? (themeProvider.myBubbleColor ?? const Color(0xFF2b5278))
        : (themeProvider.theirBubbleColor ?? const Color(0xFF182533));
    return baseColor.withOpacity(1.0 - messageOpacity);
  }

  Color _getTextColor(
    bool isMe,
    Color bubbleColor,
    double messageTextOpacity,
    BuildContext context,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      return Colors.white;
    } else {
      return Colors.black;
    }
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
              padding: const EdgeInsets.only(left: 2.0, bottom: 2.0),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getUserColor(
                    message.senderId,
                    context,
                  ).withOpacity(0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      if (isGroupChat && !isMe && senderName != null) const SizedBox(height: 4),
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
          const SizedBox(height: 6),
        ],
        if (message.text.isNotEmpty) ...[
          if (message.text.startsWith('kometSM.') &&
              message.text.length > 'kometSM.'.length &&
              !isEncryptionPasswordSet)
            Text(
              'это зашифрованное сообщение, для его отображение поставьте пароль шифрования на чат.',
              style: TextStyle(
                color: Colors.red,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            )
          else if (message.text.startsWith('kometSM.') &&
              message.text.length > 'kometSM.'.length &&
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
            _buildMixedMessageContent(decryptedText!, defaultTextStyle, linkStyle, onOpenLink)
          else if (message.text.contains("welcome.saved.dialog.message"))
            Linkify(
              text:
                  'Привет! Это твои избранные. Все написанное сюда попадёт прямиком к дяде Майору.',
              style: TextStyle(color: textColor, fontStyle: FontStyle.italic),
              linkStyle: linkStyle,
              onOpen: onOpenLink,
              options: const LinkifyOptions(humanize: false),
              textAlign: TextAlign.left,
            )
          else if (message.text.contains("komet.cosmetic.") ||
              message.text.contains("komet.color_"))
            _buildMixedMessageContent(message.text, defaultTextStyle, linkStyle, onOpenLink)
          else
            Linkify(
              text: message.text,
              style: defaultTextStyle,
              linkStyle: linkStyle,
              onOpen: onOpenLink,
              options: const LinkifyOptions(humanize: false),
              textAlign: TextAlign.left,
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
                          color: textColor.withOpacity(
                            0.7 * messageTextOpacity,
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
                  color: textColor.withOpacity(0.5 * messageTextOpacity),
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
                  } else {
                    return Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 16,
                      color: iconColor,
                    );
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
                  color: textColor.withOpacity(0.5 * messageTextOpacity),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    ];
  }

  /// Парсит сообщение на сегменты с разными эффектами
  List<_KometSegment> _parseMixedMessageSegments(String text) {
    final segments = <_KometSegment>[];
    int index = 0;

    while (index < text.length) {
      // Ищем ближайший маркер
      int nextPulse = text.indexOf("komet.cosmetic.pulse#", index);
      int nextGalaxy = text.indexOf("komet.cosmetic.galaxy'", index);
      int nextColor = text.indexOf("komet.color_", index);

      // Находим ближайший маркер
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

      // Если маркер не найден, добавляем оставшийся текст как обычный
      if (markerType == null) {
        if (index < text.length) {
          segments.add(_KometSegment(text.substring(index), _KometSegmentType.normal));
        }
        break;
      }

      // Добавляем текст до маркера как обычный
      if (nextMarker > index) {
        segments.add(_KometSegment(text.substring(index, nextMarker), _KometSegmentType.normal));
      }

      // Обрабатываем найденный маркер
      if (markerType == "pulse") {
        const prefix = "komet.cosmetic.pulse#";
        final afterHash = text.substring(nextMarker + prefix.length);
        final quoteIndex = afterHash.indexOf("'");
        if (quoteIndex != -1 && quoteIndex >= 6) {
          final hexStr = afterHash.substring(0, quoteIndex).trim();
          final textStart = quoteIndex + 1;
          final secondQuote = afterHash.indexOf("'", textStart);
          if (secondQuote != -1) {
            final segmentText = afterHash.substring(textStart, secondQuote);
            final color = _parseKometHexColor(hexStr, null);
            segments.add(_KometSegment(segmentText, _KometSegmentType.pulse, color: color));
            index = nextMarker + prefix.length + secondQuote + 2; // +2 для двух кавычек
            continue;
          }
        }
        // Если парсинг не удался, добавляем как обычный текст
        segments.add(_KometSegment(text.substring(nextMarker, nextMarker + prefix.length + 10), _KometSegmentType.normal));
        index = nextMarker + prefix.length + 10;
      } else if (markerType == "galaxy") {
        const prefix = "komet.cosmetic.galaxy'";
        final textStart = nextMarker + prefix.length;
        final quoteIndex = text.indexOf("'", textStart);
        if (quoteIndex != -1) {
          final segmentText = text.substring(textStart, quoteIndex);
          segments.add(_KometSegment(segmentText, _KometSegmentType.galaxy));
          index = quoteIndex + 1;
          continue;
        }
        // Если парсинг не удался, добавляем как обычный текст
        segments.add(_KometSegment(text.substring(nextMarker, textStart + 10), _KometSegmentType.normal));
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
            segments.add(_KometSegment(segmentText, _KometSegmentType.colored, color: color));
            index = secondQuote + 1;
            continue;
          }
        }
        // Если парсинг не удался, добавляем как обычный текст
        segments.add(_KometSegment(text.substring(nextMarker, colorStart + 10), _KometSegmentType.normal));
        index = colorStart + 10;
      }
    }

    return segments;
  }

  /// Строит виджет для смешанного сообщения с разными эффектами
  Widget _buildMixedMessageContent(
    String text,
    TextStyle baseStyle,
    TextStyle linkStyle,
    Future<void> Function(LinkableElement) onOpenLink,
  ) {
    final segments = _parseMixedMessageSegments(text);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: segments.map((seg) {
        switch (seg.type) {
          case _KometSegmentType.normal:
            return Linkify(
              text: seg.text,
              style: baseStyle,
              linkStyle: linkStyle,
              onOpen: onOpenLink,
              options: const LinkifyOptions(humanize: false),
            );
          case _KometSegmentType.colored:
            return Linkify(
              text: seg.text,
              style: baseStyle.copyWith(color: seg.color),
              linkStyle: linkStyle,
              onOpen: onOpenLink,
              options: const LinkifyOptions(humanize: false),
            );
          case _KometSegmentType.galaxy:
            return _GalaxyAnimatedText(text: seg.text);
          case _KometSegmentType.pulse:
            // Создаем строку в правильном формате для _PulseAnimatedText
            final hexStr = seg.color!.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
            return _PulseAnimatedText(text: "komet.cosmetic.pulse#$hexStr'${seg.text}'");
        }
      }).toList(),
    );
  }

  /// Строит раскрашенный текст на основе синтаксиса komet.color_#HEX'текст'.
  /// Если цвет некорректный, используется красный.
  Widget _buildKometColorRichText(String rawText, TextStyle baseStyle) {
    final segments = _parseKometColorSegments(rawText, baseStyle.color);

    return RichText(
      textAlign: TextAlign.left,
      text: TextSpan(
        style: baseStyle,
        children: segments
            .map(
              (seg) => TextSpan(
                text: seg.text,
                style: seg.color != null
                    ? baseStyle.copyWith(color: seg.color)
                    : baseStyle,
              ),
            )
            .toList(),
      ),
    );
  }

  List<_KometColoredSegment> _parseKometColorSegments(
    String text,
    Color? fallbackColor,
  ) {
    const marker = 'komet.color_';
    final segments = <_KometColoredSegment>[];

    int index = 0;
    while (index < text.length) {
      final start = text.indexOf(marker, index);
      if (start == -1) {
        segments.add(_KometColoredSegment(text.substring(index), null));
        break;
      }

      if (start > index) {
        segments.add(_KometColoredSegment(text.substring(index, start), null));
      }

      final colorStart = start + marker.length;
      final firstQuote = text.indexOf("'", colorStart);
      if (firstQuote == -1) {
        // Кривой синтаксис — считаем всё остальное обычным текстом.
        segments.add(_KometColoredSegment(text.substring(start), null));
        break;
      }

      final colorStr = text.substring(colorStart, firstQuote);
      final textStart = firstQuote + 1;
      final secondQuote = text.indexOf("'", textStart);
      if (secondQuote == -1) {
        segments.add(_KometColoredSegment(text.substring(start), null));
        break;
      }

      final segmentText = text.substring(textStart, secondQuote);
      final color = _parseKometHexColor(colorStr, fallbackColor);

      segments.add(_KometColoredSegment(segmentText, color));
      index = secondQuote + 1;
    }

    return segments;
  }

  Color _parseKometHexColor(String raw, Color? fallbackColor) {
    String hex = raw.trim();
    if (hex.startsWith('#')) {
      hex = hex.substring(1);
    }

    // Ожидаем 6 или 8 символов; всё остальное считаем "херовым" цветом.
    final isValidLength = hex.length == 6 || hex.length == 8;
    final isValidChars = RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
    if (!isValidLength || !isValidChars) {
      return const Color(0xFFFF0000); // дефолт – красный
    }

    if (hex.length == 6) {
      hex = 'FF$hex'; // добавляем альфу
    }

    try {
      final value = int.parse(hex, radix: 16);
      return Color(value);
    } catch (_) {
      return const Color(0xFFFF0000);
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
          color: Colors.black.withOpacity(messageShadowIntensity),
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
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: _getMessageMargin(context),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
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

    return Builder(
      builder: (context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => openUserProfileById(context, message.senderId),
          child: AvatarCacheService().getAvatarWidget(
            avatarUrl,
            userId: message.senderId,
            size: 32,
            fallbackText: contactName,
            backgroundColor: _getUserColor(message.senderId, context),
            textColor: Colors.white,
          ),
        ),
      ),
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

    // [!code ++] (НОВЫЙ БЛОК)
    // Если URL пустой, нечего загружать.
    // Полагаемся только на previewBytes.
    if (widget.url.isEmpty) {
      return;
    }
    // [!code ++] (КОНЕЦ НОВОГО БЛОКА)

    // Если есть в глобальном кэше — используем сразу
    final cached = GlobalImageStore.getData(widget.url);
    if (cached != null) {
      _fullBytes = cached;
      // no return, продолжаем проверить диск на всякий
    }
    // Если есть в кэше — используем
    if (_memoryCache.containsKey(widget.url)) {
      _fullBytes = _memoryCache[widget.url];
    }
    if (widget.startDownloadNextFrame) {
      // Загружаем в следующем кадре
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryLoadFromDiskThenDownload();
      });
    } else {
      _tryLoadFromDiskThenDownload();
    }
  }

  Future<void> _tryLoadFromDiskThenDownload() async {
    // [!code ++] (НОВЫЙ БЛОК)
    // Не пытаемся грузить, если URL пустой
    if (widget.url.isEmpty) {
      return;
    }
    // [!code ++] (КОНЕЦ НОВОГО БЛОКА)

    // Попытка прочитать из дискового кэша
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
        if (mounted) setState(() => _fullBytes = data);
        return; // нашли на диске, скачивать не надо
      }
    } catch (_) {}
    await _download();
  }

  Future<void> _download() async {
    try {
      final req = http.Request('GET', Uri.parse(widget.url));
      req.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      final resp = await req.send();
      if (resp.statusCode != 200) {
        setState(() => _error = true);
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
          _progress =
              p; // не дергаем setState, чтобы не создавать лишние перерисовки при slide
          GlobalImageStore.setProgress(widget.url, _progress);
        }
      }
      final data = Uint8List.fromList(bytes);
      _memoryCache[widget.url] = data;
      GlobalImageStore.setData(widget.url, data);
      // Пишем на диск
      try {
        final path = _diskPath;
        if (path != null) {
          final f = io.File(path);
          await f.writeAsBytes(data, flush: true);
        }
      } catch (_) {}
      if (mounted) setState(() => _fullBytes = data);
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
    // Полное качество есть — показываем
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            0,
          ), // Упрощено для производительности
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1) Стабильный нижний слой — превью или нейтральный фон
              if (widget.previewBytes != null)
                Image.memory(
                  widget.previewBytes!,
                  fit: widget.fit,
                  filterQuality: FilterQuality.none,
                )
              else
                Container(color: Colors.black12),
              // 2) Верхний слой — оригинал. Он появляется, но не убирает превью, чтобы не мигать
              if (_fullBytes != null)
                Image.memory(
                  _fullBytes!,
                  fit: widget.fit,
                  filterQuality: FilterQuality.high,
                ),
              // нижний прогресс убран, чтобы не перерисовывать слой картинки во время slide;
              // прогресс выводится рядом со временем сообщения
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
      // Пересоберём keepAlive флаг
      updateKeepAlive();
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

  // Логика нажатия упрощена
  void _handleTap() {
    // Анимация масштабирования для обратной связи
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    // Сразу открываем диалог
    _showCustomEmojiDialog();
  }

  void _showCustomEmojiDialog() {
    showDialog(
      context: context,
      builder: (context) => _CustomEmojiDialog(
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
              // Стрелка заменена на иконку "добавить"
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

class _CustomEmojiDialog extends StatefulWidget {
  final Function(String) onEmojiSelected;

  const _CustomEmojiDialog({required this.onEmojiSelected});

  @override
  State<_CustomEmojiDialog> createState() => _CustomEmojiDialogState();
}

class _CustomEmojiDialogState extends State<_CustomEmojiDialog> {
  final TextEditingController _controller = TextEditingController();
  String _selectedEmoji = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            Icons.emoji_emotions,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Text('Введите эмодзи'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: TextField(
              controller: _controller,
              maxLength: 1, // Только один символ
              decoration: InputDecoration(
                hintText: 'Введите эмодзи...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedEmoji = value;
                });
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedEmoji.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(_selectedEmoji, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _selectedEmoji.isNotEmpty
              ? () {
                  widget.onEmojiSelected(_selectedEmoji);
                  Navigator.of(context).pop();
                }
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Добавить'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ],
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
  });

  @override
  _MessageContextMenuState createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<_MessageContextMenu>
    with SingleTickerProviderStateMixin {
  bool _isEmojiListExpanded = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Короткий список для быстрого доступа
  static const List<String> _quickReactions = [
    '👍',
    '❤️',
    '😂',
    '🔥',
    '👏',
    '🤔',
  ];

  // Полный список всех реакций
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

  void _onCopy() {
    Clipboard.setData(ClipboardData(text: widget.message.text));
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
    final screenSize = MediaQuery.of(context).size;

    const menuWidth = 250.0;
    final double estimatedMenuHeight = _isEmojiListExpanded ? 320.0 : 250.0;

    double left = widget.position.dx - (menuWidth / 4);
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 16;
    }
    if (left < 16) {
      left = 16;
    }

    double top = widget.position.dy;
    if (top + estimatedMenuHeight > screenSize.height) {
      top = widget.position.dy - estimatedMenuHeight - 10;
    }

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.1),
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
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.topCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: themeProvider.messageMenuBlur,
                    sigmaY: themeProvider.messageMenuBlur,
                  ),
                  child: Card(
                    elevation: 8,
                    color: theme.colorScheme.surface.withOpacity(
                      themeProvider.messageMenuOpacity,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      width: menuWidth,
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _buildEmojiSection(),
                          ),
                          const Divider(height: 12),
                          _buildActionsSection(theme),
                        ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.message.text.isNotEmpty)
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

  const FullScreenPhotoViewer({
    super.key,
    required this.imageChild,
    this.attach,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final TransformationController _transformationController;
  // Переменная для контроля, можно ли двигать изображение
  bool _isPanEnabled = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    // "Слушаем" изменения зума
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    // Получаем текущий масштаб
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    // Разрешаем двигать, только если масштаб больше 1
    final shouldPan = currentScale > 1.0;

    // Обновляем состояние, только если оно изменилось
    if (shouldPan != _isPanEnabled) {
      setState(() {
        _isPanEnabled = shouldPan;
      });
    }
  }

  Future<void> _downloadPhoto() async {
    if (widget.attach == null) return;

    try {
      // Get Downloads directory
      io.Directory? downloadDir;

      if (io.Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          downloadDir = io.Directory(
            '${directory.path.split('Android')[0]}Download',
          );
          if (!await downloadDir.exists()) {
            downloadDir = io.Directory(
              '${directory.path.split('Android')[0]}Downloads',
            );
          }
        }
      } else if (io.Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        downloadDir = directory;
      } else if (io.Platform.isWindows || io.Platform.isLinux) {
        final homeDir =
            io.Platform.environment['HOME'] ??
            io.Platform.environment['USERPROFILE'] ??
            '';
        downloadDir = io.Directory('$homeDir/Downloads');
      } else {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      if (downloadDir == null || !await downloadDir.exists()) {
        throw Exception('Downloads directory not found');
      }

      // Get photo URL
      final url = widget.attach!['url'] ?? widget.attach!['baseUrl'];
      if (url == null || url.isEmpty) {
        throw Exception('Photo URL not found');
      }

      // Extract file extension from URL or use .jpg as default
      String extension = 'jpg';
      final uri = Uri.tryParse(url);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last;
        final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(lastSegment);
        if (extMatch != null) {
          extension = extMatch.group(1)!;
        }
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.$extension';
      final filePath = '${downloadDir.path}/$fileName';
      final file = io.File(filePath);

      // Download the image
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        // Save to SharedPreferences
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: _isPanEnabled,
              boundaryMargin: EdgeInsets.zero,
              minScale: 1.0,
              maxScale: 5.0,
              child: Center(child: widget.imageChild),
            ),
          ),
          // Top bar with close button and download button
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
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: _downloadPhoto,
                      tooltip: 'Скачать фото',
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
  // Важно добавить 'with SingleTickerProviderStateMixin'
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // Длительность одного оборота (2 секунды)
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // Запускаем анимацию на бесконечное повторение
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RotationTransition - это виджет, который вращает своего "ребенка"
    return RotationTransition(
      turns: _controller, // Анимация вращения
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final int duration;
  final String durationText;
  final String? wave;
  final int? audioId;
  final Color textColor;
  final BorderRadius borderRadius;
  final double messageTextOpacity;

  const _AudioPlayerWidget({
    required this.url,
    required this.duration,
    required this.durationText,
    this.wave,
    this.audioId,
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

    if (widget.wave != null && widget.wave!.isNotEmpty) {
      _decodeWaveform(widget.wave!);
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
        customKey: widget.audioId?.toString(),
      );
      if (!hasCached) {
        print('Pre-caching audio: ${widget.url}');
        final cachedPath = await cacheService.cacheAudioFile(
          widget.url,
          customKey: widget.audioId?.toString(),
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
              customKey: widget.audioId?.toString(),
            );

            if (cachedFile != null && await cachedFile.exists()) {
              print('Using cached audio file: ${cachedFile.path}');
              await _audioPlayer.setFilePath(cachedFile.path);
            } else {
              print('Audio not cached, playing from URL: ${widget.url}');
              try {
                await _audioPlayer.setUrl(widget.url);

                cacheService
                    .cacheAudioFile(
                      widget.url,
                      customKey: widget.audioId?.toString(),
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
            }
          }
        }
        await _audioPlayer.play();
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

    return Container(
      decoration: BoxDecoration(
        color: widget.textColor.withOpacity(0.05),
        borderRadius: widget.borderRadius,
        border: Border.all(color: widget.textColor.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.textColor.withOpacity(0.1),
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
                        color: widget.textColor.withOpacity(
                          0.8 * widget.messageTextOpacity,
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
                          color: widget.textColor.withOpacity(
                            0.6 * widget.messageTextOpacity,
                          ),
                          progressColor: widget.textColor.withOpacity(
                            0.9 * widget.messageTextOpacity,
                          ),
                        ),
                        child: GestureDetector(
                          onTapDown: (details) {
                            final RenderBox box =
                                context.findRenderObject() as RenderBox;
                            final localPosition = details.localPosition;
                            final tapProgress =
                                localPosition.dx / box.size.width;
                            final newPosition = Duration(
                              milliseconds:
                                  (_totalDuration.inMilliseconds * tapProgress)
                                      .round(),
                            );
                            _seek(newPosition);
                          },
                        ),
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: widget.textColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.textColor.withOpacity(
                            0.6 * widget.messageTextOpacity,
                          ),
                        ),
                        minHeight: 3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                          color: widget.textColor.withOpacity(
                            0.7 * widget.messageTextOpacity,
                          ),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _totalDuration.inMilliseconds > 0
                            ? _formatDuration(_totalDuration)
                            : widget.durationText,
                        style: TextStyle(
                          color: widget.textColor.withOpacity(
                            0.7 * widget.messageTextOpacity,
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
                  color: Colors.black.withOpacity(0.3),
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
                      color: Colors.black.withOpacity(0.3),
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
