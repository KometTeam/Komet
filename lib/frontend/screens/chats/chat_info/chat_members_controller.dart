import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../core/cache/info_cache.dart';
import '../../../../core/config/app_stories.dart';
import '../../../../core/storage/chat_members_store.dart';
import '../../../../main.dart';
import '../../../../models/chat_info.dart';

// #***! карточка участника чата для рендера списка
class MemberInfo {
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

  const MemberInfo({
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

// #***! загрузка/пагинация/сортировка участников чата — владельцы/админы
// впереди, подгрузка по мере скролла; UI (тайлы/футер) остаётся в экране
class ChatMembersController {
  final int Function() myId;
  final int chatId;
  final ChatInfo? Function() chatInfo;
  final void Function(ChatInfo) setChatInfo;
  final VoidCallback rebuild;
  final VoidCallback rebuildImmediate;
  final ScrollController? Function() bodyScrollController;
  final bool Function() isMounted;

  ChatMembersController({
    required this.myId,
    required this.chatId,
    required this.chatInfo,
    required this.setChatInfo,
    required this.rebuild,
    required this.rebuildImmediate,
    required this.bodyScrollController,
    required this.isMounted,
  });

  final List<MemberInfo> members = [];
  final List<MemberInfo> owners = [];
  final List<MemberInfo> admins = [];
  final List<MemberInfo> contactMembers = [];
  final List<MemberInfo> otherMembers = [];
  final Set<int> seenMemberIds = {};
  Set<int> contactIds = {};
  int _memberMarker = 0;
  bool membersLoading = false;
  bool membersEnd = false;
  static const int memberRenderChunk = 24;
  int memberRenderLimit = memberRenderChunk;
  bool _memberFillScheduled = false;

  MemberInfo memberFrom(ChatMemberEntry e) {
    final info = chatInfo();
    return MemberInfo(
      id: e.id,
      name: e.name,
      avatarUrl: e.avatarUrl,
      isAdmin: info?.isAdmin(e.id) ?? false,
      isOwner: info?.isOwner(e.id) ?? false,
      isMe: e.id == myId(),
      alias: info?.adminAlias(e.id),
      seenTime: e.seenTime,
      presenceStatus: e.presenceStatus,
      blocked: e.blocked,
      isContact: contactIds.contains(e.id),
    );
  }

  Future<void> loadLeaders() async {
    final info = chatInfo();
    if (info == null) return;

    final owner = info.owner;
    final leaderIds = <int>[
      if (owner != null && owner != 0) owner,
      for (final a in info.adminIds)
        if (a != owner) a,
    ];
    if (leaderIds.isEmpty) return;

    final contactsFuture = ContactInfoFetch.getMany(leaderIds);
    final presenceFuture = PresenceFetch.getMany(leaderIds);
    final contacts = await contactsFuture;
    final presence = await presenceFuture;
    if (!isMounted()) return;

    for (final id in leaderIds) {
      if (!seenMemberIds.add(id)) continue;
      final c = contacts[id];
      final pres = presence[id];
      addMember(
        MemberInfo(
          id: id,
          name: c?.displayName ?? ContactCache.get(id),
          avatarUrl: c?.avatarUrl ?? ContactCache.getAvatar(id),
          isAdmin: info.isAdmin(id),
          isOwner: info.isOwner(id),
          isMe: id == myId(),
          alias: info.adminAlias(id),
          seenTime: pres?['seen'] as int?,
          presenceStatus: (pres?['status'] as int?) ?? 0,
          blocked: c?.isDeleted ?? false,
          isContact: contactIds.contains(id),
        ),
      );
    }
    rebuildMembers();
  }

  int _memberRank(MemberInfo m) {
    if (m.isOwner) return 0;
    if (m.isAdmin) return 1;
    if (m.isContact) return 2;
    return 3;
  }

  void addMember(MemberInfo m) {
    switch (_memberRank(m)) {
      case 0:
        owners.add(m);
      case 1:
        admins.add(m);
      case 2:
        contactMembers.add(m);
      default:
        otherMembers.add(m);
    }
  }

  void rebuildMembers() {
    members
      ..clear()
      ..addAll(owners)
      ..addAll(admins)
      ..addAll(contactMembers)
      ..addAll(otherMembers);
  }

  Future<void> fetchMembersPage({bool initial = false}) async {
    if (membersLoading || membersEnd) return;
    membersLoading = true;
    if (!initial) rebuild();

    final page = await chats.getChatMembers(api, chatId, marker: _memberMarker);
    membersLoading = false;
    if (!isMounted()) return;

    if (page == null) {
      if (!initial) rebuild();
      return;
    }

    var added = 0;
    final fresh = <int>[];
    for (final e in page.members) {
      if (seenMemberIds.add(e.id)) {
        addMember(memberFrom(e));
        fresh.add(e.id);
        added++;
      }
    }
    if (added > 0) {
      rebuildMembers();
      scheduleMemberFillCheck();
    }
    if (fresh.isNotEmpty && AppStories.current.value) {
      unawaited(storiesModule.loadOwnersPreviews(fresh));
    }

    final total = ChatMembersStore.instance.count(chatId);
    if (page.members.isEmpty ||
        added == 0 ||
        page.marker == _memberMarker ||
        (total != null && members.length >= total)) {
      membersEnd = true;
    }
    _memberMarker = page.marker;

    if (!initial) rebuild();
  }

  bool revealMoreMembers() {
    if (memberRenderLimit >= members.length) return false;
    memberRenderLimit += memberRenderChunk;
    rebuildImmediate();
    scheduleMemberFillCheck();
    return true;
  }

  void scheduleMemberFillCheck() {
    if (_memberFillScheduled) return;
    _memberFillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _memberFillScheduled = false;
      if (!isMounted()) return;
      if (memberRenderLimit >= members.length) return;
      final controller = bodyScrollController();
      if (controller == null || !controller.hasClients) return;
      if (controller.position.maxScrollExtent > 0) return;
      revealMoreMembers();
    });
  }

  Future<void> refreshMembers() async {
    final info = await ChatInfoFetch.get(chatId, forceRefresh: true);
    if (!isMounted()) return;
    if (info != null) setChatInfo(info);
    contactMembers.clear();
    otherMembers.clear();
    seenMemberIds
      ..clear()
      ..addAll(owners.map((m) => m.id))
      ..addAll(admins.map((m) => m.id));
    _memberMarker = 0;
    membersEnd = false;
    membersLoading = false;
    memberRenderLimit = memberRenderChunk;
    rebuildMembers();
    rebuild();
    await fetchMembersPage(initial: true);
    rebuild();
  }
}
