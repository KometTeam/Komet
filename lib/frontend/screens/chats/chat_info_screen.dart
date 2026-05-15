import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/protocol/opcode_map.dart';
import '../../../core/storage/app_database.dart';
import '../../../main.dart' as main;

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

  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  int _myId = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _chatData;

  // DIALOG
  int? _otherId;
  Map<String, dynamic>? _contactData;
  int? _seenTime;
  bool _isOnline = false;
  bool _isBot = false;

  bool _infoExpanded = false;

  // CHAT
  List<_MemberInfo> _members = [];
  int _onlineCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await AppDatabase.loadActiveProfile();
    _myId = profile?.id ?? 0;

    final packet = await main.api.sendRequest(
      Opcode.chatInfo,
      {'chatIds': [widget.chatId]},
    );
    if (!packet.isOk || !mounted) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final chats = (packet.payload as Map?)?['chats'] as List?;
    if (chats == null || chats.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _chatData = Map<String, dynamic>.from(chats.first as Map);

    if (widget.chatType == 'DIALOG') {
      final parts = _chatData!['participants'] as Map? ?? {};
      for (final key in parts.keys) {
        final id = key is int ? key : int.tryParse(key.toString());
        if (id != null && id != _myId) {
          _otherId = id;
          break;
        }
      }

      if (_otherId != null) {
        final cp = await main.api.sendRequest(
          Opcode.contactInfo,
          {'contactIds': [_otherId]},
        );
        if (cp.isOk) {
          final contacts = (cp.payload as Map?)?['contacts'] as List?;
          if (contacts != null && contacts.isNotEmpty) {
            _contactData = Map<String, dynamic>.from(contacts.first as Map);
            final opts = _contactData!['options'];
            _isBot = (opts is List) && opts.contains('BOT');
          }
        }

        final pp = await main.api.sendRequest(
          Opcode.contactPresence,
          {'contactIds': [_otherId]},
        );
        if (pp.isOk) {
          final presence = (pp.payload as Map?)?['presence'] as Map?;
          final p = presence?[_otherId.toString()] ?? presence?[_otherId];
          if (p is Map) {
            _seenTime = p['seen'] as int?;
            _isOnline = ((p['status'] as int?) ?? 0) > 0;
          }
        }
      }
    } else if (widget.chatType == 'CHAT') {
      final parts = _chatData!['participants'] as Map? ?? {};
      final admins = _chatData!['adminParticipants'] as Map? ?? {};
      final owner = _chatData!['owner'] as int?;

      final memberIds = <int>[];
      for (final k in parts.keys) {
        final id = k is int ? k : int.tryParse(k.toString());
        if (id != null) memberIds.add(id);
      }

      final Map<int, Map> presenceMap = {};
      if (memberIds.isNotEmpty) {
        final pp = await main.api.sendRequest(
          Opcode.contactPresence,
          {'contactIds': memberIds},
        );
        if (pp.isOk) {
          final presence = (pp.payload as Map?)?['presence'] as Map?;
          if (presence != null) {
            for (final e in presence.entries) {
              final id = e.key is int ? e.key as int : int.tryParse(e.key.toString());
              if (id != null && e.value is Map) presenceMap[id] = e.value as Map;
            }
          }
        }
      }

      _onlineCount = 0;
      _members = memberIds.map((id) {
        final pres = presenceMap[id];
        final online = ((pres?['status'] as int?) ?? 0) > 0;
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

    if (mounted) setState(() => _isLoading = false);
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bg = isDark ? Colors.black : cs.surface;

    return Scaffold(
      backgroundColor: bg,
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
            icon: Icon(Symbols.arrow_back, color: cs.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (widget.chatType == 'DIALOG' && !_isBot)
              IconButton(
                icon: Icon(Symbols.edit, color: cs.onSurface),
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
        children: [
          const SizedBox(height: 4),
          _buildAvatar(cs),
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
          LayoutBuilder(
            builder: (ctx, constraints) =>
                _buildInfoArea(cs, constraints.maxWidth),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ─── AVATAR ──────────────────────────────────────────────────────────────

  Widget _buildAvatar(ColorScheme cs) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
      child: widget.imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (context, error, stack) => _avatarLetters(cs),
              ),
            )
          : _avatarLetters(cs),
    );
  }

  Widget _avatarLetters(ColorScheme cs) => Center(
        child: Text(
          widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  // ─── SUBTITLE ────────────────────────────────────────────────────────────

  String _subtitle() {
    switch (widget.chatType) {
      case 'DIALOG':
        if (_isBot) {
          final link = _contactData?['link'] as String?;
          final handle = link != null ? '@${Uri.parse(link).pathSegments.last}' : '';
          return '$handle · Бот'.trim();
        }
        if (_isOnline) return 'В сети';
        if (_seenTime != null) return _formatLastSeen(_seenTime!);
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
    final List<({IconData icon, String label})> btns;

    if (widget.chatType == 'DIALOG') {
      if (_isBot) {
        btns = [
          (icon: Symbols.chat_bubble, label: 'Цат'),
          (icon: Symbols.notifications, label: 'Звук'),
          (icon: Symbols.more_horiz, label: 'Ещё'),
        ];
      } else {
        btns = [
          (icon: Symbols.call, label: 'Звонок'),
          (icon: Symbols.videocam, label: 'Видео'),
          (icon: Symbols.notifications, label: 'Звук'),
          (icon: Symbols.more_horiz, label: 'Ещё'),
        ];
      }
    } else {
      btns = [
        (icon: Symbols.notifications, label: 'Звук'),
        (icon: Symbols.search, label: 'Найти'),
        (icon: Symbols.more_horiz, label: 'Ещё'),
      ];
    }

    return Row(
      children: [
        for (int i = 0; i < btns.length; i++) ...[
          _actionBtn(cs, btns[i].icon, btns[i].label),
          if (i < btns.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _actionBtn(ColorScheme cs, IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF007AFF), size: 24),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: cs.onSurface, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ─── SECTIONS ────────────────────────────────────────────────────────────

  List<Widget> _buildSections(ColorScheme cs) {
    switch (widget.chatType) {
      case 'DIALOG':
        return _dialogSections(cs);
      case 'CHAT':
        return _groupSections(cs);
      case 'CHANNEL':
        return _channelSections(cs);
      default:
        return [_attachmentsCard(cs)];
    }
  }

  List<Widget> _dialogSections(ColorScheme cs) {
    final result = <Widget>[];

    if (_isBot) {
      final link = _contactData?['link'] as String?;
      if (link != null) {
        result
          ..add(_linkCard(cs, link))
          ..add(const SizedBox(height: 8));
      }
    } else {
      final phone = _contactData?['phone'];
      final phoneInt = phone is int ? phone : int.tryParse(phone?.toString() ?? '');
      if (phoneInt != null && phoneInt > 0) {
        result
          ..add(_infoCard(cs, 'Номер телефона', _formatPhone(phoneInt)))
          ..add(const SizedBox(height: 8));
      }
    }

    result.add(_attachmentsCard(cs));
    return result;
  }

  List<Widget> _groupSections(ColorScheme cs) {
    return [
      _attachmentsCard(cs),
      const SizedBox(height: 24),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          'УЧАСТНИКИ',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            _memberAction(cs, Symbols.person_add, 'Добавить участника', () {}),
            _listDivider(cs),
            _memberAction(cs, Symbols.link, 'Пригласить по ссылке', () {}),
            ..._members.expand((m) => [_listDivider(cs), _memberTile(cs, m)]),
          ],
        ),
      ),
    ];
  }

  List<Widget> _channelSections(ColorScheme cs) {
    final result = <Widget>[];

    final link = _chatData?['link'] as String?;
    if (link != null) {
      result
        ..add(_linkCard(cs, link))
        ..add(const SizedBox(height: 8));
    }

    final desc = _chatData?['description'] as String?;
    if (desc != null && desc.isNotEmpty) {
      result
        ..add(_descCard(cs, desc))
        ..add(const SizedBox(height: 8));
    }

    result.add(_attachmentsCard(cs));
    return result;
  }

  // ─── CARD WIDGETS ────────────────────────────────────────────────────────

  Widget _infoCard(ColorScheme cs, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _linkCard(ColorScheme cs, String link) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ссылка',
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 4),
                Text(link,
                    style: const TextStyle(
                        color: Color(0xFF007AFF), fontSize: 15)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.share,
                color: Color(0xFF007AFF), size: 22),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Symbols.qr_code,
                color: Color(0xFF007AFF), size: 22),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _descCard(ColorScheme cs, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(desc,
          style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.4)),
    );
  }

  Widget _attachmentsCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Symbols.photo_library, color: cs.onSurfaceVariant, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Вложения',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                Text('Фото, видео, файлы и ссылки',
                    style:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          Icon(Symbols.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  // ─── MEMBER LIST ─────────────────────────────────────────────────────────

  Widget _memberAction(
      ColorScheme cs, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF007AFF), size: 26),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(color: cs.onSurface, fontSize: 16)),
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

    final String? roleLabel =
        member.isOwner ? 'владелец' : (member.isAdmin ? 'Адмін' : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          (avatar != null && avatar.isNotEmpty)
              ? CircleAvatar(
                  radius: 22,
                  backgroundImage: CachedNetworkImageProvider(avatar),
                  backgroundColor: cs.primaryContainer,
                )
              : CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: cs.onPrimaryContainer, fontSize: 16),
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                Text(sublabel,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
          if (roleLabel != null)
            Text(roleLabel,
                style:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── INFO AREA ───────────────────────────────────────────────────────────

  Widget _buildInfoArea(ColorScheme cs, double W) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Кнопка "Инфо" — всегда полная ширина
        GestureDetector(
          onTap: () => setState(() => _infoExpanded = !_infoExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Symbols.info, color: const Color(0xFF007AFF), size: 22),
                const SizedBox(width: 12),
                Text(
                  'Инфо',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _infoExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Symbols.keyboard_arrow_down,
                      color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Контент: при закрытии — обычная колонка, при открытии — Row
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          sizeCurve: Curves.easeOut,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          crossFadeState: _infoExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildSections(cs),
          ),
          secondChild: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCompactSections(cs)),
              const SizedBox(width: 8),
              Expanded(child: _buildInfoPanelCard(cs)),
            ],
          ),
        ),
      ],
    );
  }

  // Компактные карточки — левая колонка при открытом инфо
  Widget _buildCompactSections(ColorScheme cs) {
    final items = <Widget>[];

    if (widget.chatType == 'DIALOG') {
      if (_isBot) {
        final link = _contactData?['link'] as String?;
        if (link != null) items.add(_compactCard(cs, 'Ссылка', link));
      } else {
        final phone = _contactData?['phone'];
        final phoneInt =
            phone is int ? phone : int.tryParse(phone?.toString() ?? '');
        if (phoneInt != null && phoneInt > 0) {
          items.add(_compactCard(cs, 'Телефон', _formatPhone(phoneInt)));
        }
      }
    }

    if (widget.chatType == 'CHANNEL') {
      final desc = _chatData?['description'] as String?;
      if (desc != null && desc.isNotEmpty) {
        items.add(_compactCard(
          cs,
          'Описание',
          desc.length > 80 ? '${desc.substring(0, 80)}…' : desc,
        ));
      }
    }

    if (widget.chatType == 'CHAT') {
      final total = (_chatData?['participantsCount'] as int?) ?? _members.length;
      items.add(_compactCard(cs, 'Участников', '$total'));
    }

    items.add(const SizedBox(height: 8));
    items.add(_compactAttachments(cs));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1 && items[i] is! SizedBox)
            const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _compactCard(ColorScheme cs, String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              maxLines: 4,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _compactAttachments(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Symbols.photo_library, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Вложения',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          Icon(Symbols.chevron_right, color: cs.onSurfaceVariant, size: 18),
        ],
      ),
    );
  }

  // Инфо-панель — правая колонка при открытом инфо
  Widget _buildInfoPanelCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _buildAllInfoRows(cs),
    );
  }

  Widget _buildAllInfoRows(ColorScheme cs) {
    final rows = <({String label, String value})>[];
    final chat = _chatData;
    if (chat == null) {
      return Text('Нет данных',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13));
    }

    void add(String label, dynamic val, {bool tsFormat = false}) {
      if (val == null) return;
      if (val is bool && !val) return;
      String str;
      if (tsFormat && val is int && val > 1) {
        str = _formatTs(val);
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
      add('Вступил', (chat['joinTime'] as int?) != null && (chat['joinTime'] as int) > 1
          ? chat['joinTime'] : null, tsFormat: true);
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
      return Text('Нет данных',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _infoRow(cs, rows[i].label, rows[i].value),
          if (i < rows.length - 1)
            Divider(
                height: 10,
                color: cs.outlineVariant.withValues(alpha: 0.25)),
        ],
      ],
    );
  }

  Widget _infoRow(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── SHIMMER ─────────────────────────────────────────────────────────────

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
            child: block(96, 96, r: 48)),
        const SizedBox(height: 14),
        Center(child: block(160, 22, r: 8)),
        const SizedBox(height: 8),
        Center(child: block(110, 16, r: 6)),
        const SizedBox(height: 24),
        block(double.infinity, 70, r: 14),
        const SizedBox(height: 12),
        block(double.infinity, 70, r: 14),
        const SizedBox(height: 12),
        block(double.infinity, 70, r: 14),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  String _formatLastSeen(int ms) {
    final diff = DateTime.now().millisecondsSinceEpoch - ms;
    if (diff < 60000) return 'только что';
    if (diff < 3600000) return '${diff ~/ 60000} мин назад';
    if (diff < 86400000) return '${diff ~/ 3600000} ч назад';
    if (diff < 604800000) return '${diff ~/ 86400000} д назад';
    return 'давно';
  }

  String _formatPhone(int phone) {
    final s = phone.toString();
    if (s.length == 11 && s.startsWith('7')) {
      return '+7 ${s.substring(1, 4)} ${s.substring(4, 7)}-'
          '${s.substring(7, 9)}-${s.substring(9, 11)}';
    }
    return '+$s';
  }

  String _formatTs(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
