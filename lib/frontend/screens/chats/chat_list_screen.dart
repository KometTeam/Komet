import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'chat_screen.dart';
import 'create_group_flow.dart';
import '../../widgets/adaptive_shell.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/swipe_route.dart';
import '../../widgets/sliding_pill_nav.dart';
import '../../../core/utils/format.dart';

import '../calls/calls_tab.dart';
import '../contacts/contacts_tab.dart';
import '../profile/settings_tab.dart';
import '../auth/login_screen.dart';
import '../../widgets/account_switcher_overlay.dart';
import '../../../backend/api.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/config/app_stories.dart';
import '../../../backend/models/chat_folder.dart';
import '../../../backend/modules/account.dart';
import '../../../backend/modules/chats.dart';
import '../../../backend/modules/cloud_storage.dart';
import '../../../backend/modules/folders.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../main.dart'
    show accountModule, api, messagesModule, appRouteObserver;

class _StoriesScrollPhysics extends BouncingScrollPhysics {
  final bool Function() blockPositive;
  final bool Function() allowPullOverscrollTop;

  const _StoriesScrollPhysics({
    required this.blockPositive,
    required this.allowPullOverscrollTop,
    super.parent,
  });

  @override
  _StoriesScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _StoriesScrollPhysics(
      blockPositive: blockPositive,
      allowPullOverscrollTop: allowPullOverscrollTop,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (blockPositive() && value > 0.0) {
      return value - max(0.0, position.pixels);
    }
    if (!allowPullOverscrollTop() &&
        value < position.minScrollExtent &&
        position.pixels <= position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class ChatListScreen extends StatefulWidget {
  final ValueChanged<DesktopChatSelection>? onChatSelected;

  const ChatListScreen({super.key, this.onChatSelected});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

enum _DeleteKind { personalLike, ownerGroup, blocked }

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin, RouteAware {
  String? _selectedFolderId;

  List<ChatFolder> _folders = [];

  int _currentNavIndex = 0;

  static const List<PillNavItem> _chatsNavItems = [
    PillNavItem(icon: Symbols.chat_bubble, label: 'Чаты'),
    PillNavItem(icon: Symbols.call, label: 'Звонки'),
    PillNavItem(icon: Symbols.person_pin, label: 'Контакты'),
    PillNavItem(
      icon: Symbols.settings,
      label: 'Настройки',
      longPressable: true,
    ),
  ];

  double _navPageAnimStart = 0;
  double _navPageAnimEnd = 0;
  final ValueNotifier<double> _navDragDx = ValueNotifier(0);
  double _navDragBaseLeft = 0;
  double _revealAnimBegin = 0.0;
  double _closeAnimBegin = 0.0;
  static const double _kStoriesPullTriggerPx = 16.0;

  final _StoriesUi _storiesUi = _StoriesUi();
  double get _pullRatio => _storiesUi.pullRatio;
  set _pullRatio(double v) => _storiesUi.pullRatio = v;
  bool get _storiesDockedOpen => _storiesUi.dockedOpen;
  set _storiesDockedOpen(bool v) => _storiesUi.dockedOpen = v;
  bool get _storiesOverscrollRevealArmed => _storiesUi.overscrollRevealArmed;
  set _storiesOverscrollRevealArmed(bool v) =>
      _storiesUi.overscrollRevealArmed = v;
  bool get _shouldCollapseSearch => _storiesUi.shouldCollapseSearch;
  set _shouldCollapseSearch(bool v) => _storiesUi.shouldCollapseSearch = v;

  bool _navDragging = false;
  bool _isFabOpen = false;
  bool _storiesAnimClosing = false;
  Timer? _contactRebuildTimer;
  bool _deferReloads = false;
  bool _reloadQueued = false;
  Timer? _settleTimer;
  bool get _isSelectionMode => _selectedChats.isNotEmpty;
  bool? _foldersListKnown;

  late AnimationController _navPageAnimController;
  late AnimationController _fabController;
  late PageController _folderPageController;
  late AnimationController _storiesRevealController;

  final List<ScrollController> _folderChatScrollControllers = [];
  final List<VoidCallback> _folderChatScrollListenerFns = [];
  final Set<String> _selectedChats = {};
  final Set<int> _inflightContactIds = {};

  DateTime _storiesRevealLayoutSettleUntil =
      DateTime.fromMillisecondsSinceEpoch(0);
  ProfileData? _profile;

  List<CachedChat> _chats = [];

  SessionState _sessionState = SessionState.disconnected;

  StreamSubscription? _stateSub;
  StreamSubscription<LoginStatus>? _loginSub;

  Widget? _cachedChatsBody;
  Object? _chatsBodyCacheKey;

  /// Возвращает дерево вкладки «Чаты», кэшируя его между ребилдами
  /// родителя. Тап/драг навбара и FAB не трогают эти state-vars,
  /// поэтому ключ остаётся прежним и subtree не пересобирается.
  Widget _getChatsBody() {
    final key = Object.hashAll([
      identityHashCode(_chats),
      identityHashCode(_folders),
      _selectedFolderId,
      _isInitialLoading,
      _foldersListKnown,
      _isSelectionMode,
      _shouldCollapseSearch,
      _selectedChats.length,
      _storiesDockedOpen,
      _storiesAnimClosing,
      _storiesOverscrollRevealArmed,
      _sessionState,
      identityHashCode(_profile),
    ]);
    if (_cachedChatsBody == null || _chatsBodyCacheKey != key) {
      _chatsBodyCacheKey = key;
      _cachedChatsBody = _buildChatsTabBody();
    }
    return _cachedChatsBody!;
  }

  void _toggleSelection(String chatId) {
    Haptics.selection();
    setState(() {
      if (_selectedChats.contains(chatId)) {
        _selectedChats.remove(chatId);
      } else {
        _selectedChats.add(chatId);
      }

      _shouldCollapseSearch = _isSelectionMode;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChats.clear();
      _shouldCollapseSearch = false;
    });
  }

  List<CachedChat> _selectedChatObjects() {
    if (_selectedChats.isEmpty) return const [];
    final ids = <int>{};
    for (final s in _selectedChats) {
      final v = int.tryParse(s);
      if (v != null) ids.add(v);
    }
    return _chats.where((c) => ids.contains(c.id)).toList();
  }

  _DeleteKind _categorizeChat(CachedChat c, int myId) {
    if (c.type == 'DIALOG') return _DeleteKind.personalLike;
    if (c.iAmAdmin(myId)) return _DeleteKind.ownerGroup;
    return _DeleteKind.blocked;
  }

  _DeleteKind? _selectionDeleteCategoryFor(List<CachedChat> selected) {
    if (_sessionState != SessionState.online) return null;
    final myId = _profile?.id;
    if (myId == null) return null;
    if (selected.isEmpty) return null;
    final cats = selected.map((c) => _categorizeChat(c, myId)).toSet();
    if (cats.contains(_DeleteKind.blocked)) return null;
    if (cats.length > 1) return null;
    return cats.single;
  }

  Future<void> _onPinTap() async {
    final selected = _selectedChatObjects();
    if (selected.isEmpty) return;
    final anyPinned = selected.any((c) => (c.favIndex ?? 0) > 0);
    final err = await ChatsModule.togglePin(
      api,
      chatIds: selected.map((c) => c.id).toList(),
      pin: !anyPinned,
    );
    if (!mounted) return;
    if (err != null) showCustomNotification(context, err);
    _clearSelection();
  }

  Future<void> _onMuteTap() async {
    final selected = _selectedChatObjects();
    if (selected.isEmpty) return;
    final anyMuted = selected.any((c) => c.isMuted);
    final targetDDU = anyMuted ? ChatsModule.muteOff : ChatsModule.muteForever;

    final errors = <String>[];
    for (final c in selected) {
      final err = await ChatsModule.setChatMute(
        api,
        chatId: c.id,
        dontDisturbUntil: targetDDU,
      );
      if (err != null) errors.add(err);
    }
    if (!mounted) return;
    if (errors.isNotEmpty) {
      showCustomNotification(
        context,
        errors.length == 1
            ? errors.first
            : 'Не удалось изменить ${errors.length} чат(ов): ${errors.first}',
      );
    }
    _clearSelection();
  }

  Future<void> _onDeleteTap() async {
    final selectedBefore = _selectedChatObjects();
    if (selectedBefore.isEmpty) return;
    final myId = _profile?.id;
    if (myId == null) return;

    await ChatsModule.refreshChats(
      api,
      selectedBefore.map((c) => c.id).toList(),
    );
    if (!mounted) return;

    final selectedAfter = _selectedChatObjects();
    if (selectedAfter.isEmpty) return;
    final cats = selectedAfter.map((c) => _categorizeChat(c, myId)).toSet();
    if (cats.contains(_DeleteKind.blocked) || cats.length > 1) {
      showCustomNotification(
        context,
        'Статус чатов изменился, попробуйте ещё раз',
      );
      return;
    }
    final kind = cats.single;

    final confirmed = await _showDeleteConfirmDialog(selectedAfter, kind);
    if (!mounted || confirmed != true) return;

    final errors = <String>[];
    for (final c in selectedAfter) {
      final forAll = kind == _DeleteKind.ownerGroup;
      final err = await ChatsModule.deleteChat(
        api,
        chatId: c.id,
        lastEventTime: c.lastEventTime,
        forAll: forAll,
      );
      if (err != null) errors.add(err);
    }
    if (!mounted) return;
    if (errors.isNotEmpty) {
      final msg = errors.length == 1
          ? errors.first
          : 'Не удалось удалить ${errors.length} чат(ов): ${errors.first}';
      showCustomNotification(context, msg);
    }
    _clearSelection();
  }

  Future<bool?> _showDeleteConfirmDialog(
    List<CachedChat> selected,
    _DeleteKind kind,
  ) {
    final cs = Theme.of(context).colorScheme;
    final count = selected.length;
    final single = count == 1 ? selected.first : null;

    String title;
    String body;
    String primaryLabel;
    switch (kind) {
      case _DeleteKind.personalLike:
        title = single != null
            ? 'Удалить чат с ${single.title ?? ''}?'
            : 'Удалить $count чатов?';
        body = 'Восстановить переписку не получится';
        primaryLabel = count == 1 ? 'Удалить чат' : 'Удалить';
      case _DeleteKind.ownerGroup:
        title = single != null
            ? 'Хотите удалить чат «${single.title ?? ''}»?'
            : 'Удалить $count групп у всех?';
        body = single != null
            ? 'Передайте права владельца, чтобы остальные участники могли продолжить общение'
            : 'Действие нельзя отменить';
        primaryLabel = count == 1 ? 'Удалить чат у всех' : 'Удалить у всех';
      case _DeleteKind.blocked:
        return Future.value(false);
    }

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 20),
                if (kind == _DeleteKind.ownerGroup && single != null) ...[
                  Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      'Передать права и выйти',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      primaryLabel,
                      style: TextStyle(
                        color: cs.onError,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isInitialLoading = true;
  DateTime _storiesLockdownUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool _shouldBlockPositiveScroll() {
    if (_pullRatio > 0 ||
        _storiesDockedOpen ||
        _storiesRevealController.isAnimating) {
      return true;
    }
    if (DateTime.now().isBefore(_storiesLockdownUntil)) {
      return true;
    }
    return false;
  }

  bool _allowStoriesPullOverscrollTop() {
    if (!AppStories.current.value) return false;
    if (_storiesDockedOpen ||
        _storiesRevealController.isAnimating ||
        _pullRatio > 0) {
      return true;
    }
    return _storiesOverscrollRevealArmed;
  }

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _navPageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
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

    _folderPageController = PageController();
    _syncFolderChatScrollControllers();

    _sessionState = api.state;
    _stateSub = api.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _sessionState = state;
        });
        if (state == SessionState.online) {
          _requestReload();
        }
      }
    });

    _loginSub = accountModule.loginStatusStream.listen((status) {
      if (status == LoginStatus.success) {
        _requestReload();
      }
    });
    ChatsModule.chatsChanged.addListener(_onChatsChanged);
    AppStories.current.addListener(_onStoriesEnabledChanged);
    _reloadChatsAndFolders();
  }

