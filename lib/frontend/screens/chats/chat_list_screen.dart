import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'chat_screen.dart';

import '../calls/calls_tab.dart';
import '../contacts/contacts_tab.dart';
import '../profile/settings_tab.dart';
import '../../../backend/api.dart';
import '../../../backend/modules/chats.dart';
import '../../../core/storage/app_database.dart';
import '../../../main.dart' show api;

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  String _selectedCategory = 'Все чаты';
  int _currentNavIndex = 0;
  bool _isFabOpen = false;
  bool _showCacheWarning = false;
  late AnimationController _fabController;
  final Set<String> _selectedChats = {};
  final ScrollController _scrollController = ScrollController();
  double _pullRatio = 0.0;
  static const double _kStoriesPullTriggerPx = 16.0;
  late AnimationController _storiesRevealController;
  double _revealAnimBegin = 0.0;
  double _closeAnimBegin = 0.0;
  bool _storiesAnimClosing = false;
  bool _storiesDockedOpen = false;
  DateTime _storiesRevealLayoutSettleUntil = DateTime.fromMillisecondsSinceEpoch(0);
  ProfileData? _profile;
  List<CachedChat> _chats = [];
  SessionState _sessionState = SessionState.disconnected;
  StreamSubscription? _stateSub;
  bool _shouldCollapseSearch = false;

  bool get _isSelectionMode => _selectedChats.isNotEmpty;

  void _toggleSelection(String chatId) {
    setState(() {
      if (_selectedChats.contains(chatId)) {
        _selectedChats.remove(chatId);
      } else {
        _selectedChats.add(chatId);
      }

      if (_isSelectionMode) {
        if (_scrollController.hasClients && _scrollController.offset < 132) {
          _shouldCollapseSearch = true;
        }
      } else {
        _shouldCollapseSearch = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChats.clear();
      _shouldCollapseSearch = false;
    });
  }

  bool _isInitialLoading = true;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _storiesRevealController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 400),
          )
          ..addListener(_onStoriesRevealTick)
          ..addStatusListener(_onStoriesRevealStatus);

    _scrollController.addListener(_onScroll);

    _sessionState = api.state;
    _stateSub = api.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _sessionState = state;
          if (state == SessionState.disconnected && _chats.isNotEmpty) {
            _showCacheWarning = true;
          }
          if (state == SessionState.online) {
            _showCacheWarning = false;
          }
        });
      }
    });

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await AppDatabase.loadActiveProfile();
    if (p != null) {
      final chats = await ChatsModule.getChats(p.id);
      if (mounted) {
        setState(() {
          _profile = p;
          _chats = chats;
          _isInitialLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildChatShimmer() {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + 0.3 * sin(_shimmerController.value * pi * 2);
        return Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onStoriesRevealTick() {
    if (!mounted) return;
    final t = Curves.easeOutCubic.transform(_storiesRevealController.value);
    setState(() {
      if (_storiesAnimClosing) {
        _pullRatio = _closeAnimBegin * (1.0 - t);
      } else {
        _pullRatio = _revealAnimBegin + (1.0 - _revealAnimBegin) * t;
      }
    });
  }

  void _onStoriesRevealStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      setState(() {
        if (_storiesAnimClosing) {
          _pullRatio = 0.0;
          _storiesDockedOpen = false;
          _storiesAnimClosing = false;
        } else {
          _pullRatio = 1.0;
          _storiesDockedOpen = true;
          _storiesRevealLayoutSettleUntil = DateTime.now().add(
            const Duration(milliseconds: 520),
          );
        }
      });
    }
  }

  void _startStoriesAutoReveal(double suggestedFrom) {
    if (_storiesRevealController.isAnimating && !_storiesAnimClosing) return;
    if (_storiesDockedOpen) return;
    _storiesRevealController.stop();
    _storiesAnimClosing = false;
    final from = max(_pullRatio, suggestedFrom.clamp(0.0, 1.0));
    if (from >= 1.0) {
      setState(() {
        _pullRatio = 1.0;
        _storiesDockedOpen = true;
      });
      _storiesRevealLayoutSettleUntil = DateTime.now().add(
        const Duration(milliseconds: 520),
      );
      return;
    }
    _revealAnimBegin = from;
    _storiesRevealController.duration = Duration(
      milliseconds: (260 + 240 * (1.0 - from)).round(),
    );
    _storiesRevealController.reset();
    _storiesRevealController.forward(from: 0);
  }

  void _startStoriesAutoClose() {
    if (_pullRatio <= 0 &&
        !_storiesDockedOpen &&
        !_storiesRevealController.isAnimating) {
      return;
    }
    if (_storiesAnimClosing && _storiesRevealController.isAnimating) return;
    _storiesRevealController.stop();
    _storiesAnimClosing = true;
    final from = _pullRatio.clamp(0.0, 1.0);
    if (from <= 0) {
      setState(() {
        _pullRatio = 0.0;
        _storiesDockedOpen = false;
        _storiesAnimClosing = false;
      });
      return;
    }
    _closeAnimBegin = from;
    _storiesRevealController.duration = Duration(
      milliseconds: (260 + 240 * from).round(),
    );
    _storiesRevealController.reset();
    _storiesRevealController.forward(from: 0);
  }

  bool _onStoriesScrollNotification(ScrollNotification n) {
    if (_currentNavIndex != 0) return false;
    if (n is! ScrollUpdateNotification) return false;
    if (!_scrollController.hasClients) return false;
    if (!_storiesDockedOpen || _storiesRevealController.isAnimating) {
      return false;
    }
    if (!DateTime.now().isAfter(_storiesRevealLayoutSettleUntil)) {
      return false;
    }
    if (n.dragDetails == null) {
      return false;
    }
    final m = n.metrics;
    if (m.axis != Axis.vertical) return false;
    if (m.pixels > m.minScrollExtent + 1.0) return false;
    final d = n.scrollDelta;
    if (d == null || d <= 0) return false;
    _startStoriesAutoClose();
    return false;
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final double offset = _scrollController.offset;
      if (_isSelectionMode && !_shouldCollapseSearch && offset < 132) {
        setState(() {
          _shouldCollapseSearch = true;
        });
      }

      if (offset < 0) {
        final dragRatio = (offset.abs() / 80.0).clamp(0.0, 1.0);
        if (_storiesRevealController.isAnimating) {
          return;
        }
        if (!_storiesDockedOpen && offset.abs() >= _kStoriesPullTriggerPx) {
          _startStoriesAutoReveal(dragRatio);
        } else if (!_storiesDockedOpen) {
          if (dragRatio != _pullRatio) {
            setState(() {
              _pullRatio = dragRatio;
            });
          }
        }
      } else {
        if (_storiesDockedOpen &&
            offset > 12 &&
            DateTime.now().isAfter(_storiesRevealLayoutSettleUntil)) {
          _startStoriesAutoClose();
        }
        if (_storiesDockedOpen || _storiesRevealController.isAnimating) {
          return;
        }
        if (_pullRatio > 0) {
          setState(() {
            _pullRatio = 0.0;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _fabController.dispose();
    _storiesRevealController
      ..removeListener(_onStoriesRevealTick)
      ..removeStatusListener(_onStoriesRevealStatus)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            IndexedStack(
              index: _currentNavIndex,
              children: [
                Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      if (_scrollController.hasClients &&
                          _scrollController.offset <= 0) {
                        if (pointerSignal.scrollDelta.dy < 0) {
                          _startStoriesAutoReveal(max(_pullRatio, 0.18));
                        } else if (pointerSignal.scrollDelta.dy > 0 &&
                            _pullRatio > 0) {
                          _startStoriesAutoClose();
                        }
                      }
                    }
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onStoriesScrollNotification,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: ClipRect(
                            clipBehavior: Clip.hardEdge,
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: _shouldCollapseSearch
                                  ? const SizedBox(
                                      width: double.infinity,
                                      height: 0,
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            12,
                                            20,
                                            2,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  if (_pullRatio < 0.8)
                                                    Opacity(
                                                      opacity: 1.0 - _pullRatio,
                                                      child: Container(
                                                        width:
                                                            50 *
                                                            (1.0 - _pullRatio),
                                                        height: 32,
                                                        margin:
                                                            const EdgeInsets.only(
                                                              right: 8,
                                                            ),
                                                        child: Stack(
                                                          children: [
                                                            _buildFoldedStory(
                                                              'https://i.pravatar.cc/150?u=dasha',
                                                              0,
                                                            ),
                                                            _buildFoldedStory(
                                                              'https://i.pravatar.cc/150?u=mastika',
                                                              1,
                                                            ),
                                                            _buildFoldedStory(
                                                              'https://i.pravatar.cc/150?u=stas',
                                                              2,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  Text(
                                                    _sessionState ==
                                                            SessionState.online
                                                        ? (_profile
                                                                  ?.firstName ??
                                                              'Чат')
                                                        : 'Подключение...',
                                                    style: TextStyle(
                                                      color: cs.onSurface,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              PopupMenuButton<int>(
                                                icon: Icon(
                                                  Symbols.more_vert,
                                                  color: cs.outline,
                                                  weight: 400,
                                                ),
                                                offset: const Offset(0, 48),
                                                elevation: 4,
                                                color: cs.surfaceContainerHigh,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                itemBuilder: (context) => [
                                                  _buildPopupMenuItem(
                                                    1,
                                                    'Кнопка 1',
                                                    Symbols.settings,
                                                  ),
                                                  _buildPopupMenuItem(
                                                    2,
                                                    'Кнопка 2',
                                                    Symbols.notifications,
                                                  ),
                                                  _buildPopupMenuItem(
                                                    3,
                                                    'Кнопка 3',
                                                    Symbols.shield,
                                                  ),
                                                  _buildPopupMenuItem(
                                                    4,
                                                    'Кнопка 4',
                                                    Symbols.info,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          height: 96 * _pullRatio,
                                          child: Opacity(
                                            opacity: _pullRatio,
                                            child: ListView(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                              children: [
                                                _buildStoryItem(
                                                  'Даша',
                                                  'https://i.pravatar.cc/150?u=dasha',
                                                  true,
                                                ),
                                                _buildStoryItem(
                                                  'Мастика',
                                                  'https://i.pravatar.cc/150?u=mastika',
                                                  false,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (_showCacheWarning)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              20,
                                              0,
                                              20,
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: cs.errorContainer
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: cs.error.withOpacity(
                                                    0.2,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Symbols.cloud_off,
                                                    size: 18,
                                                    color: cs.error,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text(
                                                      'Ошибка соединения, сейчас вы смотрите КЕШ',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            2,
                                            20,
                                            8,
                                          ),
                                          child: Container(
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(50),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Symbols.search,
                                                  color: cs.outline,
                                                  size: 20,
                                                  weight: 400,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: TextField(
                                                    style: TextStyle(
                                                      color: cs.onSurface,
                                                      fontSize: 15,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText: 'Поиск',
                                                      hintStyle: TextStyle(
                                                        color: cs.outline,
                                                        fontSize: 15,
                                                      ),
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
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
                        ),
                        SliverPadding(
                          padding: EdgeInsets.zero,
                          sliver: SliverToBoxAdapter(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              height: 48,
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(
                                      dragDevices: {
                                        ui.PointerDeviceKind.touch,
                                        ui.PointerDeviceKind.mouse,
                                        ui.PointerDeviceKind.trackpad,
                                      },
                                    ),
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    _buildFolderChip('Все чаты'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Контакты'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Пидоры'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Каналы'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Группы'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Боты'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Избранное'),
                                    const SizedBox(width: 8),
                                    _buildFolderChip('Архив'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (_isInitialLoading) {
                                return _buildChatShimmer();
                              }
                              final chat = _chats[index];
                              return _buildChatItem(
                                chat.id.toString(),
                                chat.title ?? 'Чат',
                                chat.lastMsgText ?? '',
                                _formatTime(chat.lastMsgTime),
                                (chat.iconUrl != null &&
                                        chat.iconUrl!.isNotEmpty)
                                    ? chat.iconUrl!
                                    : '',
                                isOnline: chat.isOnline,
                                unreadCount: chat.unreadCount,
                                isMuted: chat.dontDisturbUntil > 0,
                              );
                            },
                            childCount: _isInitialLoading ? 10 : _chats.length,
                          ),
                        ),
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 100),
                        ),
                      ],
                    ),
                  ),
                ),
                const CallsTab(),
                const ContactsTab(),
                const SettingsTab(),
              ],
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: 8,
              right: 8,
              bottom: _isSelectionMode ? -100 : 10.0,
              child: RepaintBoundary(
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double totalWidth = constraints.maxWidth;

                      double totalWeight = 5.2;
                      double unitWidth = totalWidth / totalWeight;
                      double activeWidth = unitWidth * 2.2;
                      double inactiveWidth = unitWidth * 1.0;

                      double leftOffset = 0;
                      for (int i = 0; i < _currentNavIndex; i++) {
                        leftOffset += inactiveWidth;
                      }

                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            left: leftOffset + 4,
                            top: 8,
                            bottom: 8,
                            width: activeWidth - 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(4, (index) {
                              IconData icon;
                              String label;
                              switch (index) {
                                case 0:
                                  icon = Symbols.chat_bubble;
                                  label = 'Чаты';
                                  break;
                                case 1:
                                  icon = Symbols.call;
                                  label = 'Звонки';
                                  break;
                                case 2:
                                  icon = Symbols.person_pin;
                                  label = 'Контакты';
                                  break;
                                default:
                                  icon = Symbols.settings;
                                  label = 'Настройки';
                              }

                              bool isSelected = _currentNavIndex == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                width: isSelected
                                    ? (activeWidth - 0.5)
                                    : (inactiveWidth - 0.5),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: _buildNavItem(index, icon, label),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _fabController,
              builder: (context, child) {
                final double val = Curves.easeOutCubic.transform(
                  _fabController.value,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_fabController.value > 0)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: _toggleFab,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            color: Colors.black.withValues(alpha: val * 0.2),
                          ),
                        ),
                      ),
                    if (!_isSelectionMode && _currentNavIndex == 0) ...[
                      if (_fabController.value > 0)
                        Positioned(
                          right: 20,
                          bottom: 90 + 74,
                          child: RepaintBoundary(
                            child: Transform.scale(
                              scale: val,
                              alignment: Alignment.bottomRight,
                              child: Opacity(
                                opacity: val > 0.5 ? (val - 0.5) * 2 : 0,
                                child: _buildFabMenu(),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 20,
                        bottom: 90,
                        child: FloatingActionButton(
                          onPressed: _toggleFab,
                          backgroundColor: cs.primaryContainer,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Transform.rotate(
                            angle: val * (pi / 4),
                            child: Icon(
                              Symbols.add,
                              color: cs.onPrimaryContainer,
                              size: 28,
                              weight: 400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: _isSelectionMode ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Symbols.arrow_back, color: cs.onSurface),
                      onPressed: _clearSelection,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedChats.length.toString(),
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Symbols.delete, color: cs.onSurface),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Symbols.archive, color: cs.onSurface),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Symbols.volume_off, color: cs.onSurface),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryItem(String name, String imageUrl, bool hasUpdate) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: 68,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: hasUpdate
                      ? Border.all(color: cs.primary, width: 2)
                      : Border.all(color: cs.outlineVariant),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: NetworkImage(imageUrl),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderChip(String title) {
    final cs = Theme.of(context).colorScheme;
    bool isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? cs.onPrimaryContainer : cs.primary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(
    String id,
    String name,
    String message,
    String time,
    String imageUrl, {
    bool isOnline = false,
    bool isTyping = false,
    bool isRead = false,
    int unreadCount = 0,
    bool isMuted = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedChats.contains(id);

    return InkWell(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: int.parse(id),
                name: name,
                imageUrl: imageUrl,
              ),
            ),
          );
        }
      },
      onLongPress: () => _toggleSelection(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isSelected ? cs.primary.withOpacity(0.08) : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 2,
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              if (isSelected)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                    child: Icon(
                      Symbols.check,
                      color: cs.onPrimary,
                      size: 14,
                      weight: 600,
                    ),
                  ),
                )
              else if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isMuted)
                Icon(
                  Symbols.notifications_off,
                  color: cs.outlineVariant,
                  size: 14,
                  weight: 400,
                ),
              const SizedBox(width: 8),
              Text(time, style: TextStyle(color: cs.outline, fontSize: 12)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isTyping ? cs.primary : cs.outline,
                      fontSize: 14,
                      fontWeight: isTyping ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isMuted
                          ? cs.surfaceContainerHighest
                          : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: TextStyle(
                        color: isMuted ? cs.outline : cs.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isRead)
                  Icon(
                    Symbols.done_all,
                    color: cs.primary,
                    size: 16,
                    weight: 400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    bool isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? cs.onPrimary : cs.onSurface,
                size: 20,
                weight: 400,
                fill: isSelected ? 1.0 : 0.0,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: isSelected ? null : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildFabMenu() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFabMenuItem(Symbols.search, 'Найти по номеру'),
          _buildFabMenuItem(Symbols.group_add, 'Добавить группу'),
          _buildFabMenuItem(Symbols.campaign, 'Создать канал'),
        ],
      ),
    );
  }

  Widget _buildFabMenuItem(IconData icon, String title) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        // Action logic here
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: cs.onSurface, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _buildPopupMenuItem(
    int value,
    String title,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: cs.onSurface, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldedStory(String imageUrl, int index) {
    return Positioned(
      left: index * 12.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(imageUrl),
        ),
      ),
    );
  }
}
