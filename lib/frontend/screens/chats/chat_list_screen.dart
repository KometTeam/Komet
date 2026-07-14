import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'create_group_flow.dart';
import '../../widgets/adaptive_shell.dart';
import '../../widgets/online_dot.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/swipe_route.dart';
import '../../widgets/sliding_pill_nav.dart';
import '../../widgets/springy_tap.dart';
import '../../widgets/formatted_message_text.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/text_format.dart';

import '../calls/calls_tab.dart';
import '../contacts/contacts_tab.dart';
import '../profile/settings_tab.dart';
import '../auth/login_screen.dart';
import '../digital_id/digital_id_web_screen.dart';
import '../../widgets/account_switcher_overlay.dart';
import 'chat/view/chat_list_shimmer.dart';
import 'chat/view/chat_list_tile.dart';
import '../../widgets/connection_status.dart';
import '../../../backend/api.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/config/app_animations.dart';
import '../../../core/config/app_frost.dart';
import '../../../core/config/app_nav_pill_style.dart';
import '../../../core/config/app_visual_style.dart';
import '../../../core/config/app_stories.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/komet_settings.dart';
import '../../../backend/models/chat_folder.dart';
import '../../../backend/modules/account.dart';
import '../../../backend/modules/chats.dart';
import '../../../backend/modules/cloud_storage.dart';
import '../../../backend/modules/contacts.dart';
import '../../../backend/modules/folders.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/draft_store.dart';
import '../../../core/storage/archived_chats_store.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/chat_activity_store.dart';
import '../../../main.dart'
    show accountModule, api, messagesModule, storiesModule, appRouteObserver;
import '../../widgets/attachment/attachment_sheet.dart';
import '../stories/story_composer_screen.dart';
import '../stories/story_owner_info.dart';
import '../stories/story_ring.dart';
import '../stories/story_viewer_screen.dart';

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

class ForwardTarget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  const ForwardTarget({
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });
}

Future<ForwardTarget?> openForwardScreen({
  required BuildContext context,
  int messageCount = 1,
}) {
  return pushSwipeable<ForwardTarget>(
    context,
    (_) => ChatListScreen(forwardMode: true, forwardMessageCount: messageCount),
  );
}

class ChatListScreen extends StatefulWidget {
  final ValueChanged<DesktopChatSelection>? onChatSelected;
  final bool forwardMode;
  final int forwardMessageCount;
  final bool archiveMode;

