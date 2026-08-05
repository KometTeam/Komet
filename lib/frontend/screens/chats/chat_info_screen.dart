import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../contacts/edit_contact_sheet.dart';
import '../../../backend/modules/complaints.dart';
import '../../../backend/modules/contacts.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/config/app_show_extra_info.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chat_info.dart';
import '../../../models/contact_info.dart';
import '../../widgets/animated_text_swap.dart';
import '../../widgets/avatar_history_screen.dart';
import '../../widgets/chat_info/shared_content_tabs.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/formatted_message_text.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/profile_hero.dart';
import '../../widgets/swipe_route.dart';
import '../../../backend/modules/chats.dart';
import '../calls/call_screen.dart';
import '../contacts/open_contact_profile.dart';
import 'chat_screen.dart';
import 'group_invite_sheets.dart';
import 'profile_action_sheets.dart';

class _MemberInfo {
  final int id;
  final String? name;
  final String? avatarUrl;
  final bool isAdmin;
  final bool isOwner;
  final bool isMe;
  final String? alias;
  final int? seenTime;
  final int presenceStatus;
  final bool blocked;
  final bool isContact;

  const _MemberInfo({
    required this.id,
    this.name,
    this.avatarUrl,
    required this.isAdmin,
    required this.isOwner,
    required this.isMe,
    this.alias,
    this.seenTime,
    required this.presenceStatus,
    this.blocked = false,
    this.isContact = false,
  });

  bool get isOnline => presenceStatus == 1;
}

enum ChatInfoTab { media }

class ChatInfoScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  final int? dialogPeerId;
  final ChatInfoTab? initialTab;
  final Object? heroTag;
  final bool openedFromChat;

  final void Function(String messageId, int time)? onJumpToMessage;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.dialogPeerId,
    this.initialTab,
    this.heroTag,
    this.openedFromChat = false,
    this.onJumpToMessage,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen>
    with ReloadOnReconnect {
  final _tabScrollController = ScrollController();
  final _bodyScrollController = ScrollController();

  int _myId = 0;
  bool _isLoading = true;
  bool _extraContactExpanded = false;
  ChatInfo? _chatInfo;
  String _selectedTab = '';
  bool _descExpanded = false;
  bool _showRealName = false;

  int? _otherId;
  ContactInfo? _contactData;
  CachedContact? _localContact;
  int? _seenTime;
  bool _isOnline = false;
  int _presenceStatus = 0;
  bool _isBot = false;

  final List<_MemberInfo> _members = [];
  final List<_MemberInfo> _owners = [];
  final List<_MemberInfo> _admins = [];
  final List<_MemberInfo> _contactMembers = [];
  final List<_MemberInfo> _otherMembers = [];
  final Set<int> _seenMemberIds = {};
  Set<int> _contactIds = {};
  int _memberMarker = 0;
  bool _membersLoading = false;
  bool _membersEnd = false;

  int _mediaChatId = 0;
  String? _anchorMsgId;

  int _dontDisturbUntil = 0;
  int _lastEventTime = 0;
  bool _blocked = false;
  bool _muteBusy = false;
  bool _addContactBusy = false;

  @override
  void initState() {
    super.initState();
    _bodyScrollController.addListener(_onBodyScroll);
    _load();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<String> get _tabs {
    final showInfo = AppShowExtraInfo.current.value;
    switch (widget.chatType) {
      case 'DIALOG':
        if (_isBot) {
          return [
            if (showInfo) 'Info',
            l10n.chatInfoTabMedia,
            l10n.chatInfoTabFiles,
            l10n.chatInfoTabVoice,
            l10n.chatInfoTabLinks,
          ];
        }
        return [
          l10n.chatInfoTabGeneralChats,
          l10n.chatInfoTabMedia,
          if (showInfo) 'Info',
          l10n.chatInfoTabFiles,
          l10n.chatInfoTabVoice,
          l10n.chatInfoTabLinks,
        ];
      case 'CHAT':
        return [
          l10n.chatInfoTabMembers,
          if (showInfo) 'Info',
          l10n.chatInfoTabMedia,
          l10n.chatInfoTabFiles,
          l10n.chatInfoTabVoice,
          l10n.chatInfoTabLinks,
        ];
      case 'CHANNEL':
        return [
          if (showInfo) 'Info',
          l10n.chatInfoTabMedia,
          l10n.chatInfoTabFiles,
          l10n.chatInfoTabVoice,
          l10n.chatInfoTabLinks,
        ];
      default:
        return [if (showInfo) 'Info'];
    }
  }

  @override
  void reloadAfterReconnect() => _load();

  Future<void> _load() async {
    final profile = await AppDatabase.loadActiveProfile();
    _myId = profile?.id ?? 0;

    final info = await ChatInfoFetch.get(widget.chatId);
    if (!mounted) return;
    _chatInfo = info;

    _mediaChatId = (info?.raw['id'] as int?) ?? widget.chatId;

    final cached = await chats.getChat(_myId, _mediaChatId);
    if (!mounted) return;
    if (cached.isNotEmpty) {
      _dontDisturbUntil = cached.first.dontDisturbUntil;
      _lastEventTime = cached.first.lastEventTime;
    }
    final serverEventTime = (info?.raw['lastEventTime'] as int?) ?? 0;
    if (serverEventTime > _lastEventTime) _lastEventTime = serverEventTime;

    final lastMessage = info?.raw['lastMessage'];
    if (lastMessage is Map) {
      _anchorMsgId = lastMessage['id']?.toString();
    }
    if (_anchorMsgId == null && info != null) {
      try {
        final recent = await messagesModule.fetchHistory(
          _myId,
          _mediaChatId,
          count: 1,
        );
        if (recent.isNotEmpty) _anchorMsgId = recent.first.id;
      } catch (_) {}
      if (!mounted) return;
    }

    if (widget.chatType == 'DIALOG') {
      _otherId = widget.dialogPeerId;
      if (_otherId == null && info != null) {
        for (final id in info.participantIds) {
          if (id != _myId) {
            _otherId = id;
            break;
          }
        }
      }

      if (_otherId != null) {
        _localContact = await ContactsModule.getContact(_myId, _otherId!);
        final contact = await ContactInfoFetch.get(_otherId!);
        if (contact != null) {
          _contactData = contact;
          _isBot = _contactData!.options.contains('BOT');
        }

        final presence = await PresenceFetch.get(_otherId!);
        if (presence != null) {
          _seenTime = presence['seen'] as int?;
          final st = (presence['status'] as int?) ?? 0;
          _presenceStatus = st;
          _isOnline = st == 1;
        }

        if (!_isBot && _otherId != _myId) _loadBlockedState(_otherId!);
      }
    } else if (info == null) {
      setState(() => _isLoading = false);
      return;
    } else if (widget.chatType == 'CHAT') {
      _contactIds = (await AppDatabase.loadContactIds(_myId)).toSet();
      await _loadLeaders();
      await _fetchMembersPage(initial: true);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_selectedTab.isEmpty && _tabs.isNotEmpty) {
          _selectedTab = _initialTabLabel() ?? _tabs.first;
        }
      });
    }
  }

  Future<void> _loadBlockedState(int peerId) async {
    final blocked = await ContactsModule.isBlocked(api, peerId);
    if (!mounted || blocked == _blocked) return;
    setState(() => _blocked = blocked);
  }

  String? _initialTabLabel() {
    if (widget.initialTab != ChatInfoTab.media) return null;
    final media = AppLocalizations.of(context)!.chatInfoTabMedia;
    return _tabs.contains(media) ? media : null;
  }

  _MemberInfo _memberFrom(ChatMemberEntry e) => _MemberInfo(
    id: e.id,
    name: e.name,
    avatarUrl: e.avatarUrl,
    isAdmin: _chatInfo?.isAdmin(e.id) ?? false,
    isOwner: _chatInfo?.isOwner(e.id) ?? false,
    isMe: e.id == _myId,
    alias: _chatInfo?.adminAlias(e.id),
    seenTime: e.seenTime,
    presenceStatus: e.presenceStatus,
    blocked: e.blocked,
    isContact: _contactIds.contains(e.id),
  );

  Future<void> _loadLeaders() async {
    final info = _chatInfo;
    if (info == null) return;

    final owner = info.owner;
    final leaderIds = <int>[
      if (owner != null && owner != 0) owner,
      for (final a in info.adminIds)
        if (a != owner) a,
    ];
    if (leaderIds.isEmpty) return;

    final contacts = await ContactInfoFetch.getMany(leaderIds);
    final presence = await PresenceFetch.getMany(leaderIds);
    if (!mounted) return;

    for (final id in leaderIds) {
      if (!_seenMemberIds.add(id)) continue;
      final c = contacts[id];
      final pres = presence[id];
      _addMember(
        _MemberInfo(
          id: id,
          name: c?.displayName ?? ContactCache.get(id),
          avatarUrl: c?.avatarUrl ?? ContactCache.getAvatar(id),
          isAdmin: info.isAdmin(id),
          isOwner: info.isOwner(id),
          isMe: id == _myId,
          alias: info.adminAlias(id),
          seenTime: pres?['seen'] as int?,
          presenceStatus: (pres?['status'] as int?) ?? 0,
          blocked: c?.isDeleted ?? false,
          isContact: _contactIds.contains(id),
        ),
      );
    }
    _rebuildMembers();
  }

  int _memberRank(_MemberInfo m) {
    if (m.isOwner) return 0;
    if (m.isAdmin) return 1;
    if (m.isContact) return 2;
    return 3;
  }

  void _addMember(_MemberInfo m) {
    switch (_memberRank(m)) {
      case 0:
        _owners.add(m);
      case 1:
        _admins.add(m);
      case 2:
        _contactMembers.add(m);
      default:
        _otherMembers.add(m);
    }
  }

  void _rebuildMembers() {
    _members
      ..clear()
      ..addAll(_owners)
      ..addAll(_admins)
      ..addAll(_contactMembers)
      ..addAll(_otherMembers);
  }

  Future<void> _fetchMembersPage({bool initial = false}) async {
    if (_membersLoading || _membersEnd) return;
    _membersLoading = true;
    if (!initial && mounted) setState(() {});

    final page = await chats.getChatMembers(
      api,
      widget.chatId,
      marker: _memberMarker,
    );
    _membersLoading = false;
    if (!mounted) return;

    if (page == null) {
      if (!initial) setState(() {});
      return;
    }

    var added = 0;
    for (final e in page.members) {
      if (_seenMemberIds.add(e.id)) {
        _addMember(_memberFrom(e));
        added++;
      }
    }
    if (added > 0) _rebuildMembers();

    final total = _chatInfo?.participantsCount;
    if (page.members.isEmpty ||
        added == 0 ||
        page.marker == _memberMarker ||
        (total != null && _members.length >= total)) {
      _membersEnd = true;
    }
    _memberMarker = page.marker;

    if (!initial) setState(() {});
  }

  void _onBodyScroll() {
    if (!mounted || widget.chatType != 'CHAT') return;
    if (_membersLoading || _membersEnd) return;
    if (_selectedTab != AppLocalizations.of(context)!.chatInfoTabMembers)
      return;
    final pos = _bodyScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _fetchMembersPage();
    }
  }

  String? get _inviteLink {
    final link = _chatInfo?.link;
    return (link != null && link.isNotEmpty) ? link : null;
  }

  Future<void> _openAddMembers() async {
    final exclude = {_myId, ..._members.map((m) => m.id)};
    final added = await showAddMembersSheet(
      context,
      chatId: widget.chatId,
      excludeIds: exclude,
    );
    if (added == true && mounted) await _refreshMembers();
  }

  void _openInviteLink(String link) {
    showInviteLinkSheet(
      context,
      link: link,
      title: widget.name,
      avatarUrl: widget.imageUrl,
    );
  }

  Future<void> _refreshMembers() async {
    _contactMembers.clear();
    _otherMembers.clear();
    _seenMemberIds
      ..clear()
      ..addAll(_owners.map((m) => m.id))
      ..addAll(_admins.map((m) => m.id));
    _memberMarker = 0;
    _membersEnd = false;
    _membersLoading = false;
    _rebuildMembers();
    if (mounted) setState(() {});
    await _fetchMembersPage(initial: true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      body: SafeArea(child: _buildScrollBody(cs)),
    );
  }

  Widget _buildScrollBody(ColorScheme cs) {
    return CustomScrollView(
      controller: _bodyScrollController,
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          floating: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [_buildMoreButton(cs)],
        ),
        SliverToBoxAdapter(child: _buildBody(cs)),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          _avatar(),
          const SizedBox(height: 14),
          _buildNameRow(cs),
          const SizedBox(height: 4),
          if (_isLoading)
            ..._loadingBlocks(cs)
          else ...[
            SelectionArea(
              child: Text(
                _subtitle(),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            _buildActions(cs),
            const SizedBox(height: 16),
            _buildPersistentInfo(cs),
            _buildTabBar(cs),
            const SizedBox(height: 12),
            _buildTabContent(cs),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  ContactName? _nameEntry(String type) {
    final data = _contactData;
    if (data == null) return null;
    for (final n in data.names) {
      if (n.type == type) return n;
    }
    return null;
  }

  bool get _isContact => _localContact != null;

  bool get _peerDeleted => _contactData?.isDeleted ?? false;

  String _joinName(String first, String last) =>
      last.trim().isEmpty ? first.trim() : '${first.trim()} ${last.trim()}';

  String get _customName {
    final c = _localContact;
    if (c != null) return _joinName(c.firstName, c.lastName ?? '');
    return widget.name;
  }

  Widget _buildMoreButton(ColorScheme cs) {
    final entries = _moreMenuEntries();
    if (entries.isEmpty) {
      return IconButton(
        icon: Icon(Icons.more_vert, color: cs.onSurface),
        onPressed: null,
      );
    }
    return PopupMenuButton<VoidCallback>(
      icon: Icon(Icons.more_vert, color: cs.onSurface),
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        for (final entry in entries)
          PopupMenuItem<VoidCallback>(
            value: entry.onTap,
            child: Row(
              children: [
                Icon(
                  entry.icon,
                  size: 20,
                  color: entry.destructive ? cs.error : cs.onSurface,
                ),
                const SizedBox(width: 12),
                Text(
                  entry.label,
                  style: entry.destructive ? TextStyle(color: cs.error) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<({IconData icon, String label, bool destructive, VoidCallback onTap})>
  _moreMenuEntries() {
    if (_isLoading) return const [];
    final entries =
        <({IconData icon, String label, bool destructive, VoidCallback onTap})>[];

    if (widget.chatType == 'DIALOG') {
      if (_isContact) {
        entries.add((
          icon: Symbols.edit,
          label: l10n.editContactMenu,
          destructive: false,
          onTap: _openEdit,
        ));
      }
      if (!_isBot && _otherId != null && _otherId != _myId) {
        entries.add((
          icon: _blocked ? Symbols.lock_open : Symbols.block,
          label: _blocked ? l10n.chatInfoMenuUnblock : l10n.chatInfoMenuBlock,
          destructive: !_blocked,
          onTap: _toggleBlock,
        ));
      }
      entries.add((
        icon: Symbols.delete,
        label: l10n.chatInfoMenuDeleteChat,
        destructive: true,
        onTap: _deleteChat,
      ));
    }

    entries.add((
      icon: Symbols.mop,
      label: l10n.chatInfoMenuClearHistory,
      destructive: true,
      onTap: _clearHistory,
    ));

    return entries;
  }

  Future<void> _openEdit() async {
    final oneme = _nameEntry('ONEME');
    final local = _localContact;
    final peerId = _otherId ?? widget.dialogPeerId ?? 0;
    if (peerId == 0) return;

    final result = await showEditContactSheet(
      context,
      contactId: peerId,
      avatarUrl: _contactData?.avatarUrl ?? local?.baseUrl ?? widget.imageUrl,
      customFirst: local?.firstName ?? '',
      customLast: local?.lastName ?? '',
      onemeFirst: oneme?.firstName ?? '',
      onemeLast: oneme?.lastName ?? '',
    );
    if (!mounted || result == null) return;

    switch (result.action) {
      case EditContactAction.updated:
        final fresh = await ContactsModule.getContact(_myId, peerId);
        if (!mounted) return;
        setState(() {
          _localContact = fresh;
          _showRealName = false;
        });
      case EditContactAction.removed:
        Navigator.of(context).pop();
    }
  }

  String? get _realName {
    final data = _contactData;
    if (data == null) return null;
    for (final n in data.names) {
      if (n.type == 'ONEME') {
        final combined = [n.firstName, n.lastName]
            .where((s) => s != null && s.trim().isNotEmpty)
            .map((s) => s!.trim())
            .join(' ');
        if (combined.isNotEmpty) return combined;
        final label = n.label;
        if (label != null && label.isNotEmpty) return label;
      }
    }
    return null;
  }

  Widget _buildNameRow(ColorScheme cs) {
    final nameStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      fontFamily: 'Outfit',
    );
    final custom = _customName;
    final real = _realName;
    final hasToggle = _isContact && real != null && real != custom;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 36),
        Flexible(
          child: SelectionArea(
            child: ProfileHeroName(
              tag: widget.heroTag,
              text: custom,
              style: nameStyle,
              child: AnimatedTextSwap(
                showAlternate: _showRealName,
                alignment: Alignment.center,
                alternate: Text(
                  real ?? custom,
                  style: nameStyle,
                  textAlign: TextAlign.center,
                ),
                child: Text(
                  custom,
                  style: nameStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: hasToggle
              ? IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: _showRealName ? cs.primary : cs.onSurfaceVariant,
                  icon: Icon(
                    _showRealName ? Symbols.visibility : Symbols.visibility_off,
                  ),
                  tooltip: real,
                  onPressed: () =>
                      setState(() => _showRealName = !_showRealName),
                )
              : null,
        ),
      ],
    );
  }

  String _subtitle() {
    switch (widget.chatType) {
      case 'DIALOG':
        if (_peerDeleted) return l10n.chatInfoMemberDeleted;
        if (_isBot) return l10n.contactProfileBot;
        if (_isOnline) return l10n.contactProfileOnline;
        if (_presenceStatus == 2 || _presenceStatus == 3)
          return l10n.contactProfileRecentlyActive;
        if (_seenTime != null && _seenTime! > 0) {
          return formatLastSeen(_seenTime!);
        }
        return '';
      case 'CHAT':
        final total = _chatInfo?.participantsCount ?? _members.length;
        return '$total ${pluralRu(total, 'участник', 'участника', 'участников')}';
      case 'CHANNEL':
        final count = _chatInfo?.participantsCount ?? 0;
        return '$count ${pluralRu(count, 'подписчик', 'подписчика', 'подписчиков')}';
      default:
        return '';
    }
  }

  bool get _isMuted {
    if (_dontDisturbUntil == ChatsModule.muteOff) return false;
    if (_dontDisturbUntil < 0) return true;
    return _dontDisturbUntil > DateTime.now().millisecondsSinceEpoch;
  }

  bool get _iAmAdmin {
    final info = _chatInfo;
    if (info == null || _myId == 0) return false;
    return info.isOwner(_myId) || info.isAdmin(_myId);
  }

  bool get _isGroupOrChannel =>
      widget.chatType == 'CHAT' || widget.chatType == 'CHANNEL';

  Widget _buildActions(ColorScheme cs) {
    final muteBtn = (
      icon: _isMuted ? Icons.notifications_off : Icons.notifications,
      label: _isMuted
          ? l10n.chatInfoActionMuted
          : l10n.contactProfileActionSound,
      onTap: _muteBusy ? null : _toggleMute,
    );
    final chatBtn = (
      icon: Icons.chat_bubble,
      label: l10n.contactProfileActionChat,
      onTap: _openChat,
    );
    final leaveBtn = (
      icon: Icons.exit_to_app,
      label: l10n.chatInfoActionLeave,
      onTap: _leaveChat,
    );

    final List<({IconData icon, String label, VoidCallback? onTap})> btns;
    if (widget.chatType == 'DIALOG') {
      btns = [
        chatBtn,
        muteBtn,
        if (!_isBot)
          (
            icon: Icons.call,
            label: l10n.contactProfileActionCall,
            onTap: _confirmAndStartCall,
          ),
      ];
    } else if (widget.chatType == 'CHANNEL') {
      btns = [muteBtn, leaveBtn];
    } else {
      btns = [chatBtn, muteBtn, leaveBtn];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (int i = 0; i < btns.length; i++) ...[
                _actionBtn(cs, btns[i].icon, btns[i].label, btns[i].onTap),
                if (i < btns.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          if (_canAddContact) ...[
            const SizedBox(height: 8),
            _wideActionBtn(
              cs,
              Symbols.person_add,
              l10n.contactProfileActionAddContact,
              _addContactBusy ? null : _addToContacts,
            ),
          ],
        ],
      ),
    );
  }

  bool get _canAddContact =>
      widget.chatType == 'DIALOG' &&
      !_isContact &&
      !_isBot &&
      !_peerDeleted &&
      _otherId != null &&
      _otherId != _myId;

  Future<void> _addToContacts() async {
    final peerId = _otherId;
    if (peerId == null || _addContactBusy) return;
    setState(() => _addContactBusy = true);

    CachedContact? contact;
    try {
      contact = await ContactsModule.addContact(api, peerId, '');
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _addContactBusy = false;
      if (contact != null) {
        _localContact = contact;
        _showRealName = false;
      }
    });
    showCustomNotification(
      context,
      contact != null ? l10n.nfcContactAdded : l10n.addContactError,
    );
  }

  void _openChat() {
    if (widget.openedFromChat) {
      Navigator.of(context).pop();
      return;
    }
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: _mediaChatId,
        name: widget.name,
        imageUrl: widget.imageUrl,
        chatType: widget.chatType,
      ),
    );
  }

  Future<void> _toggleMute() async {
    if (_muteBusy) return;
    setState(() => _muteBusy = true);
    final muted = _isMuted;
    final target = muted ? ChatsModule.muteOff : ChatsModule.muteForever;
    final error = await chats.setChatMute(
      api,
      chatId: _mediaChatId,
      dontDisturbUntil: target,
    );
    if (!mounted) return;
    setState(() {
      _muteBusy = false;
      if (error == null) _dontDisturbUntil = target;
    });
    showCustomNotification(
      context,
      error ??
          (muted ? l10n.chatInfoNotificationsOn : l10n.chatInfoNotificationsOff),
    );
  }

  Future<void> _confirmAndStartCall() async {
    final peerId = _otherId;
    if (peerId == null || peerId == _myId) return;

    final choice = await showBlurredConfirm(
      context,
      title: l10n.chatInfoCallConfirmTitle,
      message: l10n.chatInfoCallConfirmMessage(_customName),
      confirmLabel: l10n.chatInfoConfirmYes,
      cancelLabel: l10n.chatInfoConfirmNo,
    );
    if (!mounted || !choice.confirmed) return;

    final navigator = Navigator.of(context);
    final avatarUrl = widget.imageUrl.isNotEmpty ? widget.imageUrl : null;
    final active = CallController.instance.activeSession;
    if (active != null) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              CallScreen(name: _customName, avatarUrl: avatarUrl, session: active),
        ),
      );
      return;
    }

    try {
      final session = await CallController.instance.startOutgoing(peerId);
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            name: _customName,
            avatarUrl: avatarUrl,
            session: session,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showCustomNotification(context, l10n.chatInfoCallFailed);
    }
  }

  Future<void> _leaveChat() async {
    final isChannel = widget.chatType == 'CHANNEL';
    final choice = await showBlurredConfirm(
      context,
      title: isChannel
          ? l10n.chatInfoLeaveChannelTitle
          : l10n.chatInfoLeaveGroupTitle,
      message: isChannel
          ? l10n.chatInfoLeaveChannelMessage
          : l10n.chatInfoLeaveGroupMessage,
      confirmLabel: l10n.chatInfoLeaveConfirm,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
    );
    if (!mounted || !choice.confirmed) return;

    final ok = await chats.leaveChat(api, chatId: _mediaChatId);
    if (!mounted) return;
    if (!ok) {
      showCustomNotification(context, l10n.chatInfoLeaveFailed);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _clearHistory() async {
    final canClearForAll = _isGroupOrChannel && _iAmAdmin;
    final choice = await showBlurredConfirm(
      context,
      title: l10n.chatInfoClearHistoryTitle,
      message: l10n.chatInfoClearHistoryMessage,
      confirmLabel: l10n.chatInfoClearHistoryConfirm,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
      checkboxLabel: canClearForAll ? l10n.chatInfoClearHistoryForAll : null,
    );
    if (!mounted || !choice.confirmed) return;

    final error = await chats.clearHistory(
      api,
      chatId: _mediaChatId,
      lastEventTime: _lastEventTime,
      forAll: canClearForAll && choice.checked,
    );
    if (!mounted) return;
    showCustomNotification(context, error ?? l10n.chatInfoClearHistoryDone);
  }

  Future<void> _deleteChat() async {
    final choice = await showBlurredConfirm(
      context,
      title: l10n.chatInfoDeleteChatTitle,
      message: l10n.chatInfoDeleteChatMessage,
      confirmLabel: l10n.chatInfoDeleteChatConfirm,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
    );
    if (!mounted || !choice.confirmed) return;

    final error = await chats.deleteChat(
      api,
      chatId: _mediaChatId,
      lastEventTime: _lastEventTime,
      forAll: false,
    );
    if (!mounted) return;
    if (error != null) {
      showCustomNotification(context, error);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _toggleBlock() async {
    final peerId = _otherId;
    if (peerId == null) return;

    final block = !_blocked;
    if (block) {
      final choice = await showBlurredConfirm(
        context,
        title: l10n.chatInfoBlockConfirmTitle,
        message: l10n.chatInfoBlockConfirmMessage(_customName),
        confirmLabel: l10n.chatInfoConfirmYes,
        cancelLabel: l10n.chatInfoConfirmNo,
        destructive: true,
      );
      if (!mounted || !choice.confirmed) return;
    }

    final ok = await ContactsModule.setBlocked(api, peerId, block);
    if (!mounted) return;
    if (!ok) {
      showCustomNotification(context, l10n.chatInfoBlockFailed);
      return;
    }
    setState(() => _blocked = block);
    showCustomNotification(
      context,
      block ? l10n.chatInfoBlockDone : l10n.chatInfoUnblockDone,
    );
    if (block) await _openComplaintCard(peerId);
  }

  Future<void> _openComplaintCard(int peerId) async {
    if (!mounted) return;
    await showComplaintCard(
      context,
      title: l10n.chatInfoComplaintTitle,
      subtitle: l10n.chatInfoComplaintSubtitle,
      sendLabel: l10n.chatInfoComplaintSend,
      closeLabel: l10n.chatInfoComplaintClose,
      emptyLabel: l10n.chatInfoComplaintEmpty,
      loadReasons: () async {
        final reasons = await ComplaintsModule.reasonsFor(
          api,
          ComplaintsModule.userTypeId,
        );
        return reasons
            .map((r) => (id: r.reasonId, title: r.reasonTitle))
            .toList();
      },
      onSend: (reasonId) async {
        final ok = await ComplaintsModule.sendComplaint(
          api,
          reasonId: reasonId,
          typeId: ComplaintsModule.userTypeId,
          ids: [peerId],
        );
        if (!mounted) return ok;
        showCustomNotification(
          context,
          ok ? l10n.chatInfoComplaintSent : l10n.chatInfoComplaintFailed,
        );
        return ok;
      },
    );
  }

  Widget _actionBtn(
    ColorScheme cs,
    IconData icon,
    String label, [
    VoidCallback? onTap,
  ]) {
    return Expanded(
      child: GlossyPill(
        onTap: onTap,
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 10),
        depth: 6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: cs.onSurface, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideActionBtn(
    ColorScheme cs,
    IconData icon,
    String label, [
    VoidCallback? onTap,
  ]) {
    return GlossyPill(
      onTap: onTap,
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      depth: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: cs.primary, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersistentInfo(ColorScheme cs) {
    final items = <Widget>[];

    if (widget.chatType == 'DIALOG') {
      if (_isBot) {
        final link = _contactData?.raw['link'] as String?;
        if (link != null && link.isNotEmpty) {
          items.add(
            _simpleInfoCard(
              cs,
              l10n.contactProfileInfoLink,
              link,
              isLink: true,
            ),
          );
        }
      } else {
        final phone = _contactData?.raw['phone'];
        final phoneInt = phone is int
            ? phone
            : int.tryParse(phone?.toString() ?? '');
        if (phoneInt != null && phoneInt > 0) {
          items.add(
            _simpleInfoCard(cs, l10n.loginPhoneNumber, formatPhone(phoneInt)!),
          );
        }
        final bio =
            (_contactData?.raw['description'] as String?) ??
            (_contactData?.raw['about'] as String?);
        if (bio != null && bio.isNotEmpty) {
          if (items.isNotEmpty) items.add(const SizedBox(height: 8));
          items.add(_simpleInfoCard(cs, l10n.chatInfoBio, bio));
        }
      }
    } else if (widget.chatType == 'CHANNEL') {
      final link = _chatInfo?.link;
      if (link != null && link.isNotEmpty) {
        items.add(_linkCard(cs, link));
      }
      final desc = _chatInfo?.description;
      if (desc != null && desc.isNotEmpty) {
        if (items.isNotEmpty) items.add(const SizedBox(height: 8));
        items.add(_collapsibleDescCard(cs, desc));
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...items, const SizedBox(height: 16)],
      ),
    );
  }

  Widget _simpleInfoCard(
    ColorScheme cs,
    String label,
    String value, {
    bool isLink = false,
  }) {
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      depth: 6,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 4),
            FormattedMessageText(
              text: value,
              ranges: const [],
              entityMode: TextEntityMode.copy,
              style: TextStyle(
                color: isLink ? cs.primary : cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkCard(ColorScheme cs, String link) {
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      depth: 6,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatInfoInviteLink,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 4),
                FormattedMessageText(
                  text: link,
                  ranges: const [],
                  entityMode: TextEntityMode.copy,
                  style: TextStyle(color: cs.primary, fontSize: 15),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.qr_code_2, color: cs.primary, size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _collapsibleDescCard(ColorScheme cs, String desc) {
    const int collapsedLines = 3;
    final isLong = desc.length > 120;

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(16),
      depth: 6,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.contactProfileInfoDescription,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 4),
            FormattedMessageText(
              text: desc,
              ranges: const [],
              entityMode: TextEntityMode.copy,
              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.4),
              maxLines: (_descExpanded || !isLong) ? null : collapsedLines,
              overflow: (_descExpanded || !isLong)
                  ? null
                  : TextOverflow.ellipsis,
            ),
            if (isLong) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _descExpanded = !_descExpanded),
                child: Text(
                  _descExpanded ? l10n.chatInfoCollapse : l10n.chatInfoShowMore,
                  style: TextStyle(color: cs.primary, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final delta = event.scrollDelta.dy != 0
                  ? event.scrollDelta.dy
                  : event.scrollDelta.dx;
              _tabScrollController.animateTo(
                (_tabScrollController.offset + delta).clamp(
                  _tabScrollController.position.minScrollExtent,
                  _tabScrollController.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
              );
            }
          },
          child: SingleChildScrollView(
            controller: _tabScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _tabs.length; i++) ...[
                    _tabChip(cs, _tabs[i]),
                    if (i < _tabs.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabChip(ColorScheme cs, String tab) {
    final selected = tab == _selectedTab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tab,
          style: TextStyle(
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme cs) {
    if (_selectedTab.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(key: ValueKey(_selectedTab), child: _tabBody(cs)),
    );
  }

  Widget _tabBody(ColorScheme cs) {
    if (_selectedTab == 'Info') return _buildInfoTabContent(cs);
    if (_selectedTab == l10n.chatInfoTabMembers) {
      return _buildMembersTabContent(cs);
    }
    if (_selectedTab == l10n.chatInfoTabGeneralChats) {
      final peerId = _otherId;
      if (peerId == null) {
        return _buildPlaceholder(
          cs,
          l10n.chatInfoEmptyGeneralChats,
          Icons.group,
        );
      }
      return CommonChatsTab(
        key: const ValueKey('tab-common-chats'),
        userId: peerId,
        emptyLabel: l10n.chatInfoEmptyGeneralChats,
      );
    }
    if (_selectedTab == l10n.chatInfoTabMedia) {
      return _sharedTab(
        cs,
        SharedContentKind.media,
        l10n.chatInfoEmptyMedia,
        Icons.photo_library,
      );
    }
    if (_selectedTab == l10n.chatInfoTabFiles) {
      return _sharedTab(
        cs,
        SharedContentKind.files,
        l10n.chatInfoEmptyFiles,
        Icons.description,
      );
    }
    if (_selectedTab == l10n.chatInfoTabVoice) {
      return _sharedTab(
        cs,
        SharedContentKind.voice,
        l10n.chatInfoEmptyVoice,
        Icons.mic,
      );
    }
    if (_selectedTab == l10n.chatInfoTabLinks) {
      return _sharedTab(
        cs,
        SharedContentKind.links,
        l10n.chatInfoEmptyLinks,
        Icons.link,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _sharedTab(
    ColorScheme cs,
    SharedContentKind kind,
    String emptyLabel,
    IconData emptyIcon,
  ) {
    final anchor = _anchorMsgId;
    if (anchor == null) return _buildPlaceholder(cs, emptyLabel, emptyIcon);
    return SharedMediaTab(
      key: ValueKey('tab-shared-$kind'),
      chatId: _mediaChatId,
      anchorMessageId: anchor,
      myId: _myId,
      sourceName: widget.name,
      kind: kind,
      emptyLabel: emptyLabel,
      emptyIcon: emptyIcon,
      onGoToMessage: _goToMessage,
      scrollController: _bodyScrollController,
    );
  }

  void _goToMessage(String messageId, int time) {
    final jumpInParent = widget.onJumpToMessage;
    if (jumpInParent != null && _mediaChatId == widget.chatId) {
      jumpInParent(messageId, time);
      return;
    }
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: _mediaChatId,
        name: widget.name,
        imageUrl: widget.imageUrl,
        chatType: widget.chatType,
        initialMessageId: messageId,
        initialMessageTime: time,
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme cs, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTabContent(ColorScheme cs) {
    final items = <Widget>[];

    if (widget.chatType == 'CHAT') {
      final desc = _chatInfo?.description;
      if (desc != null && desc.isNotEmpty) {
        items
          ..add(_infoCard(cs, l10n.contactProfileInfoDescription, desc))
          ..add(const SizedBox(height: 8));
      }
    }

    items.add(_buildInfoRowsCard(cs));

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }

  Widget _buildInfoRowsCard(ColorScheme cs) {
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      depth: 6,
      child: _buildAllInfoRows(cs),
    );
  }

  Widget _infoCard(ColorScheme cs, String label, String value) {
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      depth: 6,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTabContent(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _memberAction(
            cs,
            Icons.person_add,
            l10n.chatInfoAddMember,
            _openAddMembers,
          ),
          if (_inviteLink != null) ...[
            _listDivider(cs),
            _memberAction(
              cs,
              Icons.link,
              l10n.chatInfoInviteByLink,
              () => _openInviteLink(_inviteLink!),
            ),
          ],
          ..._members.expand((m) => [_listDivider(cs), _memberTile(cs, m)]),
          if (_membersLoading || !_membersEnd) ...[
            _listDivider(cs),
            _membersFooter(cs),
          ],
        ],
      ),
    );
  }

  Widget _membersFooter(ColorScheme cs) {
    if (_membersLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _fetchMembersPage(),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.expand_more, color: cs.primary, size: 26),
            const SizedBox(width: 14),
            Text(
              l10n.chatInfoShowMore,
              style: TextStyle(color: cs.primary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberAction(
    ColorScheme cs,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: cs.primary, size: 26),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: cs.onSurface, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _listDivider(ColorScheme cs) => Divider(
    height: 1,
    indent: 56,
    endIndent: 0,
    color: cs.outlineVariant.withValues(alpha: 0.3),
  );

  Widget _memberTile(ColorScheme cs, _MemberInfo member) {
    final name =
        member.name ??
        ContactCache.get(member.id) ??
        (member.isMe ? l10n.callParticipantYou : '${member.id}');
    final avatar = member.avatarUrl ?? ContactCache.getAvatar(member.id);

    final String sublabel;
    if (member.blocked) {
      sublabel = l10n.chatInfoMemberDeleted;
    } else if (member.isMe) {
      sublabel = l10n.callParticipantYou;
    } else if (member.presenceStatus == 1) {
      sublabel = l10n.contactProfileOnline;
    } else if (member.presenceStatus == 2 || member.presenceStatus == 3) {
      sublabel = l10n.contactProfileRecentlyActive;
    } else if (member.seenTime != null && member.seenTime! > 0) {
      sublabel = formatLastSeen(member.seenTime!);
    } else {
      sublabel = l10n.contactProfileRecentlyActive;
    }

    final String? roleLabel = member.isOwner
        ? l10n.chatInfoRoleOwner
        : (member.isAdmin ? l10n.chatInfoRoleAdmin : null);

    return InkWell(
      onTap: member.isMe
          ? null
          : () => openContactDialogProfile(
              context,
              contactId: member.id,
              name: name,
              avatarUrl: avatar,
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (member.blocked)
              _ghostAvatar()
            else if (avatar != null && avatar.isNotEmpty)
              CircleAvatar(
                radius: 22,
                backgroundImage: CachedNetworkImageProvider(
                  avatar,
                  maxWidth: 144,
                  maxHeight: 144,
                ),
                backgroundColor: cs.primaryContainer,
              )
            else
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: cs.onPrimaryContainer, fontSize: 16),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (member.alias != null)
              _memberTag(cs, member.alias!)
            else if (roleLabel != null)
              Text(
                roleLabel,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ghostAvatar({double radius = 22, double fontSize = 24}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFD4D4D4),
      child: Text('👻', style: TextStyle(fontSize: fontSize)),
    );
  }

  Widget _memberTag(ColorScheme cs, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAllInfoRows(ColorScheme cs) {
    final rows = <({String label, String value})>[];
    final chat = _chatInfo?.raw;
    if (chat == null) {
      return Text(
        l10n.chatInfoNoData,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      );
    }

    void add(String label, dynamic val, {bool tsFormat = false}) {
      if (val == null) return;
      if (val is bool && !val) return;
      String str;
      if (tsFormat && val is int && val > 1) {
        str = formatDateTimeNumeric(DateTime.fromMillisecondsSinceEpoch(val));
      } else if (val is bool) {
        str = l10n.callValueYes;
      } else {
        str = val.toString();
      }
      if (str.isEmpty) return;
      rows.add((label: label, value: str));
    }

    final type = widget.chatType;
    add(l10n.chatInfoRowId, chat['id']);

    if (type == 'DIALOG') {
      add(l10n.chatInfoRowCreated, chat['created'], tsFormat: true);
      add(l10n.chatInfoRowModified, chat['modified'], tsFormat: true);
      add(l10n.callInfoStatus, chat['status']);
    }

    if (type == 'CHAT') {
      add(l10n.chatInfoRowMembersCount, chat['participantsCount']);
      final owner = chat['owner'] as int?;
      if (owner != null && owner != 0) {
        add(l10n.chatInfoRowOwner, ContactCache.get(owner) ?? '$owner');
      }
      add(l10n.chatInfoRowCreatedGroup, chat['created'], tsFormat: true);
      add(
        l10n.chatInfoRowJoined,
        (chat['joinTime'] as int?) != null && (chat['joinTime'] as int) > 1
            ? chat['joinTime']
            : null,
        tsFormat: true,
      );
      add(l10n.chatInfoRowModifiedGroup, chat['modified'], tsFormat: true);
      add(l10n.chatInfoRowHasBots, chat['hasBots'] as bool?);
      final blocked = chat['blockedParticipantsCount'] as int?;
      if (blocked != null && blocked > 0) {
        add(l10n.chatInfoRowBlockedCount, blocked);
      }
      final opts = chat['options'] as Map?;
      add(l10n.chatInfoRowOfficialGroup, opts?['OFFICIAL'] as bool?);
      add(l10n.chatInfoRowSignAdmin, opts?['SIGN_ADMIN'] as bool?);
      add(l10n.callInfoStatus, chat['status']);
    }

    if (type == 'CHANNEL') {
      add(l10n.chatInfoRowSubscribersCount, chat['participantsCount']);
      add(l10n.chatInfoRowCreated, chat['created'], tsFormat: true);
      add(l10n.chatInfoRowModified, chat['modified'], tsFormat: true);
      final opts = chat['options'] as Map?;
      add(l10n.chatInfoRowOfficialChannel, opts?['OFFICIAL'] as bool?);
      add(l10n.chatInfoRowComments, opts?['COMMENTS'] as bool?);
      add(l10n.chatInfoRowRkn, opts?['A_PLUS_CHANNEL'] as bool?);
      add(l10n.chatInfoRowSignAdmin, opts?['SIGN_ADMIN'] as bool?);
      add(
        l10n.chatInfoRowOnlyAdmin,
        opts?['ONLY_ADMIN_CAN_ADD_MEMBER'] as bool?,
      );
      add(l10n.callInfoStatus, chat['status']);
    }

    if (rows.isEmpty) {
      return Text(
        l10n.chatInfoNoData,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      );
    }

    final extraRows = _buildExtraContactRows();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _infoRow(
              cs,
              rows[i].label,
              rows[i].value,
              trailing: _trailingFor(rows[i].label, cs),
            ),
            if (i < rows.length - 1 ||
                (_extraContactExpanded && extraRows.isNotEmpty))
              Divider(
                height: 10,
                color: cs.outlineVariant.withValues(alpha: 0.25),
              ),
          ],
          if (_extraContactExpanded)
            for (int i = 0; i < extraRows.length; i++) ...[
              _infoRow(cs, extraRows[i].label, extraRows[i].value),
              if (i < extraRows.length - 1)
                Divider(
                  height: 10,
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                ),
            ],
        ],
      ),
    );
  }

  List<({String label, String value})> _buildExtraContactRows() {
    final c = _contactData;
    if (c == null) return const [];
    final rows = <({String label, String value})>[];
    final reg = c.raw['registrationTime'];
    if (reg is int && reg > 0) {
      rows.add((
        label: l10n.contactProfileInfoRegistration,
        value: formatDateTimeNumeric(DateTime.fromMillisecondsSinceEpoch(reg)),
      ));
    }
    final upd = c.raw['updateTime'];
    if (upd is int && upd > 0) {
      rows.add((
        label: l10n.contactProfileInfoUpdated,
        value: formatDateTimeNumeric(DateTime.fromMillisecondsSinceEpoch(upd)),
      ));
    }
    final country = c.raw['country'];
    if (country is String && country.isNotEmpty) {
      rows.add((label: l10n.contactProfileInfoCountry, value: country));
    }
    final gender = c.raw['gender'];
    if (gender is int) {
      final g = formatGender(gender);
      if (g != null) rows.add((label: l10n.contactProfileInfoGender, value: g));
    }
    final phone = c.raw['phone'];
    if (phone is int && phone > 0) {
      rows.add((label: l10n.contactProfileInfoPhone, value: '+$phone'));
    } else if (phone is String && phone.isNotEmpty && phone != '***') {
      rows.add((label: l10n.contactProfileInfoPhone, value: phone));
    }
    final accStatus = c.raw['accountStatus'];
    if (accStatus is int && accStatus != 0) {
      rows.add((
        label: l10n.contactProfileInfoAccountStatus,
        value: accStatus.toString(),
      ));
    }
    final opts = c.raw['options'];
    if (opts is List && opts.isNotEmpty) {
      rows.add((
        label: l10n.contactProfileInfoFlags,
        value: opts.whereType<String>().join(', '),
      ));
    }
    final link = c.raw['link'];
    if (link is String && link.isNotEmpty) {
      rows.add((label: l10n.contactProfileInfoLink, value: link));
    }
    return rows;
  }

  Widget? _trailingFor(String label, ColorScheme cs) {
    if (label != l10n.chatInfoRowId) return null;
    if (widget.chatType != 'DIALOG') return null;
    if (_contactData == null) return null;
    return IconButton(
      tooltip: _extraContactExpanded
          ? l10n.chatInfoHideExtra
          : l10n.chatInfoShowMoreExtra,
      icon: AnimatedRotation(
        turns: _extraContactExpanded ? 0.125 : 0,
        duration: const Duration(milliseconds: 220),
        child: Icon(Symbols.add_circle, color: cs.primary, size: 22),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () =>
          setState(() => _extraContactExpanded = !_extraContactExpanded),
    );
  }

  Widget _infoRow(
    ColorScheme cs,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _avatar() {
    const size = 96.0;
    final peerId = widget.chatType == 'DIALOG' ? _otherId : null;
    final hasHistory =
        peerId != null && widget.imageUrl.isNotEmpty && !_peerDeleted;
    return ProfileHeroAvatar(
      tag: widget.heroTag,
      size: size,
      child: GestureDetector(
        onTap: hasHistory
            ? () => AvatarHistoryScreen.open(
                context,
                contactId: peerId,
                name: widget.name,
                currentAvatarUrl: widget.imageUrl,
              )
            : null,
        child: _peerDeleted
            ? _ghostAvatar(radius: size / 2, fontSize: 52)
            : KometAvatar(
                name: widget.name,
                imageUrl: widget.imageUrl,
                size: size,
                fontSize: 36,
                fadeIn: false,
              ),
      ),
    );
  }

  List<Widget> _loadingBlocks(ColorScheme cs) {
    Widget block(double w, double h, {double r = 8}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return [
      const SizedBox(height: 4),
      block(110, 16, r: 6),
      const SizedBox(height: 24),
      block(240, 54, r: 14),
      const SizedBox(height: 16),
      block(double.infinity, 36, r: 20),
      const SizedBox(height: 12),
      block(double.infinity, 120, r: 14),
    ];
  }
}
