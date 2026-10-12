import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../main.dart';

class MembersPager extends ChangeNotifier {
  final int chatId;

  MembersPager({required this.chatId});

  final List<ChatMemberEntry> _members = [];
  final Set<int> _seen = {};
  int _marker = 0;
  int _generation = 0;
  String _query = '';
  bool _loading = false;
  bool _end = false;
  bool _failed = false;
  bool _disposed = false;

  bool get loading => _loading;
  bool get end => _end;
  bool get failed => _failed;
  bool get searching => _query.trim().isNotEmpty;
  Set<int> get loadedIds => UnmodifiableSetView(_seen);

  List<ChatMemberEntry> get members {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return UnmodifiableListView(_members);
    return _members.where((member) => _matches(member, query)).toList();
  }

  set query(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loading || _end) return;
    final generation = _generation;
    _loading = true;
    _failed = false;
    notifyListeners();
    final page = await chats.getChatMembers(api, chatId, marker: _marker);
    if (_disposed || generation != _generation) return;
    _loading = false;
    if (page == null) {
      _failed = true;
      notifyListeners();
      return;
    }
    final fresh = page.members.where((member) => _seen.add(member.id)).toList();
    final before = _members.length;
    _members.addAll(fresh);
    if (_members.length == before || page.marker == _marker) _end = true;
    _marker = page.marker;
    notifyListeners();
  }

  Future<void> reload() async {
    _generation++;
    _loading = false;
    _members.clear();
    _seen.clear();
    _marker = 0;
    _end = false;
    _failed = false;
    await loadMore();
  }

  static bool _matches(ChatMemberEntry member, String query) {
    for (final name in [member.name, member.fullName]) {
      if (name != null && name.toLowerCase().contains(query)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
