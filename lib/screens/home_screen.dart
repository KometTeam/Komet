import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/screens/chats_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/screens/settings/reconnection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/services/version_checker.dart';
import 'package:app_links/app_links.dart';
import 'package:gwid/models/chat.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _chatsFuture;
  Profile? _myProfile;
  bool _isProfileLoading = true;
  String? _connectionStatus;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _messageSubscription;

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  Uri? _initialUri;

  @override
  void initState() {
    super.initState();

    _loadMyProfile();
    _chatsFuture = (() async {
      try {
        await ApiService.instance.waitUntilOnline();
        return ApiService.instance.getChatsAndContacts();
      } catch (e) {
        print('Ошибка получения чатов в HomeScreen: $e');
        if (e.toString().contains('Auth token not found') ||
            e.toString().contains('FAIL_WRONG_PASSWORD')) {}
        rethrow;
      }
    })();

    _checkVersionInBackground();
    _initDeepLinking();
    _showSpoofUpdateDialogIfNeeded();

    _connectionSubscription = ApiService.instance.connectionStatus.listen((
      status,
    ) {
      if (mounted) {
        setState(() => _connectionStatus = status);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _connectionStatus = null);
          }
        });
      }
    });

    _messageSubscription = ApiService.instance.messages.listen((message) {
      if (message['type'] == 'session_terminated' && mounted) {
        _handleSessionTerminated(message['message']);
      } else if (message['type'] == 'invalid_token' && mounted) {
        _handleInvalidToken(message['message']);
      } else if (message['type'] == 'group_join_success' && mounted) {
        _handleGroupJoinSuccess(message);
      } else if (message['cmd'] == 3 && message['opcode'] == 57 && mounted) {
        _handleGroupJoinError(message);
      }
    });
  }

  Future<void> _loadMyProfile() async {
    if (!mounted) return;
    setState(() => _isProfileLoading = true);
    try {
      final cachedProfile = ApiService.instance.lastChatsPayload?['profile'];
      if (cachedProfile != null) {
        if (mounted) {
          setState(() {
            _myProfile = Profile.fromJson(cachedProfile);
            _isProfileLoading = false;
          });
        }
      } else {
        final result = await ApiService.instance.getChatsAndContacts(
          force: false,
        );
        if (mounted) {
          final profileJson = result['profile'];
          if (profileJson != null) {
            setState(() {
              _myProfile = Profile.fromJson(profileJson);
              _isProfileLoading = false;
            });
          } else {
            setState(() => _isProfileLoading = false);
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isProfileLoading = false);
      print("Ошибка загрузки профиля в _HomeScreenState: $e");
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    String newVersion,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Доступно обновление'),
          content: Text(
            'Найдена новая версия приложения: $newVersion. Рекомендуется обновить данные сессии, чтобы соответствовать последней версии.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отменить'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            FilledButton(
              child: const Text('Обновить'),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('spoof_appversion', newVersion);

                try {
                  await ApiService.instance.performFullReconnection();
                  print("Переподключение выполнено успешно");
                } catch (e) {
                  print("Ошибка переподключения: $e");
                }

                if (mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Версия сессии обновлена до $newVersion!'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkVersionInBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isWebVersionCheckEnabled =
          prefs.getBool('enable_web_version_check') ?? false;

      if (!isWebVersionCheckEnabled) {
        print("Web version checking is disabled, skipping check");
        return;
      }

      final isAutoUpdateEnabled = prefs.getBool('auto_update_enabled') ?? false;
      final showUpdateNotification =
          prefs.getBool('show_update_notification') ?? true;

      final currentVersion = prefs.getString('spoof_appversion') ?? '0.0.0';
      final latestVersion = await VersionChecker.getLatestVersion();

      if (latestVersion != currentVersion) {
        if (isAutoUpdateEnabled) {
          await prefs.setString('spoof_appversion', latestVersion);
          print("Версия сессии автоматически обновлена до $latestVersion");

          try {
            await ApiService.instance.performFullReconnection();
            print("Переподключение выполнено успешно");
          } catch (e) {
            print("Ошибка переподключения: $e");
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Спуф сессии автоматически обновлен до версии $latestVersion',
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(10),
              ),
            );
          }
        } else if (showUpdateNotification) {
          if (mounted) {
            _showUpdateDialog(context, latestVersion);
          }
        }
      }
    } catch (e) {
      print("Фоновая проверка версии не удалась: $e");
    }
  }

  Future<void> _initDeepLinking() async {
    _appLinks = AppLinks();

    Uri? initialUriFromLaunch;

    try {
      initialUriFromLaunch = await _appLinks.getInitialLink();
      if (initialUriFromLaunch != null) {
        print('Получена ссылка (initial): $initialUriFromLaunch');
        if (mounted) {
          _handleJoinLink(initialUriFromLaunch);
        }
      }
    } catch (e) {
      print('Ошибка получения initial link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('Получена ссылка (stream): $uri');

      if (uri == initialUriFromLaunch) {
        print('Ссылка из stream совпадает с initial, игнорируем.');

        initialUriFromLaunch = null;
        return;
      }

      if (mounted) {
        _handleJoinLink(uri);
      }
    });
  }

  void _handleJoinLink(Uri uri) {
    if (uri.host != 'max.ru') return;

    String fullLink = uri.toString();

    
    if (fullLink.startsWith('@')) {
      fullLink = fullLink.substring(1);
    }

    final bool isGroupLink = uri.path.startsWith('/join/');
    final bool isChannelLink =
        !isGroupLink &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first.startsWith('id');

    if (!isGroupLink && !isChannelLink) {
      return;
    }

    if (isGroupLink) {
      final String processedLink = _extractJoinLink(fullLink);

      if (!processedLink.contains('join/')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Неверный формат ссылки. Ссылка должна содержать "join/"',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(10),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Загрузка информации о группе...'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 10),
        ),
      );

      ApiService.instance.waitUntilOnline().then((_) {
        ApiService.instance
            .getChatInfoByLink(processedLink)
            .then((chatInfo) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (mounted) {
                _showJoinConfirmationDialog(chatInfo, processedLink);
              }
            })
            .catchError((error) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: ${error.toString()}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            });
      });
    } else if (isChannelLink) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Загрузка информации о канале...'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 10),
        ),
      );

      ApiService.instance.waitUntilOnline().then((_) {
        ApiService.instance
            .getChatInfoByLink(fullLink)
            .then((chatInfo) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (mounted) {
                _showChannelSubscribeDialog(chatInfo, fullLink);
              }
            })
            .catchError((error) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: ${error.toString()}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            });
      });
    }
  }

  void _showJoinConfirmationDialog(
    Map<String, dynamic> chatInfo,
    String linkToJoin,
  ) {
    final String title = chatInfo['title'] ?? 'Без названия';
    final String? iconUrl = chatInfo['baseIconUrl'];

    int joinState = 0;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget content;
            List<Widget> actions = [];

            if (joinState == 1) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Присоединение...',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              );
              actions = [];
            } else if (joinState == 2) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Вы вступили в группу!',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              );
              actions = [
                FilledButton(
                  child: const Text('Отлично'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ];
            } else if (joinState == 3) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ошибка',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'Не удалось вступить в группу.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                ],
              );
              actions = [
                TextButton(
                  child: const Text('Закрыть'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ];
            } else {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconUrl != null && iconUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(iconUrl),
                      onBackgroundImageError: (e, s) {
                        print("Ошибка загрузки аватара: $e");
                      },
                      backgroundColor: Colors.grey.shade300,
                    )
                  else
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade300,
                      child: const Icon(
                        Icons.group,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Вы действительно хотите вступить в эту группу?',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
              actions = [
                TextButton(
                  child: const Text('Отмена'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                FilledButton(
                  child: const Text('Вступить'),
                  onPressed: () async {
                    setState(() {
                      joinState = 1;
                    });

                    try {
                      await ApiService.instance.joinGroupByLink(linkToJoin);

                      setState(() {
                        joinState = 2;
                      });

                      ApiService.instance.clearChatsCache();

                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      setState(() {
                        joinState = 3;
                        errorMessage = e.toString().replaceFirst(
                          "Exception: ",
                          "",
                        );
                      });
                    }
                  },
                ),
              ];
            }

            return AlertDialog(
              title: joinState == 0 ? const Text('Вступить в группу?') : null,
              content: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final slideAnimation =
                            Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutQuart,
                              ),
                            );

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slideAnimation,
                            child: child,
                          ),
                        );
                      },
                  child: Container(
                    key: ValueKey<int>(joinState),
                    child: content,
                  ),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: actions,
            );
          },
        );
      },
    );
  }

  void _showChannelSubscribeDialog(
    Map<String, dynamic> chatInfo,
    String linkToJoin,
  ) {
    final String title = chatInfo['title'] ?? 'Канал';
    final String? iconUrl =
        chatInfo['baseIconUrl'] ?? chatInfo['baseUrl'] ?? chatInfo['iconUrl'];

    int subscribeState = 0;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget content;
            List<Widget> actions = [];

            if (subscribeState == 1) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Подписка...',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              );
              actions = [];
            } else if (subscribeState == 2) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Вы подписались на канал!',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              );
              actions = [
                FilledButton(
                  child: const Text('Отлично'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ];
            } else if (subscribeState == 3) {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 32),
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 60,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ошибка',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'Не удалось подписаться на канал.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                ],
              );
              actions = [
                TextButton(
                  child: const Text('Закрыть'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ];
            } else {
              content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconUrl != null && iconUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(iconUrl),
                      onBackgroundImageError: (e, s) {
                        print("Ошибка загрузки аватара канала: $e");
                      },
                      backgroundColor: Colors.grey.shade300,
                    )
                  else
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade300,
                      child: const Icon(
                        Icons.campaign,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Вы действительно хотите подписаться на этот канал?',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
              actions = [
                TextButton(
                  child: const Text('Отмена'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                FilledButton(
                  child: const Text('Подписаться'),
                  onPressed: () async {
                    setState(() {
                      subscribeState = 1;
                    });

                    try {
                      await ApiService.instance.subscribeToChannel(linkToJoin);

                      setState(() {
                        subscribeState = 2;
                      });

                      ApiService.instance.clearChatsCache();

                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    } catch (e) {
                      setState(() {
                        subscribeState = 3;
                        errorMessage = e.toString().replaceFirst(
                          "Exception: ",
                          "",
                        );
                      });
                    }
                  },
                ),
              ];
            }

            return AlertDialog(
              title: subscribeState == 0
                  ? const Text('Подписаться на канал?')
                  : null,
              content: AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final slideAnimation =
                            Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutQuart,
                              ),
                            );

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slideAnimation,
                            child: child,
                          ),
                        );
                      },
                  child: Container(
                    key: ValueKey<int>(subscribeState),
                    child: content,
                  ),
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: actions,
            );
          },
        );
      },
    );
  }

  String _extractJoinLink(String inputLink) {
    final link = inputLink.trim();

    if (link.startsWith('join/')) {
      print('Ссылка уже в правильном формате: $link');
      return link;
    }

    final joinIndex = link.indexOf('join/');
    if (joinIndex != -1) {
      final extractedLink = link.substring(joinIndex);
      print('Извлечена ссылка из полной ссылки: $link -> $extractedLink');
      return extractedLink;
    }

    print('Не найдено "join/" в ссылке: $link');
    return link;
  }

  void _handleGroupJoinSuccess(Map<String, dynamic> message) {
    final payload = message['payload'];
    final chat = payload['chat'];
    final chatTitle = chat?['title'] ?? 'Группа';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Успешно присоединились к группе "$chatTitle"!'),
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _showSpoofUpdateDialogIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool('show_spoof_update_dialog') ?? true;

    if (!shouldShow || !mounted) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          bool dontShowAgain = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Проверка обновлений'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Хотите проверить обновления спуфа?'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: dontShowAgain,
                          onChanged: (value) {
                            setState(() {
                              dontShowAgain = value ?? false;
                            });
                          },
                        ),
                        const Expanded(child: Text('Больше не показывать')),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      if (dontShowAgain) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('show_spoof_update_dialog', false);
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Нет'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (dontShowAgain) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('show_spoof_update_dialog', false);
                      }
                      Navigator.of(context).pop();
                      await _checkSpoofUpdateManually();
                    },
                    child: const Text('Ок!'),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  Future<void> _checkSpoofUpdateManually() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isAutoUpdateEnabled = prefs.getBool('auto_update_enabled') ?? false;
      final currentVersion = prefs.getString('spoof_appversion') ?? '0.0.0';
      final latestVersion = await VersionChecker.getLatestVersion();

      if (latestVersion != currentVersion) {
        if (isAutoUpdateEnabled) {
          await prefs.setString('spoof_appversion', latestVersion);
          print("Версия сессии обновлена до $latestVersion");

          try {
            await ApiService.instance.performFullReconnection();
            print("Переподключение выполнено успешно");
          } catch (e) {
            print("Ошибка переподключения: $e");
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Спуф сессии обновлен до версии $latestVersion'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(10),
              ),
            );
          }
        } else {
          if (mounted) {
            _showUpdateDialog(context, latestVersion);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Версия спуфа актуальна'),
              backgroundColor: Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    } catch (e) {
      print("Проверка версии спуфа не удалась: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка проверки обновлений: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
  }

  void _handleGroupJoinError(Map<String, dynamic> message) {
    final errorPayload = message['payload'];
    String errorMessage = 'Неизвестная ошибка';
    if (errorPayload != null) {
      if (errorPayload['localizedMessage'] != null) {
        errorMessage = errorPayload['localizedMessage'];
      } else if (errorPayload['message'] != null) {
        errorMessage = errorPayload['message'];
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Theme.of(context).colorScheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _checkAndConnect() async {
    final hasToken = await ApiService.instance.hasToken();
    if (hasToken) {
      print("В HomeScreen: токен найден, проверяем подключение...");
      try {
        await ApiService.instance.connect();
        print("В HomeScreen: подключение к WebSocket успешно");
      } catch (e) {
        print("В HomeScreen: ошибка подключения к WebSocket: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка подключения к серверу: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      print("В HomeScreen: токен не найден, пользователь не авторизован");
    }
  }

  void _handleSessionTerminated(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PhoneEntryScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }
    });
  }

  void _showReconnectionScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ReconnectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _handleInvalidToken(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const PhoneEntryScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  static const double kDesktopLayoutBreakpoint = 700.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final shouldUseDesktopLayout =
                themeProvider.useDesktopLayout &&
                constraints.maxWidth >= kDesktopLayoutBreakpoint;

            if (shouldUseDesktopLayout) {
              return const _DesktopLayout();
            } else {
              return const ChatsScreen();
            }
          },
        );
      },
    );
  }
}

