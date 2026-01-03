import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/app_sizes.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final TextEditingController _linkController = TextEditingController();
  StreamSubscription? _apiSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listenToApiMessages();
  }

  @override
  void dispose() {
    _linkController.dispose();
    _apiSubscription?.cancel();
    super.dispose();
  }

  void _listenToApiMessages() {
    _apiSubscription = ApiService.instance.messages.listen((message) {
      if (!mounted) return;

      if (message['type'] == 'group_join_success') {
        setState(() {
          _isLoading = false;
        });

        final payload = message['payload'];
        final chat = payload?['chat'];
        final chatTitle = chat?['title'] ?? 'Группа';

        ApiService.instance.clearChatsCache();

        Future.microtask(() {
          if (!mounted) return;
          try {
            if (Navigator.of(context, rootNavigator: false).canPop()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Успешно присоединились к группе "$chatTitle"!',
                  ),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdBorder,
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(AppSpacing.lg),
                ),
              );

              Navigator.of(context).pop();
            }
          } catch (e) {
            print('Ошибка при закрытии экрана присоединения: $e');
          }
        });
      }

      if (message['cmd'] == 1 && message['opcode'] == 57) {
        setState(() {
          _isLoading = false;
        });

        Future.microtask(() {
          if (!mounted) return;
          try {
            if (Navigator.of(context, rootNavigator: false).canPop()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Успешно подписались на канал!'),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdBorder,
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(AppSpacing.lg),
                ),
              );

              Navigator.of(context).pop();
            }
          } catch (e) {
            print('Ошибка при закрытии экрана подписки на канал: $e');
          }
        });
      }

      if (message['cmd'] == 3 && message['opcode'] == 57) {
        setState(() {
          _isLoading = false;
        });

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
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdBorder,
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(AppSpacing.lg),
          ),
        );
      }
    });
  }

  String _normalizeLink(String inputLink) {
    String link = inputLink.trim();

    if (link.startsWith('@')) {
      link = link.substring(1).trim();
    }

    return link;
  }

  String _extractJoinLink(String inputLink) {
    final link = _normalizeLink(inputLink);

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

  bool _isChannelLink(String inputLink) {
    final link = _normalizeLink(inputLink);

    try {
      final uri = Uri.parse(link);
      if (uri.host == 'max.ru' &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first.startsWith('id')) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  void _joinGroup() async {
    final rawInput = _linkController.text.trim();
    final inputLink = _normalizeLink(rawInput);

    if (inputLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Введите ссылку'),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(AppSpacing.lg),
        ),
      );
      return;
    }

    if (_isChannelLink(inputLink)) {
      setState(() {
        _isLoading = true;
      });

      try {
        final chatInfo = await ApiService.instance.getChatInfoByLink(inputLink);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        _showChannelSubscribeDialog(chatInfo, inputLink);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdBorder,
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(AppSpacing.lg),
          ),
        );
      }
      return;
    }

    final processedLink = _extractJoinLink(inputLink);

    if (!processedLink.contains('join/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Неверный формат ссылки. Для группы ссылка должна содержать "join/"',
          ),
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(AppSpacing.lg),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    bool successHandled = false;
    Timer? timeoutTimer;

    timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!successHandled && mounted) {
        setState(() {
          _isLoading = false;
        });
        ApiService.instance.clearChatsCache();

        Future.microtask(() {
          if (!mounted) return;
          try {
            if (Navigator.of(context, rootNavigator: false).canPop()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Присоединение выполнено. Обновите список чатов.',
                  ),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdBorder,
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.all(AppSpacing.lg),
                ),
              );
              Navigator.of(context).pop();
            }
          } catch (e) {
            print('Ошибка при закрытии экрана (таймаут): $e');
          }
        });
      }
    });

    StreamSubscription? tempSubscription;

    tempSubscription = ApiService.instance.messages.listen((message) {
      if (message['type'] == 'group_join_success' && !successHandled) {
        successHandled = true;
        timeoutTimer?.cancel();
        tempSubscription?.cancel();
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          final payload = message['payload'];
          final chat = payload?['chat'];
          final chatTitle = chat?['title'] ?? 'Группа';
          ApiService.instance.clearChatsCache();

          Future.microtask(() {
            if (!mounted) return;
            try {
              if (Navigator.of(context, rootNavigator: false).canPop()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Успешно присоединились к группе "$chatTitle"!',
                    ),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdBorder,
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(AppSpacing.lg),
                  ),
                );
                Navigator.of(context).pop();
              }
            } catch (e) {
              print('Ошибка при закрытии экрана присоединения (temp): $e');
            }
          });
        }
      }
    });

    try {
      await ApiService.instance.joinGroupByLink(processedLink);

      if (!successHandled) {
        await Future.delayed(const Duration(seconds: 2));
        if (!successHandled && mounted) {
          timeoutTimer.cancel();
          tempSubscription.cancel();
          setState(() {
            _isLoading = false;
          });
          ApiService.instance.clearChatsCache();

          Future.microtask(() {
            if (!mounted) return;
            try {
              if (Navigator.of(context, rootNavigator: false).canPop()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Присоединение выполнено. Обновите список чатов.',
                    ),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdBorder,
                    ),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.all(AppSpacing.lg),
                  ),
                );
                Navigator.of(context).pop();
              }
            } catch (e) {
              print('Ошибка при закрытии экрана (задержка): $e');
            }
          });
        }
      }
    } catch (e) {
      timeoutTimer.cancel();
      tempSubscription.cancel();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка присоединения: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdBorder,
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(AppSpacing.lg),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Присоединиться по ссылке'),
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.link, color: colors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Присоединение по ссылке',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Введите ссылку на группу или канал, чтобы присоединиться. '
                        'Для групп можно вводить полную (https://max.ru/join/...) '
                        'или короткую (join/...) ссылку, для каналов — ссылку вида '
                        'https://max.ru/idXXXXXXXX.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Ссылка',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    labelText: 'Ссылка на группу или канал',
                    hintText:
                        'https://max.ru/join/ABC123DEF456GHI789JKL или https://max.ru/id7452017130_gos',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.link),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outline.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Формат ссылки:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Для групп: ссылка должна содержать "join/"\n'
                        '• После "join/" должен идти уникальный идентификатор группы\n'
                        '• Примеры групп:\n'
                        '  - https://max.ru/join/ABC123DEF456GHI789JKL\n'
                        '  - join/ABC123DEF456GHI789JKL\n'
                        '• Для каналов: ссылка вида https://max.ru/idXXXXXXXX',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _joinGroup,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _isLoading
                          ? 'Присоединение...'
                          : 'Присоединиться по ссылке',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
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
}
