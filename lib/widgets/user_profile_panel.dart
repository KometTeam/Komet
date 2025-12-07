import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/widgets/contact_name_widget.dart';
import 'package:gwid/widgets/contact_avatar_widget.dart';
import 'package:gwid/services/contact_local_names_service.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/screens/chat_screen.dart';

class UserProfilePanel extends StatefulWidget {
  final int userId;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? description;
  final int myId;
  final int? currentChatId;
  final Map<String, dynamic>? contactData;
  final int? dialogChatId;

  const UserProfilePanel({
    super.key,
    required this.userId,
    this.name,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.description,
    required this.myId,
    this.currentChatId,
    this.contactData,
    this.dialogChatId,
  });

  @override
  State<UserProfilePanel> createState() => _UserProfilePanelState();
}

class _UserProfilePanelState extends State<UserProfilePanel> {
  final ScrollController _nameScrollController = ScrollController();
  String? _localDescription;
  StreamSubscription? _changesSubscription;
  StreamSubscription? _wsSubscription;
  bool _isOpeningChat = false;
  bool _isInContacts = false;
  bool _isAddingToContacts = false;

  String get _displayName {
    final displayName = getContactDisplayName(
      contactId: widget.userId,
      originalName: widget.name,
      originalFirstName: widget.firstName,
      originalLastName: widget.lastName,
    );
    return displayName;
  }

  String? get _displayDescription {
    if (_localDescription != null && _localDescription!.isNotEmpty) {
      return _localDescription;
    }
    return widget.description;
  }

  @override
  void initState() {
    super.initState();
    _loadLocalDescription();
    _checkIfInContacts();

    _changesSubscription = ContactLocalNamesService().changes.listen((
      contactId,
    ) {
      if (contactId == widget.userId && mounted) {
        _loadLocalDescription();
        _checkIfInContacts();
      }
    });

    _wsSubscription = ApiService.instance.messages.listen((msg) {
      try {
        if (msg['opcode'] == 34 &&
            msg['cmd'] == 1 &&
            msg['payload'] != null &&
            msg['payload']['contact'] != null) {
          final contactJson = msg['payload']['contact'] as Map<String, dynamic>;
          final id = contactJson['id'] as int?;
          if (id == widget.userId && mounted) {
            final contact = Contact.fromJson(contactJson);
            ApiService.instance.updateContactCache([contact]);
            setState(() {
              _isInContacts = true;
            });
          }
        }
      } catch (_) {}
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNameLength();
    });
  }

  Future<void> _checkIfInContacts() async {
    final cached = ApiService.instance.getCachedContact(widget.userId);
    if (mounted) {
      setState(() {
        _isInContacts = cached != null;
      });
    }
  }

  Future<void> _loadLocalDescription() async {
    final localData = ContactLocalNamesService().getContactData(widget.userId);
    if (mounted) {
      setState(() {
        _localDescription = localData?['notes'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    _wsSubscription?.cancel();
    _nameScrollController.dispose();
    super.dispose();
  }

  void _checkNameLength() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_nameScrollController.hasClients) {
        final maxScroll = _nameScrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _startNameScroll();
        }
      }
    });
  }

  void _startNameScroll() {
    if (!_nameScrollController.hasClients) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !_nameScrollController.hasClients) return;

      _nameScrollController
          .animateTo(
            _nameScrollController.position.maxScrollExtent,
            duration: const Duration(seconds: 3),
            curve: Curves.easeInOut,
          )
          .then((_) {
            if (!mounted) return;
            Future.delayed(const Duration(seconds: 1), () {
              if (!mounted || !_nameScrollController.hasClients) return;
              _nameScrollController
                  .animateTo(
                    0,
                    duration: const Duration(seconds: 3),
                    curve: Curves.easeInOut,
                  )
                  .then((_) {
                    if (mounted) {
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) _startNameScroll();
                      });
                    }
                  });
            });
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ContactAvatarWidget(
                  contactId: widget.userId,
                  originalAvatarUrl: widget.avatarUrl,
                  radius: 40,
                  fallbackText: _displayName.isNotEmpty
                      ? _displayName[0].toUpperCase()
                      : '?',
                  backgroundColor: colors.primaryContainer,
                  textColor: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textPainter = TextPainter(
                      text: TextSpan(
                        text: _displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      maxLines: 1,
                      textDirection: TextDirection.ltr,
                    );
                    textPainter.layout();
                    final textWidth = textPainter.size.width;
                    final needsScroll = textWidth > constraints.maxWidth;

                    if (needsScroll) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _checkNameLength();
                      });
                      return SizedBox(
                        height: 28,
                        child: SingleChildScrollView(
                          controller: _nameScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    } else {
                      return Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.phone,
                      label: 'Позвонить',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Звонков пока нету'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      colors: colors,
                    ),
                    if (widget.userId >= 0) ...[
                      _buildActionButton(
                        icon: Icons.person_add,
                        label: _isInContacts ? 'В контактах' : 'В контакты',
                        onPressed: _isInContacts || _isAddingToContacts
                            ? null
                            : _handleAddToContacts,
                        colors: colors,
                        isLoading: _isAddingToContacts,
                      ),
                      _buildActionButton(
                        icon: Icons.message,
                        label: 'Написать',
                        onPressed: _isOpeningChat ? null : _handleWriteMessage,
                        colors: colors,
                        isLoading: _isOpeningChat,
                      ),
                    ],
                  ],
                ),
                if (_displayDescription != null &&
                    _displayDescription!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    _displayDescription!,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required ColorScheme colors,
    bool isLoading = false,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(icon, color: colors.primary),
                  onPressed: onPressed,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _handleWriteMessage() async {
    if (_isOpeningChat) return;

    setState(() {
      _isOpeningChat = true;
    });

    try {
      // Сначала пробуем использовать dialogChatId, если он уже есть
      int? chatId = widget.dialogChatId;

      if (chatId == null || chatId == 0) {
        // Если нет, считаем chatId по формуле chatId = userId1 ^ userId2
        chatId = await ApiService.instance.getChatIdByUserId(widget.userId);
      }

      if (chatId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось открыть чат с пользователем'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Закрываем панель профиля
      Navigator.of(context).pop();

      // Открываем экран чата
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ChatScreen(
            chatId: chatId!,
            contact: Contact(
              id: widget.userId,
              name: widget.name ?? _displayName,
              firstName: widget.firstName ?? '',
              lastName: widget.lastName ?? '',
              description: widget.description,
              photoBaseUrl: widget.avatarUrl,
              accountStatus: 0,
              status: null,
              options: const [],
            ),
            myId: widget.myId,
            isGroupChat: false,
            isChannel: false,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при открытии чата: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningChat = false;
        });
      }
    }
  }

  Future<void> _handleAddToContacts() async {
    if (_isAddingToContacts || _isInContacts) return;

    setState(() {
      _isAddingToContacts = true;
    });

    try {
      // Отправляем opcode=34 с action="ADD"
      await ApiService.instance.addContact(widget.userId);

      // Пытаемся сразу подтянуть обновлённые данные контакта
      await ApiService.instance.requestContactsByIds([widget.userId]);

      await _checkIfInContacts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запрос на добавление в контакты отправлен'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при добавлении в контакты: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToContacts = false;
        });
      }
    }
  }
}
