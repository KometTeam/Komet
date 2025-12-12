import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:gwid/api/api_service.dart';
import 'package:flutter/services.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/widgets/chat_message_bubble.dart';
import 'package:gwid/widgets/complaint_dialog.dart';
import 'package:gwid/widgets/pinned_message_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gwid/services/chat_cache_service.dart';
import 'package:gwid/services/avatar_cache_service.dart';
import 'package:gwid/services/chat_read_settings_service.dart';
import 'package:gwid/services/contact_local_names_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gwid/screens/group_settings_screen.dart';
import 'package:gwid/screens/edit_contact_screen.dart';
import 'package:gwid/widgets/contact_name_widget.dart';
import 'package:gwid/widgets/contact_avatar_widget.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:gwid/screens/chat_encryption_settings_screen.dart';
import 'package:gwid/screens/chat_media_screen.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gwid/services/chat_encryption_service.dart';
import 'package:lottie/lottie.dart';
import 'package:gwid/widgets/formatted_text_controller.dart';

bool _debugShowExactDate = false;

void toggleDebugExactDate() {
  _debugShowExactDate = !_debugShowExactDate;
  print('Debug режим точной даты: $_debugShowExactDate');
}

abstract class ChatItem {}

class MessageItem extends ChatItem {
  final Message message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool isGrouped;

  MessageItem(
    this.message, {
    this.isFirstInGroup = false,
    this.isLastInGroup = false,
    this.isGrouped = false,
  });
}

class DateSeparatorItem extends ChatItem {
  final DateTime date;
  DateSeparatorItem(this.date);
}




class _EmptyChatWidget extends StatelessWidget {
  final Map<String, dynamic>? sticker;
  final VoidCallback? onStickerTap;