  const ChatListScreen({
    super.key,
    this.onChatSelected,
    this.forwardMode = false,
    this.forwardMessageCount = 1,
    this.archiveMode = false,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

enum _DeleteKind { personalLike, ownerGroup, blocked }

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin, RouteAware {
  String? _selectedFolderId;

  List<ChatFolder> _folders = [];
  Set<int> _contactIds = <int>{};

  int _currentNavIndex = 0;

  static const List<PillNavItem> _chatsNavItems = [
    PillNavItem(icon: Symbols.chat_bubble, label: 'Чаты'),
    PillNavItem(icon: Symbols.call, label: 'Звонки'),
    PillNavItem(icon: Symbols.person_pin, label: 'Контакты'),
    PillNavItem(
      icon: Symbols.settings,
      label: 'Настройки',
      longPressable: true,
      animationAsset: AppAnimations.settings,
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
  bool _reloadInFlight = false;
  Timer? _settleTimer;
  bool get _isSelectionMode => _selectedChats.isNotEmpty;
  bool? _foldersListKnown;

  late AnimationController _navPageAnimController;
  late AnimationController _fabController;
  final BackdropKey _frostBackdrop = BackdropKey();
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
  int _archivedCount = 0;
  int _archivedUnread = 0;
  bool _archiveHadChats = false;

  int _chatListRevision = 0;
  final Set<String> _knownChatIds = {};
  bool _didInitialChatLoad = false;
  Set<String> _enteringChatIds = {};

  SessionState _sessionState = SessionState.disconnected;

  StreamSubscription? _stateSub;
  StreamSubscription<LoginStatus>? _loginSub;
  StreamSubscription<Packet>? _typingSub;
  StreamSubscription<MessageEvent>? _typingMsgSub;

  Widget? _cachedChatsBody;
  Object? _chatsBodyCacheKey;

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
    final err = await chats.togglePin(
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
      final err = await chats.setChatMute(
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

  Future<void> _onArchiveTap() async {
    final selected = _selectedChatObjects();
    if (selected.isEmpty) return;
    final p = _profile;
    if (p == null) return;
    final archive = !widget.archiveMode;
    for (final c in selected) {
      await ArchivedChatsStore.instance.setArchived(p.id, c.id, archive);
    }
    if (!mounted) return;
    _clearSelection();
    final count = selected.length;
    showCustomNotification(
      context,
      archive
          ? (count == 1 ? 'Чат в архиве' : 'Чаты в архиве ($count)')
          : (count == 1 ? 'Чат возвращён' : 'Чаты возвращены ($count)'),
    );
  }

  Future<void> _onDeleteTap() async {
    final selectedBefore = _selectedChatObjects();
    if (selectedBefore.isEmpty) return;
    final myId = _profile?.id;
    if (myId == null) return;

    await chats.refreshChats(api, selectedBefore.map((c) => c.id).toList());
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
      final err = await chats.deleteChat(
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
          _maybeLoadStories();
        }
      }
    });

    _loginSub = accountModule.loginStatusStream.listen((status) {
      if (status == LoginStatus.success) {
        _requestReload();
        _maybeLoadStories();
      }
    });
    chats.chatsChanged.addListener(_onChatsChanged);
    ArchivedChatsStore.instance.revision.addListener(_onArchivedChanged);
    DraftStore.instance.revision.addListener(_onDraftsChanged);
    AppStories.current.addListener(_onStoriesEnabledChanged);
    storiesModule.storiesChanged.addListener(_onStoriesDataChanged);
    KometSettings.hideAllChatsFolder.addListener(_requestReload);
    KometSettings.showHiddenChats.addListener(_requestReload);
    _maybeLoadStories();
    _typingSub = api.pushStream
        .where((p) => p.opcode == Opcode.notifTyping)
        .listen(_onTypingPush);
    _typingMsgSub = chats.messageEvents.listen(_onTypingMessageEvent);
    unawaited(_runReload());
  }

  void _onTypingPush(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chatId = payload['chatId'];
    final userId = payload['userId'];
    if (chatId is! int || userId is! int) return;
    if (userId == (_profile?.id ?? 0)) return;
    ChatActivityStore.instance.mark(
      chatId,
      userId,
      chatActivityFromType(payload['type']),
    );
  }

  void _onTypingMessageEvent(MessageEvent event) {
    if (event is MessageAddedEvent) {
      ChatActivityStore.instance.clearUser(
        event.chatId,
        event.message.senderId,
      );
    }
  }

  void _onDraftsChanged() {
    if (mounted) _requestReload();
  }

  void _onArchivedChanged() {
    if (mounted) _requestReload();
  }

  void _onStoriesEnabledChanged() {
    if (!mounted) return;
    if (!AppStories.current.value) {
      _storiesRevealController.stop();
      _pullRatio = 0;
      _storiesDockedOpen = false;
      _storiesAnimClosing = false;
      _storiesOverscrollRevealArmed = false;
    } else {
      _maybeLoadStories();
    }
    setState(() {});
  }

  void _onStoriesDataChanged() {
    if (mounted) setState(() {});
  }

  void _maybeLoadStories() {
    if (!AppStories.current.value) return;
    if (api.state != SessionState.online) return;
    unawaited(storiesModule.loadFeed());
  }

  StoryOwnerInfo? _selfOwnerInfo() {
    final p = _profile;
    if (p == null) return null;
    final name = [p.firstName, p.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join(' ');
    return StoryOwnerInfo(
      name: name.isEmpty ? 'Вы' : name,
      avatarUrl: p.baseUrl,
    );
  }

  Map<int, StoryOwnerInfo> _storyOwnerOverrides() {
    final me = _profile?.id;
    final self = _selfOwnerInfo();
    if (me == null || self == null) return const {};
    return {
      me: StoryOwnerInfo(name: 'Ваша история', avatarUrl: self.avatarUrl),
    };
  }

  void _openStories(int index, [Offset? origin]) {
    final previews = storiesModule.previews;
    if (previews.isEmpty) return;
    openStoryViewer(
      context,
      previews: previews,
      initialIndex: index.clamp(0, previews.length - 1),
      ownerOverrides: _storyOwnerOverrides(),
      origin: origin,
    );
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
        unawaited(_runReload());
      }
    });
  }

  void _requestReload() {
    if (!mounted) return;
    if (_deferReloads || _reloadInFlight) {
      _reloadQueued = true;
      return;
    }
    unawaited(_runReload());
  }

  Future<void> _runReload() async {
    _reloadInFlight = true;
    try {
      await _reloadChatsAndFolders();
    } finally {
      _reloadInFlight = false;
      if (_reloadQueued && mounted && !_deferReloads) {
        _reloadQueued = false;
        unawaited(_runReload());
      }
    }
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
      final loadedChats = await chats.getChats(
        p.id,
        includeHidden:
            widget.archiveMode || KometSettings.showHiddenChats.value,
      );
      final archivedIds = ArchivedChatsStore.instance.archivedChatIds(p.id);
      var archivedCount = 0;
      var archivedUnread = 0;
      for (final c in loadedChats) {
        if (!archivedIds.contains(c.id)) continue;
        if (CloudStorageModule.isCloudStorageGroup(c)) continue;
        archivedCount++;
        archivedUnread += c.unreadCount;
      }
      var folders = await FoldersModule.loadFolders(p.id);
      final foldersKnown = await FoldersModule.hasReceivedFoldersList(p.id);
      final contactIds = (await ContactsModule.getContacts(
        p.id,
      )).map((c) => c.id).toSet();

      final allChatsFolder = ChatFolder(
        id: 'all.chat.folder',
        title: 'Все чаты',
        filters: [],
        hideEmpty: false,
        widgets: [],
      );

      if (widget.archiveMode) {
        folders = const [];
      } else {
        final hasRealFolders = folders.any(
          (f) => !FoldersModule.isAllChatsFolder(f),
        );
        if (KometSettings.hideAllChatsFolder.value && hasRealFolders) {
          folders = folders
              .where((f) => !FoldersModule.isAllChatsFolder(f))
              .toList();
        } else if (!folders.any((f) => FoldersModule.isAllChatsFolder(f))) {
          folders = [allChatsFolder, ...folders];
        }
      }

      final pageCount = folders.isEmpty ? 1 : folders.length;
      _syncFolderChatScrollControllersForCount(pageCount);

      final filteredChats = loadedChats
          .where((c) => !CloudStorageModule.isCloudStorageGroup(c))
          .where(
            (c) => widget.archiveMode
                ? archivedIds.contains(c.id)
                : !archivedIds.contains(c.id),
          )
          .toList();

      final newIds = filteredChats.map((c) => c.id.toString()).toSet();
      final entering = _didInitialChatLoad
          ? newIds.difference(_knownChatIds)
          : <String>{};
      _knownChatIds
        ..clear()
        ..addAll(newIds);
      _didInitialChatLoad = true;

      if (mounted) {
        setState(() {
          _profile = p;
          _chats = filteredChats;
          _archivedCount = archivedCount;
          _archivedUnread = archivedUnread;
          _contactIds = contactIds;
          _enteringChatIds = entering;
          _chatListRevision++;
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
        _prefetchContactsForChats(loadedChats);
        if (widget.archiveMode) {
          if (filteredChats.isNotEmpty) {
            _archiveHadChats = true;
          } else if (_archiveHadChats) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).maybePop();
            });
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _jumpFolderPageToSelection();
          if (_enteringChatIds.isNotEmpty) _enteringChatIds = <String>{};
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

  Future<void> _prefetchContactsForChats(List<CachedChat> chats) async {
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
    try {
      await messagesModule.ensureContactNames(ids);
    } finally {
      _inflightContactIds.removeAll(ids);
      _scheduleContactRebuild();
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
      identityHashCode(_contactIds),
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
      final myId = _profile?.id ?? 0;
      base = FoldersModule.isAllChatsFolder(folder)
          ? _chats
          : _chats
                .where(
                  (c) => FoldersModule.chatMatchesFolder(
                    c,
                    folder,
                    myId: myId,
                    contactIds: _contactIds,
                  ),
                )
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
    chats.chatsChanged.removeListener(_onChatsChanged);
    ArchivedChatsStore.instance.revision.removeListener(_onArchivedChanged);
    DraftStore.instance.revision.removeListener(_onDraftsChanged);
    AppStories.current.removeListener(_onStoriesEnabledChanged);
    storiesModule.storiesChanged.removeListener(_onStoriesDataChanged);
    KometSettings.hideAllChatsFolder.removeListener(_requestReload);
    KometSettings.showHiddenChats.removeListener(_requestReload);
    _loginSub?.cancel();
    _stateSub?.cancel();
    _typingSub?.cancel();
    _typingMsgSub?.cancel();
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
                                        _pullRatio < 0.8 &&
                                        storiesModule.hasAny)
                                      Opacity(
                                        opacity: 1.0 - _pullRatio,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _openStories(0),
                                          child: Container(
                                            width: 50 * (1.0 - _pullRatio),
                                            height: 32,
                                            margin: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: FoldedStoryStack(
                                              previews: storiesModule.previews,
                                              opacity: 1.0 - _pullRatio,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      connectionStatusLabel(_sessionState) ??
                                          (_profile?.firstName ?? 'Чат'),
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
                                  onSelected: _onOverflowMenuSelected,
                                  itemBuilder: (context) => [
                                    _buildPopupMenuItem(
                                      1,
                                      'Избранное',
                                      Symbols.bookmark,
                                    ),
                                    _buildPopupMenuItem(
                                      2,
                                      'Прочитать всё',
                                      Symbols.done_all,
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
                                child: _buildStoriesRow(),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 3, 20, 8),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.forwardMode
                                  ? null
                                  : () => pushSwipeable(
                                      context,
                                      (_) => const SearchScreen(),
                                    ),
                              child: GlossyPill(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                depth: 6,
                                child: SizedBox(
                                  height: 44,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Symbols.search,
                                        color: cs.outline,
                                        size: 20,
                                        weight: 400,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        widget.forwardMode
                                            ? 'Пересылка...'
                                            : 'Поиск',
                                        style: TextStyle(
                                          color: cs.outline,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                    ? FolderStripShimmer(shimmer: _shimmerController)
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
    final idToIndex = <String, int>{
      for (var i = 0; i < chats.length; i++) chats[i].id.toString(): i,
    };
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
          if (_shouldShowArchiveEntry(pageIndex))
            SliverToBoxAdapter(child: _buildArchiveEntry(cs)),
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
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (_isInitialLoading) {
                    return ChatShimmerTile(shimmer: _shimmerController);
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
                    final name = ContactCache.get(secondId) ?? chat.title;
                    final avatar =
                        ContactCache.getAvatar(secondId) ?? chat.iconUrl;
                    final isVerified =
                        ContactCache.isOfficial(secondId) || chat.isOfficial;

                    final isPlaceholder = chat.isLastMsgDeleted;
                    final previewText = isPlaceholder
                        ? 'зайдите в чат для подгрузки'
                        : (chat.lastMsgTextOneLine ?? '');
                    return _animateChatTile(
                      chat.id.toString(),
                      _buildChatItem(
                        chat.id.toString(),
                        name ?? "Пользователь",
                        previewText,
                        _formatTime(chat.lastMsgTime),
                        avatar ?? "",
                        presenceUserId: secondId,
                        unreadCount: chat.unreadCount,
                        isMuted: chat.isMuted,
                        isVerified: isVerified,
                        isPinned: isPinned,
                        chatType: "DIALOG",
                        messageItalic: isPlaceholder,
                        draft: _draftFor(chat.id),
                        ownStatus: _ownStatusFor(chat, isPlaceholder),
                        ownRead: chat.lastMsgReadByOthers,
                        messageRanges: isPlaceholder
                            ? const []
                            : chat.lastMsgFormatRanges,
                      ),
                    );
                  } else {
                    final isPlaceholder = chat.isLastMsgDeleted;
                    final sender = chat.lastMsgSenderId != null
                        ? ContactCache.get(chat.lastMsgSenderId!)
                        : null;

                    String fullMsg = "";
                    List<FormatRange> messageRanges = const [];
                    if (isPlaceholder) {
                      fullMsg = 'зайдите в чат для подгрузки';
                    } else {
                      var prefixLen = 0;
                      if (sender?.isNotEmpty == true && chat.id != 0) {
                        final prefix = "$sender: ";
                        fullMsg += prefix;
                        prefixLen = prefix.length;
                      }
                      if (chat.lastMsgText?.isNotEmpty == true) {
                        fullMsg += chat.lastMsgText ?? "";
                        final ranges = chat.lastMsgFormatRanges;
                        messageRanges = prefixLen == 0
                            ? ranges
                            : [
                                for (final r in ranges)
                                  FormatRange(
                                    format: r.format,
                                    start: r.start + prefixLen,
                                    length: r.length,
                                    attributes: r.attributes,
                                  ),
                              ];
                      }
                    }

                    return _animateChatTile(
                      chat.id.toString(),
                      _buildChatItem(
                        chat.id.toString(),
                        chat.id == 0 ? "Избранное" : chat.title ?? "Чат",
                        fullMsg,
                        _formatTime(chat.lastMsgTime),
                        (chat.iconUrl != null && chat.iconUrl!.isNotEmpty)
                            ? chat.iconUrl!
                            : '',
                        unreadCount: chat.unreadCount,
                        isMuted: chat.isMuted,
                        isVerified: chat.isOfficial,
                        isPinned: isPinned,
                        chatType: chat.type,
                        messageItalic: isPlaceholder,
                        draft: chat.id == 0 ? null : _draftFor(chat.id),
                        ownStatus: _ownStatusFor(chat, isPlaceholder),
                        ownRead: chat.lastMsgReadByOthers,
                        messageRanges: messageRanges,
                      ),
                    );
                  }
                },
                childCount: totalItems,
                findChildIndexCallback: (Key key) {
                  if (key is! ValueKey<String>) return null;
                  final v = key.value;
                  if (!v.startsWith('chat_')) return null;
                  final idx = idToIndex[v.substring(5)];
                  if (idx == null) return null;
                  return hasSeparator && idx >= pinnedCount ? idx + 1 : idx;
                },
              ),
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
                backdropKey: _frostBackdrop,
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
    if (widget.archiveMode) {
      return _buildArchiveScaffold(cs);
    }
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (widget.forwardMode) {
              return _getChatsBody();
            }
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
                            child: ValueListenableBuilder<VisualStyle>(
                              valueListenable: AppVisualStyle.current,
                              builder: (context, style, child) =>
                                  ValueListenableBuilder<NavPillStyle>(
                                    valueListenable: AppNavPillStyle.current,
                                    builder: (context, navStyle, child) {
                                      final liquid =
                                          style.glossyChrome &&
                                          NavPillMaterial.isLiquid(navStyle);
                                      final frost =
                                          style.glossyChrome &&
                                          NavPillMaterial.isFrost(navStyle);
                                      return GlossyPill(
                                        onTap: _toggleFab,
                                        color: frost || liquid
                                            ? AppFrost.fabTint(cs)
                                            : cs.primaryContainer,
                                        blurSigma: frost
                                            ? AppFrost.sigma
                                            : null,
                                        liquid: liquid,
                                        backdropKey: _frostBackdrop,
                                        borderRadius: BorderRadius.circular(28),
                                        elevated: true,
                                        depth: 12,
                                        child: child!,
                                      );
                                    },
                                    child: child,
                                  ),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: Center(
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
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                _buildSelectionActionBar(cs),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildArchiveScaffold(ColorScheme cs) {
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildArchiveAppBar(cs),
                Expanded(child: _buildFolderChatPage(0)),
              ],
            ),
            _buildSelectionActionBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveAppBar(ColorScheme cs) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Symbols.arrow_back, color: cs.onSurface),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 4),
            Text(
              'Архив',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowArchiveEntry(int pageIndex) {
    if (widget.archiveMode || widget.forwardMode) return false;
    if (_isInitialLoading) return false;
    if (_archivedCount <= 0) return false;
    if (_folders.isEmpty) return pageIndex == 0;
    final allIdx = _folders.indexWhere(
      (f) => FoldersModule.isAllChatsFolder(f),
    );
    return pageIndex == (allIdx >= 0 ? allIdx : 0);
  }

  Widget _buildArchiveEntry(ColorScheme cs) {
    return InkWell(
      onTap: () {
        if (_isSelectionMode) return;
        pushSwipeable(context, (_) => const ChatListScreen(archiveMode: true));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.surfaceContainerHighest,
              child: Icon(
                Symbols.archive,
                color: cs.onSurfaceVariant,
                weight: 500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Архив',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_archivedUnread > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _archivedUnread > 99 ? '99+' : '$_archivedUnread',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Icon(Symbols.chevron_right, color: cs.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionActionBar(ColorScheme cs) {
    return AnimatedPositioned(
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
            final deleteCategory = _selectionDeleteCategoryFor(selected);
            final anyMuted = selected.any((c) => c.isMuted);
            final anyPinned = selected.any((c) => (c.favIndex ?? 0) > 0);
            return Row(
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
                if (deleteCategory != null)
                  IconButton(
                    icon: Icon(Symbols.delete, color: cs.onSurface),
                    onPressed: _onDeleteTap,
                  ),
                IconButton(
                  icon: Icon(
                    widget.archiveMode ? Symbols.unarchive : Symbols.archive,
                    color: cs.onSurface,
                  ),
                  onPressed: selected.isEmpty ? null : _onArchiveTap,
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
                    anyMuted ? Symbols.volume_up : Symbols.volume_off,
                    color: cs.onSurface,
                  ),
                  onPressed: selected.isEmpty ? null : _onMuteTap,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoriesRow() {
    final previews = storiesModule.previews;
    final me = _profile?.id;
    final selfInfo = _selfOwnerInfo();
    final myIndex = me == null
        ? -1
        : previews.indexWhere((p) => p.owner.ownerId == me);
    final otherIndices = <int>[
      for (var i = 0; i < previews.length; i++)
        if (i != myIndex) i,
    ];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: otherIndices.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return StorySelfTile(
            preview: myIndex >= 0 ? previews[myIndex] : null,
            selfInfo: selfInfo == null
                ? null
                : StoryOwnerInfo(
                    name: 'Ваша история',
                    avatarUrl: selfInfo.avatarUrl,
                  ),
            onOpen: (center) => _openStories(myIndex < 0 ? 0 : myIndex, center),
            onAdd: _composeStory,
          );
        }
        final gi = otherIndices[index - 1];
        return StoryRing(
          preview: previews[gi],
          onTap: (center) => _openStories(gi, center),
        );
      },
    );
  }

  Future<void> _composeStory() async {
    await showAttachmentSheet(
      context,
      title: 'Новая история',
      onSend: (photos, caption) async {
        if (photos.isEmpty) return;
        final picked = photos.first;
        if (picked.item.isVideo) {
          if (mounted) {
            showCustomNotification(
              context,
              'Видео в историях пока не поддерживается',
            );
          }
          return;
        }
        final file =
            picked.editedFile ??
            picked.item.localFile ??
            await picked.item.originFile();
        if (file == null) {
          if (mounted) {
            showCustomNotification(context, 'Не удалось открыть фото');
          }
          return;
        }
        if (!mounted) return;
        pushSwipeable(context, (_) => StoryComposerScreen(file: file));
      },
    );
  }

  String _folderChipLabel(ChatFolder f) {
    final e = f.emoji;
    if (e != null && e.isNotEmpty) return '$e ${f.title}';
    return f.title;
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
      child: GlossyPill(
        color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(50),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        depth: 4,
        child: Center(
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
      ),
    );
  }

  String? _draftFor(int chatId) {
    final raw = DraftStore.instance.get(_profile?.id ?? 0, chatId);
    if (raw == null) return null;
    final oneLine = raw.replaceAll('\n', ' ').trim();
    return oneLine.isEmpty ? null : oneLine;
  }

  String? _ownStatusFor(CachedChat chat, bool isPlaceholder) {
    if (isPlaceholder || chat.id == 0) return null;
    final me = _profile?.id;
    if (me == null || chat.lastMsgSenderId != me) return null;
    return chat.lastMsgStatus ?? 'sent';
  }

  Widget _ownStatusIcon(ColorScheme cs, String status, bool read) {
    IconData icon;
    Color color;
    switch (status) {
      case 'sending':
      case 'pending':
        icon = Symbols.schedule;
        color = cs.outline;
      case 'error':
        icon = Symbols.error;
        color = Colors.redAccent;
      default:
        if (read) {
          icon = Symbols.done_all;
          color = kReadReceiptBlue;
        } else {
          icon = Symbols.check;
          color = cs.outline;
        }
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(icon, size: 16, color: color, fill: 1),
    );
  }

  Widget _animateChatTile(String id, Widget child) {
    return AnimatedChatTile(
      key: ValueKey('chat_$id'),
      id: id,
      revision: _chatListRevision,
      isNew: _enteringChatIds.contains(id),
      child: child,
    );
  }

  Widget _buildPreviewLine(
    ColorScheme cs,
    String message,
    List<FormatRange> messageRanges,
    String? draft,
    bool messageItalic,
  ) {
    if (draft != null) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Черновик: ',
              style: TextStyle(color: cs.error),
            ),
            TextSpan(
              text: draft,
              style: TextStyle(color: cs.outline),
            ),
          ],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            height: 1.2,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final previewStyle = TextStyle(
      color: cs.outline,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      fontStyle: messageItalic ? FontStyle.italic : FontStyle.normal,
      height: 1.2,
    );
    if (messageRanges.isEmpty) {
      return Text(
        message,
        style: previewStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      FormattedMessageText.buildInlineSpan(
        message,
        messageRanges,
        previewStyle,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildChatItem(
    String id,
    String name,
    String message,
    String time,
    String imageUrl, {
    int presenceUserId = 0,
    bool isRead = false,
    int unreadCount = 0,
    bool isMuted = false,
    bool isVerified = false,
    bool isPinned = false,
    String chatType = "CHAT",
    bool messageItalic = false,
    String? draft,
    String? ownStatus,
    bool ownRead = false,
    List<FormatRange> messageRanges = const [],
  }) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedChats.contains(id);
    final Widget? statusIcon = (ownStatus != null && draft == null)
        ? _ownStatusIcon(cs, ownStatus, ownRead)
        : null;
    final Widget messageLine = _buildPreviewLine(
      cs,
      message,
      messageRanges,
      draft,
      messageItalic,
    );

    final Widget avatarCircle = CircleAvatar(
      radius: 24,
      backgroundColor: cs.surfaceContainerHighest,
      backgroundImage: imageUrl.isNotEmpty
          ? CachedNetworkImageProvider(
              imageUrl,
              maxWidth: kAvatarThumbSize,
              maxHeight: kAvatarThumbSize,
            )
          : null,
      child: imageUrl.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 20),
            )
          : null,
    );
    return SpringyTap(
      key: ValueKey('chat_$id'),
      child: InkWell(
        onTap: () {
          if (widget.forwardMode) {
            Navigator.of(context).pop(
              ForwardTarget(
                chatId: int.parse(id),
                name: name,
                imageUrl: imageUrl,
                chatType: chatType,
              ),
            );
            return;
          }
          if (_isSelectionMode) {
            _toggleSelection(id);
            return;
          }
          if (imageUrl.isNotEmpty) {
            unawaited(
              precacheImage(
                CachedNetworkImageProvider(
                  imageUrl,
                  maxWidth: kAvatarThumbSize,
                  maxHeight: kAvatarThumbSize,
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
        onLongPress: widget.forwardMode ? null : () => _toggleSelection(id),
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
                    avatarCircle,
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
                    else if (presenceUserId != 0)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: OnlineDot(
                          userId: presenceUserId,
                          borderColor: cs.surface,
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
                                style: TextStyle(
                                  color: cs.outline,
                                  fontSize: 12,
                                ),
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
                                child: ActivitySubtitle(
                                  chatId: int.tryParse(id) ?? 0,
                                  child: messageLine,
                                ),
                              ),
                              ?statusIcon,
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
                                        : cs.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: TextStyle(
                                      color: isMuted
                                          ? cs.outline
                                          : cs.onPrimary,
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
          await resetDigitalIdSession();
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
        await resetDigitalIdSession();
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
    return SizedBox(
      width: 220,
      child: GlossyPill(
        onTap: onTap,
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        elevated: true,
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

  void _onOverflowMenuSelected(int value) {
    switch (value) {
      case 1:
        _openSavedMessages();
      case 2:
        unawaited(_markAllChatsRead());
    }
  }

  void _openSavedMessages() {
    CachedChat? self;
    for (final c in _chats) {
      if (c.id == 0) {
        self = c;
        break;
      }
    }
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: 0,
        name: 'Избранное',
        imageUrl: self?.iconUrl ?? '',
        chatType: self?.type ?? 'DIALOG',
      ),
    );
  }

  Future<void> _markAllChatsRead() async {
    final p = _profile ?? await AppDatabase.loadActiveProfile();
    if (p == null) return;
    final all = await chats.getChats(
      p.id,
      includeHidden: KometSettings.showHiddenChats.value,
    );
    final targets = all
        .where((c) => c.unreadCount > 0)
        .where((c) => c.lastMsgId != null)
        .where((c) => !CloudStorageModule.isCloudStorageGroup(c))
        .toList();
    if (targets.isEmpty) {
      if (mounted) showCustomNotification(context, 'Непрочитанных чатов нет');
      return;
    }
    for (final c in targets) {
      await chats.markRead(
        api,
        p.id,
        c.id,
        c.lastMsgId!.toString(),
        c.lastMsgTime ?? 0,
      );
    }
    if (mounted) {
      showCustomNotification(context, 'Все чаты отмечены прочитанными');
    }
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
}

class _StoriesUi extends ChangeNotifier {
  double pullRatio = 0.0;
  bool dockedOpen = false;
  bool overscrollRevealArmed = true;
  bool shouldCollapseSearch = false;

  void notify() => notifyListeners();
}
