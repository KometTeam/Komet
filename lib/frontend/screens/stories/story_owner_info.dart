import 'package:flutter/material.dart';

import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../main.dart' show messagesModule;
import '../../../models/story.dart';

class StoryOwnerInfo {
  final String name;
  final String? avatarUrl;
  const StoryOwnerInfo({required this.name, this.avatarUrl});
}

StoryOwnerInfo? peekStoryOwnerInfo(StoryOwner owner) {
  if (owner.isUser) {
    // 1) Локальный кэш контактов (имя из адресной книги) — самый надёжный.
    final cachedName = ContactCache.get(owner.ownerId);
    final cachedAvatar = ContactCache.getAvatar(owner.ownerId);
    if (cachedName != null && cachedName.isNotEmpty) {
      return StoryOwnerInfo(name: cachedName, avatarUrl: cachedAvatar);
    }
    // 2) Серверный кэш ContactInfo.
    final c = ContactInfoFetch.peek(owner.ownerId);
    final name = c?.displayName ?? c?.firstName;
    if (name != null && name.isNotEmpty) {
      return StoryOwnerInfo(name: name, avatarUrl: c?.avatarUrl ?? cachedAvatar);
    }
    return null;
  }
  final chat = ChatInfoFetch.peek(owner.ownerId);
  if (chat == null) return null;
  final title = (chat.raw['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;
  return StoryOwnerInfo(name: title, avatarUrl: chat.raw['baseUrl'] as String?);
}

Future<StoryOwnerInfo?> fetchStoryOwnerInfo(StoryOwner owner) async {
  final peeked = peekStoryOwnerInfo(owner);
  if (peeked != null && peeked.name.isNotEmpty) return peeked;

  if (owner.isUser) {
    // Канонический путь приложения: подтягивает имена и кладёт их в ContactCache.
    await messagesModule.ensureContactNames({owner.ownerId});
    final cachedName = ContactCache.get(owner.ownerId);
    final cachedAvatar = ContactCache.getAvatar(owner.ownerId);
    if (cachedName != null && cachedName.isNotEmpty) {
      return StoryOwnerInfo(name: cachedName, avatarUrl: cachedAvatar);
    }
    // Запасной путь через серверный ContactInfo.
    final c = await ContactInfoFetch.get(owner.ownerId);
    final name = c?.displayName ?? c?.firstName;
    final avatar = c?.avatarUrl ?? cachedAvatar;
    if (name != null && name.isNotEmpty) {
      ContactCache.put(owner.ownerId, name);
      if (avatar != null) ContactCache.putAvatar(owner.ownerId, avatar);
      return StoryOwnerInfo(name: name, avatarUrl: avatar);
    }
    return avatar == null ? null : StoryOwnerInfo(name: '', avatarUrl: avatar);
  }

  final chat = await ChatInfoFetch.get(owner.ownerId);
  if (chat == null) return null;
  final title = (chat.raw['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;
  return StoryOwnerInfo(name: title, avatarUrl: chat.raw['baseUrl'] as String?);
}

/// Резолвит имя/аватар владельца истории (из кэша, с дозагрузкой) и отдаёт их
/// в [builder]. [override] позволяет подставить готовые данные (напр. свой
/// профиль) без обращения к кэшу.
class StoryOwnerBuilder extends StatefulWidget {
  final StoryOwner owner;
  final StoryOwnerInfo? overrideInfo;
  final Widget Function(BuildContext context, StoryOwnerInfo? info) builder;

  const StoryOwnerBuilder({
    super.key,
    required this.owner,
    required this.builder,
    this.overrideInfo,
  });

  @override
  State<StoryOwnerBuilder> createState() => _StoryOwnerBuilderState();
}

class _StoryOwnerBuilderState extends State<StoryOwnerBuilder> {
  StoryOwnerInfo? _info;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _info = widget.overrideInfo ?? peekStoryOwnerInfo(widget.owner);
  }

  @override
  void didUpdateWidget(StoryOwnerBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner ||
        oldWidget.overrideInfo != widget.overrideInfo) {
      _info = widget.overrideInfo ?? peekStoryOwnerInfo(widget.owner);
    }
  }

  /// Пока имя не найдено — пробуем дозагрузить при каждой перестройке.
  /// Повторные попытки дешёвые: серверные запросы дросселируются кэшем
  /// (TTL/бэкофф), а локальный ContactCache проверяется синхронно. Так имя
  /// «дорезолвится» само, когда появится соединение или прогреются контакты.
  void _ensureResolved() {
    if (_info != null || _fetching) return;
    _fetching = true;
    fetchStoryOwnerInfo(widget.owner).then((info) {
      _fetching = false;
      if (!mounted || info == null) return;
      setState(() => _info = info);
    }).catchError((_) {
      _fetching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null && widget.overrideInfo == null) _ensureResolved();
    return widget.builder(context, _info);
  }
}
