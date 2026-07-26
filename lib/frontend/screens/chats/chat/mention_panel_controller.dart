import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../backend/modules/chats.dart' show chats;
import '../../../../main.dart' show api;

class MentionCandidate {
  final int id;
  final String name;
  final String? avatarUrl;
  final bool isContact;

  const MentionCandidate({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isContact = false,
  });

  @override
  bool operator ==(Object other) =>
      other is MentionCandidate &&
      other.id == id &&
      other.name == name &&
      other.isContact == isContact;

  @override
  int get hashCode => Object.hash(id, name, isContact);
}

class MentionQuery {
  final int start;
  final int end;
  final String text;

  const MentionQuery({
    required this.start,
    required this.end,
    required this.text,
  });
}

MentionQuery? mentionQueryAt(String text, int cursor) {
  if (cursor <= 0 || cursor > text.length) return null;
  const maxQueryLength = 32;

  var index = cursor - 1;
  while (index >= 0) {
    final code = text.codeUnitAt(index);
    if (code == 0x40) break;
    if (code == 0x20 || code == 0x0A || code == 0x09) return null;
    if (cursor - index > maxQueryLength) return null;
    index--;
  }
  if (index < 0) return null;
  if (index > 0) {
    final before = text.codeUnitAt(index - 1);
    if (before != 0x20 && before != 0x0A && before != 0x09) return null;
  }

  return MentionQuery(
    start: index,
    end: cursor,
    text: text.substring(index + 1, cursor),
  );
}

class MentionPanelController {
  MentionPanelController({
    required TickerProvider vsync,
    required this.chatId,
    required this.enabled,
    required this.selfId,
    required this.valueOf,
    required this.onSelected,
  }) {
    anim = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
    );
  }

  static const int _pageSize = 50;
  static const int _desiredMatches = 30;
  static const int _autoFetchLimit = 300;

  final int chatId;
  final bool Function() enabled;
  final int Function() selfId;
  final TextEditingValue Function() valueOf;
  final void Function(MentionCandidate candidate, MentionQuery query)
  onSelected;

  late final AnimationController anim;
  final ValueNotifier<List<MentionCandidate>> matches = ValueNotifier(const []);
  final ValueNotifier<bool> loadingMore = ValueNotifier(false);

  final List<MentionCandidate> _members = [];
  final Set<int> _seen = {};
  int _marker = 0;
  bool _end = false;
  bool _fetching = false;
  bool _visible = false;
  MentionQuery? _query;

  bool get hasMore => !_end;

  void update() {
    final query = enabled() ? _queryAt(valueOf()) : null;
    _query = query;

    if (query == null) {
      _setVisible(false);
      return;
    }

    if (_members.isEmpty && !_end) unawaited(_fetchPage());

    final found = _match(query.text);
    if (!listEquals(matches.value, found)) matches.value = found;
    if (found.length < _desiredMatches && _members.length < _autoFetchLimit) {
      unawaited(_fetchPage());
    }

    _setVisible(found.isNotEmpty || (_members.isEmpty && !_end));
  }

  void select(MentionCandidate candidate) {
    final query = _query;
    if (query == null) return;
    onSelected(candidate, query);
  }

  Future<void> loadMore() => _fetchPage();

  MentionQuery? _queryAt(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    return mentionQueryAt(value.text, selection.baseOffset);
  }

  List<MentionCandidate> _match(String raw) {
    final me = selfId();
    final query = raw.toLowerCase().trim();
    final found = _members
        .where((c) => c.id != me)
        .where((c) => query.isEmpty || _matchesQuery(c.name, query));
    return [
      ...found.where((c) => c.isContact),
      ...found.where((c) => !c.isContact),
    ];
  }

  bool _matchesQuery(String name, String query) {
    final lower = name.toLowerCase();
    if (lower.startsWith(query)) return true;
    for (final word in lower.split(' ')) {
      if (word.startsWith(query)) return true;
    }
    return lower.contains(query);
  }

  Future<void> _fetchPage() async {
    if (_fetching || _end) return;
    _fetching = true;
    loadingMore.value = true;
    try {
      final page = await chats.getChatMembers(
        api,
        chatId,
        marker: _marker,
        count: _pageSize,
      );
      if (page == null) {
        _end = true;
        return;
      }

      var added = 0;
      for (final member in page.members) {
        final name = member.fullName ?? member.name;
        if (name == null || name.isEmpty) continue;
        if (member.blocked) continue;
        if (!_seen.add(member.id)) continue;
        _members.add(
          MentionCandidate(
            id: member.id,
            name: name,
            avatarUrl: member.avatarUrl,
            isContact: member.isContact,
          ),
        );
        added++;
      }

      if (added == 0 || page.members.isEmpty || page.marker == _marker) {
        _end = true;
      }
      _marker = page.marker;

      if (added > 0 && _query != null) {
        final found = _match(_query!.text);
        if (!listEquals(matches.value, found)) matches.value = found;
        _setVisible(found.isNotEmpty);
      }
    } finally {
      _fetching = false;
      loadingMore.value = false;
    }
  }

  void _setVisible(bool show) {
    if (show == _visible) return;
    _visible = show;
    if (show) {
      anim.forward();
    } else {
      anim.reverse();
    }
  }

  void dispose() {
    anim.dispose();
    matches.dispose();
    loadingMore.dispose();
  }
}