  void _onStoriesEnabledChanged() {
    if (!mounted) return;
    if (!AppStories.current.value) {
      _storiesRevealController.stop();
      _pullRatio = 0;
      _storiesDockedOpen = false;
      _storiesAnimClosing = false;
      _storiesOverscrollRevealArmed = false;
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _deferReloads = true;
  }

  @override
  void didPopNext() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _deferReloads = false;
      if (_reloadQueued) {
        _reloadQueued = false;
        _reloadChatsAndFolders();
      }
    });
  }

  void _requestReload() {
    if (!mounted) return;
    if (_deferReloads) {
      _reloadQueued = true;
      return;
    }
    _reloadChatsAndFolders();
  }

  void _onChatsChanged() {
    _requestReload();
  }

  Future<void> _reloadChatsAndFolders() async {
    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      _syncFolderChatScrollControllersForCount(1);
      if (mounted) {
        setState(() {
          _folders = [];
          _selectedFolderId = null;
          _foldersListKnown = null;
          _isInitialLoading = false;
        });
      }
      return;
    }

    try {
      final chats = await ChatsModule.getChats(p.id);
      var folders = await FoldersModule.loadFolders(p.id);
      final foldersKnown = await FoldersModule.hasReceivedFoldersList(p.id);

      final allChatsFolder = ChatFolder(
        id: 'all.chat.folder',
        title: 'Все чаты',
        filters: [],
        hideEmpty: false,
        widgets: [],
      );

      if (!folders.any((f) => FoldersModule.isAllChatsFolder(f))) {
        folders = [allChatsFolder, ...folders];
      }

      final pageCount = folders.isEmpty ? 1 : folders.length;
      _syncFolderChatScrollControllersForCount(pageCount);
      if (mounted) {
        setState(() {
          _profile = p;
          _chats = chats
              .where((c) => !CloudStorageModule.isCloudStorageGroup(c))
              .toList();
          _folders = folders;
          _foldersListKnown = foldersKnown;
          if (_selectedFolderId != null &&
              !_folders.any((f) => f.id == _selectedFolderId)) {
            _selectedFolderId = null;
          }
          if (_folders.isNotEmpty) {
            final preferred = FoldersModule.preferredInitialFolderId(_folders);
            if (_selectedFolderId == null ||
                !_folders.any((f) => f.id == _selectedFolderId)) {
              _selectedFolderId = preferred;
            }
          } else {
            _selectedFolderId = null;
          }
          _isInitialLoading = false;
        });
        _prefetchContactsForChats(chats);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _jumpFolderPageToSelection();
        });
      }
    } catch (_) {
      _syncFolderChatScrollControllersForCount(1);
      if (mounted) {
        setState(() {
          _folders = [];
          _selectedFolderId = null;
          _foldersListKnown = null;
          _isInitialLoading = false;
        });
      }
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _jumpFolderPageToSelection();
        });
      }
    }
  }

  bool get _showFoldersShimmer {
    if (_profile == null) return false;
    if (_foldersListKnown != false) return false;
    return _sessionState != SessionState.disconnected;
  }

  int get _folderPageCount => _folders.isEmpty ? 1 : _folders.length;

  int get _selectedFolderIndex {
    if (_folders.isEmpty) return 0;
    final i = _folders.indexWhere((f) => f.id == _selectedFolderId);
    if (i >= 0) return i;
    return 0;
  }

  int _folderIndexForId(String? id) {
    if (_folders.isEmpty) return 0;
    if (id == null) return 0;
    final i = _folders.indexWhere((f) => f.id == id);
    if (i >= 0) return i;
    final pref = FoldersModule.preferredInitialFolderId(_folders);
    if (pref != null) {
      final j = _folders.indexWhere((f) => f.id == pref);
      if (j >= 0) return j;
    }
    return 0;
  }

  void _prefetchContactsForChats(List<CachedChat> chats) {
    final myId = _profile?.id;
    final ids = <int>{};
    for (final chat in chats) {
      if (chat.type == 'DIALOG' && chat.id != 0) {
        for (final entry in chat.participants.entries) {
          if (entry.key != myId) {
            ids.add(entry.key);
            break;
          }
        }
      }
      final senderId = chat.lastMsgSenderId;
      if (senderId != null) ids.add(senderId);
    }
    ids.removeWhere((id) => ContactCache.get(id) != null);
    ids.removeAll(_inflightContactIds);
    if (ids.isEmpty) return;
    _inflightContactIds.addAll(ids);
    for (final id in ids) {
      messagesModule.searchContactById(id).whenComplete(() {
        _inflightContactIds.remove(id);
        _scheduleContactRebuild();
      });
    }
  }

  void _scheduleContactRebuild() {
    if (!mounted) return;
    _contactRebuildTimer?.cancel();
    _contactRebuildTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _cachedChatsBody = null;
      setState(() {});
    });
  }

  int? _pageChatsBaseKey;
  final Map<int, List<CachedChat>> _pageChatsCache = {};

  List<CachedChat> _chatsForPageIndex(int pageIndex) {
    final baseKey = Object.hash(
      identityHashCode(_chats),
      identityHashCode(_folders),
    );
    if (_pageChatsBaseKey != baseKey) {
      _pageChatsBaseKey = baseKey;
      _pageChatsCache.clear();
    }
    final cached = _pageChatsCache[pageIndex];
    if (cached != null) return cached;

    List<CachedChat> base;
    if (_folders.isEmpty) {
      base = _chats;
    } else if (pageIndex < 0 || pageIndex >= _folders.length) {
      base = _chats;
    } else {
      final folder = _folders[pageIndex];
      base = FoldersModule.isAllChatsFolder(folder)
          ? _chats
          : _chats
                .where((c) => FoldersModule.chatMatchesFolder(c, folder))
                .toList();
    }
    final pinned = base.where((c) => (c.favIndex ?? 0) > 0).toList()
      ..sort((a, b) => a.favIndex!.compareTo(b.favIndex!));
    final regular = base.where((c) => (c.favIndex ?? 0) <= 0).toList();
    final result = [...pinned, ...regular];
    _pageChatsCache[pageIndex] = result;
    return result;
  }

  void _syncFolderChatScrollControllers() {
    _syncFolderChatScrollControllersForCount(_folderPageCount);
  }

  void _syncFolderChatScrollControllersForCount(int n) {
    while (_folderChatScrollControllers.length < n) {
      final i = _folderChatScrollControllers.length;
      void fn() => _onFolderChatScrollAt(i);
      final c = ScrollController();
      c.addListener(fn);
      _folderChatScrollControllers.add(c);
      _folderChatScrollListenerFns.add(fn);
    }
    while (_folderChatScrollControllers.length > n) {
      final c = _folderChatScrollControllers.removeLast();
      final fn = _folderChatScrollListenerFns.removeLast();
      c.removeListener(fn);
      c.dispose();
    }
  }

  bool _isChatScrollControllerActive(int index) {
    if (_folderPageCount <= 1) return index == 0;
    if (!_folderPageController.hasClients) {
      return index == _selectedFolderIndex;
    }
    final p = _folderPageController.page;
    if (p == null) return index == _selectedFolderIndex;
    final r = p.round().clamp(0, _folderPageCount - 1);
    return r == index;
  }

  void _onFolderChatScrollAt(int index) {
    if (!_isChatScrollControllerActive(index)) return;
    if (index < 0 || index >= _folderChatScrollControllers.length) return;
    final c = _folderChatScrollControllers[index];
    _applyChatScrollOffset(c);
  }

  void _applyChatScrollOffset(ScrollController c) {
    if (!c.hasClients) return;
    final double offset = c.offset;
    if (_isSelectionMode && !_shouldCollapseSearch && offset < 132) {
      _shouldCollapseSearch = true;
      _storiesUi.notify();
    }

    if (offset < 0) {
      if (!_allowStoriesPullOverscrollTop()) {
        return;
      }
      final dragRatio = (offset.abs() / 80.0).clamp(0.0, 1.0);
      if (_storiesRevealController.isAnimating) {
        return;
      }
      if (!_storiesDockedOpen && offset.abs() >= _kStoriesPullTriggerPx) {
        _startStoriesAutoReveal(dragRatio);
      } else if (!_storiesDockedOpen) {
        if (dragRatio != _pullRatio) {
          _pullRatio = dragRatio;
          _storiesUi.notify();
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
      final disarm = offset > 3 && _storiesOverscrollRevealArmed;
      final clearPull = _pullRatio > 0;
      if (disarm || clearPull) {
        if (disarm) _storiesOverscrollRevealArmed = false;
        if (clearPull) _pullRatio = 0.0;
        _storiesUi.notify();
      }
    }
  }

  ScrollController? _activeChatScrollController() {
    if (_folderChatScrollControllers.isEmpty) return null;
    if (!_folderPageController.hasClients) {
      return _folderChatScrollControllers.first;
    }
    final p = _folderPageController.page;
    final i = (p != null ? p.round() : _selectedFolderIndex).clamp(
      0,
      _folderChatScrollControllers.length - 1,
    );
    return _folderChatScrollControllers[i];
  }

  void _jumpFolderPageToSelection() {
    if (!_folderPageController.hasClients) return;
    final target = _folderIndexForId(_selectedFolderId);
    final current = _folderPageController.page?.round();
    if (current != target) {
      _folderPageController.jumpToPage(target);
    }
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null || timestamp == 0) return '';
    return formatClock(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Widget _buildChatShimmer() {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + 0.3 * sin(_shimmerController.value * pi * 2);
        return Opacity(opacity: opacity, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
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

  void _onStoriesRevealTick() {
    if (!mounted) return;
    final t = Curves.easeOutCubic.transform(_storiesRevealController.value);
    if (_storiesAnimClosing) {
      _pullRatio = _closeAnimBegin * (1.0 - t);
    } else {
      _pullRatio = _revealAnimBegin + (1.0 - _revealAnimBegin) * t;
    }
    _storiesUi.notify();
  }

  void _onStoriesRevealStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      if (_storiesAnimClosing) {
        _pullRatio = 0.0;
        _storiesDockedOpen = false;
        _storiesAnimClosing = false;
        _storiesOverscrollRevealArmed = true;
      } else {
        _pullRatio = 1.0;
        _storiesDockedOpen = true;
        _storiesRevealLayoutSettleUntil = DateTime.now().add(
          const Duration(milliseconds: 520),
        );
      }
      _storiesUi.notify();
    }
  }

  void _startStoriesAutoReveal(double suggestedFrom) {
    if (_storiesRevealController.isAnimating && !_storiesAnimClosing) return;
    if (_storiesDockedOpen) return;
    _storiesRevealController.stop();
    _storiesAnimClosing = false;
    final from = max(_pullRatio, suggestedFrom.clamp(0.0, 1.0));
    if (from >= 1.0) {
      _pullRatio = 1.0;
      _storiesDockedOpen = true;
      _storiesUi.notify();
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
    _storiesLockdownUntil = DateTime.now().add(
      const Duration(milliseconds: 800),
    );
    _storiesRevealController.stop();
    _storiesAnimClosing = true;
    final from = _pullRatio.clamp(0.0, 1.0);
    if (from <= 0) {
      _pullRatio = 0.0;
      _storiesDockedOpen = false;
      _storiesAnimClosing = false;
      _storiesOverscrollRevealArmed = true;
      _storiesUi.notify();
      return;
    }
    _closeAnimBegin = from;
    _storiesRevealController.duration = Duration(
      milliseconds: (260 + 240 * from).round(),
    );
    _storiesRevealController.reset();
    _storiesRevealController.forward(from: 0);
  }

  bool _handleStoriesScrollNotification(ScrollNotification n) {
    if (_currentNavIndex != 0) return false;

    if (n is ScrollEndNotification) {
      if (n.metrics.pixels <= 0.5) {
        _storiesOverscrollRevealArmed = true;
        _storiesUi.notify();
      }
      return false;
    }

    if (n is OverscrollNotification && n.overscroll > 0) {
      if ((_storiesDockedOpen ||
              _storiesRevealController.isAnimating ||
              _pullRatio > 0) &&
          !_storiesAnimClosing &&
          DateTime.now().isAfter(_storiesRevealLayoutSettleUntil)) {
        _startStoriesAutoClose();
      }
      return false;
    }

    if (n is! ScrollUpdateNotification) return false;
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

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _settleTimer?.cancel();
    ChatsModule.chatsChanged.removeListener(_onChatsChanged);
    AppStories.current.removeListener(_onStoriesEnabledChanged);
    _loginSub?.cancel();
    _stateSub?.cancel();
    _fabController.dispose();
    _navPageAnimController.dispose();
    _storiesRevealController
      ..removeListener(_onStoriesRevealTick)
      ..removeStatusListener(_onStoriesRevealStatus)
      ..dispose();
    _shimmerController.dispose();
    _folderPageController.dispose();
    while (_folderChatScrollControllers.isNotEmpty) {
      final c = _folderChatScrollControllers.removeLast();
      final fn = _folderChatScrollListenerFns.removeLast();
      c.removeListener(fn);
      c.dispose();
    }
    _contactRebuildTimer?.cancel();
    _storiesUi.dispose();
    _navDragDx.dispose();
    super.dispose();
  }

  double _effectivePageNavRowT({
    required double inactiveWidth,
    required double Function(int index) bubbleLeftForIndex,
  }) {
    if (_navDragging) {
      final left = (_navDragBaseLeft + _navDragDx.value).clamp(
        bubbleLeftForIndex(0),
        bubbleLeftForIndex(3),
      );
      return ((left - 4) / inactiveWidth).clamp(0.0, 3.0);
    }
    if (_navPageAnimController.isAnimating) {
      final t = Curves.easeOutCubic.transform(_navPageAnimController.value);
      return ui.lerpDouble(_navPageAnimStart, _navPageAnimEnd, t)!;
    }
    return _currentNavIndex.toDouble();
  }

  void _onNavTabSelected(int index) {
    if (index == _currentNavIndex && !_navPageAnimController.isAnimating) {
      return;
    }
    // Detent "click" when crossing into a different tab.
    Haptics.selection();
    double fromT;
    if (_navPageAnimController.isAnimating) {
      final t = Curves.easeOutCubic.transform(_navPageAnimController.value);
      fromT = ui.lerpDouble(_navPageAnimStart, _navPageAnimEnd, t)!;
    } else {
      fromT = _currentNavIndex.toDouble();
    }
    _navPageAnimStart = fromT;
    _navPageAnimEnd = index.toDouble();
    setState(() => _currentNavIndex = index);
    _navPageAnimController.forward(from: 0);
  }

  void _toggleFab() {
    Haptics.tap();
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  Widget _buildPinnedChatsHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _storiesUi,
            builder: (context, _) => ClipRect(
              clipBehavior: Clip.hardEdge,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _shouldCollapseSearch
                    ? const SizedBox(width: double.infinity, height: 52)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 6, 20, 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (AppStories.current.value &&
                                        _pullRatio < 0.8)
                                      Opacity(
                                        opacity: 1.0 - _pullRatio,
                                        child: Container(
                                          width: 50 * (1.0 - _pullRatio),
                                          height: 32,
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Stack(
                                            children: [
                                              _buildFoldedStory(
                                                cs,
                                                'https://i.pravatar.cc/150?u=dasha',
                                                0,
                                              ),
                                              _buildFoldedStory(
                                                cs,
                                                'https://i.pravatar.cc/150?u=mastika',
                                                1,
                                              ),
                                              _buildFoldedStory(
                                                cs,
                                                'https://i.pravatar.cc/150?u=stas',
                                                2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Text(
                                      _sessionState == SessionState.online
                                          ? (_profile?.firstName ?? 'Чат')
                                          : 'Подключение...',
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
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
                                    borderRadius: BorderRadius.circular(16),
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
                          if (AppStories.current.value)
                            SizedBox(
                              height: 96 * _pullRatio,
                              child: Opacity(
                                opacity: _pullRatio,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 3, 20, 8),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(50),
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
                                        contentPadding: EdgeInsets.zero,
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
          if (_folders.length > 1)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 34,
              color: cs.surface,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    ui.PointerDeviceKind.touch,
                    ui.PointerDeviceKind.mouse,
                    ui.PointerDeviceKind.trackpad,
                  },
                ),
                child: _showFoldersShimmer
                    ? _buildFolderStripShimmer(cs)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth - 40;
                          final folderCount = _folders.length;
                          final minWidthPerFolder = 80.0;
                          final totalMinWidth =
                              folderCount * minWidthPerFolder +
                              (folderCount - 1) * 8;
                          final needsScroll = totalMinWidth > availableWidth;

                          if (needsScroll) {
                            return ListView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                for (var i = 0; i < _folders.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _buildFolderChip(
                                    _folderChipLabel(_folders[i]),
                                    folderId: _folders[i].id,
                                  ),
                                ],
                              ],
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  for (var i = 0; i < _folders.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildFolderChip(
                                        _folderChipLabel(_folders[i]),
                                        folderId: _folders[i].id,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }
                        },
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderChatPage(int pageIndex) {
    final chats = _chatsForPageIndex(pageIndex);
    final sc = _folderChatScrollControllers[pageIndex];
    final cs = Theme.of(context).colorScheme;
    final pinnedCount = _isInitialLoading
        ? 0
        : chats.where((c) => (c.favIndex ?? 0) > 0).length;
    final hasSeparator = pinnedCount > 0 && pinnedCount < chats.length;
    final totalItems = _isInitialLoading
        ? 10
        : chats.length + (hasSeparator ? 1 : 0);
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (_currentNavIndex != 0) return false;
        if (!_folderPageController.hasClients) {
          if (pageIndex != _selectedFolderIndex) return false;
        } else {
          final p = _folderPageController.page;
          if (p == null) {
            if (pageIndex != _selectedFolderIndex) return false;
          } else {
            final r = p.round().clamp(0, _folderPageCount - 1);
            if (r != pageIndex) return false;
          }
        }
        return _handleStoriesScrollNotification(n);
      },
      child: CustomScrollView(
        controller: sc,
        physics: _StoriesScrollPhysics(
          blockPositive: _shouldBlockPositiveScroll,
          allowPullOverscrollTop: _allowStoriesPullOverscrollTop,
          parent: const AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (chats.isEmpty && !_isInitialLoading)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Кажется, тут пусто...',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (_isInitialLoading) {
                  return _buildChatShimmer();
                }

                if (hasSeparator && index == pinnedCount) {
                  return Padding(
                    key: const ValueKey('pinned_divider'),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  );
                }

                final chatIndex = hasSeparator && index > pinnedCount
                    ? index - 1
                    : index;
                final chat = chats[chatIndex];
                final isPinned = (chat.favIndex ?? 0) > 0;

                if (chat.type.isNotEmpty &&
                    chat.type == "DIALOG" &&
                    chat.id != 0) {
                  int secondId = _profile?.id ?? 0;
                  for (final entry in chat.participants.entries) {
                    if (entry.key != _profile?.id) {
                      secondId = entry.key;
                      break;
                    }
                  }
                  final name = ContactCache.get(secondId);
                  final avatar = ContactCache.getAvatar(secondId);
                  // ContactCache.isOfficial covers contacts loaded via opcode 32;
                  // chat.isOfficial covers contacts from the login payload.
                  final isVerified =
                      ContactCache.isOfficial(secondId) || chat.isOfficial;

                  final isPlaceholder =
                      chat.lastMsgText == ChatsModule.lastMsgPlaceholder;
                  final previewText = isPlaceholder
                      ? 'зайдите в чат для подгрузки'
                      : (chat.lastMsgTextOneLine ?? '');
                  return _buildChatItem(
                    chat.id.toString(),
                    name ?? "Пользователь",
                    previewText,
                    _formatTime(chat.lastMsgTime),
                    avatar ?? "",
                    isOnline: chat.isOnline,
                    unreadCount: chat.unreadCount,
                    isMuted: chat.isMuted,
                    isVerified: isVerified,
                    isPinned: isPinned,
                    chatType: "DIALOG",
                    messageItalic: isPlaceholder,
                  );
                } else {
                  final isPlaceholder =
                      chat.lastMsgText == ChatsModule.lastMsgPlaceholder;
                  final sender = chat.lastMsgSenderId != null
                      ? ContactCache.get(chat.lastMsgSenderId!)
                      : null;

                  String fullMsg = "";
                  if (isPlaceholder) {
                    fullMsg = 'зайдите в чат для подгрузки';
                  } else {
                    if (sender?.isNotEmpty == true && chat.id != 0) {
                      fullMsg += "$sender: ";
                    }
                    if (chat.lastMsgText?.isNotEmpty == true) {
                      fullMsg += chat.lastMsgText ?? "";
                    }
                  }

                  return _buildChatItem(
                    chat.id.toString(),
                    chat.id == 0 ? "Избранное" : chat.title ?? "Чат",
                    fullMsg,
                    _formatTime(chat.lastMsgTime),
                    (chat.iconUrl != null && chat.iconUrl!.isNotEmpty)
                        ? chat.iconUrl!
                        : '',
                    isOnline: chat.isOnline,
                    unreadCount: chat.unreadCount,
                    isMuted: chat.isMuted,
                    isVerified: chat.isOfficial,
                    isPinned: isPinned,
                    chatType: chat.type,
                    messageItalic: isPlaceholder,
                  );
                }
              }, childCount: totalItems),
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTabBody() {
    return Listener(
      onPointerDown: (_) {
        _storiesLockdownUntil = DateTime.fromMillisecondsSinceEpoch(0);
      },
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (_shouldBlockPositiveScroll() &&
              pointerSignal.scrollDelta.dy > 0) {
            _storiesLockdownUntil = DateTime.now().add(
              const Duration(milliseconds: 300),
            );
          }
          final ac = _activeChatScrollController();
          if (ac != null && ac.hasClients && ac.offset <= 0) {
            if (pointerSignal.scrollDelta.dy < 0) {
              if (_allowStoriesPullOverscrollTop()) {
                _startStoriesAutoReveal(max(_pullRatio, 0.18));
              }
            } else if (pointerSignal.scrollDelta.dy > 0 && _pullRatio > 0) {
              _startStoriesAutoClose();
            }
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPinnedChatsHeader(context),
          Expanded(
            child: PageView.builder(
              controller: _folderPageController,
              physics: _folderPageCount <= 1
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              onPageChanged: (i) {
                if (_folders.isEmpty) return;
                if (i < 0 || i >= _folders.length) return;
                setState(() {
                  _selectedFolderId = _folders[i].id;
                });
              },
              itemCount: _folderPageCount,
              itemBuilder: (context, pageIndex) {
                return _buildFolderChatPage(pageIndex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockedBottomNav(
    ColorScheme cs,
    double navInnerW,
    double bottomInset,
  ) {
    final geometry = PillNavGeometry.fromInnerWidth(navInnerW, 4);
    final inactiveWidth = geometry.inactiveWidth;
    final bubbleW = geometry.activeWidth - 8;

    double bubbleLeftForIndex(int index) => index * inactiveWidth + 4;

    final minBubbleLeft = bubbleLeftForIndex(0);
    final maxBubbleLeft = bubbleLeftForIndex(3);

    int indexForBubbleLeft(double left) {
      final cx = left + bubbleW / 2;
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < 4; i++) {
        final c = bubbleLeftForIndex(i) + bubbleW / 2;
        final d = (c - cx).abs();
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      return best;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: 8,
      right: 8,
      bottom: _isSelectionMode ? -100 : bottomInset + 10.0,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            if (_isSelectionMode) return;
            _navPageAnimController.stop();
            _navPageAnimController.value = 1.0;
            _navDragDx.value = 0;
            setState(() {
              _navDragging = true;
              _navDragBaseLeft = bubbleLeftForIndex(_currentNavIndex);
            });
          },
          onHorizontalDragUpdate: (details) {
            if (!_navDragging) return;
            _navDragDx.value += details.delta.dx;
          },
          onHorizontalDragEnd: (_) {
            if (!_navDragging) return;
            final left = (_navDragBaseLeft + _navDragDx.value).clamp(
              minBubbleLeft,
              maxBubbleLeft,
            );
            final next = indexForBubbleLeft(left);
            _navDragDx.value = 0;
            setState(() {
              _currentNavIndex = next;
              _navDragging = false;
            });
          },
          onHorizontalDragCancel: () {
            if (!_navDragging) return;
            _navDragDx.value = 0;
            setState(() {
              _navDragging = false;
            });
          },
          child: ValueListenableBuilder<double>(
            valueListenable: _navDragDx,
            builder: (context, navDragDx, _) {
              final position = _navDragging
                  ? ((_navDragBaseLeft + navDragDx).clamp(
                              minBubbleLeft,
                              maxBubbleLeft,
                            ) -
                            4) /
                        inactiveWidth
                  : _currentNavIndex.toDouble();
              return SlidingPillNav(
                items: _chatsNavItems,
                position: position,
                animationDuration: _navDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                geometry: geometry,
                iconSize: 20,
                labelGap: 4,
                onTap: _onNavTabSelected,
                onItemLongPress: (index, pos) {
                  if (index == 3) _openAccountSwitcher(pos);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
            final pageW = constraints.maxWidth;
            final pageH = constraints.maxHeight;
            final navInnerW = pageW - 20;
            final totalWeight = 5.2;
            final unitWidth = navInnerW / totalWeight;
            final inactiveWidth = unitWidth * 1.0;
            double bubbleLeftForPageT(int index) {
              double lo = 0;
              for (int i = 0; i < index; i++) {
                lo += inactiveWidth;
              }
              return lo + 4;
            }

            return Stack(
              children: [
                ClipRect(
                  child: SizedBox(
                    width: pageW,
                    height: pageH,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: pageW * 4,
                      maxHeight: pageH,
                      child: SizedBox(
                        width: pageW * 4,
                        height: pageH,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _navPageAnimController,
                            _navDragDx,
                          ]),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RepaintBoundary(
                                child: SizedBox(
                                  width: pageW,
                                  height: pageH,
                                  child: _getChatsBody(),
                                ),
                              ),
                              RepaintBoundary(
                                child: SizedBox(
                                  width: pageW,
                                  height: pageH,
                                  child: const CallsTab(),
                                ),
                              ),
                              RepaintBoundary(
                                child: SizedBox(
                                  width: pageW,
                                  height: pageH,
                                  child: const ContactsTab(),
                                ),
                              ),
                              RepaintBoundary(
                                child: SizedBox(
                                  width: pageW,
                                  height: pageH,
                                  child: const SettingsTab(),
                                ),
                              ),
                            ],
                          ),
                          builder: (context, child) {
                            final pageDisplayT = _effectivePageNavRowT(
                              inactiveWidth: inactiveWidth,
                              bubbleLeftForIndex: bubbleLeftForPageT,
                            );
                            return Transform.translate(
                              offset: Offset(-pageDisplayT * pageW, 0),
                              child: child,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                _buildDockedBottomNav(cs, navInnerW, bottomInset),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _fabController,
                    _navPageAnimController,
                  ]),
                  builder: (context, _) {
                    final pageDisplayT = _effectivePageNavRowT(
                      inactiveWidth: inactiveWidth,
                      bubbleLeftForIndex: bubbleLeftForPageT,
                    );
                    final showChatsFab =
                        !_isSelectionMode &&
                        (_navDragging || _navPageAnimController.isAnimating
                            ? pageDisplayT < 1.0
                            : _currentNavIndex == 0);
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
                                color: Colors.black.withValues(
                                  alpha: val * 0.2,
                                ),
                              ),
                            ),
                          ),
                        if (showChatsFab) ...[
                          if (_fabController.value > 0)
                            Positioned(
                              right: 20,
                              bottom: bottomInset + 90 + 74,
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
                            bottom: bottomInset + 90,
                            child: FloatingActionButton(
                              onPressed: _toggleFab,
                              backgroundColor: cs.primaryContainer,
                              elevation: 4,
                              shape: const CircleBorder(),
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
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Builder(
                      builder: (_) {
                        final selected = _selectedChatObjects();
                        final deleteCategory = _selectionDeleteCategoryFor(
                          selected,
                        );
                        final anyMuted = selected.any((c) => c.isMuted);
                        final anyPinned = selected.any(
                          (c) => (c.favIndex ?? 0) > 0,
                        );
                        return Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Symbols.arrow_back,
                                color: cs.onSurface,
                              ),
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
                            if (deleteCategory != null)
                              IconButton(
                                icon: Icon(Symbols.delete, color: cs.onSurface),
                                onPressed: _onDeleteTap,
                              ),
                            IconButton(
                              icon: Icon(Symbols.archive, color: cs.onSurface),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: Icon(
                                anyPinned ? Symbols.keep_off : Symbols.keep,
                                color: cs.onSurface,
                              ),
                              onPressed: selected.isEmpty ? null : _onPinTap,
                            ),
                            IconButton(
                              icon: Icon(
                                anyMuted
                                    ? Symbols.volume_up
                                    : Symbols.volume_off,
                                color: cs.onSurface,
                              ),
                              onPressed: selected.isEmpty ? null : _onMuteTap,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
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
                  backgroundImage: CachedNetworkImageProvider(
                    imageUrl,
                    maxWidth: 144,
                    maxHeight: 144,
                  ),
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

  String _folderChipLabel(ChatFolder f) {
    final e = f.emoji;
    if (e != null && e.isNotEmpty) return '$e ${f.title}';
    return f.title;
  }

  Widget _buildFolderStripShimmer(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + 0.3 * sin(_shimmerController.value * pi * 2);
        return Opacity(
          opacity: opacity,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            physics: const BouncingScrollPhysics(),
            children: [
              _folderShimmerPill(cs, 88),
              const SizedBox(width: 8),
              _folderShimmerPill(cs, 72),
              const SizedBox(width: 8),
              _folderShimmerPill(cs, 96),
              const SizedBox(width: 8),
              _folderShimmerPill(cs, 64),
              const SizedBox(width: 8),
              _folderShimmerPill(cs, 80),
            ],
          ),
        );
      },
    );
  }

  Widget _folderShimmerPill(ColorScheme cs, double width) {
    return Container(
      width: width,
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildFolderChip(String title, {required String folderId}) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedFolderId == folderId;
    return GestureDetector(
      onTap: () {
        final target = _folders.indexWhere((f) => f.id == folderId);
        if (target < 0) return;
        setState(() => _selectedFolderId = folderId);
        if (_folderPageController.hasClients) {
          final cur = _folderPageController.page?.round() ?? 0;
          if (cur == target) return;
          if ((target - cur).abs() > 1) {
            final neighbor = target > cur ? target - 1 : target + 1;
            _folderPageController.jumpToPage(neighbor);
          }
          _folderPageController.animateToPage(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? cs.onPrimaryContainer : cs.primary,
            fontSize: 13,
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
    bool isVerified = false,
    bool isPinned = false,
    String chatType = "CHAT",
    bool messageItalic = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedChats.contains(id);

    return InkWell(
      key: ValueKey('chat_$id'),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(id);
          return;
        }
        if (imageUrl.isNotEmpty) {
          unawaited(
            precacheImage(
              CachedNetworkImageProvider(
                imageUrl,
                maxWidth: 144,
                maxHeight: 144,
              ),
              context,
            ),
          );
        }
        if (widget.onChatSelected != null) {
          widget.onChatSelected!(
            DesktopChatSelection(
              chatId: int.parse(id),
              name: name,
              imageUrl: imageUrl,
              chatType: chatType,
            ),
          );
        } else {
          pushSwipeable(
            context,
            (context) => ChatScreen(
              chatId: int.parse(id),
              name: name,
              imageUrl: imageUrl,
              chatType: chatType,
            ),
          );
        }
      },
      onLongPress: () => _toggleSelection(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isSelected
            ? cs.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.surfaceContainerHighest,
                    backgroundImage: imageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(
                            imageUrl,
                            maxWidth: 144,
                            maxHeight: 144,
                          )
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
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: cs.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Symbols.verified,
                                      color: cs.primary,
                                      size: 16,
                                      weight: 600,
                                      fill: 1,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isMuted) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Symbols.notifications_off,
                                color: cs.outlineVariant,
                                size: 14,
                                weight: 400,
                              ),
                            ],
                            if (isPinned) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Symbols.keep,
                                color: cs.outlineVariant,
                                size: 14,
                                weight: 400,
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              time,
                              style: TextStyle(color: cs.outline, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: isTyping ? cs.primary : cs.outline,
                                  fontSize: 14,
                                  fontWeight: isTyping
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  fontStyle: messageItalic
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
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
                                    height: 1.1,
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

  void _openAccountSwitcher(Offset point) {
    Haptics.medium();
    final controller = AccountSwitcherController()..attach(point);
    showAccountSwitcher(
      context: context,
      tapPoint: point,
      controller: controller,
      onSelected: (accountId) async {
        controller.dispose();
        if (!mounted) return;
        if (accountId == null) {
          final previousId = await TokenStorage.getActiveAccountId();
          try {
            await accountModule.beginAddAccount();
          } catch (_) {}
          if (!mounted) return;
          await Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LoginScreen(returnToAccountId: previousId),
            ),
            (route) => false,
          );
          return;
        }
        try {
          await accountModule.switchAccount(accountId);
        } catch (e) {
          if (!mounted) return;
          showCustomNotification(context, 'Не удалось переключить аккаунт');
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdaptiveShell()),
          (route) => false,
        );
      },
    );
  }

  Widget _buildFabMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildFabMenuItem(
          Symbols.group_add,
          'Создать группу',
          onTap: () {
            _toggleFab();
            showCreateGroupFlow(context);
          },
        ),
        const SizedBox(height: 4),
        _buildFabMenuItem(Symbols.campaign, 'Создать канал'),
        const SizedBox(height: 4),
        _buildFabMenuItem(Symbols.person_add, 'Создать контакт'),
      ],
    );
  }

  Widget _buildFabMenuItem(IconData icon, String title, {VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
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

  Widget _buildFoldedStory(ColorScheme cs, String imageUrl, int index) {
    return Positioned(
      left: index * 12.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.surface, width: 2),
        ),
        child: CircleAvatar(
          radius: 12,
          backgroundImage: CachedNetworkImageProvider(
            imageUrl,
            maxWidth: 144,
            maxHeight: 144,
          ),
        ),
      ),
    );
  }
}

class _StoriesUi extends ChangeNotifier {
  double pullRatio = 0.0;
  bool dockedOpen = false;
  bool overscrollRevealArmed = true;
  bool shouldCollapseSearch = false;

  void notify() => notifyListeners();
}
