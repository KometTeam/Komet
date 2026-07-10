import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../core/config/app_show_extra_info.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chat_info.dart';
import '../../../models/contact_info.dart';
import '../../widgets/avatar_history_screen.dart';
import '../../widgets/chat_info/shared_content_tabs.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/swipe_route.dart';
import 'chat_screen.dart';

class _MemberInfo {
  final int id;
  final bool isAdmin;
  final bool isOwner;
  final bool isMe;
  final int? seenTime;
  final bool isOnline;

  const _MemberInfo({
    required this.id,
    required this.isAdmin,
    required this.isOwner,
    required this.isMe,
    this.seenTime,
    required this.isOnline,
  });
}

class ChatInfoScreen extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  final int? dialogPeerId;

  final void Function(String messageId, int time)? onJumpToMessage;

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.dialogPeerId,
    this.onJumpToMessage,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final _tabScrollController = ScrollController();
  final _bodyScrollController = ScrollController();

  int _myId = 0;
  bool _isLoading = true;
  bool _extraContactExpanded = false;
  ChatInfo? _chatInfo;
  String _selectedTab = '';
  bool _descExpanded = false;

  int? _otherId;
  ContactInfo? _contactData;
  int? _seenTime;
  bool _isOnline = false;
  int _presenceStatus = 0;
  bool _isBot = false;

  List<_MemberInfo> _members = [];
  int _onlineCount = 0;

  int _mediaChatId = 0;
  String? _anchorMsgId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _bodyScrollController.dispose();
    super.dispose();
  }

  List<String> get _tabs {
    final l10n = AppLocalizations.of(context)!;
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

  Future<void> _load() async {
    final profile = await AppDatabase.loadActiveProfile();
    _myId = profile?.id ?? 0;

    final info = await ChatInfoFetch.get(widget.chatId);
    if (!mounted) return;
    _chatInfo = info;

    _mediaChatId = (info?.raw['id'] as int?) ?? widget.chatId;
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
      }
    } else if (info == null) {
      setState(() => _isLoading = false);
      return;
    } else if (widget.chatType == 'CHAT') {
      final chatInfo = _chatInfo!;
      final memberIds = chatInfo.participantIds;

      Map<int, Map<String, dynamic>> presenceMap = {};
      if (memberIds.isNotEmpty) {
        presenceMap = await PresenceFetch.getMany(memberIds);
      }

      _onlineCount = 0;
      _members = memberIds.map((id) {
        final pres = presenceMap[id];
        final online = (pres?['status'] as int?) == 1;
        if (online) _onlineCount++;
        return _MemberInfo(
          id: id,
          isAdmin: chatInfo.isAdmin(id),
          isOwner: chatInfo.isOwner(id),
          isMe: id == _myId,
          seenTime: pres?['seen'] as int?,
          isOnline: online,
        );
      }).toList();

      _members.sort((a, b) {
        if (a.isMe != b.isMe) return a.isMe ? -1 : 1;
        if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
        return (b.seenTime ?? 0).compareTo(a.seenTime ?? 0);
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_selectedTab.isEmpty && _tabs.isNotEmpty) {
          _selectedTab = _tabs.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      body: SafeArea(
        child: _isLoading ? _buildShimmer(cs) : _buildScrollBody(cs),
      ),
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
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: cs.onSurface),
              onPressed: () {},
            ),
          ],
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
          Text(
            widget.name,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle(),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
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
      ),
    );
  }

  String _subtitle() {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.chatType) {
      case 'DIALOG':
        if (_isBot) return l10n.contactProfileBot;
        if (_isOnline) return l10n.contactProfileOnline;
        if (_presenceStatus == 2 || _presenceStatus == 3) return l10n.contactProfileRecentlyActive;
        if (_seenTime != null && _seenTime! > 0) {
          return formatLastSeen(_seenTime!);
        }
        return '';
      case 'CHAT':
        final total = _chatInfo?.participantsCount ?? _members.length;
        if (_onlineCount > 0) {
          return l10n.chatInfoOnlineOfTotal('$_onlineCount', '$total');
        }
        return '$total ${pluralRu(total, 'участник', 'участника', 'участников')}';
      case 'CHANNEL':
        final count = _chatInfo?.participantsCount ?? 0;
        return '$count ${pluralRu(count, 'подписчик', 'подписчика', 'подписчиков')}';
      default:
        return '';
    }
  }

  Widget _buildActions(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final List<({IconData icon, String label, VoidCallback? onTap})> btns;

    if (widget.chatType == 'DIALOG') {
      if (_isBot) {
        btns = [
          (
            icon: Icons.chat_bubble,
            label: l10n.contactProfileActionChat,
            onTap: _openChat,
          ),
          (
            icon: Icons.notifications,
            label: l10n.contactProfileActionSound,
            onTap: null,
          ),
        ];
      } else {
        btns = [
          (
            icon: Icons.chat_bubble,
            label: l10n.contactProfileActionChat,
            onTap: _openChat,
          ),
          (
            icon: Icons.notifications,
            label: l10n.contactProfileActionSound,
            onTap: null,
          ),
          (icon: Icons.call, label: l10n.contactProfileActionCall, onTap: null),
        ];
      }
    } else if (widget.chatType == 'CHANNEL') {
      btns = [
        (
          icon: Icons.notifications,
          label: l10n.contactProfileActionSound,
          onTap: null,
        ),
        (icon: Icons.exit_to_app, label: l10n.chatInfoActionLeave, onTap: null),
      ];
    } else {
      btns = [
        (
          icon: Icons.chat_bubble,
          label: l10n.contactProfileActionChat,
          onTap: null,
        ),
        (
          icon: Icons.notifications,
          label: l10n.contactProfileActionSound,
          onTap: null,
        ),
        (icon: Icons.exit_to_app, label: l10n.chatInfoActionLeave, onTap: null),
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (int i = 0; i < btns.length; i++) ...[
            _actionBtn(cs, btns[i].icon, btns[i].label, btns[i].onTap),
            if (i < btns.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  void _openChat() {
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: widget.chatId,
        name: widget.name,
        imageUrl: widget.imageUrl,
        chatType: 'DIALOG',
      ),
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

  Widget _buildPersistentInfo(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...items, const SizedBox(height: 16)],
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
            Text(
              value,
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(link, style: TextStyle(color: cs.primary, fontSize: 15)),
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
    final l10n = AppLocalizations.of(context)!;
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
            Text(
              desc,
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
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _memberAction(cs, Icons.person_add, l10n.chatInfoAddMember, () {}),
          ..._members.expand((m) => [_listDivider(cs), _memberTile(cs, m)]),
        ],
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
    final l10n = AppLocalizations.of(context)!;
    final name =
        ContactCache.get(member.id) ??
        (member.isMe ? l10n.callParticipantYou : '${member.id}');
    final avatar = ContactCache.getAvatar(member.id);

    final String sublabel;
    if (member.isMe) {
      sublabel = l10n.callParticipantYou;
    } else if (member.isOnline) {
      sublabel = l10n.contactProfileOnline;
    } else if (member.seenTime != null) {
      sublabel = formatLastSeen(member.seenTime!);
    } else {
      sublabel = l10n.contactProfileRecentlyActive;
    }

    final String? roleLabel = member.isOwner
        ? l10n.chatInfoRoleOwner
        : (member.isAdmin ? l10n.chatInfoRoleAdmin : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          (avatar != null && avatar.isNotEmpty)
              ? CircleAvatar(
                  radius: 22,
                  backgroundImage: CachedNetworkImageProvider(
                    avatar,
                    maxWidth: 144,
                    maxHeight: 144,
                  ),
                  backgroundColor: cs.primaryContainer,
                )
              : CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 16,
                    ),
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
          if (roleLabel != null)
            Text(
              roleLabel,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildAllInfoRows(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
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
    final avatar = KometAvatar(
      name: widget.name,
      imageUrl: widget.imageUrl,
      size: 96,
      fontSize: 36,
    );
    final peerId = widget.chatType == 'DIALOG' ? _otherId : null;
    if (peerId == null || widget.imageUrl.isEmpty) return avatar;
    return GestureDetector(
      onTap: () => AvatarHistoryScreen.open(
        context,
        contactId: peerId,
        name: widget.name,
        currentAvatarUrl: widget.imageUrl,
      ),
      child: avatar,
    );
  }

  Widget _buildShimmer(ColorScheme cs) {
    Widget block(double w, double h, {double r = 8}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
      children: [
        Center(child: block(96, 96, r: 48)),
        const SizedBox(height: 14),
        Center(child: block(160, 22, r: 8)),
        const SizedBox(height: 8),
        Center(child: block(110, 16, r: 6)),
        const SizedBox(height: 24),
        Center(child: block(240, 54, r: 14)),
        const SizedBox(height: 16),
        block(double.infinity, 36, r: 20),
        const SizedBox(height: 12),
        block(double.infinity, 120, r: 14),
      ],
    );
  }
}
