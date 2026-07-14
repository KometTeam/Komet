import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../widgets/custom_notification.dart';
import '../widgets/glossy_pill.dart';
import '../widgets/small_spinner.dart';

class DebugIdSearchSection extends StatelessWidget {
  final TextEditingController idController;
  final bool isSearching;
  final bool hasSearched;
  final List<SearchHit> hits;
  final Map<String, String> errors;
  final VoidCallback onSearch;

  const DebugIdSearchSection({
    super.key,
    required this.idController,
    required this.isSearching,
    required this.hasSearched,
    required this.hits,
    required this.errors,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Поиск по ID',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Параллельно: contactInfo (32) + chatInfo (48) + publicSearch (60)',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: idController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Введите ID',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: isSearching ? null : onSearch,
                child: isSearching
                    ? const SmallSpinner(size: 20)
                    : const Icon(Symbols.search, size: 20),
              ),
            ],
          ),
          if (hasSearched && !isSearching) ...[
            const SizedBox(height: 12),
            if (hits.isEmpty && errors.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Ничего не найдено',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
            for (final hit in hits) ...[
              _SearchResultCard(hit: hit),
              const SizedBox(height: 8),
            ],
            for (final entry in errors.entries) ...[
              _ErrorChip(label: entry.key, message: entry.value),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

enum HitKind { dialog, chat, channel, bot, official, contact, user, unknown }

class SearchHit {
  final String source;
  final int id;
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final List<HitKind> badges;
  final bool isChatEntity;

  SearchHit({
    required this.source,
    required this.id,
    required this.title,
    required this.avatarUrl,
    required this.badges,
    required this.isChatEntity,
    this.subtitle,
  });

  static SearchHit? fromContact(String source, Map raw) {
    final id = raw['id'];
    if (id is! int) return null;
    final namesRaw = raw['names'];
    String title = 'User #$id';
    if (namesRaw is List && namesRaw.isNotEmpty) {
      final n = namesRaw.first;
      if (n is Map) {
        final full = n['name']?.toString();
        if (full != null && full.isNotEmpty) title = full;
      }
    }
    final opts = (raw['options'] is List)
        ? (raw['options'] as List).whereType<String>().toSet()
        : <String>{};
    final badges = <HitKind>[];
    if (opts.contains('BOT')) badges.add(HitKind.bot);
    if (opts.contains('OFFICIAL')) badges.add(HitKind.official);
    if (badges.isEmpty) badges.add(HitKind.contact);
    return SearchHit(
      source: source,
      id: id,
      title: title,
      subtitle: (raw['description'] as String?)?.trim().isNotEmpty == true
          ? raw['description'] as String
          : (raw['phone'] != null ? 'Телефон скрыт' : null),
      avatarUrl: raw['baseUrl'] as String?,
      badges: badges,
      isChatEntity: false,
    );
  }

  static SearchHit? fromChat(String source, Map raw) {
    final id = raw['id'];
    if (id is! int) return null;
    final type = (raw['type'] as String?) ?? 'CHAT';
    final title = (raw['title'] as String?) ?? 'Chat #$id';
    final pCount = raw['participantsCount'] as int?;
    final badges = <HitKind>[];
    switch (type) {
      case 'DIALOG':
        badges.add(HitKind.dialog);
      case 'CHANNEL':
        badges.add(HitKind.channel);
      case 'CHAT':
        badges.add(HitKind.chat);
      default:
        badges.add(HitKind.unknown);
    }
    final opts = raw['options'];
    if (opts is Map && opts['OFFICIAL'] == true) {
      badges.add(HitKind.official);
    }
    String? subtitle;
    if (type == 'CHANNEL') {
      subtitle = pCount != null ? 'Канал · $pCount подписч.' : 'Канал';
    } else if (type == 'CHAT') {
      subtitle = pCount != null ? 'Группа · $pCount участн.' : 'Группа';
    } else {
      subtitle = 'Диалог';
    }
    return SearchHit(
      source: source,
      id: id,
      title: title,
      subtitle: subtitle,
      avatarUrl: raw['baseIconUrl'] as String?,
      badges: badges,
      isChatEntity: true,
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchHit hit;
  const _SearchResultCard({required this.hit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HitAvatar(hit: hit, cs: cs),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        hit.title,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    for (final b in hit.badges) ...[
                      const SizedBox(width: 6),
                      _BadgeChip(kind: b, cs: cs),
                    ],
                  ],
                ),
                if (hit.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hit.subtitle!,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'id: ${hit.id}',
                      style: TextStyle(
                        color: cs.outline,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'via ${hit.source}',
                      style: TextStyle(color: cs.outline, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Скопировать id',
            icon: Icon(
              Symbols.content_copy,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: hit.id.toString()));
              if (context.mounted) {
                showCustomNotification(context, 'id скопирован');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _HitAvatar extends StatelessWidget {
  final SearchHit hit;
  final ColorScheme cs;
  const _HitAvatar({required this.hit, required this.cs});

  @override
  Widget build(BuildContext context) {
    const size = 44.0;
    final url = hit.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _fallback(),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = hit.title.isNotEmpty ? hit.title[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final HitKind kind;
  final ColorScheme cs;
  const _BadgeChip({required this.kind, required this.cs});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    switch (kind) {
      case HitKind.bot:
        label = 'Bot';
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      case HitKind.official:
        label = '✓';
        bg = cs.primary;
        fg = cs.onPrimary;
      case HitKind.contact:
        label = 'Контакт';
        bg = cs.surface;
        fg = cs.onSurfaceVariant;
      case HitKind.user:
        label = 'User';
        bg = cs.surface;
        fg = cs.onSurfaceVariant;
      case HitKind.dialog:
        label = 'Диалог';
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case HitKind.chat:
        label = 'Группа';
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case HitKind.channel:
        label = 'Канал';
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
      case HitKind.unknown:
        label = '?';
        bg = cs.surface;
        fg = cs.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorChip extends StatelessWidget {
  final String label;
  final String message;
  const _ErrorChip({required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Symbols.error_outline, size: 16, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $message',
              style: TextStyle(color: cs.onErrorContainer, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
