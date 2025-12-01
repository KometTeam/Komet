import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:gwid/api/api_service.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gwid/screens/chat_screen.dart';
import 'package:gwid/screens/manage_account_screen.dart';
import 'package:gwid/screens/settings/settings_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/models/chat_folder.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/screens/join_group_screen.dart';
import 'package:gwid/screens/search_contact_screen.dart';
import 'package:gwid/screens/channels_list_screen.dart';
import 'package:gwid/models/channel.dart';
import 'package:gwid/screens/search_channels_screen.dart';
import 'package:gwid/screens/downloads_screen.dart';
import 'package:gwid/utils/user_id_lookup_screen.dart';
import 'package:gwid/screens/music_library_screen.dart';
import 'package:gwid/widgets/message_preview_dialog.dart';
import 'package:gwid/services/chat_read_settings_service.dart';
import 'package:gwid/services/local_profile_manager.dart';
import 'package:gwid/widgets/contact_name_widget.dart';
import 'package:gwid/widgets/contact_avatar_widget.dart';
import 'package:gwid/services/account_manager.dart';
import 'package:gwid/models/account.dart';

class SearchResult {
  final Chat chat;
  final Contact? contact;
  final String matchedText;
  final String matchType;
  final int? messageIndex;

  SearchResult({
    required this.chat,
    this.contact,
    required this.matchedText,
    required this.matchType,
    this.messageIndex,
  });
}

class ChatsScreen extends StatefulWidget {
  final void Function(
    Chat chat,
    Contact contact,
    bool isGroup,
    bool isChannel,
    int? participantCount,
  )?
  onChatSelected;
  final bool hasScaffold;

  const ChatsScreen({super.key, this.onChatSelected, this.hasScaffold = true});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late Future<Map<String, dynamic>> _chatsFuture;
  bool _showChannelsRail = false;
  List<Channel> _channels = [];
  bool _channelsLoaded = false;
  StreamSubscription? _apiSubscription;
  List<Chat> _allChats = [];
  List<Chat> _filteredChats = [];
  Map<int, Contact> _contacts = {};
  bool _isSearchExpanded = false;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  List<SearchResult> _searchResults = [];
  String _searchFilter = 'all';
  bool _hasRequestedBlockedContacts = false;
  final Set<int> _loadingContactIds = {};

  List<ChatFolder> _folders = [];
  String? _selectedFolderId;
  late TabController _folderTabController;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _searchAnimationController;
  Profile? _myProfile;
  bool _isProfileLoading = true;
  String _connectionStatus = 'connecting';
  StreamSubscription<void>? _connectionStatusSubscription;
  StreamSubscription<String>? _connectionStateSubscription;
  bool _isAccountsExpanded = false;

  SharedPreferences? _prefs;

