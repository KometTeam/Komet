import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/cache/info_cache.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/format.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/swipe_route.dart';
import '../chats/chat_screen.dart';

class ContactProfileScreen extends StatefulWidget {
  final int contactId;
  final String? initialName;
  final String? initialAvatarUrl;

  const ContactProfileScreen({
    super.key,
    required this.contactId,
    this.initialName,
    this.initialAvatarUrl,
  });

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _contact;
  int? _seenTime;
  int _presenceStatus = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ContactInfoFetch.get(widget.contactId),
        PresenceFetch.get(widget.contactId),
      ]);
      if (!mounted) return;
      final contact = results[0];
      if (contact != null) {
        _contact = contact;
      }
      final presence = results[1];
      if (presence != null) {
        _seenTime = presence['seen'] as int?;
        _presenceStatus = (presence['status'] as int?) ?? 0;
      }
    } catch (e) {
      if (mounted) showCustomNotification(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayName() {
    final c = _contact;
    if (c != null) {
      final names = c['names'];
      if (names is List && names.isNotEmpty) {
        final n = names.first;
        if (n is Map) {
          final full = n['name']?.toString();
          if (full != null && full.isNotEmpty) return full;
          final first = n['firstName']?.toString() ?? '';
          final last = n['lastName']?.toString() ?? '';
          final combined = '$first $last'.trim();
          if (combined.isNotEmpty) return combined;
        }
      }
    }
    return widget.initialName ?? 'User #${widget.contactId}';
  }

  String? _avatarUrl() {
    return (_contact?['baseUrl'] as String?) ?? widget.initialAvatarUrl;
  }

  Set<String> _options() {
    final raw = _contact?['options'];
    if (raw is List) return raw.whereType<String>().toSet();
    return const {};
  }

  bool get _isBot => _options().contains('BOT');
  bool get _isVerified => _options().contains('OFFICIAL');

  String _subtitle() {
    if (_isBot) return 'Бот';
    if (_presenceStatus == 1) return 'В сети';
    if (_presenceStatus == 3) return 'Был(-а) недавно';
    if (_seenTime != null && _seenTime! > 0) return formatLastSeen(_seenTime!);
    return '';
  }

  Future<void> _openChat() async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final existing = await AppDatabase.findDialogChatByParticipant(
      accountId,
      widget.contactId,
    );
    final chatId = existing ?? (accountId ^ widget.contactId);
    if (!mounted) return;
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: chatId,
        name: _displayName(),
        imageUrl: _avatarUrl() ?? '',
        chatType: 'DIALOG',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: const ConnectionSpinner(),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(cs),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
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
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                KometAvatar(
                  name: _displayName(),
                  imageUrl: _avatarUrl(),
                  size: 96,
                  fontSize: 36,
                ),
                const SizedBox(height: 14),
                _buildNameRow(cs),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _buildActions(cs),
                const SizedBox(height: 16),
                _buildInfoCard(cs),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameRow(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            _displayName(),
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_isVerified) ...[
          const SizedBox(width: 6),
          Icon(Symbols.verified, color: cs.primary, size: 20, fill: 1),
        ],
      ],
    );
  }

  Widget _buildActions(ColorScheme cs) {
    final actions = <({IconData icon, String label, VoidCallback? onTap})>[
      (icon: Symbols.chat_bubble, label: 'Чат', onTap: _openChat),
      (icon: Symbols.notifications, label: 'Звук', onTap: null),
      if (!_isBot) (icon: Symbols.call, label: 'Звонок', onTap: null),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: actions[i].onTap,
              child: GlossyPill(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                padding: const EdgeInsets.symmetric(vertical: 12),
                depth: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actions[i].icon, color: cs.primary, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      actions[i].label,
                      style: TextStyle(color: cs.onSurface, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < actions.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildInfoCard(ColorScheme cs) {
    final c = _contact;
    if (c == null) return const SizedBox.shrink();

    final rows = <Widget>[];

    final phoneStr = formatPhone(c['phone']);
    if (phoneStr != null) {
      rows.add(_infoRow(cs, Symbols.phone, 'Телефон', phoneStr));
    }

    final country = c['country'] as String?;
    if (country != null && country.isNotEmpty) {
      rows.add(_infoRow(cs, Symbols.public, 'Страна', country));
    }

    final genderStr = formatGender(c['gender']);
    if (genderStr != null) {
      rows.add(_infoRow(cs, Symbols.wc, 'Пол', genderStr));
    }

    final regTime = c['registrationTime'] as int?;
    if (regTime != null && regTime > 0) {
      rows.add(
        _infoRow(
          cs,
          Symbols.event,
          'Регистрация',
          formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(regTime)),
        ),
      );
    }

    final updateTime = c['updateTime'] as int?;
    if (updateTime != null && updateTime > 0) {
      rows.add(
        _infoRow(
          cs,
          Symbols.update,
          'Обновлён',
          formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(updateTime)),
        ),
      );
    }

    final accountStatus = c['accountStatus'];
    if (accountStatus is int && accountStatus != 0) {
      rows.add(
        _infoRow(
          cs,
          Symbols.account_circle,
          'Статус аккаунта',
          accountStatus.toString(),
        ),
      );
    }

    final desc = (c['description'] as String?)?.trim();
    if (desc != null && desc.isNotEmpty) {
      rows.add(_infoRow(cs, Symbols.info, 'Описание', desc, multiline: true));
    }

    final link = c['link'] as String?;
    if (link != null && link.isNotEmpty) {
      rows.add(_infoRow(cs, Symbols.link, 'Ссылка', link));
    }

    final webApp = c['webApp'] as String?;
    if (webApp != null && webApp.isNotEmpty) {
      rows.add(_infoRow(cs, Symbols.web, 'Web app', webApp));
    }

    final opts = _options();
    if (opts.isNotEmpty) {
      rows.add(
        _infoRow(cs, Symbols.label, 'Флаги', opts.join(', '), multiline: true),
      );
    }

    rows.add(_infoRow(cs, Symbols.tag, 'ID', widget.contactId.toString()));

    if (rows.isEmpty) return const SizedBox.shrink();

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      depth: 6,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    ColorScheme cs,
    IconData icon,
    String label,
    String value, {
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: cs.onSurface, fontSize: 14),
                  maxLines: multiline ? null : 1,
                  overflow: multiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
