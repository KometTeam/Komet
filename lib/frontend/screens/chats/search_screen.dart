import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../main.dart';
import '../../../backend/modules/chats.dart';
import '../../../backend/modules/contacts.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/names.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/swipe_route.dart';
import '../contacts/open_contact_profile.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _debounce = Debouncer(const Duration(milliseconds: 300));
  int _seq = 0;
  int? _accountId;

  bool _loading = false;
  PhoneLookupResult? _phoneResult;
  List<Map<String, dynamic>> _contacts = const [];
  List<Map<String, dynamic>> _chats = const [];
  List<MessageSearchHit> _messages = const [];
  Map<int, Map<String, dynamic>> _msgChatMeta = const {};
  List<ChatSearchHit> _public = const [];

  @override
  void initState() {
    super.initState();
    AppDatabase.loadActiveProfile().then((p) {
      if (mounted) _accountId = p?.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (value.trim().isEmpty) {
      _debounce.cancel();
      _seq++;
      setState(() {
        _loading = false;
        _phoneResult = null;
        _contacts = const [];
        _chats = const [];
        _messages = const [];
        _msgChatMeta = const {};
        _public = const [];
      });
      return;
    }
    if (_phoneResult != null) {
      setState(() => _phoneResult = null);
    }
    _debounce.run(_runSearch);
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final token = ++_seq;
    setState(() => _loading = true);

    final accountId = _accountId;
    final phoneQuery = _phoneCandidate(query);
    final results = await Future.wait([
      accountId == null
          ? Future.value(const <Map<String, dynamic>>[])
          : AppDatabase.searchContacts(accountId, query),
      accountId == null
          ? Future.value(const <Map<String, dynamic>>[])
          : AppDatabase.searchChatsByTitle(accountId, query),
      chats.searchMessages(api, query),
      chats.searchPublic(api, query),
      phoneQuery == null
          ? Future<PhoneLookupResult?>.value(null)
          : ContactsModule.findByPhone(api, phoneQuery),
    ]);

    if (!mounted || token != _seq) return;

    final localChats = results[1] as List<Map<String, dynamic>>;
    final messages = results[2] as List<MessageSearchHit>;
    final localChatIds = localChats.map((c) => c['id'] as int).toSet();
    final public = (results[3] as List<ChatSearchHit>)
        .where((c) => !localChatIds.contains(c.id))
        .toList();

    var meta = <int, Map<String, dynamic>>{};
    if (accountId != null && messages.isNotEmpty) {
      final ids = messages.map((m) => m.chatId).toSet().toList();
      final rows = await AppDatabase.loadChatsByIds(accountId, ids);
      meta = {for (final r in rows) r['id'] as int: r};
      if (!mounted || token != _seq) return;
    }

    setState(() {
      _phoneResult = results[4] as PhoneLookupResult?;
      _contacts = results[0] as List<Map<String, dynamic>>;
      _chats = localChats;
      _messages = messages;
      _msgChatMeta = meta;
      _public = public;
      _loading = false;
    });
  }

  String _contactName(Map<String, dynamic> row) {
    return displayName(
      row['first_name'],
      row['last_name'],
      fallback: '+${row['phone']}',
    );
  }

  void _openChat(int chatId, String name, String? avatarUrl, String type) {
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: chatId,
        name: name,
        imageUrl: avatarUrl ?? '',
        chatType: type,
      ),
    );
  }

  void _openContact(Map<String, dynamic> row) {
    unawaited(
      openContactDialogProfile(
        context,
        contactId: row['id'] as int,
        name: _contactName(row),
        avatarUrl: row['base_url'] as String?,
      ),
    );
  }

  String? _phoneCandidate(String query) {
    if (!RegExp(r'^[+\d\s\-()]+$').hasMatch(query)) return null;
    final digits = query.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 5) return null;
    return query;
  }

  void _openPhoneResult(PhoneLookupResult result) {
    unawaited(
      openContactDialogProfile(
        context,
        contactId: result.id,
        name: result.name ?? 'User #${result.id}',
        avatarUrl: result.avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _controller.text.trim();
    final hasResults =
        _phoneResult != null ||
        _contacts.isNotEmpty ||
        _chats.isNotEmpty ||
        _messages.isNotEmpty ||
        _public.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: TextStyle(color: cs.onSurface, fontSize: 16),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Поиск',
            hintStyle: TextStyle(color: cs.outline, fontSize: 16),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        actions: [
          if (query.isNotEmpty)
            IconButton(
              icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
              onPressed: () {
                _controller.clear();
                _onChanged('');
                _focusNode.requestFocus();
              },
            ),
        ],
      ),
      body: _buildBody(cs, query, hasResults),
    );
  }

  Widget _buildBody(ColorScheme cs, String query, bool hasResults) {
    if (query.isEmpty) {
      return _buildHint(cs, Symbols.search, 'Начните вводить запрос');
    }
    if (!hasResults) {
      if (_loading) {
        return const Center(child: SmallSpinner(size: 36));
      }
      return _buildHint(cs, Symbols.search_off, 'Ничего не найдено');
    }
    final phoneResult = _phoneResult;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (phoneResult != null) ...[
          _sectionHeader(cs, 'По номеру'),
          _ResultTile(
            name: phoneResult.name ?? '',
            imageUrl: phoneResult.avatarUrl,
            subtitle: query,
            onTap: () => _openPhoneResult(phoneResult),
          ),
        ],
        if (_contacts.isNotEmpty) ...[
          _sectionHeader(cs, 'Контакты'),
          for (final row in _contacts)
            _ResultTile(
              name: _contactName(row),
              imageUrl: row['base_url'] as String?,
              subtitle: '+${row['phone']}',
              onTap: () => _openContact(row),
            ),
        ],
        if (_chats.isNotEmpty) ...[
          _sectionHeader(cs, 'Чаты'),
          for (final row in _chats)
            _ResultTile(
              name: (row['title'] as String?) ?? '',
              imageUrl: row['icon_url'] as String?,
              onTap: () => _openChat(
                row['id'] as int,
                (row['title'] as String?) ?? '',
                row['icon_url'] as String?,
                (row['type'] as String?) ?? 'CHAT',
              ),
            ),
        ],
        if (_messages.isNotEmpty) ...[
          _sectionHeader(cs, 'Сообщения'),
          for (final hit in _messages) _messageTile(hit),
        ],
        if (_public.isNotEmpty) ...[
          _sectionHeader(cs, 'Глобальный поиск'),
          for (final hit in _public) _chatTile(hit),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _chatTile(ChatSearchHit hit) => _ResultTile(
    name: hit.title ?? '',
    imageUrl: hit.avatarUrl,
    subtitle: hit.subtitle,
    onTap: () => _openChat(hit.id, hit.title ?? '', hit.avatarUrl, hit.type),
  );

  Widget _messageTile(MessageSearchHit hit) {
    final meta = _msgChatMeta[hit.chatId];
    final title = (meta?['title'] as String?) ?? 'Чат';
    final icon = meta?['icon_url'] as String?;
    final type = (meta?['type'] as String?) ?? 'CHAT';
    return _ResultTile(
      name: title,
      imageUrl: icon,
      subtitle: hit.text?.trim(),
      onTap: () => _openChat(hit.chatId, title, icon, type),
    );
  }

  Widget _sectionHeader(ColorScheme cs, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
    child: Text(
      title,
      style: TextStyle(
        color: cs.primary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildHint(ColorScheme cs, IconData icon, String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: cs.outline),
        const SizedBox(height: 12),
        Text(text, style: TextStyle(color: cs.outline, fontSize: 15)),
      ],
    ),
  );
}

class _ResultTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? subtitle;
  final VoidCallback onTap;

  const _ResultTile({
    required this.name,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sub = subtitle?.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            KometAvatar(name: name, size: 48, imageUrl: imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.isEmpty ? 'Без названия' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