  Future<void> _initializePrefs() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _prefs = p;
      });
    } else {
      _prefs = p;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePrefs();
    _loadMyProfile();
    _chatsFuture = (() async {
      try {
        await ApiService.instance.waitUntilOnline();
        return ApiService.instance.getChatsAndContacts();
      } catch (e) {
        print('Ошибка получения чатов: $e');
        if (e.toString().contains('Auth token not found') ||
            e.toString().contains('FAIL_WRONG_PASSWORD')) {
          _showTokenExpiredDialog(
            'Токен авторизации недействителен. Требуется повторная авторизация.',
          );
        }
        rethrow;
      }
    })();

    _listenForUpdates();

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _folderTabController = TabController(length: 1, vsync: this);
    _folderTabController.addListener(_onFolderTabChanged);

    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);

    _connectionStateSubscription = ApiService.instance.connectionStatus.listen((
      status,
    ) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    });

    _connectionStatusSubscription = ApiService.instance.reconnectionComplete
        .listen((_) {
          if (mounted) {
            print("🔄 ChatsScreen: Получено уведомление о переподключении");
            _loadChatsAndContacts();
            print("🔄 ChatsScreen: Обновление чатов запущено");
          }
        });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _loadChannels();
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadMyProfile() async {
    if (!mounted) return;
    setState(() {
      _isProfileLoading = true;
    });

    Profile? serverProfile;

    try {
      final accountManager = AccountManager();
      await accountManager.initialize();
      final currentAccount = accountManager.currentAccount;
      if (currentAccount?.profile != null) {
        serverProfile = currentAccount!.profile;
      }
    } catch (e) {
      print('Ошибка загрузки профиля из AccountManager: $e');
    }

    if (serverProfile == null) {
      final cachedProfileData =
          ApiService.instance.lastChatsPayload?['profile'];
      if (cachedProfileData != null) {
        serverProfile = Profile.fromJson(cachedProfileData);
      }
    }

    try {
      final profileManager = LocalProfileManager();
      await profileManager.initialize();
      final actualProfile = await profileManager.getActualProfile(
        serverProfile,
      );

      if (mounted && actualProfile != null) {
        setState(() {
          _myProfile = actualProfile;
          _isProfileLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Ошибка загрузки локального профиля: $e');
    }

    if (mounted && serverProfile != null) {
      setState(() {
        _myProfile = serverProfile;
        _isProfileLoading = false;
      });
      return;
    }

    try {
      if (!ApiService.instance.isOnline) {
        await ApiService.instance.waitUntilOnline().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print("Таймаут ожидания подключения для загрузки профиля");
            throw TimeoutException("Таймаут подключения");
          },
        );
      }

      final result = await ApiService.instance
          .getChatsAndContacts(force: true)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print("Таймаут загрузки чатов и профиля");
              throw TimeoutException("Таймаут загрузки");
            },
          );

      if (mounted) {
        final profileJson = result['profile'];
        if (profileJson != null) {
          setState(() {
            _myProfile = Profile.fromJson(profileJson);
            _isProfileLoading = false;
          });
        } else {
          setState(() {
            _isProfileLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProfileLoading = false;
        });
        print("Ошибка загрузки профиля в ChatsScreen: $e");
      }
    }
  }

  void _navigateToLogin() {
    print('Перенаправляем на экран входа из-за недействительного токена');
    /*Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const PhoneEntryScreen()),
    );*/
  }

  void _showTokenExpiredDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка авторизации'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin();
              },
              child: const Text('Войти заново'),
            ),
          ],
        );
      },
    );
  }

  void _listenForUpdates() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      if (message['type'] == 'invalid_token') {
        print(
          'Получено событие недействительного токена, перенаправляем на вход',
        );
        _showTokenExpiredDialog(
          message['message'] ?? 'Токен авторизации недействителен',
        );
        return;
      }

      final opcode = message['opcode'];
      final cmd = message['cmd'];
      final payload = message['payload'];

      if (opcode == 19 && cmd == 1 && payload != null) {
        final profileData = payload['profile'];
        if (profileData != null) {
          print('🔄 ChatsScreen: Получен профиль из opcode 19, обновляем UI');
          if (mounted) {
            setState(() {
              _myProfile = Profile.fromJson(profileData);
              _isProfileLoading = false;
            });
          }
        }
      }

      if (payload == null) return;
      final chatIdValue = payload['chatId'];
      final int? chatId = chatIdValue != null ? chatIdValue as int? : null;

      // Для части опкодов (48, 55, 135, 272, 274) нам не нужен явный chatId в корне
      // payload, поэтому не отбрасываем их, даже если chatId == null.
      if (opcode == 272 ||
          opcode == 274 ||
          opcode == 48 ||
          opcode == 55 ||
          opcode == 135) {
        // продолжаем обработку ниже
      } else if (chatId == null) {
        return;
      }

      if (opcode == 129 && chatId != null) {
        _setTypingForChat(chatId);
      }

      // Ответ на отправку сообщения (opcode 64).
      // Если сервер прислал в payload полный объект chat (как при создании группы
      // через CONTROL new), добавляем/обновляем чат локально.
      if (opcode == 64 && cmd == 1 && payload['chat'] is Map<String, dynamic>) {
        final chatJson = payload['chat'] as Map<String, dynamic>;
        final newChat = Chat.fromJson(chatJson);

        // Обновляем также глобальный кэш ApiService, чтобы настройки группы и
        // другие экраны сразу видели корректные права/админов/опции.
        ApiService.instance.updateChatInCacheFromJson(chatJson);

        if (mounted) {
          setState(() {
            final existingIndex = _allChats.indexWhere(
              (chat) => chat.id == newChat.id,
            );

            if (existingIndex != -1) {
              _allChats[existingIndex] = newChat;
            } else {
              final savedIndex = _allChats.indexWhere(_isSavedMessages);
              final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
              _allChats.insert(insertIndex, newChat);
            }

            _filterChats();
          });
        }
      }

      // Новый входящий месседж (opcode 128) — обновляем последний месседж и
      // двигаем чат вверх БЕЗ полного рефреша с сервера. Если такого чата ещё нет
      // (нам написал новый пользователь), создаём его на основе payload.chat.
      if (opcode == 128 && chatId != null) {
        final newMessage = Message.fromJson(payload['message']);
        ApiService.instance.clearCacheForChat(chatId);

        final int chatIndex = _allChats.indexWhere((chat) => chat.id == chatId);

        if (chatIndex != -1) {
          final oldChat = _allChats[chatIndex];
          final updatedChat = oldChat.copyWith(
            lastMessage: newMessage,
            newMessages: newMessage.senderId != oldChat.ownerId
                ? oldChat.newMessages + 1
                : oldChat.newMessages,
          );

          setState(() {
            _allChats.removeAt(chatIndex);

            if (_isSavedMessages(updatedChat)) {
              if (updatedChat.id == 0) {
                _allChats.insert(0, updatedChat);
              } else {
                final savedIndex = _allChats.indexWhere(
                  (c) => _isSavedMessages(c) && c.id == 0,
                );
                final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
                _allChats.insert(insertIndex, updatedChat);
              }
            } else {
              final savedIndex = _allChats.indexWhere(
                (c) => _isSavedMessages(c),
              );
              final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
              _allChats.insert(insertIndex, updatedChat);
            }
            _filterChats();
          });
        } else if (payload['chat'] is Map<String, dynamic>) {
          // Чат ещё не известен клиенту — создаём его на основе payload.chat.
          final chatJson = payload['chat'] as Map<String, dynamic>;
          final newChat = Chat.fromJson(chatJson);

          // Обновляем глобальный кэш ApiService, чтобы дальше во всех экранах
          // был один и тот же объект чата.
          ApiService.instance.updateChatInCacheFromJson(chatJson);

          setState(() {
            final savedIndex = _allChats.indexWhere(_isSavedMessages);
            final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
            _allChats.insert(insertIndex, newChat);
            _filterChats();
          });
        }
      } else if (opcode == 67 && chatId != null) {
        final editedMessage = Message.fromJson(payload['message']);
        ApiService.instance.clearCacheForChat(chatId);

        final int chatIndex = _allChats.indexWhere((chat) => chat.id == chatId);
        if (chatIndex != -1) {
          final oldChat = _allChats[chatIndex];

          if (oldChat.lastMessage.id == editedMessage.id) {
            final updatedChat = oldChat.copyWith(lastMessage: editedMessage);
            setState(() {
              _allChats.removeAt(chatIndex);

              if (_isSavedMessages(updatedChat)) {
                if (updatedChat.id == 0) {
                  _allChats.insert(0, updatedChat);
                } else {
                  final savedIndex = _allChats.indexWhere(
                    (c) => _isSavedMessages(c) && c.id == 0,
                  );
                  final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
                  _allChats.insert(insertIndex, updatedChat);
                }
              } else {
                final savedIndex = _allChats.indexWhere(
                  (c) => _isSavedMessages(c),
                );
                final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
                _allChats.insert(insertIndex, updatedChat);
              }
              _filterChats();
            });
          }
        }
      } else if (opcode == 66 && chatId != null) {
        final deletedMessageIds = List<String>.from(
          payload['messageIds'] ?? [],
        );
        ApiService.instance.clearCacheForChat(chatId);

        final int chatIndex = _allChats.indexWhere((chat) => chat.id == chatId);
        if (chatIndex != -1) {
          final oldChat = _allChats[chatIndex];

          if (deletedMessageIds.contains(oldChat.lastMessage.id)) {
            ApiService.instance.getChatsOnly(force: true).then((data) {
              if (mounted) {
                final chats = data['chats'] as List<dynamic>;
                final filtered = chats
                    .cast<Map<String, dynamic>>()
                    .where((chat) => chat['id'] == chatId)
                    .toList();
                final Map<String, dynamic>? updatedChatData =
                    filtered.isNotEmpty ? filtered.first : null;
                if (updatedChatData != null) {
                  final updatedChat = Chat.fromJson(updatedChatData);
                  setState(() {
                    _allChats.removeAt(chatIndex);
                    _allChats.insert(0, updatedChat);
                    _filterChats();
                  });
                }
              }
            });
          }
        }
      }

      if (opcode == 132) {
        final bool isOnline = payload['online'] == true;

        final dynamic contactIdAny = payload['contactId'] ?? payload['userId'];
        if (contactIdAny != null) {
          final int? cid = contactIdAny is int
              ? contactIdAny
              : int.tryParse(contactIdAny.toString());
          if (cid != null) {
            final currentTime =
                DateTime.now().millisecondsSinceEpoch ~/
                1000; // Конвертируем в секунды
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

            for (final chat in _allChats) {
              final otherId = chat.participantIds.firstWhere(
                (id) => id != chat.ownerId,
                orElse: () => chat.ownerId,
              );
              if (otherId == cid) {
                if (isOnline) {
                  _onlineChats.add(chat.id);
                } else {
                  _onlineChats.remove(chat.id);
                }
              }
            }
            if (mounted) setState(() {});
            return;
          }
        }

        final dynamic cidAny = payload['chatId'];
        final int? chatIdFromPayload = cidAny is int
            ? cidAny
            : int.tryParse(cidAny?.toString() ?? '');
        if (chatIdFromPayload != null) {
          if (isOnline) {
            _onlineChats.add(chatIdFromPayload);
          } else {
            _onlineChats.remove(chatIdFromPayload);
          }
          if (mounted) setState(() {});
        }
      }

      if (opcode == 36 && payload['contacts'] != null) {
        final List<dynamic> blockedContactsJson = payload['contacts'] as List;
        final blockedContacts = blockedContactsJson
            .map((json) => Contact.fromJson(json))
            .toList();

        for (final blockedContact in blockedContacts) {
          print(
            'Обновляем контакт ${blockedContact.name} (ID: ${blockedContact.id}): isBlocked=${blockedContact.isBlocked}, isBlockedByMe=${blockedContact.isBlockedByMe}',
          );
          if (_contacts.containsKey(blockedContact.id)) {
            _contacts[blockedContact.id] = blockedContact;
            print(
              'Обновлен существующий контакт: ${_contacts[blockedContact.id]?.name}',
            );

            ApiService.instance.notifyContactUpdate(blockedContact);
          } else {
            _contacts[blockedContact.id] = blockedContact;
            print(
              'Добавлен новый заблокированный контакт: ${blockedContact.name}',
            );

            ApiService.instance.notifyContactUpdate(blockedContact);
          }
        }

        if (mounted) setState(() {});
      }

      // Создание/обновление группы (opcode 48) — стараемся обновить список чатов
      // локально по объекту chat из payload, без повторного getChatsAndContacts.
      if (opcode == 48) {
        print('Получен ответ на создание/обновление группы: $payload');

        final chatJson = payload['chat'] as Map<String, dynamic>?;
        final chatsJson = payload['chats'] as List<dynamic>?;

        // Приоритет: одиночный chat, дальше — первый из списка chats.
        Map<String, dynamic>? effectiveChatJson = chatJson;
        if (effectiveChatJson == null &&
            chatsJson != null &&
            chatsJson.isNotEmpty) {
          final first = chatsJson.first;
          if (first is Map<String, dynamic>) {
            effectiveChatJson = first;
          }
        }

        if (effectiveChatJson != null) {
          final newChat = Chat.fromJson(effectiveChatJson);

          // Синхронизируем объект чата и в глобальном кэше ApiService.
          ApiService.instance.updateChatInCacheFromJson(effectiveChatJson);
          if (mounted) {
            setState(() {
              final existingIndex = _allChats.indexWhere(
                (chat) => chat.id == newChat.id,
              );

              if (existingIndex != -1) {
                _allChats[existingIndex] = newChat;
              } else {
                // Вставляем новый чат сразу после "Избранного", если оно есть.
                final savedIndex = _allChats.indexWhere(_isSavedMessages);
                final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
                _allChats.insert(insertIndex, newChat);
              }

              _filterChats();
            });
          }
        } else {
          // Fallback: если сервер не прислал chat, обновляемся старым способом.
          _refreshChats();
        }
      }

      // Изменение параметров чата (rename, invite‑link и т.п.) приходит с opcode 55.
      // В payload обычно лежит обновленный объект chat.
      if (opcode == 55 && cmd == 1) {
        final chatJson = payload['chat'] as Map<String, dynamic>?;
        if (chatJson != null) {
          final updatedChat = Chat.fromJson(chatJson);

          // Обновляем глобальный кэш ApiService, чтобы настройки группы и др.
          // сразу видели новые права/линки/название.
          ApiService.instance.updateChatInCacheFromJson(chatJson);
          if (mounted) {
            setState(() {
              final existingIndex = _allChats.indexWhere(
                (chat) => chat.id == updatedChat.id,
              );

              if (existingIndex != -1) {
                _allChats[existingIndex] = updatedChat;
              } else {
                final savedIndex = _allChats.indexWhere(_isSavedMessages);
                final insertIndex = savedIndex >= 0 ? savedIndex + 1 : 0;
                _allChats.insert(insertIndex, updatedChat);
              }

              _filterChats();
            });
          }
        }
      }

      // Выход из группы: сервер сначала шлёт opcode 135 с chat.status = REMOVED,
      // а уже потом opcode 58 с CONTROL-сообщением "leave". Для обновления списка
      // чатов нам важен именно 135.
      if (opcode == 135 && payload['chat'] is Map<String, dynamic>) {
        final removedChat = payload['chat'] as Map<String, dynamic>;
        final int? removedChatId = removedChat['id'] as int?;
        final String? status = removedChat['status'] as String?;

        if (removedChatId != null && status == 'REMOVED') {
          if (mounted) {
            setState(() {
              _allChats.removeWhere((chat) => chat.id == removedChatId);
              _filteredChats.removeWhere((chat) => chat.id == removedChatId);
            });
          }
        }
      }

      if (opcode == 272) {
        print('Получен ответ на обновление папок: $payload');

        if (payload['folders'] != null || payload['foldersOrder'] != null) {
          try {
            final foldersJson = payload['folders'] as List<dynamic>?;
            if (foldersJson != null) {
              final folders = foldersJson
                  .map(
                    (json) => ChatFolder.fromJson(json as Map<String, dynamic>),
                  )
                  .toList();

              if (mounted) {
                setState(() {
                  _folders = folders;
                  final foldersOrder =
                      payload['foldersOrder'] as List<dynamic>?;
                  _sortFoldersByOrder(foldersOrder);
                });
                _updateFolderTabController();
                _filterChats();
              }
            }
          } catch (e) {
            print('Ошибка обработки папок из opcode 272: $e');
          }
        } else {
          _refreshChats();
        }
      }

      if (opcode == 274 && cmd == 1) {
        print('Получен ответ на создание/обновление папки: $payload');

        try {
          final folderJson = payload['folder'] as Map<String, dynamic>?;
          if (folderJson != null) {
            final updatedFolder = ChatFolder.fromJson(folderJson);
            final folderId = updatedFolder.id;

            if (mounted) {
              final existingIndex = _folders.indexWhere(
                (f) => f.id == folderId,
              );
              final isNewFolder = existingIndex == -1;

              setState(() {
                if (existingIndex != -1) {
                  _folders[existingIndex] = updatedFolder;
                } else {
                  _folders.add(updatedFolder);
                }

                final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
                _sortFoldersByOrder(foldersOrder);
              });

              _updateFolderTabController();
              _filterChats();

              if (isNewFolder) {
                final newFolderIndex = _folders.indexWhere(
                  (f) => f.id == folderId,
                );
                if (newFolderIndex != -1) {
                  final targetIndex = newFolderIndex + 1;
                  if (_folderTabController.length > targetIndex) {
                    _folderTabController.animateTo(targetIndex);
                  }
                }
              }
            }
          }
        } catch (e) {
          print(
            'Ошибка обработки созданной/обновленной папки из opcode 274: $e',
          );
        }
      }

      if (opcode == 276 && cmd == 1) {
        print('Получен ответ на удаление папки: $payload');

        try {
          final foldersOrder = payload['foldersOrder'] as List<dynamic>?;
          if (foldersOrder != null && mounted) {
            final currentIndex = _folderTabController.index;

            setState(() {
              final orderedIds = foldersOrder
                  .map((id) => id.toString())
                  .toList();
              _folders.removeWhere((folder) => !orderedIds.contains(folder.id));
              _sortFoldersByOrder(foldersOrder);
            });

            _updateFolderTabController();
            _filterChats();

            if (currentIndex >= _folderTabController.length) {
              _folderTabController.animateTo(0);
            } else if (currentIndex > 0) {
              _folderTabController.animateTo(
                currentIndex < _folderTabController.length ? currentIndex : 0,
              );
            }

            ApiService.instance.requestFolderSync();
          }
        } catch (e) {
          print('Ошибка обработки удаления папки из opcode 276: $e');
        }
      }

      if (message['type'] == 'channels_found') {
        final payload = message['payload'];
        final channelsData = payload['contacts'] as List<dynamic>?;

        if (channelsData != null) {
          setState(() {
            _channels = channelsData
                .map((channelJson) => Channel.fromJson(channelJson))
                .toList();
          });
        }
      }
    });
  }

  void _removeChatLocally(int chatId) {
    if (!mounted) return;
    setState(() {
      _allChats.removeWhere((c) => c.id == chatId);
      _filteredChats.removeWhere((c) => c.id == chatId);
    });
  }

  final Map<int, Timer> _typingDecayTimers = {};
  final Set<int> _typingChats = {};
  final Set<int> _onlineChats = {};
  void _setTypingForChat(int chatId) {
    _typingChats.add(chatId);
    _typingDecayTimers[chatId]?.cancel();
    _typingDecayTimers[chatId] = Timer(const Duration(seconds: 11), () {
      _typingChats.remove(chatId);
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  void _refreshChats() {
    _chatsFuture = ApiService.instance.getChatsAndContacts(force: true);
    _chatsFuture.then((data) {
      if (mounted) {
        final chats = data['chats'] as List<dynamic>;
        final contacts = data['contacts'] as List<dynamic>;
        final profileData = data['profile'];

        _allChats = chats
            .where((json) => json != null)
            .map((json) => Chat.fromJson(json))
            .toList();
        _contacts.clear();
        for (final contactJson in contacts) {
          final contact = Contact.fromJson(contactJson);
          _contacts[contact.id] = contact;
        }

        setState(() {
          if (profileData != null) {
            _myProfile = Profile.fromJson(profileData);
            _isProfileLoading = false;
          }
        });

        _filterChats();
      }
    });
  }

  Widget _buildChannelsRail() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.outline.withOpacity(0.2), width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: colors.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.broadcast_on_personal,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Каналы',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                    fontSize: 16,
                  ),
                ),
                /*const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ChannelsListScreen(),
                      ),
                    );
                  },
                  tooltip: 'Поиск каналов',
                ),*/
              ],
            ),
          ),

          Expanded(child: _buildChannelsList()),
        ],
      ),
    );
  }

  void _loadChannels() async {
    if (_channelsLoaded) return;

    try {
      await ApiService.instance.searchChannels('каналы');
      _channelsLoaded = true;
    } catch (e) {
      print('Ошибка загрузки каналов: $e');
    }
  }

  Widget _buildChannelsList() {
    final colors = Theme.of(context).colorScheme;

    if (_channels.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _buildChannelItem(
            'Новости',
            'Актуальные новости',
            Icons.newspaper,
            colors.primaryContainer,
            colors.onPrimaryContainer,
          ),
          _buildChannelItem(
            'Технологии',
            'IT и технологии',
            Icons.computer,
            colors.secondaryContainer,
            colors.onSecondaryContainer,
          ),
          _buildChannelItem(
            'Спорт',
            'Спортивные новости',
            Icons.sports,
            colors.tertiaryContainer,
            colors.onTertiaryContainer,
          ),
          _buildChannelItem(
            'Развлечения',
            'Фильмы, музыка, игры',
            Icons.movie,
            colors.errorContainer,
            colors.onErrorContainer,
          ),
          _buildChannelItem(
            'Образование',
            'Учеба и развитие',
            Icons.school,
            colors.primaryContainer,
            colors.onPrimaryContainer,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final channel = _channels[index];
        return _buildRealChannelItem(channel);
      },
    );
  }

  Widget _buildChannelItem(
    String title,
    String subtitle,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: backgroundColor,
          child: Icon(icon, size: 16, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Открытие канала: $title'),
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRealChannelItem(Channel channel) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundImage: channel.photoBaseUrl != null
              ? NetworkImage(channel.photoBaseUrl!)
              : null,
          child: channel.photoBaseUrl == null
              ? Text(
                  channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                )
              : null,
        ),
        title: Text(
          channel.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          channel.description ?? 'Канал',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChannelDetailsScreen(channel: channel),
            ),
          );
        },
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Создать',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.group_add,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Создать группу'),
                subtitle: const Text('Создать чат с несколькими участниками'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateGroupDialog();
                },
              ),

              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_search,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Найти контакт'),
                subtitle: const Text('Поиск по номеру телефона'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SearchContactScreen(),
                    ),
                  );
                },
              ),

              /*ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.broadcast_on_personal,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: const Text('Каналы'),
                subtitle: const Text('Просмотр и подписка на каналы'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ChannelsListScreen(),
                    ),
                  );
                },
              ),*/
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.link,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                title: const Text('Присоединиться по ссылке'),
                subtitle: const Text('По ссылке-приглашению'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const JoinGroupScreen(),
                    ),
                  );
                },
              ),

              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.download,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                title: const Text('Загрузки'),
                subtitle: const Text('Скачанные файлы'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DownloadsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showCreateGroupDialog() {
    final TextEditingController nameController = TextEditingController();
    final List<int> selectedContacts = [];

    final int? myId = _myProfile?.id;

    final List<Contact> availableContacts = _contacts.values.where((contact) {
      final contactNameLower = contact.name.toLowerCase();
      return contactNameLower != 'max' &&
          contactNameLower != 'gigachat' &&
          (myId == null || contact.id != myId);
    }).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Создать группу'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Название группы',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Выберите участников:'),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                width: 300,

                child: ListView.builder(
                  itemCount: availableContacts.length,
                  itemBuilder: (context, index) {
                    final contact = availableContacts[index];
                    final isSelected = selectedContacts.contains(contact.id);

                    return CheckboxListTile(
                      title: Text(
                        getContactDisplayName(
                          contactId: contact.id,
                          originalName: contact.name,
                          originalFirstName: contact.firstName,
                          originalLastName: contact.lastName,
                        ),
                      ),
                      subtitle: Text(
                        contact.firstName.isNotEmpty &&
                                contact.lastName.isNotEmpty
                            ? '${contact.firstName} ${contact.lastName}'
                            : '',
                      ),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedContacts.add(contact.id);
                          } else {
                            selectedContacts.remove(contact.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  ApiService.instance.createGroupWithMessage(
                    nameController.text.trim(),
                    selectedContacts, // Будет [] если никого не выбрали
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSavedMessages(Chat chat) {
    return chat.id == 0;
  }

  bool _isGroupChat(Chat chat) {
    return chat.type == 'CHAT' || chat.participantIds.length > 2;
  }

  void _updateFolderTabController() {
    final oldIndex = _folderTabController.index;
    final newLength = 1 + _folders.length;
    if (_folderTabController.length != newLength) {
      _folderTabController.removeListener(_onFolderTabChanged);
      _folderTabController.dispose();
      _folderTabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: oldIndex < newLength ? oldIndex : 0,
      );
      _folderTabController.addListener(_onFolderTabChanged);
    }
  }

  void _sortFoldersByOrder(List<dynamic>? foldersOrder) {
    if (foldersOrder == null || foldersOrder.isEmpty) return;

    final orderedIds = foldersOrder.map((id) => id.toString()).toList();
    _folders.sort((a, b) {
      final aIndex = orderedIds.indexOf(a.id);
      final bIndex = orderedIds.indexOf(b.id);
      if (aIndex == -1 && bIndex == -1) return 0;
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });
  }

  void _loadFolders(Map<String, dynamic> data) {
    try {
      final config = data['config'] as Map<String, dynamic>?;
      if (config == null) return;

      final chatFolders = config['chatFolders'] as Map<String, dynamic>?;
      if (chatFolders == null) return;

      final foldersJson = chatFolders['FOLDERS'] as List<dynamic>?;
      if (foldersJson == null) return;

      final folders = foldersJson
          .map((json) => ChatFolder.fromJson(json as Map<String, dynamic>))
          .toList();

      setState(() {
        _folders = folders;

        final foldersOrder = chatFolders['foldersOrder'] as List<dynamic>?;
        _sortFoldersByOrder(foldersOrder);

        _updateFolderTabController();

        if (_selectedFolderId == null) {
          if (_folderTabController.index != 0) {
            _folderTabController.animateTo(0);
          }
        } else {
          final folderIndex = _folders.indexWhere(
            (f) => f.id == _selectedFolderId,
          );
          if (folderIndex != -1) {
            final targetIndex = folderIndex + 1;
            if (_folderTabController.index != targetIndex) {
              _folderTabController.animateTo(targetIndex);
            }
          }
        }
      });
    } catch (e) {
      print('Ошибка загрузки папок: $e');
    }
  }

  bool _chatBelongsToFolder(Chat chat, ChatFolder? folder) {
    if (folder == null) return true;

    if (folder.include != null && folder.include!.isNotEmpty) {
      return folder.include!.contains(chat.id);
    }

    if (folder.filters.isNotEmpty) {
      final hasContact = folder.filters.any(
        (f) => f == 9 || f == '9' || f == 'CONTACT',
      );
      final hasNotContact = folder.filters.any(
        (f) => f == 8 || f == '8' || f == 'NOT_CONTACT',
      );

      if (hasContact && hasNotContact) {
        if (chat.type != 'DIALOG' ||
            chat.participantIds.length > 2 ||
            _isGroupChat(chat)) {
          return false;
        }

        final otherParticipantId = chat.participantIds.firstWhere(
          (id) => id != chat.ownerId,
          orElse: () => 0,
        );
        if (otherParticipantId != 0) {
          final contact = _contacts[otherParticipantId];
          if (contact != null && contact.isBot) {
            return false;
          }
        }

        return true;
      }

      for (final filter in folder.filters) {
        bool matchesThisFilter = false;
        if (filter == 0 || filter == '0' || filter == 'UNREAD') {
          matchesThisFilter = chat.newMessages > 0;
        } else if (filter == 9 || filter == '9' || filter == 'CONTACT') {
          if (chat.type != 'DIALOG' ||
              chat.participantIds.length > 2 ||
              _isGroupChat(chat)) {
            matchesThisFilter = false;
          } else {
            final otherParticipantId = chat.participantIds.firstWhere(
              (id) => id != chat.ownerId,
              orElse: () => 0,
            );
            if (otherParticipantId != 0) {
              final contact = _contacts[otherParticipantId];
              matchesThisFilter = contact == null || !contact.isBot;
            } else {
              matchesThisFilter = true;
            }
          }
        } else if (filter == 8 || filter == '8' || filter == 'NOT_CONTACT') {
          matchesThisFilter =
              chat.type == 'CHAT' ||
              chat.type == 'CHANNEL' ||
              _isGroupChat(chat);
        } else {
          matchesThisFilter = false;
        }

        if (matchesThisFilter) {
          return true;
        }
      }
      return false;
    }

    return false;
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<Chat> chatsToFilter = _allChats;

      if (_selectedFolderId != null) {
        final selectedFolder = _folders.firstWhere(
          (f) => f.id == _selectedFolderId,
          orElse: () => _folders.first,
        );
        chatsToFilter = _allChats
            .where((chat) => _chatBelongsToFolder(chat, selectedFolder))
            .toList();
      }

      if (query.isEmpty && !_searchFocusNode.hasFocus) {
        _filteredChats = List.from(chatsToFilter);

        _filteredChats.sort((a, b) {
          final aIsSaved = _isSavedMessages(a);
          final bIsSaved = _isSavedMessages(b);
          if (aIsSaved && !bIsSaved) return -1; // Избранное в начало
          if (!aIsSaved && bIsSaved) return 1; // Избранное в начало

          if (aIsSaved && bIsSaved) {
            if (a.id == 0) return -1;
            if (b.id == 0) return 1;
          }
          return 0; // Остальные чаты сохраняют порядок
        });
      } else if (_searchFocusNode.hasFocus && query.isEmpty) {
        _filteredChats = [];
      } else if (query.isNotEmpty) {
        _filteredChats = chatsToFilter.where((chat) {
          final isSavedMessages = _isSavedMessages(chat);
          if (isSavedMessages) {
            return "избранное".contains(query);
          }
          final otherParticipantId = chat.participantIds.firstWhere(
            (id) => id != chat.ownerId,
            orElse: () => 0,
          );
          final contactName =
              _contacts[otherParticipantId]?.name.toLowerCase() ?? '';
          return contactName.contains(query);
        }).toList();

        _filteredChats.sort((a, b) {
          final aIsSaved = _isSavedMessages(a);
          final bIsSaved = _isSavedMessages(b);
          if (aIsSaved && !bIsSaved) return -1;
          if (!aIsSaved && bIsSaved) return 1;

          if (aIsSaved && bIsSaved) {
            if (a.id == 0) return -1;
            if (b.id == 0) return 1;
          }
          return 0;
        });
      } else {
        _filteredChats = [];
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _searchQuery = query;

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      _isSearchExpanded = true;
      _searchAnimationController.forward();
    } else if (_searchController.text.isEmpty) {
      _isSearchExpanded = false;
      _searchAnimationController.reverse();
    }
  }

  void _performSearch() async {
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {});

    final results = <SearchResult>[];
    final query = _searchQuery.toLowerCase();

    for (final chat in _allChats) {
      final isSavedMessages = _isSavedMessages(chat);

      if (isSavedMessages) {
        if ("избранное".contains(query)) {
          results.add(
            SearchResult(
              chat: chat,
              contact: _contacts[chat.ownerId],
              matchedText: "Избранное",
              matchType: 'name',
            ),
          );
        }
        continue;
      }

      final otherParticipantId = chat.participantIds.firstWhere(
        (id) => id != chat.ownerId,
        orElse: () => 0,
      );
      final contact = _contacts[otherParticipantId];

      if (contact == null) continue;

      final displayName = getContactDisplayName(
        contactId: contact.id,
        originalName: contact.name,
        originalFirstName: contact.firstName,
        originalLastName: contact.lastName,
      );

      if (displayName.toLowerCase().contains(query) ||
          contact.name.toLowerCase().contains(query)) {
        results.add(
          SearchResult(
            chat: chat,
            contact: contact,
            matchedText: displayName,
            matchType: 'name',
          ),
        );
        continue;
      }

      if (contact.description != null &&
          contact.description?.toLowerCase().contains(query) == true) {
        results.add(
          SearchResult(
            chat: chat,
            contact: contact,
            matchedText: contact.description ?? '',
            matchType: 'description',
          ),
        );
        continue;
      }

      if (chat.lastMessage.text.toLowerCase().contains(query) ||
          (chat.lastMessage.text.contains("welcome.saved.dialog.message") &&
              'привет избранные майор'.contains(query.toLowerCase()))) {
        results.add(
          SearchResult(
            chat: chat,
            contact: contact,
            matchedText:
                chat.lastMessage.text.contains("welcome.saved.dialog.message")
                ? 'Привет! Это твои избранные...'
                : chat.lastMessage.text,
            matchType: 'message',
          ),
        );
      }
    }

    List<SearchResult> filteredResults = results;
    if (_searchFilter == 'recent') {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      filteredResults = results.where((result) {
        final lastMessageTime = DateTime.fromMillisecondsSinceEpoch(
          result.chat.lastMessage.time,
        );
        return lastMessageTime.isAfter(weekAgo);
      }).toList();
    }

    setState(() {
      _searchResults = filteredResults;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _searchResults.clear();
      _isSearchExpanded = false;
    });
    _searchAnimationController.reverse();
  }

  void _loadChatsAndContacts() {
    // Берём актуальный снапшот чатов, если он уже есть (_lastChatsPayload),
    // а если нет — ApiService сам дёрнет opcode 19.
    final future = ApiService.instance.getChatsOnly();

    setState(() {
      _chatsFuture = future;
    });

    future.then((data) {
      if (!mounted) return;

      final chats = (data['chats'] as List?) ?? const [];
      final contacts = (data['contacts'] as List?) ?? const [];
      final profileData = data['profile'];

      setState(() {
        _allChats = chats
            .where((json) => json != null)
            .map((json) => Chat.fromJson(json))
            .toList();

        _contacts.clear();
        for (final contactJson in contacts) {
          final contact = Contact.fromJson(contactJson);
          _contacts[contact.id] = contact;
        }

        if (profileData != null) {
          _myProfile = Profile.fromJson(profileData);
          _isProfileLoading = false;
        }
      });

      _filterChats();
    });
  }

  Future<void> _loadChatOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOrder = prefs.getStringList('chat_order');
    if (savedOrder != null && savedOrder.isNotEmpty) {
      final chatIds = savedOrder.map((id) => int.parse(id)).toList();
      final orderedChats = <Chat>[];
      final remainingChats = List<Chat>.from(_allChats);

      for (final id in chatIds) {
        final chatIndex = remainingChats.indexWhere((chat) => chat.id == id);
        if (chatIndex != -1) {
          orderedChats.add(remainingChats.removeAt(chatIndex));
        }
      }

      orderedChats.addAll(remainingChats);

      _allChats = orderedChats;
      _filteredChats = List.from(_allChats);
    }
  }

  Future<void> _loadMissingContact(int contactId) async {
    if (_loadingContactIds.contains(contactId) ||
        _contacts.containsKey(contactId)) {
      return;
    }

    _loadingContactIds.add(contactId);

    try {
      final contacts = await ApiService.instance.fetchContactsByIds([
        contactId,
      ]);
      if (contacts.isNotEmpty && mounted) {
        setState(() {
          _contacts[contactId] = contacts.first;
        });
      }
    } catch (e) {
      print('Ошибка загрузки контакта $contactId: $e');
    } finally {
      _loadingContactIds.remove(contactId);
    }
  }

  String _formatTimestamp(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (now.day == dt.day && now.month == dt.month && now.year == dt.year) {
      return DateFormat('HH:mm', 'ru').format(dt);
    } else {
      final yesterday = now.subtract(const Duration(days: 1));
      if (dt.day == yesterday.day &&
          dt.month == yesterday.month &&
          dt.year == yesterday.year) {
        return 'Вчера';
      } else {
        return DateFormat('d MMM', 'ru').format(dt);
      }
    }
  }

  Future<void> _openSferum() async {
    try {
      await ApiService.instance.waitUntilOnline();
      final seq32 = ApiService.instance.sendAndTrackFullJsonRequest(
        jsonEncode({
          "ver": 11,
          "cmd": 0,
          "seq": 0,
          "opcode": 32,
          "payload": {
            "contactIds": [2340831],
          },
        }),
      );

      final resp32 = await ApiService.instance.messages
          .firstWhere((m) => m['seq'] == seq32)
          .timeout(const Duration(seconds: 10));

      final contacts = resp32['payload']['contacts'] as List;
      if (contacts.isEmpty) {
        throw Exception('Не удалось получить информацию о боте');
      }
      final webAppUrl = contacts[0]['webApp'] as String?;
      if (webAppUrl == null) {
        throw Exception('Бот не имеет веб-приложения');
      }

      int? chatId;
      for (var chat in _allChats) {
        if (chat.participantIds.contains(2340831)) {
          chatId = chat.id;
          break;
        }
      }

      print('🔍 Найден chatId для бота Сферума: ${chatId ?? "не найден"}');

      final seq160 = ApiService.instance.sendAndTrackFullJsonRequest(
        jsonEncode({
          "ver": 11,
          "cmd": 0,
          "seq": 0,
          "opcode": 160,
          "payload": {"botId": 2340831, "chatId": chatId ?? 0},
        }),
      );

      print('📤 Отправлен opcode 160 с seq: $seq160');

      final resp160 = await ApiService.instance.messages
          .firstWhere((m) => m['seq'] == seq160)
          .timeout(const Duration(seconds: 10));

      print('📥 Получен ответ на opcode 160: ${resp160.toString()}');

      final webUrl = resp160['payload']['url'] as String?;
      if (webUrl == null) {
        throw Exception('Не удалось получить URL веб-приложения');
      }

      print('🌐 URL веб-приложения: $webUrl');

      if (mounted) {
        _showSferumWebView(context, webUrl);
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка открытия Сферума: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка открытия Сферума: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSferumWebView(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SferumWebViewPanel(url: url),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildConnectionScreen() {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
            const SizedBox(height: 24),

            Text(
              'Подключение',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'Устанавливаем соединение с сервером...',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Widget bodyContent = Stack(
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _chatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildConnectionScreen();
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Ошибка загрузки чатов: ${snapshot.error}'),
              );
            }
            if (snapshot.hasData) {
              if (_allChats.isEmpty) {
                final chatListJson = snapshot.data!['chats'] as List;
                final contactListJson = snapshot.data!['contacts'] as List;
                _allChats = chatListJson
                    .map((json) => Chat.fromJson(json))
                    .toList();
                final contacts = contactListJson.map(
                  (json) => Contact.fromJson(json),
                );
                _contacts = {for (var c in contacts) c.id: c};

                final presence =
                    snapshot.data!['presence'] as Map<String, dynamic>?;
                if (presence != null) {
                  print('Получен presence: $presence');
                }

                if (!_hasRequestedBlockedContacts) {
                  _hasRequestedBlockedContacts = true;
                  ApiService.instance.getBlockedContacts();
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadFolders(snapshot.data!);
                });

                _loadChatOrder().then((_) {
                  setState(() {
                    _filteredChats = List.from(_allChats);
                  });
                });
              }
              // Если чаты есть, но текущий фильтр/папка не даёт ни одного результата
              // (например, после переподключения или некорректного фильтра),
              // то по умолчанию показываем все чаты, а не пустой экран.
              if (_filteredChats.isEmpty && _allChats.isNotEmpty) {
                _filteredChats = List.from(_allChats);
              }
              if (_filteredChats.isEmpty && _allChats.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_isSearchExpanded) {
                return _buildSearchResults();
              } else {
                return Column(
                  children: [
                    _buildFolderTabs(),
                    Expanded(
                      child: TabBarView(
                        controller: _folderTabController,
                        children: _buildFolderPages(),
                      ),
                    ),
                  ],
                );
              }
            }
            return const Center(child: Text('Нет данных'));
          },
        ),

        if (!_isSearchExpanded) _buildDebugRefreshPanel(context),
      ],
    );

    if (widget.hasScaffold) {
      return Builder(
        builder: (context) {
          return Scaffold(
            appBar: _buildAppBar(context),
            drawer: _buildAppDrawer(context),
            body: Row(children: [Expanded(child: bodyContent)]),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                _showAddMenu(context);
              },
              tooltip: 'Создать',
              heroTag: 'create_menu',
              child: const Icon(Icons.edit),
            ),
          );
        },
      );
    } else {
      return bodyContent;
    }
  }

  Widget _buildAppDrawer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<List<Account>>(
            future: _loadAccounts(),
            builder: (context, accountsSnapshot) {
              final accounts = accountsSnapshot.data ?? [];
              final accountManager = AccountManager();
              final currentAccount = accountManager.currentAccount;
              final hasMultipleAccounts = accounts.length > 1;

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16.0,
                      left: 16.0,
                      right: 16.0,
                      bottom: 16.0,
                    ),
                    decoration: BoxDecoration(color: colors.primaryContainer),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 30, // Чуть крупнее
                              backgroundColor: colors.primary,
                              backgroundImage:
                                  _isProfileLoading ||
                                      _myProfile?.photoBaseUrl == null
                                  ? null
                                  : NetworkImage(_myProfile!.photoBaseUrl!),
                              child: _isProfileLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : (_myProfile?.photoBaseUrl == null
                                        ? Text(
                                            _myProfile
                                                        ?.displayName
                                                        .isNotEmpty ==
                                                    true
                                                ? _myProfile!.displayName[0]
                                                      .toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: colors.onPrimary,
                                              fontSize: 28, // Крупнее
                                            ),
                                          )
                                        : null),
                            ),
                            IconButton(
                              icon: Icon(
                                isDarkMode
                                    ? Icons.brightness_7
                                    : Icons.brightness_4, // Солнце / Луна
                                color: colors.onPrimaryContainer,
                                size: 26,
                              ),
                              onPressed: () {
                                themeProvider.toggleTheme();
                              },
                              tooltip: isDarkMode
                                  ? 'Светлая тема'
                                  : 'Темная тема',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text(
                          _myProfile?.displayName ?? 'Загрузка...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _myProfile?.formattedPhone ?? '',
                                style: TextStyle(
                                  color: colors.onPrimaryContainer.withOpacity(
                                    0.8,
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isAccountsExpanded = !_isAccountsExpanded;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(
                                  _isAccountsExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: colors.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  ClipRect(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: _isAccountsExpanded
                          ? Column(
                              children: [
                                if (hasMultipleAccounts)
                                  ...accounts.map((account) {
                                    final isCurrent =
                                        account.id == currentAccount?.id;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: isCurrent
                                            ? colors.primary
                                            : colors.surfaceVariant,
                                        backgroundImage:
                                            account.avatarUrl != null
                                            ? NetworkImage(account.avatarUrl!)
                                            : null,
                                        child: account.avatarUrl == null
                                            ? Text(
                                                account.displayName.isNotEmpty
                                                    ? account.displayName[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  color: isCurrent
                                                      ? colors.onPrimary
                                                      : colors.onSurfaceVariant,
                                                  fontSize: 16,
                                                ),
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        account.displayName,
                                        style: TextStyle(
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: account.displayPhone.isNotEmpty
                                          ? Text(account.displayPhone)
                                          : null,
                                      trailing: isCurrent
                                          ? Icon(
                                              Icons.check_circle,
                                              color: colors.primary,
                                              size: 20,
                                            )
                                          : IconButton(
                                              icon: Icon(
                                                Icons.close,
                                                size: 20,
                                                color: colors.onSurfaceVariant,
                                              ),
                                              onPressed: () {
                                                _showDeleteAccountDialog(
                                                  context,
                                                  account,
                                                  accountManager,
                                                  () {
                                                    // Обновляем список аккаунтов
                                                    setState(() {});
                                                  },
                                                );
                                              },
                                            ),
                                      onTap: isCurrent
                                          ? null
                                          : () async {
                                              Navigator.pop(context);
                                              try {
                                                await ApiService.instance
                                                    .switchAccount(account.id);
                                                if (mounted) {
                                                  setState(() {
                                                    _isAccountsExpanded = false;
                                                    _loadMyProfile();
                                                    _chatsFuture = (() async {
                                                      try {
                                                        await ApiService
                                                            .instance
                                                            .waitUntilOnline();
                                                        return ApiService
                                                            .instance
                                                            .getChatsAndContacts();
                                                      } catch (e) {
                                                        print(
                                                          'Ошибка получения чатов: $e',
                                                        );
                                                        rethrow;
                                                      }
                                                    })();
                                                  });
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Ошибка переключения аккаунта: $e',
                                                      ),
                                                      backgroundColor:
                                                          colors.error,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                    );
                                  }).toList(),

                                ListTile(
                                  leading: const Icon(Icons.add_circle_outline),
                                  title: const Text('Добавить аккаунт'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PhoneEntryScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: Column(
              children: [
                _buildAccountsSection(context, colors),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Мой профиль'),
                  onTap: () {
                    Navigator.pop(context); // Закрыть Drawer
                    _navigateToProfileEdit(); // Этот метод у вас уже есть
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Звонки'),
                  onTap: () {
                    Navigator.pop(context); // Закрыть Drawer
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CallsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text('Музыка'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MusicLibraryScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Настройки'),
                  onTap: () {
                    Navigator.pop(context); // Закрыть Drawer

                    final screenSize = MediaQuery.of(context).size;
                    final screenWidth = screenSize.width;
                    final screenHeight = screenSize.height;
                    final isDesktopOrTablet =
                        screenWidth >= 600 &&
                        screenHeight >= 800; // Планшеты и десктопы

                    print(
                      'Screen size: ${screenWidth}x${screenHeight}, isDesktopOrTablet: $isDesktopOrTablet',
                    );

                    if (isDesktopOrTablet) {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        builder: (context) => SettingsScreen(
                          showBackToChats: true,
                          onBackToChats: () => Navigator.of(context).pop(),
                          myProfile: _myProfile,
                          isModal: true, // Включаем модальный режим
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            showBackToChats: true,
                            onBackToChats: () => Navigator.of(context).pop(),
                            myProfile: _myProfile,
                            isModal: false, // Отключаем модальный режим
                          ),
                        ),
                      );
                    }
                  },
                ),

                const Spacer(),

                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.logout, color: colors.error),
                  title: Text('Выйти', style: TextStyle(color: colors.error)),
                  onTap: () {
                    Navigator.pop(context); // Закрыть Drawer
                    _showLogoutDialog();
                  },
                ),
                const SizedBox(height: 8), // Небольшой отступ снизу
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context, ColorScheme colors) {
    return const SizedBox.shrink();
  }

  Future<List<Account>> _loadAccounts() async {
    final accountManager = AccountManager();
    await accountManager.initialize();
    return accountManager.accounts;
  }

  Widget _buildSearchResults() {
    final colors = Theme.of(context).colorScheme;

    if (_searchQuery.isEmpty) {
      return Column(
        children: [
          _buildRecentChatsIcons(),
          const Divider(height: 1),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: colors.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Начните вводить для поиска',
                    style: TextStyle(
                      fontSize: 18,
                      color: colors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Или выберите чат из списка выше',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colors.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Ничего не найдено',
              style: TextStyle(
                fontSize: 18,
                color: colors.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Попробуйте изменить поисковый запрос',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildSearchResultItem(_searchResults[index]);
      },
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    final colors = Theme.of(context).colorScheme;
    final chat = result.chat;
    final contact = result.contact;

    if (contact == null) return const SizedBox.shrink();

    return ListTile(
      onTap: () {
        final bool isSavedMessages = _isSavedMessages(chat);
        final bool isGroupChat = _isGroupChat(chat);
        final bool isChannel = chat.type == 'CHANNEL';
        final participantCount =
            chat.participantsCount ?? chat.participantIds.length;

        final Contact contactToUse = isSavedMessages
            ? Contact(
                id: chat.id,
                name: "Избранное",
                firstName: "",
                lastName: "",
                photoBaseUrl: null,
                description: null,
                isBlocked: false,
                isBlockedByMe: false,
              )
            : contact;

        if (widget.onChatSelected != null) {
          widget.onChatSelected!(
            chat,
            contactToUse,
            isGroupChat,
            isChannel,
            participantCount,
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chat.id,
                contact: contactToUse,
                myId: chat.ownerId,
                isGroupChat: isGroupChat,
                isChannel: isChannel,
                participantCount: participantCount,
                onChatRemoved: () {
                  _removeChatLocally(chat.id);
                },
              ),
            ),
          );
        }
      },
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colors.primaryContainer,
        backgroundImage: contact.photoBaseUrl != null
            ? NetworkImage(contact.photoBaseUrl ?? '')
            : null,
        child: contact.photoBaseUrl == null
            ? Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                style: TextStyle(color: colors.onPrimaryContainer),
              )
            : null,
      ),
      title: _buildHighlightedText(
        getContactDisplayName(
          contactId: contact.id,
          originalName: contact.name,
          originalFirstName: contact.firstName,
          originalLastName: contact.lastName,
        ),
        result.matchedText,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.matchType == 'message')
            chat.lastMessage.text.contains("welcome.saved.dialog.message")
                ? _buildWelcomeMessage()
                : _buildSearchMessagePreview(chat, result.matchedText),
          if (result.matchType == 'description')
            _buildHighlightedText(
              contact.description ?? '',
              result.matchedText,
            ),
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(chat.lastMessage.time),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      trailing: chat.newMessages > 0
          ? CircleAvatar(
              radius: 10,
              backgroundColor: colors.primary,
              child: Text(
                chat.newMessages.toString(),
                style: TextStyle(color: colors.onPrimary, fontSize: 12),
              ),
            )
          : null,
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) return Text(text);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, index),
            style: const TextStyle(color: Colors.black),
          ),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: text.substring(index + query.length),
            style: const TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChatsIcons() {
    final colors = Theme.of(context).colorScheme;

    final recentChats = _allChats.take(15).toList();

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: recentChats.length,
        itemBuilder: (context, index) {
          final chat = recentChats[index];
          final bool isGroupChat = _isGroupChat(chat);
          final bool isSavedMessages = _isSavedMessages(chat);

          final Contact? contact;
          int? otherParticipantId;
          if (isSavedMessages) {
            contact = _contacts[chat.ownerId];
          } else if (isGroupChat) {
            contact = null;
          } else {
            otherParticipantId = chat.participantIds.firstWhere(
              (id) => id != chat.ownerId,
              orElse: () => 0,
            );
            contact = _contacts[otherParticipantId];
          }

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                final bool isChannel = chat.type == 'CHANNEL';
                String title;
                if (isGroupChat) {
                  title = chat.title?.isNotEmpty == true
                      ? chat.title!
                      : "Группа";
                } else if (isSavedMessages) {
                  title = "Избранное";
                } else if (contact != null) {
                  title = getContactDisplayName(
                    contactId: contact.id,
                    originalName: contact.name,
                    originalFirstName: contact.firstName,
                    originalLastName: contact.lastName,
                  );
                } else if (chat.title?.isNotEmpty == true) {
                  title = chat.title!;
                } else {
                  // Контакт ещё не загружен — показываем плейсхолдер и
                  // параллельно запускаем загрузку.
                  title = "Данные загружаются...";
                  if (otherParticipantId != null && otherParticipantId != 0) {
                    _loadMissingContact(otherParticipantId);
                  }
                }
                final String? avatarUrl = isGroupChat
                    ? chat.baseIconUrl
                    : (isSavedMessages ? null : contact?.photoBaseUrl);
                final participantCount =
                    chat.participantsCount ?? chat.participantIds.length;

                final Contact contactFallback =
                    contact ??
                    Contact(
                      id: chat.id,
                      name: title,
                      firstName: "",
                      lastName: "",
                      photoBaseUrl: avatarUrl,
                      description: isChannel ? chat.description : null,
                      isBlocked: false,
                      isBlockedByMe: false,
                    );

                if (widget.onChatSelected != null) {
                  widget.onChatSelected!(
                    chat,
                    contactFallback,
                    isGroupChat,
                    isChannel,
                    participantCount,
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chat.id,
                        contact: contactFallback,
                        myId: chat.ownerId,
                        isGroupChat: isGroupChat,
                        isChannel: isChannel,
                        participantCount: participantCount,
                        onChatUpdated: () {
                          _loadChatsAndContacts();
                        },
                        onChatRemoved: () {
                          _removeChatLocally(chat.id);
                        },
                      ),
                    ),
                  );
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      isSavedMessages || isGroupChat
                          ? CircleAvatar(
                              radius: 28,
                              backgroundColor: colors.primaryContainer,
                              backgroundImage:
                                  isGroupChat && chat.baseIconUrl != null
                                  ? NetworkImage(chat.baseIconUrl ?? '')
                                  : null,
                              child:
                                  isSavedMessages ||
                                      (isGroupChat && chat.baseIconUrl == null)
                                  ? Icon(
                                      isSavedMessages
                                          ? Icons.bookmark
                                          : Icons.group,
                                      color: colors.onPrimaryContainer,
                                      size: 20,
                                    )
                                  : null,
                            )
                          : contact != null
                          ? ContactAvatarWidget(
                              contactId: contact.id,
                              originalAvatarUrl: contact.photoBaseUrl,
                              radius: 28,
                              fallbackText: contact.name.isNotEmpty
                                  ? contact.name[0].toUpperCase()
                                  : '?',
                              backgroundColor: colors.primaryContainer,
                            )
                          : CircleAvatar(
                              radius: 28,
                              backgroundColor: colors.primaryContainer,
                              child: const Text('?'),
                            ),

                      if (chat.newMessages > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                chat.newMessages > 9
                                    ? '9+'
                                    : chat.newMessages.toString(),
                                style: TextStyle(
                                  color: colors.onPrimary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 56,
                    child: isGroupChat
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group,
                                size: 10,
                                color: colors.onSurface,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  chat.title?.isNotEmpty == true
                                      ? chat.title!
                                      : "Группа (${chat.participantIds.length})",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            isSavedMessages
                                ? "Избранное"
                                : (contact?.name ??
                                      (chat.title?.isNotEmpty == true
                                          ? chat.title!
                                          : (otherParticipantId != null
                                                ? 'ID $otherParticipantId'
                                                : 'ID 0'))),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onFolderTabChanged() {
    if (!_folderTabController.indexIsChanging) {
      final index = _folderTabController.index;
      final folderId = index == 0 ? null : _folders[index - 1].id;

      if (_selectedFolderId != folderId) {
        setState(() {
          _selectedFolderId = folderId;
        });
        _filterChats();
      }
    }
  }

  List<Widget> _buildFolderPages() {
    final List<Widget> pages = [
      _buildChatsListForFolder(null),
      ..._folders.map((folder) => _buildChatsListForFolder(folder)),
    ];

    return pages;
  }

  Widget _buildChatsListForFolder(ChatFolder? folder) {
    List<Chat> chatsForFolder = _allChats;

    if (folder != null) {
      chatsForFolder = _allChats
          .where((chat) => _chatBelongsToFolder(chat, folder))
          .toList();
    }

    chatsForFolder.sort((a, b) {
      final aIsSaved = _isSavedMessages(a);
      final bIsSaved = _isSavedMessages(b);
      if (aIsSaved && !bIsSaved) return -1;
      if (!aIsSaved && bIsSaved) return 1;
      if (aIsSaved && bIsSaved) {
        if (a.id == 0) return -1;
        if (b.id == 0) return 1;
      }
      return 0;
    });

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      chatsForFolder = chatsForFolder.where((chat) {
        final isSavedMessages = _isSavedMessages(chat);
        if (isSavedMessages) {
          return "избранное".contains(query);
        }
        final otherParticipantId = chat.participantIds.firstWhere(
          (id) => id != chat.ownerId,
          orElse: () => 0,
        );
        final contactName =
            _contacts[otherParticipantId]?.name.toLowerCase() ?? '';
        return contactName.contains(query);
      }).toList();
    }

    if (chatsForFolder.isEmpty) {
      return Center(
        child: Text(
          folder == null ? 'Нет чатов' : 'В этой папке пока нет чатов',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: chatsForFolder.length,
      itemBuilder: (context, index) {
        return _buildChatListItem(chatsForFolder[index], index, folder);
      },
    );
  }

  Widget _buildFolderTabs() {
    if (_folderTabController.length <= 1) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    final List<Widget> tabs = [
      Tab(
        child: GestureDetector(
          onLongPress: () {},
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Все чаты', style: TextStyle(fontSize: 14))],
          ),
        ),
      ),
      ..._folders.map(
        (folder) => Tab(
          child: GestureDetector(
            onLongPress: () {
              _showFolderEditMenu(folder);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (folder.emoji != null) ...[
                  Text(folder.emoji!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                ],
                Text(folder.title, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.outline.withOpacity(0.2), width: 1),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: _folders.length <= 3
                    ? Center(
                        child: TabBar(
                          controller: _folderTabController,
                          isScrollable: false,
                          tabAlignment: TabAlignment.center,
                          labelColor: colors.primary,
                          unselectedLabelColor: colors.onSurfaceVariant,
                          indicator: UnderlineTabIndicator(
                            borderSide: BorderSide(
                              width: 3,
                              color: colors.primary,
                            ),
                            insets: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          indicatorSize: TabBarIndicatorSize.label,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: tabs,
                          onTap: (index) {},
                        ),
                      )
                    : Transform.translate(
                        offset: const Offset(-42, 0),
                        child: TabBar(
                          controller: _folderTabController,
                          isScrollable: true,
                          labelColor: colors.primary,
                          unselectedLabelColor: colors.onSurfaceVariant,
                          indicator: UnderlineTabIndicator(
                            borderSide: BorderSide(
                              width: 3,
                              color: colors.primary,
                            ),
                            insets: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          indicatorSize: TabBarIndicatorSize.label,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: tabs,
                          onTap: (index) {},
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _showCreateFolderDialog,
              tooltip: 'Создать папку',
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать папку'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название папки',
            hintText: 'Введите название',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ApiService.instance.createFolder(value.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ApiService.instance.createFolder(title);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFolderEditMenu(ChatFolder folder) async {
    final colors = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.3,
          maxChildSize: 0.6,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colors.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (folder.emoji != null) ...[
                          Text(
                            folder.emoji!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(
                            folder.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: colors.onSurfaceVariant,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildFolderEditMenuContent(folder, context)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFolderEditMenuContent(ChatFolder folder, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Действия',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Выбрать чаты'),
            onTap: () {
              Navigator.of(context).pop();
              _showAddChatsToFolderDialog(folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Переименовать'),
            onTap: () {
              Navigator.of(context).pop();
              _showRenameFolderDialog(folder);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text(
              'Удалить папку',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.of(context).pop();
              _showDeleteFolderDialog(folder);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(ChatFolder folder) {
    final TextEditingController titleController = TextEditingController(
      text: folder.title,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Переименовать папку'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Название папки',
            hintText: 'Введите название',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ApiService.instance.updateFolder(
                folder.id,
                title: value.trim(),
                include: folder.include,
                filters: folder.filters,
              );
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                ApiService.instance.updateFolder(
                  folder.id,
                  title: title,
                  include: folder.include,
                  filters: folder.filters,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFolderDialog(ChatFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить папку'),
        content: Text(
          'Вы уверены, что хотите удалить папку "${folder.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ApiService.instance.deleteFolder(folder.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Папка "${folder.title}" удалена'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMessagePreview(Chat chat, ChatFolder? currentFolder) async {
    await MessagePreviewDialog.show(
      context,
      chat,
      _contacts,
      _myProfile,
      null,
      (context) => _buildChatMenuContent(chat, currentFolder, context),
    );
  }

  Widget _buildChatMenuContent(
    Chat chat,
    ChatFolder? currentFolder,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Действия',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(),
          if (currentFolder == null && _folders.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Добавить в папку'),
              onTap: () {
                Navigator.of(context).pop();
                _showFolderSelectionMenu(chat);
              },
            ),
          ListTile(
            leading: const Icon(Icons.mark_chat_read),
            title: const Text('Настройки чтения'),
            subtitle: const Text('Настроить чтение сообщений для этого чата'),
            onTap: () {
              Navigator.of(context).pop();
              _showReadSettingsDialog(chat);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showFolderSelectionMenu(Chat chat) {
    if (_folders.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Выберите папку',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(),
              ..._folders.map((folder) {
                return ListTile(
                  leading: folder.emoji != null
                      ? Text(
                          folder.emoji!,
                          style: const TextStyle(fontSize: 24),
                        )
                      : const Icon(Icons.folder),
                  title: Text(folder.title),
                  onTap: () {
                    Navigator.of(context).pop();
                    _addChatToFolder(chat, folder);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showReadSettingsDialog(Chat chat) async {
    final settingsService = ChatReadSettingsService.instance;
    final currentSettings = await settingsService.getSettings(chat.id);
    final theme = context.read<ThemeProvider>();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return _ReadSettingsDialogContent(
          chat: chat,
          initialSettings: currentSettings,
          globalReadOnAction: theme.debugReadOnAction,
          globalReadOnEnter: theme.debugReadOnEnter,
        );
      },
    );
  }

  void _addChatToFolder(Chat chat, ChatFolder folder) {
    final currentInclude = folder.include ?? [];

    if (currentInclude.contains(chat.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Чат уже находится в папке "${folder.title}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final newInclude = List<int>.from(currentInclude)..add(chat.id);

    ApiService.instance.updateFolder(
      folder.id,
      title: folder.title,
      include: newInclude,
      filters: folder.filters,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Чат добавлен в папку "${folder.title}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddChatsToFolderDialog(ChatFolder folder) {
    final currentInclude = folder.include ?? [];

    // Получаем все чаты, кроме "Избранного" (chat.id == 0)
    final allAvailableChats = _allChats.where((chat) {
      return chat.id != 0;
    }).toList();

    // Сортируем: сначала чаты, которые уже в папке, затем остальные
    final sortedChats = List<Chat>.from(allAvailableChats);
    sortedChats.sort((a, b) {
      final aInFolder = currentInclude.contains(a.id);
      final bInFolder = currentInclude.contains(b.id);
      if (aInFolder && !bInFolder) return -1;
      if (!aInFolder && bInFolder) return 1;
      return 0;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddChatsToFolderDialog(
          folder: folder,
          availableChats: sortedChats,
          contacts: _contacts,
          onAddChats: (selectedChats) {
            _updateFolderChats(selectedChats, folder);
          },
        );
      },
    );
  }

  void _updateFolderChats(List<Chat> selectedChats, ChatFolder folder) {
    final currentInclude = folder.include ?? [];
    final selectedChatIds = selectedChats.map((chat) => chat.id).toSet();

    // Создаем новый список include только с выбранными чатами
    final newInclude = selectedChatIds.toList();

    // Подсчитываем изменения
    final addedCount = newInclude
        .where((id) => !currentInclude.contains(id))
        .length;
    final removedCount = currentInclude
        .where((id) => !selectedChatIds.contains(id))
        .length;

    ApiService.instance.updateFolder(
      folder.id,
      title: folder.title,
      include: newInclude,
      filters: folder.filters,
    );

    String message;
    if (addedCount > 0 && removedCount > 0) {
      message = 'Папка "${folder.title}" обновлена';
    } else if (addedCount > 0) {
      message = addedCount == 1
          ? 'Чат добавлен в папку "${folder.title}"'
          : '$addedCount чатов добавлено в папку "${folder.title}"';
    } else if (removedCount > 0) {
      message = removedCount == 1
          ? 'Чат удален из папки "${folder.title}"'
          : '$removedCount чатов удалено из папки "${folder.title}"';
    } else {
      message = 'Изменения сохранены';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildDebugRefreshPanel(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    if (!theme.debugShowChatsRefreshPanel) return const SizedBox.shrink();
    final bool hasBottomBar = theme.debugShowBottomBar;
    final double bottomPadding = hasBottomBar ? 80.0 : 20.0;
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomPadding,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: colors.surface.withOpacity(0.95),
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _allChats.clear();
                        _filteredChats.clear();
                        _chatsFuture = ApiService.instance.getChatsAndContacts(
                          force: true,
                        );
                      });
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.refresh),
                      const SizedBox(width: 8),
                      const Text('Обновить список чатов'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required Key key,
    required String text,
    required Widget icon,
  }) {
    return Row(
      key: key,
      children: [
        SizedBox(width: 18, height: 18, child: Center(child: icon)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTitleWidget() {
    final colors = Theme.of(context).colorScheme;
    final onSurfaceVariant = colors.onSurfaceVariant;

    if (_connectionStatus == 'connecting') {
      return _buildStatusRow(
        key: const ValueKey('status_connecting'),
        text: 'Подключение...',
        icon: CircularProgressIndicator(
          strokeWidth: 2,
          color: onSurfaceVariant,
        ),
      );
    }

    if (_connectionStatus == 'authorizing') {
      return _buildStatusRow(
        key: const ValueKey('status_authorizing'),
        text: 'Авторизация...',
        icon: CircularProgressIndicator(
          strokeWidth: 2,
          color: onSurfaceVariant,
        ),
      );
    }

    if (_connectionStatus == 'disconnected' ||
        _connectionStatus == 'Все серверы недоступны') {
      return _buildStatusRow(
        key: const ValueKey('status_error'),
        text: 'Нет сети',
        icon: Icon(Icons.cloud_off, size: 18, color: colors.error),
      );
    }

    if (_isProfileLoading) {
      return _buildStatusRow(
        key: const ValueKey('status_loading'),
        text: 'Загрузка...',
        icon: CircularProgressIndicator(
          strokeWidth: 2,
          color: onSurfaceVariant,
        ),
      );
    }

    return Text(
      _myProfile?.displayName ?? 'Komet',
      key: const ValueKey('status_username'),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppBar(
      titleSpacing: 4.0,

      leading: _isSearchExpanded
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _clearSearch,
            )
          : Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Меню',
                );
              },
            ),

      title: _isSearchExpanded
          ? _buildSearchField(colors)
          : Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: _buildCurrentTitleWidget(),
                  ),
                ),
              ],
            ),
      actions: _isSearchExpanded
          ? [
              if (_searchQuery.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(left: 4),
                child: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showSearchFilters,
                ),
              ),
            ]
          : [
              if ((_prefs?.getBool('show_sferum_button') ?? true))
                IconButton(
                  icon: Image.asset(
                    'assets/images/spermum.png',
                    width: 28,
                    height: 28,
                  ),
                  onPressed: _openSferum,
                  tooltip: 'Сферум',
                ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DownloadsScreen(),
                    ),
                  );
                },
                tooltip: 'Загрузки',
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isSearchExpanded = true;
                  });
                  _searchAnimationController.forward();
                  _searchFocusNode.requestFocus();
                },

                onLongPress: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UserIdLookupScreen(),
                    ),
                  );
                },
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(Icons.search),
                ),
              ),
              const SizedBox(width: 8),
            ],
    );
  }

  Widget _buildWelcomeMessage() {
    return Text(
      'Привет! Это твои избранные. Все написанное сюда попадёт прямиком к дяде Майору.',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSearchField(ColorScheme colors) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          prefixIcon: Icon(
            Icons.search,
            color: colors.onSurfaceVariant,
            size: 18,
          ),
          hintText: 'Поиск в чатах...',
          hintStyle: TextStyle(color: colors.onSurfaceVariant),
          filled: true,
          fillColor: colors.surfaceContainerHighest.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _navigateToProfileEdit() {
    if (_myProfile != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ManageAccountScreen(myProfile: _myProfile!),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль еще не загружен')));
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выход из аккаунта'),
          content: const Text('Вы действительно хотите выйти из аккаунта?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PhoneEntryScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при выходе: $e')));
      }
    }
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    Account account,
    AccountManager accountManager,
    VoidCallback onDeleted,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удаление аккаунта'),
          content: const Text('Точно хочешь удалить аккаунт?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Нет'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await accountManager.removeAccount(account.id);
                  if (mounted) {
                    onDeleted();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Аккаунт удален'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ошибка: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Да'),
            ),
          ],
        );
      },
    );
  }

  void _showSearchFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Фильтры поиска',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildFilterOption('all', 'Все чаты', Icons.chat_bubble_outline),
            _buildFilterOption('recent', 'Недавние', Icons.access_time),
            _buildFilterOption(
              'channels',
              'Каналы',
              Icons.broadcast_on_personal,
            ),
            _buildFilterOption('groups', 'Группы', Icons.group),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String value, String title, IconData icon) {
    final isSelected = _searchFilter == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() {
          _searchFilter = value;
        });
        Navigator.pop(context);
        _performSearch();
      },
    );
  }

  Widget _buildLastMessagePreview(Chat chat) {
    final message = chat.lastMessage;

    if (message.attaches.isNotEmpty) {
      for (final attach in message.attaches) {
        final type = attach['_type'];
        if (type == 'CALL' || type == 'call') {
          return _buildCallPreview(attach, message, chat);
        }
      }
    }

    if (message.text.isEmpty && message.attaches.isNotEmpty) {
      return Text('Вложение', maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Text(message.text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  Widget _buildSearchMessagePreview(Chat chat, String matchedText) {
    final message = chat.lastMessage;

    if (message.attaches.isNotEmpty) {
      final callAttachments = message.attaches.where((attach) {
        final type = attach['_type'];
        return type == 'CALL' || type == 'call';
      }).toList();

      if (callAttachments.isNotEmpty) {
        return _buildCallPreview(callAttachments.first, message, chat);
      }
    }

    if (message.text.isEmpty && message.attaches.isNotEmpty) {
      return Text('Вложение', maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return _buildHighlightedText(message.text, matchedText);
  }

  Widget _buildCallPreview(
    Map<String, dynamic> callAttach,
    Message message,
    Chat chat,
  ) {
    final colors = Theme.of(context).colorScheme;
    final hangupType = callAttach['hangupType'] as String? ?? '';
    final callType = callAttach['callType'] as String? ?? 'AUDIO';
    final duration = callAttach['duration'] as int? ?? 0;

    String callText;
    IconData callIcon;
    Color? callColor;

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
        callColor = colors.primary;
        break;

      case 'MISSED':
        final callTypeText = callType == 'VIDEO'
            ? 'Пропущенный видеозвонок'
            : 'Пропущенный звонок';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_missed;
        callColor = colors.error;
        break;

      case 'CANCELED':
        final callTypeText = callType == 'VIDEO'
            ? 'Видеозвонок отменен'
            : 'Звонок отменен';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_end;
        callColor = colors.onSurfaceVariant;
        break;

      case 'REJECTED':
        final callTypeText = callType == 'VIDEO'
            ? 'Видеозвонок отклонен'
            : 'Звонок отклонен';
        callText = callTypeText;
        callIcon = callType == 'VIDEO' ? Icons.videocam_off : Icons.call_end;
        callColor = colors.onSurfaceVariant;
        break;

      default:
        callText = callType == 'VIDEO' ? 'Видеозвонок' : 'Звонок';
        callIcon = callType == 'VIDEO' ? Icons.videocam : Icons.call;
        callColor = colors.onSurfaceVariant;
        break;
    }

    return Row(
      children: [
        Icon(callIcon, size: 16, color: callColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            callText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: callColor),
          ),
        ),
      ],
    );
  }

  Widget _buildChatListItem(Chat chat, int index, ChatFolder? currentFolder) {
    final colors = Theme.of(context).colorScheme;

    final bool isSavedMessages = _isSavedMessages(chat);
    final bool isGroupChat = _isGroupChat(chat);
    final bool isChannel = chat.type == 'CHANNEL';

    Contact? contact;
    String title;
    final String? avatarUrl;
    IconData leadingIcon;

    if (isSavedMessages) {
      contact = _contacts[chat.ownerId];
      title = "Избранное";
      leadingIcon = Icons.bookmark;
      avatarUrl = null;
    } else if (isChannel) {
      contact = null;
      title = chat.title ?? "Канал";
      leadingIcon = Icons.campaign;
      avatarUrl = chat.baseIconUrl;
    } else if (isGroupChat) {
      contact = null;
      title = chat.title?.isNotEmpty == true
          ? chat.title!
          : "Группа (${chat.participantIds.length} участников)";
      leadingIcon = Icons.group;
      avatarUrl = chat.baseIconUrl;
    } else {
      final myId = chat.ownerId;
      final otherParticipantId = chat.participantIds.firstWhere(
        (id) => id != myId,
        orElse: () => myId,
      );
      contact = _contacts[otherParticipantId];

      if (contact != null) {
        title = getContactDisplayName(
          contactId: contact.id,
          originalName: contact.name,
          originalFirstName: contact.firstName,
          originalLastName: contact.lastName,
        );
      } else if (chat.title?.isNotEmpty == true) {
        title = chat.title!;
      } else {
        // Контакт ещё не загружен — плейсхолдер и асинхронная подзагрузка.
        title = "Данные загружаются...";
        _loadMissingContact(otherParticipantId);
      }
      avatarUrl = contact?.photoBaseUrl;
      leadingIcon = Icons.person;
    }

    return ListTile(
      key: ValueKey(chat.id),
      onTap: () {
        final theme = context.read<ThemeProvider>();
        if (theme.debugReadOnEnter) {
          final chatIndex = _allChats.indexWhere((c) => c.id == chat.id);
          if (chatIndex != -1) {
            final oldChat = _allChats[chatIndex];
            if (oldChat.newMessages > 0) {
              final updatedChat = oldChat.copyWith(newMessages: 0);
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _allChats[chatIndex] = updatedChat;
                    _filterChats();
                  });
                }
              });
            }
          }
        }

        final Contact contactFallback = isSavedMessages
            ? Contact(
                id: chat.id,
                name: "Избранное",
                firstName: "",
                lastName: "",
                photoBaseUrl: null,
                description: null,
                isBlocked: false,
                isBlockedByMe: false,
              )
            : contact ??
                  Contact(
                    id: chat.id,
                    name: title,
                    firstName: "",
                    lastName: "",
                    photoBaseUrl: avatarUrl,
                    description: isChannel ? chat.description : null,
                    isBlocked: false,
                    isBlockedByMe: false,
                  );

        final participantCount =
            chat.participantsCount ?? chat.participantIds.length;

        if (widget.onChatSelected != null) {
          widget.onChatSelected!(
            chat,
            contactFallback,
            isGroupChat,
            isChannel,
            participantCount,
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chat.id,
                contact: contactFallback,
                myId: chat.ownerId,
                isGroupChat: isGroupChat,
                isChannel: isChannel,
                participantCount: participantCount,
                onChatRemoved: () {
                  _removeChatLocally(chat.id);
                },
              ),
            ),
          );
        }
      },
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onLongPress: () => _showMessagePreview(chat, currentFolder),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: colors.primaryContainer,

              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,

              child: avatarUrl == null
                  ? (isSavedMessages || isGroupChat || isChannel)
                        ? Icon(leadingIcon, color: colors.onPrimaryContainer)
                        : Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: TextStyle(color: colors.onPrimaryContainer),
                          )
                  : null,
            ),
          ),
          Positioned(
            right: -4,
            bottom: -2,
            child: _typingChats.contains(chat.id)
                ? _TypingDots(color: colors.primary, size: 20)
                : (_onlineChats.contains(chat.id)
                      ? _PresenceDot(isOnline: true, size: 12)
                      : const SizedBox.shrink()),
          ),
        ],
      ),
      title: Row(
        children: [
          if (isGroupChat) ...[
            Icon(Icons.group, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      subtitle: chat.lastMessage.text.contains("welcome.saved.dialog.message")
          ? _buildWelcomeMessage()
          : _buildLastMessagePreview(chat),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTimestamp(chat.lastMessage.time),
            style: TextStyle(
              color: chat.newMessages > 0
                  ? colors.primary
                  : colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          if (chat.newMessages > 0 && !isSavedMessages) ...[
            const SizedBox(height: 4),
            CircleAvatar(
              radius: 10,
              backgroundColor: colors.primary,
              child: Text(
                chat.newMessages.toString(),
                style: TextStyle(color: colors.onPrimary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    _searchAnimationController.dispose();
    _folderTabController.dispose();
    super.dispose();
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  final double size;
  const _TypingDots({required this.color, this.size = 18});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    return SizedBox(
      width: w,
      height: w * 0.6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          double a(int i) => 0.3 + 0.7 * ((t + i / 3) % 1.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              return Opacity(
                opacity: a(i),
                child: Container(
                  width: w * 0.22,
                  height: w * 0.22,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  const _PresenceDot({required this.isOnline, this.size = 10});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? colors.primary : colors.onSurfaceVariant,
      ),
    );
  }
}

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Звонки')),
      body: const Center(child: Text('Звонки скоро будут доступны')),
    );
  }
}

class SferumWebViewPanel extends StatefulWidget {
  final String url;

  const SferumWebViewPanel({super.key, required this.url});

  @override
  State<SferumWebViewPanel> createState() => _SferumWebViewPanelState();
}

class _SferumWebViewPanelState extends State<SferumWebViewPanel> {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;

  Future<void> _checkCanGoBack() async {}

  Future<void> _goBack() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      await _webViewController!.goBack();
      _checkCanGoBack();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Row(
          children: [
            Image.asset('assets/images/spermum.png', width: 28, height: 28),
            const SizedBox(width: 12),
            const Text(
              'Сферум',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Закрыть',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!Platform.isLinux)
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                useShouldOverrideUrlLoading: true,
                useOnLoadResource: false,
                useOnDownloadStart: false,
                cacheEnabled: true,
                verticalScrollBarEnabled: true,
                horizontalScrollBarEnabled: true,
                supportZoom: false,
                disableVerticalScroll: false,
                disableHorizontalScroll: false,
                allowsInlineMediaPlayback: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsBackForwardNavigationGestures: true,
                useHybridComposition: true,
                supportMultipleWindows: false,
                javaScriptCanOpenWindowsAutomatically: false,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onCreateWindow: (controller, createWindowAction) async {
                final uri = createWindowAction.request.url;
                print('🪟 Попытка открыть новое окно: $uri');
                if (uri != null) {
                  await controller.loadUrl(urlRequest: URLRequest(url: uri));
                }
                return true;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                final navigationType = navigationAction.navigationType;
                print(
                  '🔗 Попытка перехода по ссылке: $uri (тип: $navigationType)',
                );

                if (navigationType == NavigationType.LINK_ACTIVATED) {
                  return NavigationActionPolicy.ALLOW;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) async {
                print('🌐 WebView начало загрузки: $url');
                setState(() {
                  _isLoading = true;
                });
                try {
                  await controller.evaluateJavascript(
                    source: '''
                    // Переопределяем window.open сразу
                    if (window.open.toString().indexOf('native code') === -1) {
                      var originalOpen = window.open;
                      window.open = function(url, name, features) {
                        if (url && typeof url === 'string') {
                          window.location.href = url;
                          return null;
                        }
                        return originalOpen.apply(this, arguments);
                      };
                    }
                  ''',
                  );
                } catch (e) {
                  print(
                    '⚠️ Ошибка при выполнении JavaScript в onLoadStart: $e',
                  );
                }
              },
              onLoadStop: (controller, url) async {
                print('✅ WebView загрузка завершена: $url');
                setState(() {
                  _isLoading = false;
                });
                _checkCanGoBack();
                try {
                  await controller.evaluateJavascript(
                    source: '''
                    // Включаем прокрутку
                    document.body.style.overflow = 'auto';
                    document.documentElement.style.overflow = 'auto';
                    document.body.style.webkitOverflowScrolling = 'touch';
                    document.body.style.position = 'relative';
                    document.documentElement.style.position = 'relative';
                    
                    // Перехватываем все клики по ссылкам и принудительно открываем в том же окне
                    (function() {
                      // Функция для обработки ссылок
                      function processLink(link) {
                        if (link && link.tagName === 'A') {
                          var href = link.getAttribute('href');
                          if (href && !href.startsWith('javascript:') && !href.startsWith('mailto:')) {
                            // Убираем target="_blank" если есть
                            link.removeAttribute('target');
                            // Добавляем обработчик клика
                            link.addEventListener('click', function(e) {
                              var href = this.getAttribute('href');
                              if (href && !href.startsWith('javascript:') && !href.startsWith('mailto:')) {
                                e.preventDefault();
                                e.stopPropagation();
                                window.location.href = href;
                                return false;
                              }
                            }, true);
                          }
                        }
                      }
                      
                      // Обрабатываем все существующие ссылки
                      function processAllLinks() {
                        var links = document.querySelectorAll('a');
                        for (var i = 0; i < links.length; i++) {
                          processLink(links[i]);
                        }
                      }
                      
                      // Обрабатываем ссылки при загрузке
                      processAllLinks();
                      
                      // Перехватываем клики на уровне document
                      document.addEventListener('click', function(e) {
                        var target = e.target;
                        // Находим ближайшую ссылку
                        while (target && target.tagName !== 'A' && target !== document.body) {
                          target = target.parentElement;
                        }
                        if (target && target.tagName === 'A') {
                          var href = target.getAttribute('href');
                          if (href && !href.startsWith('javascript:') && !href.startsWith('mailto:')) {
                            // Убираем target если есть
                            target.removeAttribute('target');
                            // Открываем в том же окне
                            e.preventDefault();
                            e.stopPropagation();
                            window.location.href = href;
                            return false;
                          }
                        }
                      }, true);
                      
                      // Отслеживаем динамически добавляемые ссылки
                      var observer = new MutationObserver(function(mutations) {
                        mutations.forEach(function(mutation) {
                          mutation.addedNodes.forEach(function(node) {
                            if (node.nodeType === 1) { // Element node
                              if (node.tagName === 'A') {
                                processLink(node);
                              }
                              // Обрабатываем ссылки внутри добавленного элемента
                              var links = node.querySelectorAll ? node.querySelectorAll('a') : [];
                              for (var i = 0; i < links.length; i++) {
                                processLink(links[i]);
                              }
                            }
                          });
                        });
                      });
                      
                      // Начинаем наблюдение за изменениями в DOM
                      observer.observe(document.body, {
                        childList: true,
                        subtree: true
                      });
                      
                      // Переопределяем window.open чтобы открывать в том же окне
                      var originalOpen = window.open;
                      window.open = function(url, name, features) {
                        if (url && typeof url === 'string') {
                          window.location.href = url;
                          return null;
                        }
                        return originalOpen.apply(this, arguments);
                      };
                    })();
                  ''',
                  );
                } catch (e) {
                  print('⚠️ Ошибка при выполнении JavaScript: $e');
                }
              },
              onReceivedError: (controller, request, error) {
                print('❌ WebView ошибка: ${error.description} (${error.type})');
              },
              onConsoleMessage: (controller, consoleMessage) {
                print('📝 Console: ${consoleMessage.message}');
              },
            ),
          if (Platform.isLinux)
            Container(
              color: colors.surface,
              child: const Center(
                child: Text(
                  'Веб приложения временно не доступны на линуксе,\nмы думаем как это исправить.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),

          if (_isLoading && !Platform.isLinux)
            Container(
              color: colors.surface,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _AddChatsToFolderDialog extends StatefulWidget {
  final ChatFolder folder;
  final List<Chat> availableChats;
  final Map<int, Contact> contacts;
  final Function(List<Chat>) onAddChats;

  const _AddChatsToFolderDialog({
    required this.folder,
    required this.availableChats,
    required this.contacts,
    required this.onAddChats,
  });

  @override
  State<_AddChatsToFolderDialog> createState() =>
      _AddChatsToFolderDialogState();
}

class _AddChatsToFolderDialogState extends State<_AddChatsToFolderDialog> {
  late final Set<int> _selectedChatIds;

  @override
  void initState() {
    super.initState();
    final currentInclude = widget.folder.include ?? [];
    _selectedChatIds = currentInclude.toSet();
  }

  bool _isGroupChat(Chat chat) {
    return chat.type == 'CHAT' || chat.participantIds.length > 2;
  }

  bool _isSavedMessages(Chat chat) {
    return chat.id == 0;
  }

  void _toggleChatSelection(Chat chat) {
    setState(() {
      if (_selectedChatIds.contains(chat.id)) {
        _selectedChatIds.remove(chat.id);
      } else {
        _selectedChatIds.add(chat.id);
      }
    });
  }

  void _addSelectedChats() {
    final selectedChats = widget.availableChats
        .where((chat) => _selectedChatIds.contains(chat.id))
        .toList();

    Navigator.of(context).pop();
    widget.onAddChats(selectedChats);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colors.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.folder.emoji != null) ...[
                      Text(
                        widget.folder.emoji!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        'Выбрать чаты для "${widget.folder.title}"',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: colors.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.availableChats.length,
                  itemBuilder: (context, index) {
                    final chat = widget.availableChats[index];
                    final isGroupChat = _isGroupChat(chat);
                    final isChannel = chat.type == 'CHANNEL';
                    final isSavedMessages = _isSavedMessages(chat);

                    Contact? contact;
                    String title;
                    String? avatarUrl;
                    IconData leadingIcon;

                    if (isSavedMessages) {
                      contact = widget.contacts[chat.ownerId];
                      title = "Избранное";
                      leadingIcon = Icons.bookmark;
                      avatarUrl = null;
                    } else if (isChannel) {
                      contact = null;
                      title = chat.title ?? "Канал";
                      leadingIcon = Icons.campaign;
                      avatarUrl = chat.baseIconUrl;
                    } else if (isGroupChat) {
                      contact = null;
                      title = chat.title?.isNotEmpty == true
                          ? chat.title!
                          : "Группа";
                      leadingIcon = Icons.group;
                      avatarUrl = chat.baseIconUrl;
                    } else {
                      final myId = chat.ownerId;
                      final otherParticipantId = chat.participantIds.firstWhere(
                        (id) => id != myId,
                        orElse: () => myId,
                      );
                      contact = widget.contacts[otherParticipantId];

                      if (contact != null) {
                        title = getContactDisplayName(
                          contactId: contact.id,
                          originalName: contact.name,
                          originalFirstName: contact.firstName,
                          originalLastName: contact.lastName,
                        );
                      } else if (chat.title?.isNotEmpty == true) {
                        title = chat.title!;
                      } else {
                        title = "ID $otherParticipantId";
                      }
                      avatarUrl = contact?.photoBaseUrl;
                      leadingIcon = Icons.person;
                    }

                    final isSelected = _selectedChatIds.contains(chat.id);

                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: colors.primaryContainer,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? (isSavedMessages || isGroupChat || isChannel)
                                      ? Icon(
                                          leadingIcon,
                                          color: colors.onPrimaryContainer,
                                        )
                                      : Text(
                                          title.isNotEmpty
                                              ? title[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: colors.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                : null,
                          ),
                        ],
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: title == 'Данные загружаются...'
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      subtitle: isGroupChat && chat.participantIds.length > 2
                          ? Text(
                              '${chat.participantIds.length} участников',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            )
                          : null,
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleChatSelection(chat),
                      ),
                      onTap: () => _toggleChatSelection(chat),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.outline.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedChatIds.isEmpty
                            ? 'Выберите чаты'
                            : 'Выбрано: ${_selectedChatIds.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: _addSelectedChats,
                      child: const Text('Сохранить'),
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

class _ReadSettingsDialogContent extends StatefulWidget {
  final Chat chat;
  final ChatReadSettings? initialSettings;
  final bool globalReadOnAction;
  final bool globalReadOnEnter;

  const _ReadSettingsDialogContent({
    required this.chat,
    required this.initialSettings,
    required this.globalReadOnAction,
    required this.globalReadOnEnter,
  });

  @override
  State<_ReadSettingsDialogContent> createState() =>
      _ReadSettingsDialogContentState();
}

class _ReadSettingsDialogContentState
    extends State<_ReadSettingsDialogContent> {
  ChatReadSettings? _settings;
  bool _useDefault = true;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _useDefault = widget.initialSettings == null;
  }

  String _getSelectedOption() {
    if (_useDefault) {
      return 'default';
    }

    if (_settings == null) {
      return 'default';
    }

    if (_settings!.disabled) {
      return 'disabled';
    } else if (_settings!.readOnAction && _settings!.readOnEnter) {
      return 'both';
    } else if (_settings!.readOnAction) {
      return 'action';
    } else if (_settings!.readOnEnter) {
      return 'enter';
    }
    return 'default';
  }

  Future<void> _setOption(String option) async {
    setState(() {
      if (option == 'default') {
        _useDefault = true;
        _settings = null;
      } else {
        _useDefault = false;
        switch (option) {
          case 'disabled':
            _settings = ChatReadSettings(
              readOnAction: false,
              readOnEnter: false,
              disabled: true,
            );
            break;
          case 'action':
            _settings = ChatReadSettings(
              readOnAction: true,
              readOnEnter: false,
              disabled: false,
            );
            break;
          case 'enter':
            _settings = ChatReadSettings(
              readOnAction: false,
              readOnEnter: true,
              disabled: false,
            );
            break;
          case 'both':
          default:
            _settings = ChatReadSettings(
              readOnAction: true,
              readOnEnter: true,
              disabled: false,
            );
            break;
        }
      }
    });

    if (_useDefault || _settings == null) {
      await ChatReadSettingsService.instance.resetSettings(widget.chat.id);
    } else {
      await ChatReadSettingsService.instance.saveSettings(
        widget.chat.id,
        _settings!,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _getDefaultDescription() {
    final action = widget.globalReadOnAction ? 'при действиях' : '';
    final enter = widget.globalReadOnEnter ? 'при входе' : '';

    if (action.isNotEmpty && enter.isNotEmpty) {
      return 'Чтение $action и $enter';
    } else if (action.isNotEmpty) {
      return 'Чтение $action';
    } else if (enter.isNotEmpty) {
      return 'Чтение $enter';
    }
    return 'Чтение отключено';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedOption = _getSelectedOption();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Настройки чтения сообщений',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('По умолчанию'),
                    subtitle: Text(_getDefaultDescription()),
                    value: 'default',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Отключить чтение'),
                    subtitle: const Text(
                      'Сообщения не будут отмечаться как прочитанные',
                    ),
                    value: 'disabled',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Чтение при действиях'),
                    subtitle: const Text(
                      'Отмечать прочитанным при отправке сообщения',
                    ),
                    value: 'action',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Чтение при входе в чат'),
                    subtitle: const Text(
                      'Отмечать прочитанным при открытии чата',
                    ),
                    value: 'enter',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Чтение при действиях и при входе'),
                    subtitle: const Text(
                      'Отмечать прочитанным при отправке и при открытии',
                    ),
                    value: 'both',
                    groupValue: selectedOption,
                    onChanged: (value) => _setOption(value!),
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
