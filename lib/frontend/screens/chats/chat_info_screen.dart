import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../core/config/app_show_extra_info.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../widgets/avatar_hero.dart';
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

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    this.dialogPeerId,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final _tabScrollController = ScrollController();
  final _avatarHeroKey = GlobalKey();

  int _myId = 0;
  bool _isLoading = true;
  bool _extraContactExpanded = false;
  Map<String, dynamic>? _chatData;
  String _selectedTab = '';
  bool _descExpanded = false;

  // DIALOG
  int? _otherId;
  Map<String, dynamic>? _contactData;
  int? _seenTime;
  bool _isOnline = false;
  int _presenceStatus = 0;
  bool _isBot = false;

  // CHAT
  List<_MemberInfo> _members = [];
  int _onlineCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  List<String> get _tabs {
    final showInfo = AppShowExtraInfo.current.value;
    switch (widget.chatType) {
      case 'DIALOG':
        if (_isBot) {
          return [
            if (showInfo) 'Info',
            'Медиа',
            'Файлы',
            'Голосовые',
            'Ссылки',
          ];
        }
        return [
          'Общие чаты',
          'Медиа',
          if (showInfo) 'Info',
          'Файлы',
          'Голосовые',
          'Ссылки',
        ];
      case 'CHAT':
        return [
          'Участники',
          if (showInfo) 'Info',
          'Медиа',
          'Файлы',
          'Голосовые',
          'Ссылки',
        ];
      case 'CHANNEL':
        return [
          if (showInfo) 'Info',
          'Медиа',
          'Файлы',
          'Голосовые',
          'Ссылки',
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
    _chatData = info;

    if (widget.chatType == 'DIALOG') {
      _otherId = widget.dialogPeerId;
      if (_otherId == null && info != null) {
        final parts = info['participants'] as Map? ?? {};
        for (final key in parts.keys) {
          final id = key is int ? key : int.tryParse(key.toString());
          if (id != null && id != _myId) {
            _otherId = id;
            break;
          }
        }
      }

      if (_otherId != null) {
        final contact = await ContactInfoFetch.get(_otherId!);
        if (contact != null) {
          _contactData = contact;
          final opts = _contactData!['options'];
          _isBot = (opts is List) && opts.contains('BOT');
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
      final parts = _chatData!['participants'] as Map? ?? {};
      final admins = _chatData!['adminParticipants'] as Map? ?? {};
      final owner = _chatData!['owner'] as int?;

      final memberIds = <int>[];
      for (final k in parts.keys) {
        final id = k is int ? k : int.tryParse(k.toString());
        if (id != null) memberIds.add(id);
      }

      Map<int, Map<String, dynamic>> presenceMap = {};
      if (memberIds.isNotEmpty) {
        presenceMap = await PresenceFetch.getMany(memberIds);
      }

      _onlineCount = 0;
      _members = memberIds.map((id) {
        final pres = presenceMap[id];
        final online = (pres?['status'] as int?) == 1;
        if (online) _onlineCount++;
        final isAdmin =
            admins.containsKey(id.toString()) || admins.containsKey(id);
        return _MemberInfo(
          id: id,
          isAdmin: isAdmin,
          isOwner: id == owner,
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
        if (_selectedTab.isEmpty && _tabs.isNotEmpty) _selectedTab = _tabs.first;
      });
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

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
          _heroAvatar(),
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

  // ─── SUBTITLE ────────────────────────────────────────────────────────────

  String _subtitle() {
    switch (widget.chatType) {
      case 'DIALOG':
        if (_isBot) return 'Бот';
        if (_isOnline) return 'В сети';
        if (_presenceStatus == 3) return 'был(-а) недавно';
        if (_seenTime != null && _seenTime! > 0) {
          return 'был(-а) ${_formatLastSeen(_seenTime!)}';
        }
        return '';
      case 'CHAT':
        final total =
            (_chatData?['participantsCount'] as int?) ?? _members.length;
        if (_onlineCount > 0) return '$_onlineCount из $total в сети';
        return _pluralCount(total, 'участник', 'участника', 'участников');
      case 'CHANNEL':
        final count = (_chatData?['participantsCount'] as int?) ?? 0;
        return _pluralCount(count, 'подписчик', 'подписчика', 'подписчиков');
      default:
        return '';
    }
  }

  // ─── ACTION BUTTONS ──────────────────────────────────────────────────────

  Widget _buildActions(ColorScheme cs) {
    final List<({IconData icon, String label, VoidCallback? onTap})> btns;

    if (widget.chatType == 'DIALOG') {
      if (_isBot) {
        btns = [
          (icon: Icons.chat_bubble, label: 'Чат', onTap: _openChat),
          (icon: Icons.notifications, label: 'Звук', onTap: null),
        ];
      } else {
        btns = [
          (icon: Icons.chat_bubble, label: 'Чат', onTap: _openChat),
          (icon: Icons.notifications, label: 'Звук', onTap: null),
          (icon: Icons.call, label: 'Звонок', onTap: null),
        ];
      }
    } else if (widget.chatType == 'CHANNEL') {
      btns = [
        (icon: Icons.notifications, label: 'Звук', onTap: null),
        (icon: Icons.exit_to_app, label: 'Покинуть', onTap: null),
      ];
    } else {
      btns = [
        (icon: Icons.chat_bubble, label: 'Чат', onTap: null),
        (icon: Icons.notifications, label: 'Звук', onTap: null),
        (icon: Icons.exit_to_app, label: 'Покинуть', onTap: null),
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

  // ─── PERSISTENT INFO (shown above tabs for all types) ────────────────────

  Widget _buildPersistentInfo(ColorScheme cs) {
    final items = <Widget>[];

    if (widget.chatType == 'DIALOG') {
      if (_isBot) {
        final link = _contactData?['link'] as String?;
        if (link != null && link.isNotEmpty) {
          items.add(_simpleInfoCard(cs, 'Ссылка', link, isLink: true));
        }
      } else {
        final phone = _contactData?['phone'];
        final phoneInt = phone is int
            ? phone
            : int.tryParse(phone?.toString() ?? '');
        if (phoneInt != null && phoneInt > 0) {
          items.add(
            _simpleInfoCard(cs, 'Номер телефона', formatPhone(phoneInt)!),
          );
        }
        final bio =
            (_contactData?['description'] as String?) ??
            (_contactData?['about'] as String?);
        if (bio != null && bio.isNotEmpty) {
          if (items.isNotEmpty) items.add(const SizedBox(height: 8));
          items.add(_simpleInfoCard(cs, 'О себе', bio));
        }
      }
    } else if (widget.chatType == 'CHANNEL') {
      final link = _chatData?['link'] as String?;
      if (link != null && link.isNotEmpty) {
        items.add(_linkCard(cs, link));
      }
      final desc = _chatData?['description'] as String?;
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
                color: isLink ? const Color(0xFF007AFF) : cs.onSurface,
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
                  'Ссылка-приглашение',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  link,
                  style: const TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.qr_code_2,
              color: Color(0xFF007AFF),
              size: 22,
            ),
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
              'Описание',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.4),
              maxLines: (_descExpanded || !isLong) ? null : collapsedLines,
              overflow:
                  (_descExpanded || !isLong) ? null : TextOverflow.ellipsis,
            ),
            if (isLong) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _descExpanded = !_descExpanded),
                child: Text(
                  _descExpanded ? 'Свернуть' : 'Ещё',
                  style:
                      const TextStyle(color: Color(0xFF007AFF), fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── TAB BAR ─────────────────────────────────────────────────────────────

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

  // ─── TAB CONTENT ─────────────────────────────────────────────────────────

  Widget _buildTabContent(ColorScheme cs) {
    if (_selectedTab.isEmpty) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(key: ValueKey(_selectedTab), child: _tabBody(cs)),
    );
  }

  Widget _tabBody(ColorScheme cs) {
    switch (_selectedTab) {
      case 'Info':
        return _buildInfoTabContent(cs);
      case 'Участники':
        return _buildMembersTabContent(cs);
      case 'Общие чаты':
        return _buildPlaceholder(cs, 'Нет общих чатов', Icons.group);
      case 'Медиа':
        return _buildPlaceholder(cs, 'Нет медиа', Icons.photo_library);
      case 'Файлы':
        return _buildPlaceholder(cs, 'Нет файлов', Icons.description);
      case 'Голосовые':
        return _buildPlaceholder(cs, 'Нет голосовых', Icons.mic);
      case 'Ссылки':
        return _buildPlaceholder(cs, 'Нет ссылок', Icons.link);
      default:
        return const SizedBox.shrink();
    }
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

  // ─── INFO TAB ────────────────────────────────────────────────────────────

  Widget _buildInfoTabContent(ColorScheme cs) {
    final items = <Widget>[];

    if (widget.chatType == 'CHAT') {
      final desc = _chatData?['description'] as String?;
      if (desc != null && desc.isNotEmpty) {
        items
          ..add(_infoCard(cs, 'Описание', desc))
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

  // ─── MEMBERS TAB ─────────────────────────────────────────────────────────

  Widget _buildMembersTabContent(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _memberAction(cs, Icons.person_add, 'Добавить участника', () {}),
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
            Icon(icon, color: const Color(0xFF007AFF), size: 26),
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
        ContactCache.get(member.id) ?? (member.isMe ? 'Вы' : '${member.id}');
    final avatar = ContactCache.getAvatar(member.id);

    final String sublabel;
    if (member.isMe) {
      sublabel = 'Вы';
    } else if (member.isOnline) {
      sublabel = 'В сети';
    } else if (member.seenTime != null) {
      sublabel = _formatLastSeen(member.seenTime!);
    } else {
      sublabel = 'Был(-а) недавно';
    }

    final String? roleLabel = member.isOwner
        ? 'владелец'
        : (member.isAdmin ? 'Адмін' : null);

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

  // ─── INFO ROWS ────────────────────────────────────────────────────────────

  Widget _buildAllInfoRows(ColorScheme cs) {
    final rows = <({String label, String value})>[];
    final chat = _chatData;
    if (chat == null) {
      return Text(
        'Нет данных',
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
        str = 'да';
      } else {
        str = val.toString();
      }
      if (str.isEmpty) return;
      rows.add((label: label, value: str));
    }

    final type = widget.chatType;
    add('ID чата', chat['id']);

    if (type == 'DIALOG') {
      add('Создан', chat['created'], tsFormat: true);
      add('Изменён', chat['modified'], tsFormat: true);
      add('Статус', chat['status']);
    }

    if (type == 'CHAT') {
      add('Участников', chat['participantsCount']);
      final owner = chat['owner'] as int?;
      if (owner != null && owner != 0) {
        add('Владелец', ContactCache.get(owner) ?? '$owner');
      }
      add('Создана', chat['created'], tsFormat: true);
      add(
        'Вступил',
        (chat['joinTime'] as int?) != null && (chat['joinTime'] as int) > 1
            ? chat['joinTime']
            : null,
        tsFormat: true,
      );
      add('Изменена', chat['modified'], tsFormat: true);
      add('Есть боты', chat['hasBots'] as bool?);
      final blocked = chat['blockedParticipantsCount'] as int?;
      if (blocked != null && blocked > 0) add('Заблокировано', blocked);
      final opts = chat['options'] as Map?;
      add('Официальная', opts?['OFFICIAL'] as bool?);
      add('Подпись адм.', opts?['SIGN_ADMIN'] as bool?);
      add('Статус', chat['status']);
    }

    if (type == 'CHANNEL') {
      add('Подписчиков', chat['participantsCount']);
      add('Создан', chat['created'], tsFormat: true);
      add('Изменён', chat['modified'], tsFormat: true);
      final opts = chat['options'] as Map?;
      add('Официальный', opts?['OFFICIAL'] as bool?);
      add('Комментарии', opts?['COMMENTS'] as bool?);
      add('РКН', opts?['A_PLUS_CHANNEL'] as bool?);
      add('Подпись адм.', opts?['SIGN_ADMIN'] as bool?);
      add('Только адм.', opts?['ONLY_ADMIN_CAN_ADD_MEMBER'] as bool?);
      add('Статус', chat['status']);
    }

    if (rows.isEmpty) {
      return Text(
        'Нет данных',
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
    final reg = c['registrationTime'];
    if (reg is int && reg > 0) {
      rows.add((
        label: 'Регистрация',
        value: formatDateTimeNumeric(DateTime.fromMillisecondsSinceEpoch(reg)),
      ));
    }
    final upd = c['updateTime'];
    if (upd is int && upd > 0) {
      rows.add((
        label: 'Обновлён',
        value: formatDateTimeNumeric(DateTime.fromMillisecondsSinceEpoch(upd)),
      ));
    }
    final country = c['country'];
    if (country is String && country.isNotEmpty) {
      rows.add((label: 'Страна', value: country));
    }
    final gender = c['gender'];
    if (gender is int) {
      final g = formatGender(gender);
      if (g != null) rows.add((label: 'Пол', value: g));
    }
    final phone = c['phone'];
    if (phone is int && phone > 0) {
      rows.add((label: 'Телефон', value: '+$phone'));
    } else if (phone is String && phone.isNotEmpty && phone != '***') {
      rows.add((label: 'Телефон', value: phone));
    }
    final accStatus = c['accountStatus'];
    if (accStatus is int && accStatus != 0) {
      rows.add((label: 'Статус аккаунта', value: accStatus.toString()));
    }
    final opts = c['options'];
    if (opts is List && opts.isNotEmpty) {
      rows.add((label: 'Флаги', value: opts.whereType<String>().join(', ')));
    }
    final link = c['link'];
    if (link is String && link.isNotEmpty) {
      rows.add((label: 'Ссылка', value: link));
    }
    return rows;
  }

  Widget? _trailingFor(String label, ColorScheme cs) {
    if (label != 'ID чата') return null;
    if (widget.chatType != 'DIALOG') return null;
    if (_contactData == null) return null;
    return IconButton(
      tooltip: _extraContactExpanded ? 'Скрыть' : 'Подробнее',
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

  // ─── SHIMMER ─────────────────────────────────────────────────────────────

  Widget _heroAvatar() {
    return AvatarHero(
      key: _avatarHeroKey,
      tag: 'chatAvatar_${widget.chatId}',
      name: widget.name,
      imageUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
      child: KometAvatar(
        name: widget.name,
        imageUrl: widget.imageUrl,
        size: 96,
        fontSize: 36,
      ),
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
        Center(
          child: AvatarHero(
            key: _avatarHeroKey,
            tag: 'chatAvatar_${widget.chatId}',
            name: widget.name,
            imageUrl: widget.imageUrl.isNotEmpty ? widget.imageUrl : null,
            child: block(96, 96, r: 48),
          ),
        ),
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

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _formatLastSeen(int secondsSinceEpoch) {
    final diff =
        DateTime.now().millisecondsSinceEpoch - secondsSinceEpoch * 1000;
    if (diff < 60000) return 'только что';
    if (diff < 3600000) return '${diff ~/ 60000} мин назад';
    if (diff < 86400000) return '${diff ~/ 3600000} ч назад';
    if (diff < 604800000) return '${diff ~/ 86400000} д назад';
    return 'давно';
  }

  String _pluralCount(int n, String one, String few, String many) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$n $many';
    if (mod10 == 1) return '$n $one';
    if (mod10 >= 2 && mod10 <= 4) return '$n $few';
    return '$n $many';
  }
}