  const _EmptyChatWidget({this.sticker, this.onStickerTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    print(
      '🎨 _EmptyChatWidget.build: sticker=${sticker != null ? "есть" : "null"}',
    );
    if (sticker != null) {
      print('🎨 Стикер данные: $sticker');
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (sticker != null) ...[
            
            GestureDetector(
              onTap: onStickerTap,
              child: _buildSticker(sticker!),
            ),
            const SizedBox(height: 24),
          ] else ...[
            
            const SizedBox(
              width: 170,
              height: 170,
              child: Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Сообщений пока нет, напишите первым или отправьте этот стикер',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSticker(Map<String, dynamic> sticker) {
    final url = sticker['url'] as String?;
    final lottieUrl = sticker['lottieUrl'] as String?;
    final width = (sticker['width'] as num?)?.toDouble() ?? 170.0;
    final height = (sticker['height'] as num?)?.toDouble() ?? 170.0;

    print(
      '🎨 _buildSticker: url=$url, lottieUrl=$lottieUrl, width=$width, height=$height',
    );

    
    if (lottieUrl != null && lottieUrl.isNotEmpty) {
      print('🎨 Пытаемся показать Lottie-анимацию: $lottieUrl');
      return SizedBox(
        width: width,
        height: height,
        child: Lottie.network(
          lottieUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Ошибка загрузки Lottie: $error');
            print('❌ StackTrace Lottie: $stackTrace');
            
            if (url != null && url.isNotEmpty) {
              return Image.network(url, fit: BoxFit.contain);
            }
            return Icon(Icons.emoji_emotions, size: width, color: Colors.grey);
          },
        ),
      );
    }

    
    final imageUrl = url;

    print('🎨 Используемый URL для статичного стикера: $imageUrl');

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              print('✅ Стикер успешно загружен');
              return child;
            }
            print(
              '⏳ Загрузка стикера: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}',
            );
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Ошибка загрузки стикера: $error');
            print('❌ StackTrace: $stackTrace');
            return Icon(Icons.emoji_emotions, size: width, color: Colors.grey);
          },
        ),
      );
    }

    print('❌ URL стикера пустой или null');
    return Icon(Icons.emoji_emotions, size: width, color: Colors.grey);
  }
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final Contact contact;
  final int myId;

  
  final VoidCallback? onChatUpdated;

  
  final VoidCallback? onChatRemoved;
  final bool isGroupChat;
  final bool isChannel;
  final int? participantCount;
  final bool isDesktopMode;
  final int initialUnreadCount;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.contact,
    required this.myId,
    this.onChatUpdated,
    this.onChatRemoved,
    this.isGroupChat = false,
    this.isChannel = false,
    this.participantCount,
    this.isDesktopMode = false,
    this.initialUnreadCount = 0,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  List<ChatItem> _chatItems = [];
  final Set<String> _animatedMessageIds = {};

  bool _isLoadingHistory = true;
  Map<String, dynamic>? _emptyChatSticker;
  final FormattedTextController _textController = FormattedTextController();
  final FocusNode _textFocusNode = FocusNode();
  StreamSubscription? _apiSubscription;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ValueNotifier<bool> _showScrollToBottomNotifier = ValueNotifier(false);

  bool _isUserAtBottom = true;
  bool _isScrollingToBottom = false;

  late Contact _currentContact;
  Message? _pinnedMessage;

  Message? _replyingToMessage;

  final Map<int, Contact> _contactDetailsCache = {};
  final Set<int> _loadingContactIds = {};

  
  int _initialUnreadCount = 0;

  
  final Set<String> _sendingReactions = {};

  

  Future<void> _onAttachPressed() async {
    
    if (Platform.isAndroid || Platform.isIOS) {
      if (!mounted) return;
      final colors = Theme.of(context).colorScheme;

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text(
                    'Отправить вложение',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: colors.primary.withOpacity(0.10),
                            foregroundColor: colors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                          ),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Фото / видео'),
                          onPressed: () async {
                            final isEncryptionActive =
                                _encryptionConfigForCurrentChat != null &&
                                _encryptionConfigForCurrentChat!
                                    .password
                                    .isNotEmpty &&
                                _sendEncryptedForCurrentChat;
                            if (isEncryptionActive) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Нельзя отправлять медиа при включенном шифровании',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                              Navigator.of(ctx).pop();
                              return;
                            }
                            Navigator.of(ctx).pop();
                            final result = await _pickPhotosFlow(context);
                            if (!mounted) return;
                            if (result != null && result.paths.isNotEmpty) {
                              await ApiService.instance.sendPhotoMessages(
                                widget.chatId,
                                localPaths: result.paths,
                                caption: result.caption,
                                senderId: _actualMyId,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.outlineVariant),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                          ),
                          icon: const Icon(Icons.insert_drive_file_outlined),
                          label: const Text('Файл с устройства'),
                          onPressed: () async {
                            final isEncryptionActive =
                                _encryptionConfigForCurrentChat != null &&
                                _encryptionConfigForCurrentChat!
                                    .password
                                    .isNotEmpty &&
                                _sendEncryptedForCurrentChat;
                            if (isEncryptionActive) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Нельзя отправлять медиа при включенном шифровании',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                              Navigator.of(ctx).pop();
                              return;
                            }
                            Navigator.of(ctx).pop();
                            await ApiService.instance.sendFileMessage(
                              widget.chatId,
                              senderId: _actualMyId,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Скоро здесь появятся последние отправленные файлы.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      final isEncryptionActive =
          _encryptionConfigForCurrentChat != null &&
          _encryptionConfigForCurrentChat!.password.isNotEmpty &&
          _sendEncryptedForCurrentChat;
      if (isEncryptionActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Нельзя отправлять медиа при включенном шифровании',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Отправить вложение'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop('media'),
              child: Row(
                children: const [
                  Icon(Icons.photo_library_outlined),
                  SizedBox(width: 8),
                  Text('Фото / видео'),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop('file'),
              child: Row(
                children: const [
                  Icon(Icons.insert_drive_file_outlined),
                  SizedBox(width: 8),
                  Text('Файл с устройства'),
                ],
              ),
            ),
          ],
        ),
      );

      if (choice == 'media') {
        final isEncryptionActive =
            _encryptionConfigForCurrentChat != null &&
            _encryptionConfigForCurrentChat!.password.isNotEmpty &&
            _sendEncryptedForCurrentChat;
        if (isEncryptionActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Нельзя отправлять медиа при включенном шифровании',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        final result = await _pickPhotosFlow(context);
        if (result != null && result.paths.isNotEmpty) {
          await ApiService.instance.sendPhotoMessages(
            widget.chatId,
            localPaths: result.paths,
            caption: result.caption,
            senderId: _actualMyId,
          );
        }
      } else if (choice == 'file') {
        final isEncryptionActive =
            _encryptionConfigForCurrentChat != null &&
            _encryptionConfigForCurrentChat!.password.isNotEmpty &&
            _sendEncryptedForCurrentChat;
        if (isEncryptionActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Нельзя отправлять медиа при включенном шифровании',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        await ApiService.instance.sendFileMessage(
          widget.chatId,
          senderId: _actualMyId,
        );
      }
    }
  }

  int? _actualMyId;

  bool _isIdReady = false;
  bool _isEncryptionPasswordSetForCurrentChat =
      false; 
  ChatEncryptionConfig? _encryptionConfigForCurrentChat;
  bool _sendEncryptedForCurrentChat = true;
  bool _specialMessagesEnabled = true;

  bool _formatWarningVisible = false;
  bool _hasTextSelection = false;
  Timer? _selectionCheckTimer;

  bool _showKometColorPicker = false;
  String? _currentKometColorPrefix;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Message> _searchResults = [];
  int _currentResultIndex = -1;
  final Map<String, GlobalKey> _messageKeys = {};

  void _checkContactCache() {
    if (widget.chatId == 0) {
      return;
    }
    final cachedContact = ApiService.instance.getCachedContact(
      widget.contact.id,
    );
    if (cachedContact != null) {
      _currentContact = cachedContact;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _scrollToBottom() {
    
    if (!_itemScrollController.isAttached) return;

    
    _isScrollingToBottom = true;
    _showScrollToBottomNotifier.value = false;

    _itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment:
          1.0, 
    );

    
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        final positions = _itemPositionsListener.itemPositions.value;
        if (positions.isNotEmpty) {
          final bottomItemPosition = positions.firstWhere(
            (p) => p.index == 0,
            orElse: () => positions.first,
          );
          final isBottomItemVisible = bottomItemPosition.index == 0;
          final isAtBottom =
              isBottomItemVisible && bottomItemPosition.itemTrailingEdge >= 0.9;
          if (isAtBottom) {
            _isScrollingToBottom = false;
            _showScrollToBottomNotifier.value = false;
          } else {
            
            _isScrollingToBottom = false;
          }
        }
      }
    });
  }

  void _jumpToBottom() {
    
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: 0);
      }
    });
  }

  void _loadContactDetails() {
    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData != null && chatData['contacts'] != null) {
      final contactsJson = chatData['contacts'] as List<dynamic>;
      for (var contactJson in contactsJson) {
        final contact = Contact.fromJson(contactJson);
        _contactDetailsCache[contact.id] = contact;
      }
      print(
        'Кэш контактов для экрана чата заполнен: ${_contactDetailsCache.length} контактов.',
      );
    }
  }

  Future<void> _loadContactIfNeeded(int contactId) async {
    if (_contactDetailsCache.containsKey(contactId) ||
        _loadingContactIds.contains(contactId)) {
      return;
    }

    _loadingContactIds.add(contactId);

    try {
      final contacts = await ApiService.instance.fetchContactsByIds([
        contactId,
      ]);
      if (contacts.isNotEmpty && mounted) {
        final contact = contacts.first;
        _contactDetailsCache[contact.id] = contact;

        final allChatContacts = _contactDetailsCache.values.toList();
        await ChatCacheService().cacheChatContacts(
          widget.chatId,
          allChatContacts,
        );

        setState(() {});
      }
    } catch (e) {
      print('Ошибка загрузки контакта $contactId: $e');
    } finally {
      _loadingContactIds.remove(contactId);
    }
  }

  Future<void> _loadGroupParticipants() async {
    try {
      print(
        '🔍 [_loadGroupParticipants] Начинаем загрузку участников группы...',
      );

      final chatData = ApiService.instance.lastChatsPayload;
      if (chatData == null) {
        print('❌ [_loadGroupParticipants] chatData == null');
        return;
      }

      final chats = chatData['chats'] as List<dynamic>?;
      if (chats == null) {
        print('❌ [_loadGroupParticipants] chats == null');
        return;
      }

      print(
        '🔍 [_loadGroupParticipants] Ищем чат с ID ${widget.chatId} среди ${chats.length} чатов...',
      );

      final currentChat = chats.firstWhere(
        (chat) => chat['id'] == widget.chatId,
        orElse: () => null,
      );

      if (currentChat == null) {
        print('❌ [_loadGroupParticipants] Чат с ID ${widget.chatId} не найден');
        return;
      }

      print(
        '✅ [_loadGroupParticipants] Чат найден: ${currentChat['title'] ?? 'Без названия'}',
      );

      final participants = currentChat['participants'] as Map<String, dynamic>?;
      if (participants == null || participants.isEmpty) {
        print('❌ [_loadGroupParticipants] Список участников пуст');
        return;
      }

      print(
        '🔍 [_loadGroupParticipants] Найдено ${participants.length} участников в чате',
      );

      final participantIds = participants.keys
          .map((id) => int.tryParse(id))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      if (participantIds.isEmpty) {
        print('❌ [_loadGroupParticipants] participantIds пуст после парсинга');
        return;
      }

      print(
        '🔍 [_loadGroupParticipants] Обрабатываем ${participantIds.length} ID участников...',
      );
      print(
        '🔍 [_loadGroupParticipants] IDs: ${participantIds.take(10).join(', ')}${participantIds.length > 10 ? '...' : ''}',
      );

      final idsToFetch = participantIds
          .where((id) => !_contactDetailsCache.containsKey(id))
          .toList();

      print(
        '🔍 [_loadGroupParticipants] В кэше уже есть: ${participantIds.length - idsToFetch.length} контактов',
      );
      print(
        '🔍 [_loadGroupParticipants] Нужно загрузить: ${idsToFetch.length} контактов',
      );

      if (idsToFetch.isEmpty) {
        print('✅ [_loadGroupParticipants] Все участники уже в кэше');
        return;
      }

      print(
        '📡 [_loadGroupParticipants] Загружаем информацию о ${idsToFetch.length} участниках...',
      );
      print(
        '📡 [_loadGroupParticipants] IDs для загрузки: ${idsToFetch.take(10).join(', ')}${idsToFetch.length > 10 ? '...' : ''}',
      );

      final contacts = await ApiService.instance.fetchContactsByIds(idsToFetch);

      print(
        '📦 [_loadGroupParticipants] Получено ${contacts.length} контактов от API из ${idsToFetch.length} запрошенных',
      );

      if (contacts.isNotEmpty) {
        for (final contact in contacts) {
          print('  📇 Контакт: ${contact.name} (ID: ${contact.id})');
        }

        if (mounted) {
          setState(() {
            for (final contact in contacts) {
              _contactDetailsCache[contact.id] = contact;
            }
          });

          await ChatCacheService().cacheChatContacts(widget.chatId, contacts);

          print(
            '✅ [_loadGroupParticipants] Загружено и сохранено ${contacts.length} контактов',
          );
          print(
            '✅ [_loadGroupParticipants] Всего в кэше теперь: ${_contactDetailsCache.length} контактов',
          );

          if (contacts.length < idsToFetch.length) {
            final receivedIds = contacts.map((c) => c.id).toSet();
            final missingIds = idsToFetch
                .where((id) => !receivedIds.contains(id))
                .toList();
            print(
              '⚠️ [_loadGroupParticipants] Не получены данные для ${missingIds.length} контактов из ${idsToFetch.length} запрошенных',
            );
            print(
              '⚠️ [_loadGroupParticipants] Отсутствующие ID: ${missingIds.take(10).join(', ')}${missingIds.length > 10 ? '...' : ''}',
            );
          }
        } else {
          print(
            '⚠️ [_loadGroupParticipants] Widget не mounted, контакты не сохранены',
          );
        }
      } else {
        print('❌ [_loadGroupParticipants] API вернул ПУСТОЙ список контактов!');
        print(
          '❌ [_loadGroupParticipants] Было запрошено ${idsToFetch.length} ID',
        );
        print(
          '❌ [_loadGroupParticipants] Запрошенные ID: ${idsToFetch.take(10).join(', ')}${idsToFetch.length > 10 ? '...' : ''}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ [_loadGroupParticipants] Ошибка загрузки участников группы: $e');
      print('❌ [_loadGroupParticipants] StackTrace: $stackTrace');
    }
  }

  @override
  void initState() {
    super.initState();
    _initialUnreadCount = widget.initialUnreadCount;
    _currentContact = widget.contact;
    _pinnedMessage =
        null; 
    _initializeChat();
    _loadEncryptionConfig();
    _loadSpecialMessagesSetting();

    _textController.addListener(() {
      _handleTextChangedForKometColor();
      _updateTextSelectionState();
    });

    _textFocusNode.addListener(() {
      if (_textFocusNode.hasFocus) {
        _startSelectionCheck();
      } else {
        _stopSelectionCheck();
        setState(() {
          _hasTextSelection = false;
        });
      }
    });
  }

  Future<void> _loadSpecialMessagesSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _specialMessagesEnabled =
          prefs.getBool('special_messages_enabled') ?? true;
    });
  }

  void _showSpecialMessagesPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Особые сообщения',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _SpecialMessageButton(
              label: 'Цветной текст',
              template: "komet.color_#''",
              icon: Icons.color_lens,
              onTap: () {
                Navigator.pop(context);
                Future.microtask(() {
                  if (!mounted) return;
                  final currentText = _textController.text;
                  final cursorPos = _textController.selection.baseOffset.clamp(
                    0,
                    currentText.length,
                  );
                  final template = "komet.color_#";
                  final newText =
                      currentText.substring(0, cursorPos) +
                      template +
                      currentText.substring(cursorPos);
                  _textController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: cursorPos + template.length - 2,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 8),
            _SpecialMessageButton(
              label: 'Переливающийся текст',
              template: "komet.cosmetic.galaxy' ваш текст '",
              icon: Icons.auto_awesome,
              onTap: () {
                Navigator.pop(context);
                Future.microtask(() {
                  if (!mounted) return;
                  final currentText = _textController.text;
                  final cursorPos = _textController.selection.baseOffset.clamp(
                    0,
                    currentText.length,
                  );
                  final template = "komet.cosmetic.galaxy' ваш текст '";
                  final newText =
                      currentText.substring(0, cursorPos) +
                      template +
                      currentText.substring(cursorPos);
                  _textController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: cursorPos + template.length - 2,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 8),
            _SpecialMessageButton(
              label: 'Пульсирующий текст',
              template: "komet.cosmetic.pulse#",
              icon: Icons.radio_button_checked,
              onTap: () {
                Navigator.pop(context);
                Future.microtask(() {
                  if (!mounted) return;
                  final currentText = _textController.text;
                  final cursorPos = _textController.selection.baseOffset.clamp(
                    0,
                    currentText.length,
                  );
                  final template = "komet.cosmetic.pulse#";
                  final newText =
                      currentText.substring(0, cursorPos) +
                      template +
                      currentText.substring(cursorPos);
                  _textController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: cursorPos + template.length,
                    ),
                  );
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTextChangedForKometColor() async {
    final prefs = await SharedPreferences.getInstance();
    final autoCompleteEnabled =
        prefs.getBool('komet_auto_complete_enabled') ?? false;

    if (!autoCompleteEnabled) {
      if (_showKometColorPicker) {
        setState(() {
          _showKometColorPicker = false;
          _currentKometColorPrefix = null;
        });
      }
      return;
    }

    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    const prefix1 = 'komet.color_#';
    const prefix2 = 'komet.cosmetic.pulse#';

    
    String? detectedPrefix;
    int? prefixStartPos;

    
    for (final prefix in [prefix1, prefix2]) {
      
      int searchStart = 0;
      int lastFound = -1;
      while (true) {
        final found = text.indexOf(prefix, searchStart);
        if (found == -1 || found > cursorPos) break;
        if (found + prefix.length <= cursorPos) {
          lastFound = found;
        }
        searchStart = found + 1;
      }

      if (lastFound != -1) {
        final afterPrefix = text.substring(
          lastFound + prefix.length,
          cursorPos,
        );
        
        if (afterPrefix.isEmpty || afterPrefix.trim().isEmpty) {
          
          final afterCursor = cursorPos < text.length
              ? text.substring(cursorPos)
              : '';
          
          if (afterCursor.length < 7 ||
              !RegExp(r"^[0-9A-Fa-f]{6}'").hasMatch(afterCursor)) {
            detectedPrefix = prefix;
            prefixStartPos = lastFound;
            break;
          }
        }
      }
    }

    if (detectedPrefix != null && prefixStartPos != null) {
      final after = text.substring(
        prefixStartPos + detectedPrefix.length,
        cursorPos,
      );
      
      if (after.isEmpty || after.trim().isEmpty) {
        if (!_showKometColorPicker ||
            _currentKometColorPrefix != detectedPrefix) {
          setState(() {
            _showKometColorPicker = true;
            _currentKometColorPrefix = detectedPrefix;
          });
        }
        return;
      }
    }

    if (_showKometColorPicker) {
      setState(() {
        _showKometColorPicker = false;
        _currentKometColorPrefix = null;
      });
    }
  }

  Future<void> _loadEncryptionConfig() async {
    final cfg = await ChatEncryptionService.getConfigForChat(widget.chatId);
    if (!mounted) return;
    setState(() {
      _encryptionConfigForCurrentChat = cfg;
      _isEncryptionPasswordSetForCurrentChat =
          cfg != null && cfg.password.isNotEmpty;
      _sendEncryptedForCurrentChat = cfg?.sendEncrypted ?? true;
    });
  }

  Future<void> _initializeChat() async {
    await _loadCachedContacts();
    final prefs = await SharedPreferences.getInstance();

    if (!widget.isGroupChat && !widget.isChannel) {
      _contactDetailsCache[widget.contact.id] = widget.contact;
      print(
        '✅ [_initializeChat] Собеседник добавлен в кэш: ${widget.contact.name} (ID: ${widget.contact.id})',
      );
    }

    final profileData = ApiService.instance.lastChatsPayload?['profile'];
    final contactProfile = profileData?['contact'] as Map<String, dynamic>?;

    if (contactProfile != null &&
        contactProfile['id'] != null &&
        contactProfile['id'] != 0) {
      String? idStr = prefs.getString("userId");
      _actualMyId = idStr!.isNotEmpty ? int.parse(idStr) : contactProfile['id'];
      print(
        '✅ [_initializeChat] ID пользователя получен из ApiService: $_actualMyId',
      );

      try {
        final myContact = Contact.fromJson(contactProfile);
        _contactDetailsCache[_actualMyId!] = myContact;
        print(
          '✅ [_initializeChat] Собственный профиль добавлен в кэш: ${myContact.name} (ID: $_actualMyId)',
        );
      } catch (e) {
        print(
          '⚠️ [_initializeChat] Не удалось добавить собственный профиль в кэш: $e',
        );
      }
    } else if (_actualMyId == null) {
      final prefs = await SharedPreferences.getInstance();
      _actualMyId = int.parse(prefs.getString('userId')!);
      print(
        '⚠️ [_initializeChat] ID не найден, используется из виджета: $_actualMyId',
      );
    } else {
      print('✅ [_initializeChat] Используется ID из кэша: $_actualMyId');
    }

    if (!widget.isGroupChat && !widget.isChannel) {
      final contactsToCache = _contactDetailsCache.values.toList();
      await ChatCacheService().cacheChatContacts(
        widget.chatId,
        contactsToCache,
      );
      print(
        '✅ [_initializeChat] Сохранено ${contactsToCache.length} контактов в кэш чата (включая собственный профиль)',
      );
    }

    if (mounted) {
      setState(() {
        _isIdReady = true;
      });
    }

    _loadContactDetails();
    _checkContactCache();

    if (!ApiService.instance.isContactCacheValid()) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ApiService.instance.getBlockedContacts();
        }
      });
    }

    ApiService.instance.contactUpdates.listen((contact) {
      if (widget.chatId == 0) {
        return;
      }
      if (contact.id == _currentContact.id && mounted) {
        ApiService.instance.updateCachedContact(contact);
        
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _currentContact = contact;
            });
          }
        });
      }
    });

    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        
        
        final bottomItemPosition = positions.firstWhere(
          (p) => p.index == 0,
          orElse: () => positions.first,
        );

        
        
        final isBottomItemVisible = bottomItemPosition.index == 0;
        final isAtBottom =
            isBottomItemVisible && bottomItemPosition.itemTrailingEdge >= 0.9;

        _isUserAtBottom = isAtBottom;

        
        if (isAtBottom) {
          _isScrollingToBottom = false;
        }

        
        
        
        
        final shouldShowArrow = !isAtBottom && !_isScrollingToBottom;
        _showScrollToBottomNotifier.value = shouldShowArrow;

        
        
        if (positions.isNotEmpty && _chatItems.isNotEmpty) {
          final maxIndex = positions
              .map((p) => p.index)
              .reduce((a, b) => a > b ? a : b);
          
          final threshold = _chatItems.length > 5
              ? 3
              : 1; 
          final isNearTop = maxIndex >= _chatItems.length - threshold;

          
          if (isNearTop &&
              _hasMore &&
              !_isLoadingMore &&
              _messages.isNotEmpty &&
              _oldestLoadedTime != null) {
            print(
              '📜 Пользователь доскроллил близко к верху (maxIndex: $maxIndex, total: ${_chatItems.length}), загружаем старые сообщения...',
            );
            
            Future.microtask(() {
              if (mounted && _hasMore && !_isLoadingMore) {
                _loadMore();
              }
            });
          }
        }
      }
    });

    _searchController.addListener(() {
      if (_searchController.text.isEmpty && _searchResults.isNotEmpty) {
        
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _searchResults.clear();
              _currentResultIndex = -1;
            });
          }
        });
      } else if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    });

    _loadHistoryAndListen();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact.id != widget.contact.id) {
      _currentContact = widget.contact;
      _checkContactCache();
      if (!ApiService.instance.isContactCacheValid()) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            ApiService.instance.getBlockedContacts();
          }
        });
      }
    }
  }

  void _loadHistoryAndListen() {
    _paginateInitialLoad();

    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      final opcode = message['opcode'];
      final cmd = message['cmd'];
      final payload = message['payload'];

      if (payload == null) return;

      final dynamic incomingChatId = payload['chatId'];
      final int? chatIdNormalized = incomingChatId is int
          ? incomingChatId
          : int.tryParse(incomingChatId?.toString() ?? '');

      if (opcode == 64 && cmd == 1) {
        if (chatIdNormalized == widget.chatId) {
          final newMessage = Message.fromJson(payload['message']);
          print(
            'Получено подтверждение (Opcode 64) для cid: ${newMessage.cid}. Обновляем сообщение.',
          );
          
          Future.microtask(() {
            if (mounted) {
              _updateMessage(newMessage);
            }
          });
        }
      } else if (opcode == 128) {
        if (chatIdNormalized == widget.chatId) {
          final newMessage = Message.fromJson(payload['message']);
          
          Future.microtask(() {
            if (!mounted) return;
            final hasSameId = _messages.any((m) => m.id == newMessage.id);
            final hasSameCid =
                newMessage.cid != null &&
                _messages.any((m) => m.cid != null && m.cid == newMessage.cid);
            if (hasSameId || hasSameCid) {
              _updateMessage(newMessage);
            } else {
              _addMessage(newMessage);
            }
          });
        }
      } else if (opcode == 129) {
        if (chatIdNormalized == widget.chatId) {
          print('Пользователь печатает в чате $chatIdNormalized');
        }
      } else if (opcode == 132) {
        if (chatIdNormalized == widget.chatId) {
          print('Обновлен статус присутствия для чата $chatIdNormalized');

          final dynamic contactIdAny =
              payload['contactId'] ?? payload['userId'];
          if (contactIdAny != null) {
            final int? cid = contactIdAny is int
                ? contactIdAny
                : int.tryParse(contactIdAny.toString());
            if (cid != null) {
              final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final isOnline = payload['online'] == true;
              final userPresence = {
                'seen': currentTime,
                'on': isOnline ? 'ON' : 'OFF',
              };
              ApiService.instance.updatePresenceData({
                cid.toString(): userPresence,
              });

              print(
                'Обновлен presence для пользователя $cid: online=$isOnline, seen=$currentTime',
              );

              
              Future.microtask(() {
                if (mounted) {
                  setState(() {});
                }
              });
            }
          }
        }
      } else if (opcode == 67) {
        if (chatIdNormalized == widget.chatId) {
          final editedMessage = Message.fromJson(payload['message']);
          
          Future.microtask(() {
            if (mounted) {
              _updateMessage(editedMessage);
            }
          });
        }
      } else if (opcode == 66) {
        if (chatIdNormalized == widget.chatId) {
          final deletedMessageIds = List<String>.from(
            payload['messageIds'] ?? [],
          );
          
          Future.microtask(() {
            if (mounted) {
              _removeMessages(deletedMessageIds);
            }
          });
        }
      } else if (opcode == 178) {
        
        if (cmd == 1) {
          if (_sendingReactions.isNotEmpty) {
            _sendingReactions.clear();
            
            Future.microtask(() {
              if (mounted) {
                setState(() {});
              }
            });
          }
        }
        
        if (cmd == 0 && chatIdNormalized == widget.chatId) {
          final messageId = payload['messageId'] as String?;
          final reactionInfo = payload['reactionInfo'] as Map<String, dynamic>?;
          if (messageId != null && reactionInfo != null) {
            
            Future.microtask(() {
              if (mounted) {
                _updateMessageReaction(messageId, reactionInfo);
              }
            });
          }
        }
      } else if (opcode == 179) {
        if (chatIdNormalized == widget.chatId) {
          final messageId = payload['messageId'] as String?;
          final reactionInfo = payload['reactionInfo'] as Map<String, dynamic>?;
          if (messageId != null) {
            
            Future.microtask(() {
              if (mounted) {
                _updateMessageReaction(messageId, reactionInfo ?? {});
              }
            });
          }
        }
      } else if (opcode == 50) {
        
        
        
        if (chatIdNormalized == widget.chatId) {
          print(
            'Получен opcode 50 для чата ${widget.chatId}, игнорируем в ChatScreen',
          );
        }
      }
    });
  }

  static const int _pageSize = 50;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int? _oldestLoadedTime;

  bool get _optimize => context.read<ThemeProvider>().optimizeChats;
  bool get _ultraOptimize => context.read<ThemeProvider>().ultraOptimizeChats;
  bool get _anyOptimize => _optimize || _ultraOptimize;

  int get _optPage => _ultraOptimize ? 10 : (_optimize ? 50 : _pageSize);

  Future<void> _paginateInitialLoad() async {
    setState(() => _isLoadingHistory = true);

    final chatCacheService = ChatCacheService();
    List<Message>? cachedMessages = await chatCacheService
        .getCachedChatMessages(widget.chatId);

    bool hasCache = cachedMessages != null && cachedMessages.isNotEmpty;
    if (hasCache) {
      print("✅ Показываем ${cachedMessages.length} сообщений из кэша...");
      if (!mounted) return;
      _messages.clear();
      _messages.addAll(cachedMessages);

      
      if (_messages.isNotEmpty) {
        _oldestLoadedTime = _messages.first.time;
        
        _hasMore = true;
        print(
          '📜 Загружено из кэша: ${_messages.length} сообщений, _oldestLoadedTime=$_oldestLoadedTime',
        );
      }

      if (widget.isGroupChat) {
        await _loadGroupParticipants();
      }

      _buildChatItems();
      
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _isLoadingHistory = false;
          });
        }
      });
      _updatePinnedMessage();

      
      if (_messages.isEmpty && !widget.isChannel) {
        _loadEmptyChatSticker();
      }
    }

    try {
      print("📡 Запрашиваем актуальные сообщения с сервера...");
      final allMessages = await ApiService.instance.getMessageHistory(
        widget.chatId,
        force: true,
      );
      if (!mounted) return;
      print("✅ Получено ${allMessages.length} сообщений с сервера.");

      final Set<int> senderIds = {};
      for (final message in allMessages) {
        senderIds.add(message.senderId);

        if (message.isReply && message.link?['message']?['sender'] != null) {
          final replySenderId = message.link!['message']!['sender'];
          if (replySenderId is int) {
            senderIds.add(replySenderId);
          }
        }
      }
      senderIds.remove(0); 

      final idsToFetch = senderIds
          .where((id) => !_contactDetailsCache.containsKey(id))
          .toList();

      if (idsToFetch.isNotEmpty) {
        print(
          '📡 [_paginateInitialLoad] Загружаем ${idsToFetch.length} отсутствующих контактов из ${senderIds.length} отправителей...',
        );
        print(
          '📡 [_paginateInitialLoad] В кэше: ${senderIds.length - idsToFetch.length}, нужно загрузить: ${idsToFetch.length}',
        );
        print(
          '📡 [_paginateInitialLoad] IDs для загрузки: ${idsToFetch.take(10).join(', ')}${idsToFetch.length > 10 ? '...' : ''}',
        );
        final newContacts = await ApiService.instance.fetchContactsByIds(
          idsToFetch,
        );

        for (final contact in newContacts) {
          _contactDetailsCache[contact.id] = contact;
        }

        if (newContacts.isNotEmpty) {
          final allChatContacts = _contactDetailsCache.values.toList();
          await ChatCacheService().cacheChatContacts(
            widget.chatId,
            allChatContacts,
          );
          print(
            '✅ [_paginateInitialLoad] Обновлен кэш: ${allChatContacts.length} контактов для чата ${widget.chatId}',
          );
        }
      } else {
        print(
          '✅ [_paginateInitialLoad] Все ${senderIds.length} отправителей уже в кэше',
        );
      }

      await chatCacheService.cacheChatMessages(widget.chatId, allMessages);

      if (widget.isGroupChat) {
        await _loadGroupParticipants();
      }

      final page = _anyOptimize ? _optPage : _pageSize;
      final slice = allMessages.length > page
          ? allMessages.sublist(allMessages.length - page)
          : allMessages;

      
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(slice);
            _oldestLoadedTime = _messages.isNotEmpty
                ? _messages.first.time
                : null;
            
            
            _hasMore =
                allMessages.length >= 1000 ||
                allMessages.length > _messages.length;
            print(
              '📜 Первая загрузка: загружено ${allMessages.length} сообщений, показано ${_messages.length}, _hasMore=$_hasMore, _oldestLoadedTime=$_oldestLoadedTime',
            );

            _buildChatItems();
            _isLoadingHistory = false;
          });
        }
      });

      
      
      _jumpToBottom();
      _updatePinnedMessage();

      
      if (_messages.isEmpty && !widget.isChannel) {
        _loadEmptyChatSticker();
      }
    } catch (e) {
      print("❌ Ошибка при загрузке с сервера: $e");
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
        
      }
    }

    final readSettings = await ChatReadSettingsService.instance.getSettings(
      widget.chatId,
    );
    final theme = context.read<ThemeProvider>();

    final shouldReadOnEnter = readSettings != null
        ? (!readSettings.disabled && readSettings.readOnEnter)
        : theme.debugReadOnEnter;

    if (shouldReadOnEnter && _messages.isNotEmpty) {
      final lastMessageId = _messages.last.id;
      ApiService.instance.markMessageAsRead(widget.chatId, lastMessageId);
    }
  }

  Future<void> _loadMore() async {
    print(
      '📜 _loadMore() вызвана: _isLoadingMore=$_isLoadingMore, _hasMore=$_hasMore, _oldestLoadedTime=$_oldestLoadedTime',
    );

    if (_isLoadingMore || !_hasMore) {
      print(
        '📜 _loadMore() пропущена: _isLoadingMore=$_isLoadingMore, _hasMore=$_hasMore',
      );
      return;
    }

    if (_messages.isEmpty || _oldestLoadedTime == null) {
      print(
        '📜 _loadMore() пропущена: _messages.isEmpty=${_messages.isEmpty}, _oldestLoadedTime=$_oldestLoadedTime',
      );
      _hasMore = false;
      return;
    }

    _isLoadingMore = true;
    setState(() {});

    try {
      print(
        '📜 Загружаем старые сообщения для chatId=${widget.chatId}, fromTimestamp=$_oldestLoadedTime',
      );
      
      final olderMessages = await ApiService.instance
          .loadOlderMessagesByTimestamp(
            widget.chatId,
            _oldestLoadedTime!,
            backward: 30,
          );

      print('📜 Получено ${olderMessages.length} старых сообщений');

      if (!mounted) return;

      if (olderMessages.isEmpty) {
        
        _hasMore = false;
        _isLoadingMore = false;
        setState(() {});
        return;
      }

      
      final existingMessageIds = _messages.map((m) => m.id).toSet();
      final newMessages = olderMessages
          .where((m) => !existingMessageIds.contains(m.id))
          .toList();

      if (newMessages.isEmpty) {
        
        _hasMore = false;
        _isLoadingMore = false;
        setState(() {});
        return;
      }

      print(
        '📜 Добавляем ${newMessages.length} новых старых сообщений (отфильтровано ${olderMessages.length - newMessages.length} дубликатов)',
      );

      
      _messages.insertAll(0, newMessages);
      _oldestLoadedTime = _messages.first.time;

      
      _hasMore = olderMessages.length >= 30;

      _buildChatItems();
      _isLoadingMore = false;

      if (mounted) {
        setState(() {});
      }

      _updatePinnedMessage();
    } catch (e) {
      print('❌ Ошибка при загрузке старых сообщений: $e');
      if (mounted) {
        _isLoadingMore = false;
        _hasMore = false;
        setState(() {});
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isMessageGrouped(Message currentMessage, Message? previousMessage) {
    if (previousMessage == null) return false;

    final currentTime = DateTime.fromMillisecondsSinceEpoch(
      currentMessage.time,
    );
    final previousTime = DateTime.fromMillisecondsSinceEpoch(
      previousMessage.time,
    );

    final timeDifference = currentTime.difference(previousTime).inMinutes;

    return currentMessage.senderId == previousMessage.senderId &&
        timeDifference <= 5;
  }

  void _buildChatItems() {
    final List<ChatItem> items = [];
    final source = _messages;

    for (int i = 0; i < source.length; i++) {
      final currentMessage = source[i];
      final previousMessage = (i > 0) ? source[i - 1] : null;

      final currentDate = DateTime.fromMillisecondsSinceEpoch(
        currentMessage.time,
      ).toLocal();
      final previousDate = previousMessage != null
          ? DateTime.fromMillisecondsSinceEpoch(previousMessage.time).toLocal()
          : null;

      if (previousMessage == null || !_isSameDay(currentDate, previousDate!)) {
        items.add(DateSeparatorItem(currentDate));
      }

      final isGrouped = _isMessageGrouped(currentMessage, previousMessage);

      final isFirstInGroup =
          previousMessage == null ||
          !_isMessageGrouped(currentMessage, previousMessage);

      final isLastInGroup =
          i == source.length - 1 ||
          !_isMessageGrouped(source[i + 1], currentMessage);

      items.add(
        MessageItem(
          currentMessage,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          isGrouped: isGrouped,
        ),
      );
    }
    _chatItems = items;

    
    final currentMessageIds = _messages.map((m) => m.id).toSet();
    final keysToRemove = _messageKeys.keys
        .where((id) => !currentMessageIds.contains(id))
        .toList();
    for (final id in keysToRemove) {
      _messageKeys.remove(id);
    }
    if (keysToRemove.isNotEmpty) {
      print('📜 Очищено ${keysToRemove.length} ключей для удаленных сообщений');
    }
  }

  Future<void> _loadEmptyChatSticker() async {
    try {
      
      final availableStickerIds = [272821, 295349, 13571];
      
      final random =
          DateTime.now().millisecondsSinceEpoch % availableStickerIds.length;
      final selectedStickerId = availableStickerIds[random];

      print('🎨 Загружаем стикер для пустого чата (ID: $selectedStickerId)...');
      final seq = ApiService.instance.sendRawRequest(28, {
        "type": "STICKER",
        "ids": [selectedStickerId],
      });

      if (seq == -1) {
        print('❌ Не удалось отправить запрос на получение стикера');
        return;
      }

      final response = await ApiService.instance.messages
          .firstWhere(
            (msg) => msg['seq'] == seq && msg['opcode'] == 28,
            orElse: () => <String, dynamic>{},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'Превышено время ожидания ответа от сервера',
            ),
          );

      if (response.isEmpty || response['payload'] == null) {
        print('❌ Не получен ответ от сервера для стикера');
        return;
      }

      final stickers = response['payload']['stickers'] as List?;
      print('🎨 Получен ответ со стикерами: ${stickers?.length ?? 0}');
      if (stickers != null && stickers.isNotEmpty) {
        final sticker = stickers.first as Map<String, dynamic>;
        
        final stickerId = sticker['id'] as int?;
        print(
          '🎨 Данные стикера: id=$stickerId, url=${sticker['url']}, lottieUrl=${sticker['lottieUrl']}, width=${sticker['width']}, height=${sticker['height']}',
        );
        if (mounted) {
          setState(() {
            _emptyChatSticker = {
              ...sticker,
              'stickerId': stickerId, 
            };
          });
          print(
            '✅ Стикер для пустого чата загружен и сохранен (ID: $stickerId)',
          );
        }
      } else {
        print('❌ Стикеры не найдены в ответе');
      }
    } catch (e) {
      print('❌ Ошибка при загрузке стикера для пустого чата: $e');
    }
  }

  void _updatePinnedMessage() {
    Message? latestPinned;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      final controlAttach = message.attaches.firstWhere(
        (a) => a['_type'] == 'CONTROL',
        orElse: () => const {},
      );
      if (controlAttach.isNotEmpty && controlAttach['event'] == 'pin') {
        final pinnedMessageData = controlAttach['pinnedMessage'];
        if (pinnedMessageData != null &&
            pinnedMessageData is Map<String, dynamic>) {
          try {
            latestPinned = Message.fromJson(pinnedMessageData);
            print('Найдено закрепленное сообщение: ${latestPinned.text}');
            break;
          } catch (e) {
            print('Ошибка парсинга закрепленного сообщения: $e');
          }
        }
      }
    }
    if (mounted) {
      setState(() {
        _pinnedMessage = latestPinned;
        if (latestPinned != null) {
          print('Закрепленное сообщение установлено: ${latestPinned.text}');
        } else {
          print('Закрепленное сообщение не найдено');
        }
      });
    }
  }

  void _scrollToPinnedMessage() {
    final pinned = _pinnedMessage;
    if (pinned == null) return;

    
    int? targetChatItemIndex;
    for (int i = 0; i < _chatItems.length; i++) {
      final item = _chatItems[i];
      if (item is MessageItem) {
        final msg = item.message;
        if (msg.id == pinned.id ||
            (msg.cid != null && pinned.cid != null && msg.cid == pinned.cid)) {
          targetChatItemIndex = i;
          break;
        }
      }
    }

    if (targetChatItemIndex == null) {
      
      return;
    }

    if (!_itemScrollController.isAttached) return;

    
    
    final visualIndex = _chatItems.length - 1 - targetChatItemIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: visualIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _addMessage(Message message, {bool forceScroll = false}) {
    if (_messages.any((m) => m.id == message.id)) {
      print('Сообщение ${message.id} уже существует, пропускаем добавление');
      return;
    }

    ApiService.instance.clearCacheForChat(widget.chatId);

    final wasAtBottom = _isUserAtBottom;

    final isMyMessage = message.senderId == _actualMyId;

    final lastMessage = _messages.isNotEmpty ? _messages.last : null;
    _messages.add(message);

    final currentDate = DateTime.fromMillisecondsSinceEpoch(
      message.time,
    ).toLocal();
    final lastDate = lastMessage != null
        ? DateTime.fromMillisecondsSinceEpoch(lastMessage.time).toLocal()
        : null;

    if (lastMessage == null || !_isSameDay(currentDate, lastDate!)) {
      final separator = DateSeparatorItem(currentDate);
      _chatItems.add(separator);
    }

    final lastMessageItem =
        _chatItems.isNotEmpty && _chatItems.last is MessageItem
        ? _chatItems.last as MessageItem
        : null;

    final isGrouped = _isMessageGrouped(message, lastMessageItem?.message);
    final isFirstInGroup = lastMessageItem == null || !isGrouped;
    final isLastInGroup = true;

    if (isGrouped && lastMessageItem != null) {
      _chatItems.removeLast();
      _chatItems.add(
        MessageItem(
          lastMessageItem.message,
          isFirstInGroup: lastMessageItem.isFirstInGroup,
          isLastInGroup: false,
          isGrouped: lastMessageItem.isGrouped,
        ),
      );
    }

    final messageItem = MessageItem(
      message,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      isGrouped: isGrouped,
    );
    _chatItems.add(messageItem);

    
    _updatePinnedMessage();

    final theme = context.read<ThemeProvider>();
    if (theme.messageTransition == TransitionOption.slide) {
      print('Добавлено новое сообщение для анимации Slide+: ${message.id}');
    } else {
      _animatedMessageIds.add(message.id);
    }

    
    Future.microtask(() {
      if (mounted) {
        setState(() {});

        if ((wasAtBottom || isMyMessage || forceScroll) &&
            _itemScrollController.isAttached) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_itemScrollController.isAttached) {
              _itemScrollController.jumpTo(index: 0);
            }
          });
        }
      }
    });
  }

  void _updateMessageReaction(
    String messageId,
    Map<String, dynamic> reactionInfo,
  ) {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final message = _messages[messageIndex];
      final updatedMessage = message.copyWith(reactionInfo: reactionInfo);
      _messages[messageIndex] = updatedMessage;

      
      if (_sendingReactions.remove(messageId)) {
        print(
          '✅ Реакция для сообщения $messageId успешно подтверждена сервером',
        );
      }

      _buildChatItems();

      print('Обновлена реакция для сообщения $messageId: $reactionInfo');

      
      Future.microtask(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _updateReactionOptimistically(String messageId, String emoji) {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final message = _messages[messageIndex];
      final currentReactionInfo = message.reactionInfo ?? {};
      final currentCounters = List<Map<String, dynamic>>.from(
        currentReactionInfo['counters'] ?? [],
      );

      final existingCounterIndex = currentCounters.indexWhere(
        (counter) => counter['reaction'] == emoji,
      );

      if (existingCounterIndex != -1) {
        currentCounters[existingCounterIndex]['count'] =
            (currentCounters[existingCounterIndex]['count'] as int) + 1;
      } else {
        currentCounters.add({'reaction': emoji, 'count': 1});
      }

      final updatedReactionInfo = {
        ...currentReactionInfo,
        'counters': currentCounters,
        'yourReaction': emoji,
        'totalCount': currentCounters.fold<int>(
          0,
          (sum, counter) => sum + (counter['count'] as int),
        ),
      };

      final updatedMessage = message.copyWith(
        reactionInfo: updatedReactionInfo,
      );
      _messages[messageIndex] = updatedMessage;

      
      _sendingReactions.add(messageId);

      _buildChatItems();

      print('Оптимистично добавлена реакция $emoji к сообщению $messageId');

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _removeReactionOptimistically(String messageId) {
    final messageIndex = _messages.indexWhere((m) => m.id == messageId);
    if (messageIndex != -1) {
      final message = _messages[messageIndex];
      final currentReactionInfo = message.reactionInfo ?? {};
      final yourReaction = currentReactionInfo['yourReaction'] as String?;

      if (yourReaction != null) {
        final currentCounters = List<Map<String, dynamic>>.from(
          currentReactionInfo['counters'] ?? [],
        );

        final counterIndex = currentCounters.indexWhere(
          (counter) => counter['reaction'] == yourReaction,
        );

        if (counterIndex != -1) {
          final currentCount = currentCounters[counterIndex]['count'] as int;
          if (currentCount > 1) {
            currentCounters[counterIndex]['count'] = currentCount - 1;
          } else {
            currentCounters.removeAt(counterIndex);
          }
        }

        final updatedReactionInfo = {
          ...currentReactionInfo,
          'counters': currentCounters,
          'yourReaction': null,
          'totalCount': currentCounters.fold<int>(
            0,
            (sum, counter) => sum + (counter['count'] as int),
          ),
        };

        final updatedMessage = message.copyWith(
          reactionInfo: updatedReactionInfo,
        );
        _messages[messageIndex] = updatedMessage;

        
        _sendingReactions.add(messageId);

        _buildChatItems();

        print('Оптимистично удалена реакция с сообщения $messageId');

        
        Future.microtask(() {
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  void _updateMessage(Message updatedMessage) {
    final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
    if (index != -1) {
      print(
        'Обновляем сообщение ${updatedMessage.id}: "${_messages[index].text}" -> "${updatedMessage.text}"',
      );

      final oldMessage = _messages[index];
      final finalMessage = updatedMessage.link != null
          ? updatedMessage
          : updatedMessage.copyWith(link: oldMessage.link);

      print('Обновляем link: ${oldMessage.link} -> ${finalMessage.link}');

      _messages[index] = finalMessage;
      ApiService.instance.clearCacheForChat(widget.chatId);
      _buildChatItems();
      
      Future.microtask(() {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      print(
        'Сообщение ${updatedMessage.id} не найдено для обновления. Запрашиваем свежую историю...',
      );
      ApiService.instance
          .getMessageHistory(widget.chatId, force: true)
          .then((fresh) {
            if (!mounted) return;
            _messages
              ..clear()
              ..addAll(fresh);
            _buildChatItems();
            
            Future.microtask(() {
              if (mounted) {
                setState(() {});
              }
            });
          })
          .catchError((_) {});
    }
  }

  void _removeMessages(List<String> messageIds) {
    print('Удаляем сообщения: $messageIds');
    final removedCount = _messages.length;
    _messages.removeWhere((message) => messageIds.contains(message.id));
    final actuallyRemoved = removedCount - _messages.length;
    print('Удалено сообщений: $actuallyRemoved');

    if (actuallyRemoved > 0) {
      ApiService.instance.clearCacheForChat(widget.chatId);
      _buildChatItems();
      
      Future.microtask(() {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _sendEmptyChatSticker() async {
    if (_emptyChatSticker == null) {
      print('❌ Стикер не загружен, невозможно отправить');
      return;
    }

    final stickerId = _emptyChatSticker!['stickerId'] as int?;
    if (stickerId == null) {
      print('❌ ID стикера не найден');
      return;
    }

    try {
      print('🎨 Отправляем стикер (ID: $stickerId) в чат ${widget.chatId}');
      final cid = DateTime.now().millisecondsSinceEpoch;

      final payload = {
        "chatId": widget.chatId,
        "message": {
          "cid": cid,
          "attaches": [
            {"_type": "STICKER", "stickerId": stickerId},
          ],
        },
        "notify": true,
      };

      ApiService.instance.sendRawRequest(64, payload);
      print('✅ Стикер отправлен (opcode 64, cid: $cid)');
    } catch (e) {
      print('❌ Ошибка при отправке стикера: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отправке стикера: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyTextFormat(String type) {
    final isEncryptionActive =
        _encryptionConfigForCurrentChat != null &&
        _encryptionConfigForCurrentChat!.password.isNotEmpty &&
        _sendEncryptedForCurrentChat;
    if (isEncryptionActive) {
      setState(() {
        _formatWarningVisible = true;
      });
      return;
    }
    final selection = _textController.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final from = selection.start;
    final length = selection.end - selection.start;
    if (length <= 0) return;

    setState(() {
      _textController.elements.add({
        'type': type,
        'from': from,
        'length': length,
      });
      _textController.selection = selection;
    });
  }

  void _updateTextSelectionState() {
    final selection = _textController.selection;
    final hasSelection =
        selection.isValid &&
        !selection.isCollapsed &&
        selection.end > selection.start;
    if (_hasTextSelection != hasSelection) {
      setState(() {
        _hasTextSelection = hasSelection;
      });
    }
  }

  void _startSelectionCheck() {
    _stopSelectionCheck();
    _selectionCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!_textFocusNode.hasFocus) {
        _stopSelectionCheck();
        return;
      }
      _updateTextSelectionState();
    });
  }

  void _stopSelectionCheck() {
    _selectionCheckTimer?.cancel();
    _selectionCheckTimer = null;
  }

  void _resetDraftFormattingIfNeeded(String newText) {
    if (newText.isEmpty) {
      _textController.elements.clear();
    }
  }

  Future<void> _sendMessage() async {
    final originalText = _textController.text.trim();
    if (originalText.isNotEmpty) {
      final theme = context.read<ThemeProvider>();
      final isBlocked = _currentContact.isBlockedByMe && !theme.blockBypass;

      if (isBlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Нельзя отправить сообщение заблокированному пользователю',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      
      
      if (_encryptionConfigForCurrentChat != null &&
          _encryptionConfigForCurrentChat!.password.isNotEmpty &&
          _sendEncryptedForCurrentChat &&
          (originalText == 'kometSM' || originalText == 'kometSM.')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Нее, так нельзя)')));
        return;
      }

      
      String textToSend = originalText;
      if (_encryptionConfigForCurrentChat != null &&
          _encryptionConfigForCurrentChat!.password.isNotEmpty &&
          _sendEncryptedForCurrentChat &&
          !ChatEncryptionService.isEncryptedMessage(originalText)) {
        textToSend = ChatEncryptionService.encryptWithPassword(
          _encryptionConfigForCurrentChat!.password,
          originalText,
        );
      }

      if (textToSend != originalText) {
        _textController.elements.clear();
      }

      final int tempCid = DateTime.now().millisecondsSinceEpoch;
      final List<Map<String, dynamic>> tempElements =
          List<Map<String, dynamic>>.from(_textController.elements);
      final tempMessageJson = {
        'id': 'local_$tempCid',
        'text': textToSend,
        'time': tempCid,
        'sender': _actualMyId!,
        'cid': tempCid,
        'type': 'USER',
        'attaches': [],
        'elements': tempElements,
        'link': _replyingToMessage != null
            ? {
                'type': 'REPLY',
                'messageId': _replyingToMessage!.id,
                'message': {
                  'sender': _replyingToMessage!.senderId,
                  'id': _replyingToMessage!.id,
                  'time': _replyingToMessage!.time,
                  'text': _replyingToMessage!.text,
                  'type': 'USER',
                  'cid': _replyingToMessage!.cid,
                  'attaches': _replyingToMessage!.attaches,
                },
                'chatId': 0, 
              }
            : null,
      };

      final tempMessage = Message.fromJson(tempMessageJson);
      _addMessage(tempMessage);
      print(
        'Создано временное сообщение с link: ${tempMessage.link} и cid: $tempCid',
      );

      ApiService.instance.sendMessage(
        widget.chatId,
        textToSend,
        replyToMessageId: _replyingToMessage?.id,
        cid: tempCid, 
        elements: tempElements,
      );

      final readSettings = await ChatReadSettingsService.instance.getSettings(
        widget.chatId,
      );

      final shouldReadOnAction = readSettings != null
          ? (!readSettings.disabled && readSettings.readOnAction)
          : theme.debugReadOnAction;

      if (shouldReadOnAction && _messages.isNotEmpty) {
        final lastMessageId = _messages.last.id;
        ApiService.instance.markMessageAsRead(widget.chatId, lastMessageId);
      }

      _textController.clear();

      setState(() {
        _replyingToMessage = null;
        _textController.elements.clear();
      });
    }
  }

  void _testSlideAnimation() {
    final myMessage = Message(
      id: 'test_my_${DateTime.now().millisecondsSinceEpoch}',
      text: 'Тест моё сообщение (должно выехать справа)',
      time: DateTime.now().millisecondsSinceEpoch,
      senderId: _actualMyId!,
    );
    _addMessage(myMessage);

    Future.delayed(const Duration(seconds: 1), () {
      final otherMessage = Message(
        id: 'test_other_${DateTime.now().millisecondsSinceEpoch}',
        text: 'Тест сообщение собеседника (должно выехать слева)',
        time: DateTime.now().millisecondsSinceEpoch,
        senderId: widget.contact.id,
      );
      _addMessage(otherMessage);
    });
  }

  void _editMessage(Message message) {
    if (!message.canEdit(_actualMyId!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isDeleted
                ? 'Удаленное сообщение нельзя редактировать'
                : message.attaches.isNotEmpty
                ? 'Сообщения с вложениями нельзя редактировать'
                : 'Сообщение можно редактировать только в течение 24 часов',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _EditMessageDialog(
        initialText: message.text,
        onSave: (newText) async {
          if (newText.trim().isNotEmpty && newText != message.text) {
            final optimistic = message.copyWith(
              text: newText.trim(),
              status: 'EDITED',
              updateTime: DateTime.now().millisecondsSinceEpoch,
            );
            _updateMessage(optimistic);

            try {
              await ApiService.instance.editMessage(
                widget.chatId,
                message.id,
                newText.trim(),
              );

              widget.onChatUpdated?.call();
            } catch (e) {
              print('Ошибка при редактировании сообщения: $e');
              _updateMessage(message);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка редактирования: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  void _replyToMessage(Message message) {
    setState(() {
      _replyingToMessage = message;
    });
    _textController.clear();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _forwardMessage(Message message) {
    _showForwardDialog(message);
  }

  void _showForwardDialog(Message message) {
    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData == null || chatData['chats'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Список чатов не загружен'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final chats = chatData['chats'] as List<dynamic>;
    final availableChats = chats
        .where(
          (chat) => chat['id'] != widget.chatId || chat['id'] == 0,
        ) 
        .toList();

    if (availableChats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных чатов для пересылки'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Переслать сообщение'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: availableChats.length,
            itemBuilder: (context, index) {
              final chat = availableChats[index] as Map<String, dynamic>;
              return _buildForwardChatTile(context, chat, message);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }

  Widget _buildForwardChatTile(
    BuildContext context,
    Map<String, dynamic> chat,
    Message message,
  ) {
    final chatId = chat['id'] as int;
    final chatTitle = chat['title'] as String?;
    
    String chatName;
    Widget avatar;
    String subtitle = '';

    if (chatId == 0) {
      chatName = 'Избранное';
      avatar = CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.star,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      );
      subtitle = 'Сохраненные сообщения';
    } else {
      final participants = chat['participants'] as Map<String, dynamic>? ?? {};
      final isGroupChat = participants.length > 2;

      if (isGroupChat) {
        chatName = chatTitle?.isNotEmpty == true ? chatTitle! : 'Группа';
        avatar = CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.group,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        );
        subtitle = '${participants.length} участников';
      } else {
        
        final participantIds = participants.keys
            .map((id) => int.tryParse(id) ?? 0)
            .toList();

        int otherParticipantId = 0;
        if (participantIds.isNotEmpty) {
          
          otherParticipantId = participantIds.firstWhere(
            (id) => _actualMyId == null || id != _actualMyId,
            orElse: () => participantIds.first,
          );
        }

        
        
        final contact = _contactDetailsCache[otherParticipantId];
        if (contact == null && otherParticipantId != 0) {
          _loadContactIfNeeded(otherParticipantId);
        }

        
        
        
        chatName = contact?.name ?? 'ID $otherParticipantId';

        final avatarUrl = contact?.photoBaseUrl;

        avatar = AvatarCacheService().getAvatarWidget(
          avatarUrl,
          userId: otherParticipantId,
          size: 48,
          fallbackText: chatName,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        );

        subtitle = contact?.status ?? '';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: ClipOval(child: avatar),
        ),
        title: Text(
          chatName,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () {
          Navigator.of(context).pop();
          _performForward(message, chatId);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _performForward(Message message, int targetChatId) {
    ApiService.instance.forwardMessage(targetChatId, message.id, widget.chatId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Сообщение переслано'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _showComplaintDialog(String messageId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) =>
          ComplaintDialog(messageId: messageId, chatId: widget.chatId),
    );
  }

  void _showBlockDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Заблокировать контакт'),
        content: Text(
          'Вы уверены, что хотите заблокировать ${_currentContact.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ApiService.instance.blockContact(widget.contact.id);
                if (mounted) {
                  setState(() {
                    _currentContact = Contact(
                      id: _currentContact.id,
                      name: _currentContact.name,
                      firstName: _currentContact.firstName,
                      lastName: _currentContact.lastName,
                      description: _currentContact.description,
                      photoBaseUrl: _currentContact.photoBaseUrl,
                      isBlocked: _currentContact.isBlocked,
                      isBlockedByMe: true,
                      accountStatus: _currentContact.accountStatus,
                      status: _currentContact.status,
                    );
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Контакт заблокирован'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка блокировки: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Разблокировать контакт'),
        content: Text(
          'Вы уверены, что хотите разблокировать ${_currentContact.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ApiService.instance.unblockContact(widget.contact.id);
                if (mounted) {
                  setState(() {
                    _currentContact = Contact(
                      id: _currentContact.id,
                      name: _currentContact.name,
                      firstName: _currentContact.firstName,
                      lastName: _currentContact.lastName,
                      description: _currentContact.description,
                      photoBaseUrl: _currentContact.photoBaseUrl,
                      isBlocked: _currentContact.isBlocked,
                      isBlockedByMe: false,
                      accountStatus: _currentContact.accountStatus,
                      status: _currentContact.status,
                    );
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Контакт разблокирован'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка разблокировки: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Разблокировать'),
          ),
        ],
      ),
    );
  }

  void _showWallpaperDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) =>
          _WallpaperSelectionDialog(
            chatId: widget.chatId,
            onImageSelected: (imagePath) async {
              Navigator.of(context).pop();
              await _setChatWallpaper(imagePath);
            },
            onRemoveWallpaper: () async {
              Navigator.of(context).pop();
              await _removeChatWallpaper();
            },
          ),
    );
  }

  void _showClearHistoryDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        bool forAll = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Очистить историю чата'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вы уверены, что хотите очистить историю чата с ${_currentContact.name}? Это действие нельзя отменить.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: forAll,
                    onChanged: (value) {
                      setStateDialog(() {
                        forAll = value ?? false;
                      });
                    },
                    title: const Text('Удалить сообщения для всех'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await ApiService.instance.clearChatHistory(
                        widget.chatId,
                        forAll: forAll,
                      );
                      if (mounted) {
                        setState(() {
                          _messages.clear();
                          _chatItems.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('История чата очищена'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка очистки истории: $e'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Очистить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteChatDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        bool forAll = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Удалить чат'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вы уверены, что хотите удалить чат с ${_currentContact.name}? Это действие нельзя отменить.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: forAll,
                    onChanged: (value) {
                      setStateDialog(() {
                        forAll = value ?? false;
                      });
                    },
                    title: const Text('Удалить сообщения для всех'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      
                      await ApiService.instance.clearChatHistory(
                        widget.chatId,
                        forAll: forAll,
                      );

                      
                      await ApiService.instance.subscribeToChat(
                        widget.chatId,
                        false,
                      );

                      if (mounted) {
                        Navigator.of(context).pop();

                        widget.onChatRemoved?.call();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Чат удален'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка удаления чата: $e'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Удалить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Уведомления для этого чата выключены')),
    );
    setState(() {});
  }

  void _showLeaveGroupDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: const Text('Выйти из группы'),
        content: Text(
          'Вы уверены, что хотите выйти из группы "${widget.contact.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              try {
                ApiService.instance.leaveGroup(widget.chatId);

                if (mounted) {
                  Navigator.of(context).pop();

                  widget.onChatRemoved?.call();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Вы вышли из группы'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при выходе из группы: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getCurrentGroupChat() {
    final chatData = ApiService.instance.lastChatsPayload;
    if (chatData == null || chatData['chats'] == null) return null;

    final chats = chatData['chats'] as List<dynamic>;
    try {
      return chats.firstWhere(
        (chat) => chat['id'] == widget.chatId,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _setChatWallpaper(String imagePath) async {
    try {
      final theme = context.read<ThemeProvider>();
      await theme.setChatSpecificWallpaper(widget.chatId, imagePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обои для чата установлены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка установки обоев: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeChatWallpaper() async {
    try {
      final theme = context.read<ThemeProvider>();
      await theme.setChatSpecificWallpaper(widget.chatId, null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обои для чата удалены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления обоев: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadCachedContacts() async {
    final chatContacts = await ChatCacheService().getCachedChatContacts(
      widget.chatId,
    );
    if (chatContacts != null && chatContacts.isNotEmpty) {
      for (final contact in chatContacts) {
        _contactDetailsCache[contact.id] = contact;

         
      }
      print(
        '✅ Загружено ${_contactDetailsCache.length} контактов из кэша чата ${widget.chatId}',
      );
      return;
    }

    
    final cachedContacts = await ChatCacheService().getCachedContacts();
    if (cachedContacts != null && cachedContacts.isNotEmpty) {
      for (final contact in cachedContacts) {
        _contactDetailsCache[contact.id] = contact;

        if (contact.id == widget.myId && _actualMyId == null) {
          final prefs = await SharedPreferences.getInstance();

          _actualMyId = int.parse(prefs.getString('userId')!);
          print(
            '✅ [_loadCachedContacts] Собственный ID восстановлен из глобального кэша: $_actualMyId (${contact.name})',
          );
        }
      }
      print(
        '✅ Загружено ${_contactDetailsCache.length} контактов из глобального кэша',
      );
    } else {
      print('⚠️ Кэш контактов пуст, будет загружено с сервера');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      extendBodyBehindAppBar: theme.useGlassPanels,
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(child: _buildChatWallpaper(theme)),
          Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.5),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _pinnedMessage != null
                    ? SafeArea(
                        key: ValueKey(_pinnedMessage!.id),
                        child: InkWell(
                          onTap: _scrollToPinnedMessage,
                          child: PinnedMessageWidget(
                            pinnedMessage: _pinnedMessage!,
                            contacts: _contactDetailsCache,
                            myId: _actualMyId ?? 0,
                            onTap: _scrollToPinnedMessage,
                            onClose: () {
                              setState(() {
                                _pinnedMessage = null;
                              });
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
              Expanded(
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: (!_isIdReady || _isLoadingHistory)
                          ? const Center(
                              key: ValueKey('loading'),
                              child: CircularProgressIndicator(),
                            )
                          : _messages.isEmpty && !widget.isChannel
                          ? _EmptyChatWidget(
                              sticker: _emptyChatSticker,
                              onStickerTap: _sendEmptyChatSticker,
                            )
                          : AnimatedPadding(
                              key: const ValueKey('chat_list'),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(
                                  context,
                                ).viewInsets.bottom,
                              ),
                              child: ScrollablePositionedList.builder(
                                itemScrollController: _itemScrollController,
                                itemPositionsListener: _itemPositionsListener,
                                reverse: true,
                                padding: EdgeInsets.fromLTRB(
                                  8.0,
                                  8.0,
                                  8.0,
                                  widget.isChannel ? 16.0 : 100.0,
                                ),
                                itemCount: _chatItems.length,
                                itemBuilder: (context, index) {
                                  final mappedIndex =
                                      _chatItems.length - 1 - index;
                                  final item = _chatItems[mappedIndex];
                                  final isLastVisual =
                                      index == _chatItems.length - 1;

                                  
                                  

                                  if (item is MessageItem) {
                                    final message = item.message;
                                    final key = _messageKeys.putIfAbsent(
                                      message.id,
                                      () => GlobalKey(),
                                    );
                                    final bool isHighlighted =
                                        _isSearching &&
                                        _searchResults.isNotEmpty &&
                                        _currentResultIndex != -1 &&
                                        message.id ==
                                            _searchResults[_currentResultIndex]
                                                .id;

                                    final isControlMessage = message.attaches
                                        .any((a) => a['_type'] == 'CONTROL');
                                    if (isControlMessage) {
                                      return _ControlMessageChip(
                                        message: message,
                                        contacts: _contactDetailsCache,
                                        myId: _actualMyId ?? widget.myId,
                                      );
                                    }

                                    final bool isMe =
                                        item.message.senderId == _actualMyId;

                                    MessageReadStatus? readStatus;
                                    if (isMe) {
                                      final messageId = item.message.id;
                                      if (messageId.startsWith('local_')) {
                                        readStatus = MessageReadStatus.sending;
                                      } else {
                                        readStatus = MessageReadStatus.sent;
                                      }
                                    }

                                    String? forwardedFrom;
                                    String? forwardedFromAvatarUrl;
                                    if (message.isForwarded) {
                                      final link = message.link;
                                      if (link is Map<String, dynamic>) {
                                        final chatName =
                                            link['chatName'] as String?;
                                        final chatIconUrl =
                                            link['chatIconUrl'] as String?;

                                        if (chatName != null) {
                                          forwardedFrom = chatName;
                                          forwardedFromAvatarUrl = chatIconUrl;
                                        } else {
                                          final forwardedMessage =
                                              link['message']
                                                  as Map<String, dynamic>?;
                                          final originalSenderId =
                                              forwardedMessage?['sender']
                                                  as int?;
                                          if (originalSenderId != null) {
                                            final originalSenderContact =
                                                _contactDetailsCache[originalSenderId];
                                            if (originalSenderContact == null) {
                                              _loadContactIfNeeded(
                                                originalSenderId,
                                              );
                                              forwardedFrom =
                                                  'Участник $originalSenderId';
                                              forwardedFromAvatarUrl = null;
                                            } else {
                                              forwardedFrom =
                                                  originalSenderContact.name;
                                              forwardedFromAvatarUrl =
                                                  originalSenderContact
                                                      .photoBaseUrl;
                                            }
                                          }
                                        }
                                      }
                                    }
                                    String? senderName;
                                    if (widget.isGroupChat && !isMe) {
                                      bool shouldShowName = true;
                                      if (mappedIndex > 0) {
                                        final previousItem =
                                            _chatItems[mappedIndex - 1];
                                        if (previousItem is MessageItem) {
                                          final previousMessage =
                                              previousItem.message;
                                          if (previousMessage.senderId ==
                                              message.senderId) {
                                            final timeDifferenceInMinutes =
                                                (message.time -
                                                    previousMessage.time) /
                                                (1000 * 60);
                                            if (timeDifferenceInMinutes < 5) {
                                              shouldShowName = false;
                                            }
                                          }
                                        }
                                      }
                                      if (shouldShowName) {
                                        final senderContact =
                                            _contactDetailsCache[message
                                                .senderId];
                                        if (senderContact != null) {
                                          senderName = getContactDisplayName(
                                            contactId: senderContact.id,
                                            originalName: senderContact.name,
                                            originalFirstName:
                                                senderContact.firstName,
                                            originalLastName:
                                                senderContact.lastName,
                                          );
                                        } else {
                                          senderName = 'ID ${message.senderId}';
                                          _loadContactIfNeeded(
                                            message.senderId,
                                          );
                                        }
                                      }
                                    }
                                    final hasPhoto = item.message.attaches.any(
                                      (a) => a['_type'] == 'PHOTO',
                                    );
                                    final isNew = !_animatedMessageIds.contains(
                                      item.message.id,
                                    );
                                    final deferImageLoading =
                                        hasPhoto &&
                                        isNew &&
                                        !_anyOptimize &&
                                        !context
                                            .read<ThemeProvider>()
                                            .animatePhotoMessages;

                                    String? decryptedText;
                                    if (_isEncryptionPasswordSetForCurrentChat &&
                                        _encryptionConfigForCurrentChat !=
                                            null &&
                                        _encryptionConfigForCurrentChat!
                                            .password
                                            .isNotEmpty &&
                                        ChatEncryptionService.isEncryptedMessage(
                                          item.message.text,
                                        )) {
                                      decryptedText =
                                          ChatEncryptionService.decryptWithPassword(
                                            _encryptionConfigForCurrentChat!
                                                .password,
                                            item.message.text,
                                          );
                                    }

                                    final bubble = ChatMessageBubble(
                                      key: key,
                                      message: item.message,
                                      isMe: isMe,
                                      readStatus: readStatus,
                                      isReactionSending: _sendingReactions
                                          .contains(item.message.id),
                                      deferImageLoading: deferImageLoading,
                                      myUserId: _actualMyId,
                                      chatId: widget.chatId,
                                      isEncryptionPasswordSet:
                                          _isEncryptionPasswordSetForCurrentChat,
                                      decryptedText: decryptedText,
                                      onReply: widget.isChannel
                                          ? null
                                          : () => _replyToMessage(item.message),
                                      onForward: () =>
                                          _forwardMessage(item.message),
                                      onEdit: isMe
                                          ? () => _editMessage(item.message)
                                          : null,
                                      canEditMessage: isMe
                                          ? item.message.canEdit(_actualMyId!)
                                          : null,
                                      onDeleteForMe: isMe
                                          ? () async {
                                              await ApiService.instance
                                                  .deleteMessage(
                                                    widget.chatId,
                                                    item.message.id,
                                                    forMe: true,
                                                  );
                                              widget.onChatUpdated?.call();
                                            }
                                          : null,
                                      onDeleteForAll: isMe
                                          ? () async {
                                              await ApiService.instance
                                                  .deleteMessage(
                                                    widget.chatId,
                                                    item.message.id,
                                                    forMe: false,
                                                  );
                                              widget.onChatUpdated?.call();
                                            }
                                          : null,
                                      onReaction: (emoji) {
                                        _updateReactionOptimistically(
                                          item.message.id,
                                          emoji,
                                        );
                                        ApiService.instance.sendReaction(
                                          widget.chatId,
                                          item.message.id,
                                          emoji,
                                        );
                                        widget.onChatUpdated?.call();
                                      },
                                      onRemoveReaction: () {
                                        _removeReactionOptimistically(
                                          item.message.id,
                                        );
                                        ApiService.instance.removeReaction(
                                          widget.chatId,
                                          item.message.id,
                                        );
                                        widget.onChatUpdated?.call();
                                      },
                                      isGroupChat: widget.isGroupChat,
                                      isChannel: widget.isChannel,
                                      senderName: senderName,
                                      forwardedFrom: forwardedFrom,
                                      forwardedFromAvatarUrl:
                                          forwardedFromAvatarUrl,
                                      contactDetailsCache: _contactDetailsCache,
                                      onReplyTap: _scrollToMessage,
                                      useAutoReplyColor: context
                                          .read<ThemeProvider>()
                                          .useAutoReplyColor,
                                      customReplyColor: context
                                          .read<ThemeProvider>()
                                          .customReplyColor,
                                      isFirstInGroup: item.isFirstInGroup,
                                      isLastInGroup: item.isLastInGroup,
                                      isGrouped: item.isGrouped,
                                      avatarVerticalOffset:
                                          -8.0, 
                                      onComplain: () =>
                                          _showComplaintDialog(item.message.id),
                                    );

                                    Widget finalMessageWidget =
                                        bubble as Widget;

                                    if (isHighlighted) {
                                      return TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 600,
                                        ),
                                        tween: Tween<double>(
                                          begin: 0.3,
                                          end: 0.6,
                                        ),
                                        curve: Curves.easeInOut,
                                        builder: (context, value, child) {
                                          return Container(
                                            
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 1, 
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer
                                                  .withOpacity(value),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: child,
                                          );
                                        },
                                        child: finalMessageWidget,
                                      );
                                    }

                                    
                                    if (isNew && !_anyOptimize) {
                                      return TweenAnimationBuilder<double>(
                                        duration: const Duration(
                                          milliseconds: 400,
                                        ),
                                        tween: Tween<double>(
                                          begin: 0.0,
                                          end: 1.0,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, value, child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Transform.translate(
                                              offset: Offset(
                                                0,
                                                20 * (1 - value),
                                              ),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: finalMessageWidget,
                                      );
                                    }

                                    return finalMessageWidget;
                                  } else if (item is DateSeparatorItem) {
                                    return _DateSeparatorChip(date: item.date);
                                  }
                                  if (isLastVisual && _isLoadingMore) {
                                    return TweenAnimationBuilder<double>(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      tween: Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        return Opacity(
                                          opacity: value,
                                          child: Transform.scale(
                                            scale: 0.7 + (0.3 * value),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOutQuad,
                      right: 16,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          MediaQuery.of(context).padding.bottom +
                          140,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        scale: _showScrollToBottomNotifier.value ? 1.0 : 0.0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _showScrollToBottomNotifier.value
                              ? 1.0
                              : 0.0,
                          child: Material(
                            color: Colors.grey[800],
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: InkWell(
                              onTap: _scrollToBottom,
                              borderRadius: BorderRadius.circular(28),
                              child: const SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Colors.white,
                                ),
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutQuad,
            left: 8,
            right: 8,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                0,
            child: _buildTextInput(),
          ),
        ],
      ),
    );
  }

  void _showContactProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ContactProfileDialog(
            contact: widget.contact,
            isChannel: widget.isChannel,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  AppBar _buildAppBar() {
    final theme = context.watch<ThemeProvider>();

    if (_isSearching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _stopSearch,
          tooltip: 'Закрыть поиск',
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Поиск по сообщениям...',
            border: InputBorder.none,
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          if (_searchResults.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  '${_currentResultIndex + 1} из ${_searchResults.length}',
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _searchResults.isNotEmpty ? _navigateToNextResult : null,
            tooltip: 'Следующий (более старый) результат',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _searchResults.isNotEmpty
                ? _navigateToPreviousResult
                : null,
            tooltip: 'Предыдущий (более новый) результат',
          ),
        ],
      );
    }

    return AppBar(
      titleSpacing: 4.0,
      backgroundColor: theme.useGlassPanels ? Colors.transparent : null,
      elevation: theme.useGlassPanels ? 0 : null,
      flexibleSpace: theme.useGlassPanels
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: theme.topBarBlur,
                  sigmaY: theme.topBarBlur,
                ),
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withOpacity(theme.topBarOpacity),
                ),
              ),
            )
          : null,
      leading: widget.isDesktopMode
          ? null 
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
      actions: [
        if (widget.isGroupChat)
          IconButton(
            onPressed: () {
              if (_actualMyId == null) return;
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      GroupSettingsScreen(
                        chatId: widget.chatId,
                        initialContact: _currentContact,
                        myId: _actualMyId!,
                        onChatUpdated: widget.onChatUpdated,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                            child: child,
                          ),
                        );
                      },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Настройки группы',
          ),
        PopupMenuButton<String>(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'search') {
              _startSearch();
            } else if (value == 'block') {
              _showBlockDialog();
            } else if (value == 'unblock') {
              _showUnblockDialog();
            } else if (value == 'wallpaper') {
              _showWallpaperDialog();
            } else if (value == 'toggle_notifications') {
              _toggleNotifications();
            } else if (value == 'clear_history') {
              _showClearHistoryDialog();
            } else if (value == 'delete_chat') {
              _showDeleteChatDialog();
            } else if (value == 'leave_group' || value == 'leave_channel') {
              _showLeaveGroupDialog();
            } else if (value == 'encryption_password') {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => ChatEncryptionSettingsScreen(
                        chatId: widget.chatId,
                        isPasswordSet: _isEncryptionPasswordSetForCurrentChat,
                      ),
                    ),
                  )
                  .then((_) => _loadEncryptionConfig());
            } else if (value == 'media') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatMediaScreen(
                    chatId: widget.chatId,
                    chatTitle: _currentContact.name,
                    messages: _messages,
                    onGoToMessage: (messageId) {
                      _scrollToMessage(messageId);
                    },
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) {
            bool amIAdmin = false;
            if (widget.isGroupChat) {
              final currentChat = _getCurrentGroupChat();
              if (currentChat != null) {
                final admins = currentChat['admins'] as List<dynamic>? ?? [];
                if (_actualMyId != null) {
                  amIAdmin = admins.contains(_actualMyId);
                }
              }
            }
            final bool canDeleteChat = !widget.isGroupChat || amIAdmin;

            final bool isEncryptionPasswordSet =
                _isEncryptionPasswordSetForCurrentChat;

            return [
              PopupMenuItem(
                value: 'encryption_password',
                child: Row(
                  children: [
                    Icon(
                      Icons.lock,
                      color: isEncryptionPasswordSet
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEncryptionPasswordSet
                          ? 'Пароль шифрования установлен'
                          : 'Пароль от шифрования',
                      style: TextStyle(
                        color: isEncryptionPasswordSet
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8),
                    Text('Поиск'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'media',
                child: Row(
                  children: [
                    Icon(Icons.photo_library),
                    SizedBox(width: 8),
                    Text('Медиа, файлы и ссылки'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'wallpaper',
                child: Row(
                  children: [
                    Icon(Icons.wallpaper),
                    SizedBox(width: 8),
                    Text('Обои'),
                  ],
                ),
              ),
              if (!widget.isGroupChat && !widget.isChannel) ...[
                if (_currentContact.isBlockedByMe)
                  const PopupMenuItem(
                    value: 'unblock',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Разблокировать'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Заблокировать'),
                      ],
                    ),
                  ),
              ],
              PopupMenuItem(
                value: 'toggle_notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications),
                    SizedBox(width: 8),
                    Text('Выкл. уведомления'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (!widget.isChannel)
                const PopupMenuItem(
                  value: 'clear_history',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Очистить историю'),
                    ],
                  ),
                ),

              if (widget.isGroupChat)
                const PopupMenuItem(
                  value: 'leave_group',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Выйти из группы'),
                    ],
                  ),
                ),

              if (widget.isChannel)
                const PopupMenuItem(
                  value: 'leave_channel', 
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Покинуть канал'), 
                    ],
                  ),
                ),

              if (canDeleteChat && !widget.isChannel)
                const PopupMenuItem(
                  value: 'delete_chat',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Удалить чат'),
                    ],
                  ),
                ),
            ];
          },
        ),
      ],
      title: Row(
        children: [
          GestureDetector(
            onTap: _showContactProfile,
            child: Hero(
              tag: 'contact_avatar_${widget.contact.id}',
              child: widget.chatId == 0
                  ? CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.bookmark,
                        size: 20,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : ContactAvatarWidget(
                      contactId: widget.contact.id,
                      originalAvatarUrl: widget.contact.photoBaseUrl,
                      radius: 18,
                      fallbackText: widget.contact.name.isNotEmpty
                          ? widget.contact.name[0].toUpperCase()
                          : '?',
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _showContactProfile,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ContactNameWidget(
                          contactId: widget.contact.id,
                          originalName: widget.contact.name,
                          originalFirstName: widget.contact.firstName,
                          originalLastName: widget.contact.lastName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (context
                          .watch<ThemeProvider>()
                          .debugShowMessageCount) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.ultraOptimizeChats
                                ? Colors.red.withOpacity(0.7)
                                : theme.optimizeChats
                                ? Colors.orange.withOpacity(0.7)
                                : Colors.blue.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_messages.length}${theme.ultraOptimizeChats
                                ? 'U'
                                : theme.optimizeChats
                                ? 'O'
                                : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 2),
                  if (widget.isGroupChat ||
                      widget.isChannel) 
                    Text(
                      widget.isChannel
                          ? "${widget.participantCount ?? 0} подписчиков"
                          : "${widget.participantCount ?? 0} участников",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else if (widget.chatId != 0)
                    _ContactPresenceSubtitle(
                      chatId: widget.chatId,
                      userId: widget.contact.id,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatWallpaper(ThemeProvider provider) {
    if (provider.hasChatSpecificWallpaper(widget.chatId)) {
      final chatSpecificImagePath = provider.getChatSpecificWallpaper(
        widget.chatId,
      );
      if (chatSpecificImagePath != null) {
        return Image.file(
          File(chatSpecificImagePath),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    }

    if (!provider.useCustomChatWallpaper) {
      return Container(color: Theme.of(context).colorScheme.surface);
    }
    switch (provider.chatWallpaperType) {
      case ChatWallpaperType.solid:
        return Container(color: provider.chatWallpaperColor1);
      case ChatWallpaperType.gradient:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                provider.chatWallpaperColor1,
                provider.chatWallpaperColor2,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      case ChatWallpaperType.image:
        final Widget image;
        if (provider.chatWallpaperImagePath != null) {
          image = Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(provider.chatWallpaperImagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              if (provider.chatWallpaperImageBlur > 0)
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: provider.chatWallpaperImageBlur,
                    sigmaY: provider.chatWallpaperImageBlur,
                  ),
                  child: Container(color: Colors.transparent),
                ),
            ],
          );
        } else {
          image = Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (provider.chatWallpaperBlur)
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: provider.chatWallpaperBlurSigma,
                  sigmaY: provider.chatWallpaperBlurSigma,
                ),
                child: Container(color: Colors.black.withOpacity(0.0)),
              ),
          ],
        );
      case ChatWallpaperType.video:
        if (Platform.isWindows) {
          return Container(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: Text(
                'Видео-обои не поддерживаются\nна Windows',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (provider.chatWallpaperVideoPath != null &&
            provider.chatWallpaperVideoPath!.isNotEmpty) {
          return _VideoWallpaperBackground(
            videoPath: provider.chatWallpaperVideoPath!,
          );
        } else {
          return Container(color: Theme.of(context).colorScheme.surface);
        }
    }
  }

  Widget _buildTextInput() {
    if (widget.isChannel) {
      return const SizedBox.shrink(); 
    }
    final theme = context.watch<ThemeProvider>();
    final isBlocked = _currentContact.isBlockedByMe && !theme.blockBypass;

    if (_currentContact.name.toLowerCase() == 'max') {
      return const SizedBox.shrink();
    }

    if (theme.useGlassPanels) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: theme.bottomBarBlur,
            sigmaY: theme.bottomBarBlur,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingToMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ответ на сообщение',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _replyingToMessage!.text.isNotEmpty
                                      ? _replyingToMessage!.text
                                      : (_replyingToMessage!.hasFileAttach
                                            ? 'Файл'
                                            : 'Фото'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _cancelReply,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isBlocked) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.block_rounded,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Пользователь заблокирован',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Разблокируйте пользователя для отправки сообщений',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'или включите block_bypass',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer.withOpacity(0.7),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_specialMessagesEnabled)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: isBlocked ? null : _showSpecialMessagesPanel,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.auto_fix_high,
                                color: isBlocked
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.3)
                                    : Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      if (_specialMessagesEnabled) const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_showKometColorPicker)
                              _KometColorPickerBar(
                                onColorSelected: (color) {
                                  if (_currentKometColorPrefix == null) return;
                                  final hex = color.value
                                      .toRadixString(16)
                                      .padLeft(8, '0')
                                      .substring(2)
                                      .toUpperCase();

                                  String newText;
                                  int cursorOffset;

                                  if (_currentKometColorPrefix ==
                                      'komet.color_#') {
                                    newText =
                                        '$_currentKometColorPrefix$hex\'ваш текст\'';
                                    final textLength = newText.length;
                                    cursorOffset = textLength - 12;
                                  } else if (_currentKometColorPrefix ==
                                      'komet.cosmetic.pulse#') {
                                    newText =
                                        '$_currentKometColorPrefix$hex\'ваш текст\'';
                                    final textLength = newText.length;
                                    cursorOffset = textLength - 12;
                                  } else {
                                    return;
                                  }

                                  _textController.text = newText;
                                  _textController.selection = TextSelection(
                                    baseOffset: cursorOffset,
                                    extentOffset: newText.length - 1,
                                  );
                                },
                              ),
                            Focus(
                              focusNode:
                                  _textFocusNode, 
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent) {
                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.enter) {
                                    final bool isShiftPressed =
                                        HardwareKeyboard
                                            .instance
                                            .logicalKeysPressed
                                            .contains(
                                              LogicalKeyboardKey.shiftLeft,
                                            ) ||
                                        HardwareKeyboard
                                            .instance
                                            .logicalKeysPressed
                                            .contains(
                                              LogicalKeyboardKey.shiftRight,
                                            );

                                    if (!isShiftPressed) {
                                      _sendMessage();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: _textController,
                                enabled: !isBlocked,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                minLines: 1,
                                maxLines: 5,
                                contextMenuBuilder: (context, editableTextState) {
                                  if (isBlocked) {
                                    return AdaptiveTextSelectionToolbar.editableText(
                                      editableTextState: editableTextState,
                                    );
                                  }

                                  final selection = _textController.selection;
                                  if (!selection.isValid ||
                                      selection.isCollapsed) {
                                    return AdaptiveTextSelectionToolbar.editableText(
                                      editableTextState: editableTextState,
                                    );
                                  }

                                  final buttonItems = <ContextMenuButtonItem>[
                                    ContextMenuButtonItem(
                                      label: 'Копировать',
                                      onPressed: () {
                                        editableTextState.copySelection(
                                          SelectionChangedCause.toolbar,
                                        );
                                        ContextMenuController.removeAny();
                                      },
                                    ),
                                    ContextMenuButtonItem(
                                      label: 'Вырезать',
                                      onPressed: () {
                                        editableTextState.cutSelection(
                                          SelectionChangedCause.toolbar,
                                        );
                                        ContextMenuController.removeAny();
                                      },
                                    ),
                                    ContextMenuButtonItem(
                                      label: 'Жирный',
                                      onPressed: () {
                                        _applyTextFormat('STRONG');
                                        ContextMenuController.removeAny();
                                      },
                                    ),
                                    ContextMenuButtonItem(
                                      label: 'Курсив',
                                      onPressed: () {
                                        _applyTextFormat('EMPHASIZED');
                                        ContextMenuController.removeAny();
                                      },
                                    ),
                                    ContextMenuButtonItem(
                                      label: 'Подчеркнуть',
                                      onPressed: () {
                                        _applyTextFormat('UNDERLINE');
                                        ContextMenuController.removeAny();
                                      },
                                    ),
                                    ContextMenuButtonItem(
                                      label: 'Зачеркнуть',
                                      onPressed: () {
                                        _applyTextFormat('STRIKETHROUGH');
                                        ContextMenuController.removeAny();
                                      },
                                    ),
                                  ];

                                  return AdaptiveTextSelectionToolbar.buttonItems(
                                    anchors:
                                        editableTextState.contextMenuAnchors,
                                    buttonItems: buttonItems,
                                  );
                                },
                                decoration: InputDecoration(
                                  hintText: isBlocked
                                      ? 'Пользователь заблокирован'
                                      : 'Сообщение...',
                                  filled: true,
                                  isDense: true,
                                  fillColor: isBlocked
                                      ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.25)
                                      : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18.0,
                                    vertical: 12.0,
                                  ),
                                ),
                                onChanged: isBlocked
                                    ? null
                                    : (v) {
                                        _resetDraftFormattingIfNeeded(v);
                                        if (v.isNotEmpty) {
                                          _scheduleTypingPing();
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: isBlocked ? null : _onAttachPressed,
                          child: Padding(
                            padding: const EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.attach_file,
                              color: isBlocked
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.3)
                                  : Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      if (context.watch<ThemeProvider>().messageTransition ==
                          TransitionOption.slide)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: isBlocked ? null : _testSlideAnimation,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.animation,
                                color: isBlocked
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.3)
                                    : Colors.orange,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: isBlocked
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.2)
                              : Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: isBlocked ? null : _sendMessage,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.send_rounded,
                                color: isBlocked
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.5)
                                    : Theme.of(context).colorScheme.onPrimary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      final theme = context.watch<ThemeProvider>();
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: theme.optimization
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingToMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ответ на сообщение',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _replyingToMessage!.text.isNotEmpty
                                          ? _replyingToMessage!.text
                                          : (_replyingToMessage!.hasFileAttach
                                                ? 'Файл'
                                                : 'Фото'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _replyingToMessage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (isBlocked) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.block_rounded,
                                    color: Theme.of(context).colorScheme.error,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Пользователь заблокирован',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Разблокируйте пользователя для отправки сообщений',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'или включите block_bypass',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer
                                      .withOpacity(0.7),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              enabled: !isBlocked,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              minLines: 1,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: isBlocked
                                    ? 'Пользователь заблокирован'
                                    : 'Сообщение...',
                                filled: true,
                                isDense: true,
                                fillColor: isBlocked
                                    ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.25)
                                    : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18.0,
                                  vertical: 12.0,
                                ),
                              ),
                              onChanged: isBlocked
                                  ? null
                                  : (v) {
                                      if (v.isNotEmpty) {
                                        _scheduleTypingPing();
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Builder(
                            builder: (context) {
                              final isEncryptionActive =
                                  _encryptionConfigForCurrentChat != null &&
                                  _encryptionConfigForCurrentChat!
                                      .password
                                      .isNotEmpty &&
                                  _sendEncryptedForCurrentChat;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: (isBlocked || isEncryptionActive)
                                      ? null
                                      : () async {
                                          final result = await _pickPhotosFlow(
                                            context,
                                          );
                                          if (result != null &&
                                              result.paths.isNotEmpty) {
                                            await ApiService.instance
                                                .sendPhotoMessages(
                                                  widget.chatId,
                                                  localPaths: result.paths,
                                                  caption: result.caption,
                                                  senderId: _actualMyId,
                                                );
                                          }
                                        },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isBlocked || isEncryptionActive)
                                          ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withOpacity(0.25)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.photo_camera_outlined,
                                      color: (isBlocked || isEncryptionActive)
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.5)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap:
                                  (isBlocked ||
                                      _textController.text.trim().isEmpty)
                                  ? null
                                  : _sendMessage,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      (isBlocked ||
                                          _textController.text.trim().isEmpty)
                                      ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.25)
                                      : Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color:
                                      (isBlocked ||
                                          _textController.text.trim().isEmpty)
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withOpacity(0.5)
                                      : Theme.of(context).colorScheme.onPrimary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(
                      0.85,
                    ), 
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingToMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply_rounded,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ответ на сообщение',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _replyingToMessage!.text.isNotEmpty
                                            ? _replyingToMessage!.text
                                            : (_replyingToMessage!.hasFileAttach
                                                  ? 'Файл'
                                                  : 'Фото'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _cancelReply,
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (isBlocked) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.block_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Пользователь заблокирован',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Разблокируйте пользователя для отправки сообщений',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'или включите block_bypass',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer
                                        .withOpacity(0.7),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                enabled: !isBlocked,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                minLines: 1,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText: isBlocked
                                      ? 'Пользователь заблокирован'
                                      : 'Сообщение...',
                                  filled: true,
                                  isDense: true,
                                  fillColor: isBlocked
                                      ? Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.25)
                                      : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18.0,
                                    vertical: 12.0,
                                  ),
                                ),
                                onChanged: isBlocked
                                    ? null
                                    : (v) {
                                        if (v.isNotEmpty) {
                                          _scheduleTypingPing();
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final isEncryptionActive =
                                    _encryptionConfigForCurrentChat != null &&
                                    _encryptionConfigForCurrentChat!
                                        .password
                                        .isNotEmpty &&
                                    _sendEncryptedForCurrentChat;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: (isBlocked || isEncryptionActive)
                                        ? null
                                        : () async {
                                            final result =
                                                await _pickPhotosFlow(context);
                                            if (result != null &&
                                                result.paths.isNotEmpty) {
                                              await ApiService.instance
                                                  .sendPhotoMessages(
                                                    widget.chatId,
                                                    localPaths: result.paths,
                                                    caption: result.caption,
                                                    senderId: _actualMyId,
                                                  );
                                            }
                                          },
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0),
                                      child: Icon(
                                        Icons.photo_library_outlined,
                                        color: (isBlocked || isEncryptionActive)
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.3)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (context
                                    .watch<ThemeProvider>()
                                    .messageTransition ==
                                TransitionOption.slide)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: isBlocked ? null : _testSlideAnimation,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.animation,
                                      color: isBlocked
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.3)
                                          : Colors.orange,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: isBlocked
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: isBlocked ? null : _sendMessage,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Icon(
                                      Icons.send_rounded,
                                      color: isBlocked
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5)
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    }
  }

  Timer? _typingTimer;
  DateTime _lastTypingSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  void _scheduleTypingPing() {
    final now = DateTime.now();
    if (now.difference(_lastTypingSentAt) >= const Duration(seconds: 9)) {
      ApiService.instance.sendTyping(widget.chatId, type: "TEXT");
      _lastTypingSentAt = now;
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 9), () {
      if (!mounted) return;
      if (_textController.text.isNotEmpty) {
        ApiService.instance.sendTyping(widget.chatId, type: "TEXT");
        _lastTypingSentAt = DateTime.now();
        _scheduleTypingPing();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _stopSelectionCheck();
    _apiSubscription?.cancel();
    _textController.removeListener(_handleTextChangedForKometColor);
    _textController.dispose();
    _textFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchResults.clear();
      _currentResultIndex = -1;
      _searchController.clear();
      _messageKeys.clear();
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      if (_searchResults.isNotEmpty) {
        setState(() {
          _searchResults.clear();
          _currentResultIndex = -1;
        });
      }
      return;
    }
    final results = _messages
        .where((msg) => msg.text.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() {
      _searchResults = results.reversed.toList();
      _currentResultIndex = _searchResults.isNotEmpty ? 0 : -1;
    });

    if (_currentResultIndex != -1) {
      _scrollToResult();
    }
  }

  void _navigateToNextResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentResultIndex = (_currentResultIndex + 1) % _searchResults.length;
    });
    _scrollToResult();
  }

  void _navigateToPreviousResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentResultIndex =
          (_currentResultIndex - 1 + _searchResults.length) %
          _searchResults.length;
    });
    _scrollToResult();
  }

  void _scrollToResult() {
    if (_currentResultIndex == -1) return;

    final targetMessage = _searchResults[_currentResultIndex];

    final itemIndex = _chatItems.indexWhere(
      (item) => item is MessageItem && item.message.id == targetMessage.id,
    );

    if (itemIndex != -1) {
      final viewIndex = _chatItems.length - 1 - itemIndex;

      _itemScrollController.scrollTo(
        index: viewIndex,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  void _scrollToMessage(String messageId) {
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final itemIndex = _chatItems.indexWhere(
        (item) => item is MessageItem && item.message.id == messageId,
      );

      if (itemIndex != -1) {
        final viewIndex = _chatItems.length - 1 - itemIndex;

        if (_itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: viewIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment:
                0.2, 
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Исходное сообщение не найдено (возможно, оно в старой истории)',
              ),
            ),
          );
        }
      }
    });
  }
}

class _SpecialMessageButton extends StatelessWidget {
  final String label;
  final String template;
  final IconData icon;
  final VoidCallback onTap;

  const _SpecialMessageButton({
    required this.label,
    required this.template,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _KometColorPickerBar extends StatefulWidget {
  final ValueChanged<Color> onColorSelected;

  const _KometColorPickerBar({required this.onColorSelected});

  @override
  State<_KometColorPickerBar> createState() => _KometColorPickerBarState();
}

class _KometColorPickerBarState extends State<_KometColorPickerBar> {
  Color _currentColor = Colors.red;

  void _showColorPickerDialog(BuildContext context) {
    Color pickedColor = _currentColor;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выберите цвет'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return ColorPicker(
                pickerColor: pickedColor,
                onColorChanged: (color) {
                  setState(() => pickedColor = color);
                },
                enableAlpha: false,
                pickerAreaHeightPercent: 0.8,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Отмена'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('Готово'),
            onPressed: () {
              widget.onColorSelected(pickedColor);
              setState(() {
                _currentColor = pickedColor;
              });
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const double diameter = 32;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Выберите цвет для komet.color',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _showColorPickerDialog(context);
            },
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: diameter - 12,
                  height: diameter - 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentColor,
                    border: Border.all(color: colors.surface, width: 1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;

  const _EditMessageDialog({required this.initialText, required this.onSave});

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать сообщение'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Введите текст сообщения',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_controller.text);
            Navigator.pop(context);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _ContactPresenceSubtitle extends StatefulWidget {
  final int chatId;
  final int userId;
  const _ContactPresenceSubtitle({required this.chatId, required this.userId});
  @override
  State<_ContactPresenceSubtitle> createState() =>
      _ContactPresenceSubtitleState();
}

class _ContactPresenceSubtitleState extends State<_ContactPresenceSubtitle> {
  String _status = 'был(а) недавно';
  Timer? _typingDecayTimer;
  bool _isOnline = false;
  DateTime? _lastSeen;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();

    final lastSeen = ApiService.instance.getLastSeen(widget.userId);
    if (lastSeen != null) {
      _lastSeen = lastSeen;
      _status = _formatLastSeen(_lastSeen);
    }

    _sub = ApiService.instance.messages.listen((msg) {
      try {
        final int? opcode = msg['opcode'];
        final payload = msg['payload'];
        if (opcode == 129) {
          final dynamic incomingChatId = payload['chatId'];
          final int? cid = incomingChatId is int
              ? incomingChatId
              : int.tryParse(incomingChatId?.toString() ?? '');
          if (cid == widget.chatId) {
            
            Future.microtask(() {
              if (mounted) {
                setState(() => _status = 'печатает…');
              }
            });
            _typingDecayTimer?.cancel();
            _typingDecayTimer = Timer(const Duration(seconds: 11), () {
              if (!mounted) return;
              if (_status == 'печатает…') {
                Future.microtask(() {
                  if (mounted) {
                    setState(() {
                      if (_isOnline) {
                        _status = 'онлайн';
                      } else {
                        _status = _formatLastSeen(_lastSeen);
                      }
                    });
                  }
                });
              }
            });
          }
        } else if (opcode == 132) {
          final dynamic incomingChatId = payload['chatId'];
          final int? cid = incomingChatId is int
              ? incomingChatId
              : int.tryParse(incomingChatId?.toString() ?? '');
          if (cid == widget.chatId) {
            final bool isOnline = payload['online'] == true;
            if (!mounted) return;
            _isOnline = isOnline;
            
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  if (_status != 'печатает…') {
                    if (_isOnline) {
                      _status = 'онлайн';
                    } else {
                      final updatedLastSeen = ApiService.instance.getLastSeen(
                        widget.userId,
                      );
                      if (updatedLastSeen != null) {
                        _lastSeen = updatedLastSeen;
                      } else {
                        _lastSeen = DateTime.now();
                      }
                      _status = _formatLastSeen(_lastSeen);
                    }
                  }
                });
              }
            });
          }
        }
      } catch (_) {}
    });
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'был(а) недавно';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'только что';
    } else if (difference.inMinutes < 60) {
      timeAgo = '${difference.inMinutes} мин. назад';
    } else if (difference.inHours < 24) {
      timeAgo = '${difference.inHours} ч. назад';
    } else if (difference.inDays < 7) {
      timeAgo = '${difference.inDays} дн. назад';
    } else {
      final day = lastSeen.day.toString().padLeft(2, '0');
      final month = lastSeen.month.toString().padLeft(2, '0');
      timeAgo = '$day.$month.${lastSeen.year}';
    }

    if (_debugShowExactDate) {
      final formatter = DateFormat('dd.MM.yyyy HH:mm:ss');
      return '$timeAgo (${formatter.format(lastSeen)})';
    }

    return timeAgo;
  }

  @override
  void dispose() {
    _typingDecayTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    String displayStatus;
    if (_status == 'печатает…' || _status == 'онлайн') {
      displayStatus = _status;
    } else if (_isOnline) {
      displayStatus = 'онлайн';
    } else {
      displayStatus = _formatLastSeen(_lastSeen);
    }

    return GestureDetector(
      onLongPress: () {
        toggleDebugExactDate();
        if (mounted) {
          setState(() {});
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayStatus,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_debugShowExactDate) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.bug_report,
              size: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotosToSend {
  final List<String> paths;
  final String caption;
  const _PhotosToSend({required this.paths, required this.caption});
}

class _SendPhotosDialog extends StatefulWidget {
  const _SendPhotosDialog();
  @override
  State<_SendPhotosDialog> createState() => _SendPhotosDialogState();
}

class _SendPhotosDialogState extends State<_SendPhotosDialog> {
  final TextEditingController _caption = TextEditingController();
  final List<String> _pickedPaths = [];
  final List<ImageProvider?> _previews = [];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickMoreDesktop() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      _pickedPaths
        ..clear()
        ..addAll(result.files.where((f) => f.path != null).map((f) => f.path!));
      _previews
        ..clear()
        ..addAll(_pickedPaths.map((p) => FileImage(File(p)) as ImageProvider));
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Ошибка выбора фото на десктопе: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Отправить фото'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _caption,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Подпись (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pickMoreDesktop,
            icon: const Icon(Icons.photo_library),
            label: Text(
              _pickedPaths.isEmpty
                  ? 'Выбрать фото'
                  : 'Выбрано: ${_pickedPaths.length}',
            ),
          ),
          if (_pickedPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 320,
              height: 220,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _previews.length,
                itemBuilder: (ctx, i) {
                  final preview = _previews[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: preview != null
                            ? Image(image: preview, fit: BoxFit.cover)
                            : const ColoredBox(color: Colors.black12),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _previews.removeAt(i);
                              _pickedPaths.removeAt(i);
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: _pickedPaths.isEmpty
              ? null
              : () {
                  Navigator.pop(
                    context,
                    _PhotosToSend(paths: _pickedPaths, caption: _caption.text),
                  );
                },
          child: const Text('Отправить'),
        ),
      ],
    );
  }
}

Future<_PhotosToSend?> _pickPhotosFlow(BuildContext context) async {
  final isMobile =
      Theme.of(context).platform == TargetPlatform.android ||
      Theme.of(context).platform == TargetPlatform.iOS;
  if (isMobile) {
    return await showModalBottomSheet<_PhotosToSend>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _SendPhotosBottomSheet(),
      ),
    );
  } else {
    return await showDialog<_PhotosToSend>(
      context: context,
      builder: (ctx) => const _SendPhotosDialog(),
    );
  }
}

class _SendPhotosBottomSheet extends StatefulWidget {
  const _SendPhotosBottomSheet();
  @override
  State<_SendPhotosBottomSheet> createState() => _SendPhotosBottomSheetState();
}

class _SendPhotosBottomSheetState extends State<_SendPhotosBottomSheet> {
  final TextEditingController _caption = TextEditingController();
  final List<String> _pickedPaths = [];
  final List<ImageProvider?> _previews = [];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickMore() async {
    try {
      final imgs = await ImagePicker().pickMultiImage(imageQuality: 100);
      if (imgs.isNotEmpty) {
        _pickedPaths.addAll(imgs.map((e) => e.path));
        _previews.addAll(imgs.map((e) => FileImage(File(e.path))));
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Выбор фото',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _pickMore,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
              ],
            ),
            if (_pickedPaths.isNotEmpty)
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (c, i) {
                    final preview = _previews[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: preview != null
                              ? Image(
                                  image: preview,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                )
                              : const ColoredBox(color: Colors.black12),
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _previews.removeAt(i);
                                _pickedPaths.removeAt(i);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _previews.length,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickMore,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Выбрать фото'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Подпись (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _pickedPaths.isEmpty
                      ? null
                      : () {
                          Navigator.pop(
                            context,
                            _PhotosToSend(
                              paths: _pickedPaths,
                              caption: _caption.text,
                            ),
                          );
                        },
                  child: const Text('Отправить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparatorChip extends StatelessWidget {
  final DateTime date;
  const _DateSeparatorChip({required this.date});

  String _formatDate(DateTime localDate) {
    final now = DateTime.now();
    if (localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day) {
      return 'Сегодня';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (localDate.year == yesterday.year &&
        localDate.month == yesterday.month &&
        localDate.day == yesterday.day) {
      return 'Вчера';
    }
    return DateFormat.yMMMMd('ru').format(localDate);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

extension BrightnessExtension on Brightness {
  bool get isDark => this == Brightness.dark;
}


class GroupProfileDraggableDialog extends StatelessWidget {
  final Contact contact;

  const GroupProfileDraggableDialog({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Hero(
                  tag: 'contact_avatar_${contact.id}',
                  child: ContactAvatarWidget(
                    contactId: contact.id,
                    originalAvatarUrl: contact.photoBaseUrl,
                    radius: 60,
                    fallbackText: contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: colors.primary),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GroupSettingsScreen(
                              chatId: -contact
                                  .id, 
                              initialContact: contact,
                              myId: 0,
                            ),
                          ),
                        );
                      },
                      tooltip: 'Настройки группы',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (contact.description != null &&
                        contact.description!.isNotEmpty)
                      Text(
                        contact.description!,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ContactProfileDialog extends StatefulWidget {
  final Contact contact;
  final bool isChannel;
  const ContactProfileDialog({
    super.key,
    required this.contact,
    this.isChannel = false,
  });

  @override
  State<ContactProfileDialog> createState() => _ContactProfileDialogState();
}

class _ContactProfileDialogState extends State<ContactProfileDialog> {
  String? _localDescription;
  StreamSubscription? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _loadLocalDescription();

    
    _changesSubscription = ContactLocalNamesService().changes.listen((
      contactId,
    ) {
      if (contactId == widget.contact.id && mounted) {
        _loadLocalDescription();
      }
    });
  }

  Future<void> _loadLocalDescription() async {
    final localData = ContactLocalNamesService().getContactData(
      widget.contact.id,
    );
    if (mounted) {
      setState(() {
        _localDescription = localData?['notes'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final String nickname = getContactDisplayName(
      contactId: widget.contact.id,
      originalName: widget.contact.name,
      originalFirstName: widget.contact.firstName,
      originalLastName: widget.contact.lastName,
    );
    final String description =
        (_localDescription != null && _localDescription!.isNotEmpty)
        ? _localDescription!
        : (widget.contact.description ?? '');

    final theme = context.watch<ThemeProvider>();

    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: theme.profileDialogBlur,
                  sigmaY: theme.profileDialogBlur,
                ),
                child: Container(
                  color: Colors.black.withOpacity(theme.profileDialogOpacity),
                ),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            -0.3 *
                                (1.0 - value) *
                                MediaQuery.of(context).size.height *
                                0.15,
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'contact_avatar_${widget.contact.id}',
                      child: ContactAvatarWidget(
                        contactId: widget.contact.id,
                        originalAvatarUrl: widget.contact.photoBaseUrl,
                        radius: 96,
                        fallbackText: widget.contact.name.isNotEmpty
                            ? widget.contact.name[0].toUpperCase()
                            : '?',
                      ),
                    ),
                  ),
                ),
              ),

              Builder(
                builder: (context) {
                  final panel = Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nickname,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (description.isNotEmpty)
                          Linkify(
                            text: description,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                            linkStyle: TextStyle(
                              color: colors.primary, 
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                            onOpen: (link) async {
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
                            },
                          )
                        else
                          const SizedBox(height: 16),

                        if (!widget.isChannel) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EditContactScreen(
                                      contactId: widget.contact.id,
                                      originalFirstName:
                                          widget.contact.firstName,
                                      originalLastName: widget.contact.lastName,
                                      originalDescription:
                                          widget.contact.description,
                                      originalAvatarUrl:
                                          widget.contact.photoBaseUrl,
                                    ),
                                  ),
                                );

                                if (result == true && context.mounted) {
                                  Navigator.of(context).pop();
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Редактировать'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          if (widget.contact.id >= 0) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final isInContacts =
                                      ApiService.instance.getCachedContact(
                                        widget.contact.id,
                                      ) !=
                                      null;
                                  if (isInContacts) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Уже в контактах'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  try {
                                    await ApiService.instance.addContact(
                                      widget.contact.id,
                                    );
                                    await ApiService.instance
                                        .requestContactsByIds([
                                          widget.contact.id,
                                        ]);

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Запрос на добавление в контакты отправлен',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Ошибка при добавлении в контакты: $e',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.person_add),
                                label: const Text('В контакты'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  
                                  
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.message),
                                label: const Text('Написать сообщение'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                  return TweenAnimationBuilder<Offset>(
                    tween: Tween<Offset>(
                      begin: const Offset(0, 300),
                      end: Offset.zero,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, offset, child) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeIn,
                        builder: (context, opacity, innerChild) {
                          return Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: offset,
                              child: innerChild,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    child: panel,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WallpaperSelectionDialog extends StatefulWidget {
  final int chatId;
  final Function(String) onImageSelected;
  final VoidCallback onRemoveWallpaper;

  const _WallpaperSelectionDialog({
    required this.chatId,
    required this.onImageSelected,
    required this.onRemoveWallpaper,
  });

  @override
  State<_WallpaperSelectionDialog> createState() =>
      _WallpaperSelectionDialogState();
}

class _WallpaperSelectionDialogState extends State<_WallpaperSelectionDialog> {
  String? _selectedImagePath;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final hasExistingWallpaper = theme.hasChatSpecificWallpaper(widget.chatId);

    return AlertDialog(
      title: const Text('Обои для чата'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImagePath != null) ...[
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImagePath!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImageFromGallery(),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Галерея'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _pickImageFromCamera(),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Камера'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (hasExistingWallpaper)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : widget.onRemoveWallpaper,
                icon: const Icon(Icons.delete),
                label: const Text('Удалить обои'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        if (_selectedImagePath != null)
          FilledButton(
            onPressed: _isLoading
                ? null
                : () => widget.onImageSelected(_selectedImagePath!),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Установить'),
          ),
      ],
    );
  }

  Future<void> _pickImageFromGallery() async {
    setState(() => _isLoading = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() {
          _selectedImagePath = image.path;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора фото: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    setState(() => _isLoading = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null && mounted) {
        setState(() {
          _selectedImagePath = image.path;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка съемки фото: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _AddMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  final Function(List<int>) onAddMembers;

  const _AddMemberDialog({required this.contacts, required this.onAddMembers});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final Set<int> _selectedContacts = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить участников'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.contacts.length,
          itemBuilder: (context, index) {
            final contact = widget.contacts[index];
            final contactId = contact['id'] as int;
            final contactName =
                contact['names']?[0]?['name'] ?? 'ID $contactId';
            final isSelected = _selectedContacts.contains(contactId);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedContacts.add(contactId);
                  } else {
                    _selectedContacts.remove(contactId);
                  }
                });
              },
              title: Text(contactName),
              subtitle: Text('ID: $contactId'),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _selectedContacts.isEmpty
              ? null
              : () => widget.onAddMembers(_selectedContacts.toList()),
          child: Text('Добавить (${_selectedContacts.length})'),
        ),
      ],
    );
  }
}

class _RemoveMemberDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Function(List<int>) onRemoveMembers;

  const _RemoveMemberDialog({
    required this.members,
    required this.onRemoveMembers,
  });

  @override
  State<_RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends State<_RemoveMemberDialog> {
  final Set<int> _selectedMembers = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить участников'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.builder(
          itemCount: widget.members.length,
          itemBuilder: (context, index) {
            final member = widget.members[index];
            final memberId = member['id'] as int;
            final memberName = member['name'] as String;
            final isSelected = _selectedMembers.contains(memberId);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedMembers.add(memberId);
                  } else {
                    _selectedMembers.remove(memberId);
                  }
                });
              },
              title: Text(memberName),
              subtitle: Text('ID: $memberId'),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _selectedMembers.isEmpty
              ? null
              : () => widget.onRemoveMembers(_selectedMembers.toList()),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text('Удалить (${_selectedMembers.length})'),
        ),
      ],
    );
  }
}

class _PromoteAdminDialog extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final Function(int) onPromoteToAdmin;

  const _PromoteAdminDialog({
    required this.members,
    required this.onPromoteToAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Назначить администратором'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final memberId = member['id'] as int;
            final memberName = member['name'] as String;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  memberName[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              title: Text(memberName),
              subtitle: Text('ID: $memberId'),
              trailing: const Icon(Icons.admin_panel_settings),
              onTap: () => onPromoteToAdmin(memberId),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}

class _ControlMessageChip extends StatelessWidget {
  final Message message;
  final Map<int, Contact> contacts; 
  final int myId;

  const _ControlMessageChip({
    required this.message,
    required this.contacts,
    required this.myId,
  });

  String _formatControlMessage() {
    final controlAttach = message.attaches.firstWhere(
      (a) => a['_type'] == 'CONTROL',
    );

    final eventType = controlAttach['event'];
    final senderContact = contacts[message.senderId];
    final senderName = senderContact != null
        ? getContactDisplayName(
            contactId: senderContact.id,
            originalName: senderContact.name,
            originalFirstName: senderContact.firstName,
            originalLastName: senderContact.lastName,
          )
        : 'ID ${message.senderId}';
    final isMe = message.senderId == myId;
    final senderDisplayName = isMe ? 'Вы' : senderName;

    String formatUserList(List<int> userIds) {
      if (userIds.isEmpty) {
        return '';
      }
      final userNames = userIds
          .map((id) {
            if (id == myId) {
              return 'Вы';
            }
            final contact = contacts[id];
            if (contact != null) {
              return getContactDisplayName(
                contactId: contact.id,
                originalName: contact.name,
                originalFirstName: contact.firstName,
                originalLastName: contact.lastName,
              );
            }
            return 'участник с ID $id';
          })
          .where((name) => name.isNotEmpty)
          .join(', ');
      return userNames;
    }

    switch (eventType) {
      case 'new':
        final title = controlAttach['title'] ?? 'Новая группа';
        return '$senderDisplayName создал(а) группу "$title"';

      case 'add':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return 'К чату присоединились новые участники';
        }
        final userNames = formatUserList(userIds);
        if (userNames.isEmpty) {
          return 'К чату присоединились новые участники';
        }
        return '$senderDisplayName добавил(а) в чат: $userNames';

      case 'remove':
      case 'kick':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName удалил(а) участников из чата';
        }
        final userNames = formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName удалил(а) участников из чата';
        }

        if (userIds.contains(myId)) {
          return 'Вы были удалены из чата';
        }
        return '$senderDisplayName удалил(а) из чата: $userNames';

      case 'leave':
        if (isMe) {
          return 'Вы покинули группу';
        }
        return '$senderName покинул(а) группу';

      case 'title':
        final newTitle = controlAttach['title'] ?? '';
        if (newTitle.isEmpty) {
          return '$senderDisplayName изменил(а) название группы';
        }
        return '$senderDisplayName изменил(а) название группы на "$newTitle"';

      case 'avatar':
      case 'photo':
        return '$senderDisplayName изменил(а) фото группы';

      case 'description':
        return '$senderDisplayName изменил(а) описание группы';

      case 'admin':
      case 'promote':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName назначил(а) администраторов';
        }
        final userNames = formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName назначил(а) администраторов';
        }

        if (userIds.contains(myId) && userIds.length == 1) {
          return 'Вас назначили администратором';
        }
        return '$senderDisplayName назначил(а) администраторами: $userNames';

      case 'demote':
      case 'remove_admin':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName снял(а) администраторов';
        }
        final userNames = formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName снял(а) администраторов';
        }

        if (userIds.contains(myId) && userIds.length == 1) {
          return 'Вас сняли с должности администратора';
        }
        return '$senderDisplayName снял(а) с должности администратора: $userNames';

      case 'ban':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName заблокировал(а) участников';
        }
        final userNames = formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName заблокировал(а) участников';
        }

        if (userIds.contains(myId)) {
          return 'Вы были заблокированы в чате';
        }
        return '$senderDisplayName заблокировал(а): $userNames';

      case 'unban':
        final userIds = List<int>.from(
          (controlAttach['userIds'] as List?)?.map((id) => id as int) ?? [],
        );
        if (userIds.isEmpty) {
          return '$senderDisplayName разблокировал(а) участников';
        }
        final userNames = formatUserList(userIds);
        if (userNames.isEmpty) {
          return '$senderDisplayName разблокировал(а) участников';
        }
        return '$senderDisplayName разблокировал(а): $userNames';

      case 'join':
        if (isMe) {
          return 'Вы присоединились к группе';
        }
        return '$senderName присоединился(ась) к группе';

      case 'pin':
        final pinnedMessage = controlAttach['pinnedMessage'];
        if (pinnedMessage != null && pinnedMessage is Map<String, dynamic>) {
          final pinnedText = pinnedMessage['text'] as String?;
          if (pinnedText != null && pinnedText.isNotEmpty) {
            return '$senderDisplayName закрепил(а) сообщение: "$pinnedText"';
          }
        }
        return '$senderDisplayName закрепил(а) сообщение';

      default:
        final eventTypeStr = eventType?.toString() ?? 'неизвестное';

        
        if (eventTypeStr.toLowerCase() == 'system') {
          return 'Стартовое событие, не обращайте внимания.';
        }
        if (eventTypeStr == 'joinByLink') {
          return 'Кто-то присоединился(ась) по пригласительной ссылке...';
        }

        return 'Событие: $eventTypeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _formatControlMessage(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openUserProfileById(BuildContext context, int userId) async {
  var contact = ApiService.instance.getCachedContact(userId);

  if (contact == null) {
    print(
      '⚠️ [openUserProfileById] Контакт $userId не найден в кэше, загружаем с сервера...',
    );

    try {
      final contacts = await ApiService.instance.fetchContactsByIds([userId]);
      if (contacts.isNotEmpty) {
        contact = contacts.first;
        print(
          '✅ [openUserProfileById] Контакт $userId загружен: ${contact.name}',
        );
      } else {
        print(
          '❌ [openUserProfileById] Сервер не вернул данные для контакта $userId',
        );
      }
    } catch (e) {
      print('❌ [openUserProfileById] Ошибка загрузки контакта $userId: $e');
    }
  }

  if (contact != null) {
    final contactData = contact;
    final isGroup = contactData.id < 0;

    if (isGroup) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        transitionAnimationController: AnimationController(
          vsync: Navigator.of(context),
          duration: const Duration(milliseconds: 400),
        )..forward(),
        builder: (context) => GroupProfileDraggableDialog(contact: contactData),
      );
    } else {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) {
            return ContactProfileDialog(contact: contactData);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  } else {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text('Не удалось загрузить информацию о пользователе $userId'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _VideoWallpaperBackground extends StatefulWidget {
  final String videoPath;

  const _VideoWallpaperBackground({required this.videoPath});

  @override
  State<_VideoWallpaperBackground> createState() =>
      _VideoWallpaperBackgroundState();
}

class _VideoWallpaperBackgroundState extends State<_VideoWallpaperBackground> {
  VideoPlayerController? _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'Video file not found';
        });
        print('ERROR: Video file does not exist: ${widget.videoPath}');
        return;
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();

      if (mounted) {
        _controller!.setVolume(0);
        _controller!.setLooping(true);
        _controller!.play();
        setState(() {});
        print('SUCCESS: Video initialized and playing');
      }
    } catch (e) {
      print('ERROR initializing video: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      print('ERROR building video widget: $_errorMessage');
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'Error loading video\n$_errorMessage',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),

        Container(color: Colors.black.withOpacity(0.3)),
      ],
    );
  }
}