class _DesktopLayout extends StatefulWidget {
  const _DesktopLayout();

  @override
  State<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<_DesktopLayout> {
  Chat? _selectedChat;
  Contact? _selectedContact;
  bool _isGroupChat = false;
  bool _isChannel = false;
  int? _participantCount;
  Profile? _myProfile;
  bool _isProfileLoading = true;

  final ValueNotifier<double> _leftPanelWidth = ValueNotifier(320.0);
  static const double _minPanelWidth = 280.0;
  static const double _maxPanelWidth = 500.0;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    if (!mounted) return;
    setState(() => _isProfileLoading = true);
    try {
      final result = await ApiService.instance.getChatsAndContacts(
        force: false,
      );
      if (mounted) {
        final profileJson = result['profile'];
        if (profileJson != null) {
          setState(() {
            _myProfile = Profile.fromJson(profileJson);
            _isProfileLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isProfileLoading = false);
      print("Ошибка загрузки профиля в _DesktopLayout: $e");
    }
  }

  void _onChatSelected(
    Chat chat,
    Contact contact,
    bool isGroup,
    bool isChannel,
    int? participantCount,
  ) {
    setState(() {
      _selectedChat = chat;
      _selectedContact = contact;
      _isGroupChat = isGroup;
      _isChannel = isChannel;
      _participantCount = participantCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _leftPanelWidth,
            builder: (context, width, child) {
              return SizedBox(
                width: width,
                child: ChatsScreen(onChatSelected: _onChatSelected),
              );
            },
          ),

          GestureDetector(
            onPanUpdate: (details) {
              final newWidth = _leftPanelWidth.value + details.delta.dx;
              if (newWidth >= _minPanelWidth && newWidth <= _maxPanelWidth) {
                _leftPanelWidth.value = newWidth;
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: Container(
                width: 4.0,
                color: colors.outline.withOpacity(0.3),
              ),
            ),
          ),

          Expanded(
            child:
                (_selectedChat == null ||
                    _selectedContact == null ||
                    _isProfileLoading)
                ? Center(
                    child: _isProfileLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.message,
                                size: 80,
                                color: colors.primary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Выберите чат, чтобы начать общение',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                  )
                : ChatScreen(
                    key: ValueKey(_selectedChat!.id),
                    chatId: _selectedChat!.id,
                    contact: _selectedContact!,
                    myId: _myProfile?.id ?? 0,
                    isGroupChat: _isGroupChat,
                    isChannel: _isChannel,
                    participantCount: _participantCount,
                    isDesktopMode: true,
                  ),
          ),
        ],
      ),
    );
  }
}
