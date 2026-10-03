import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../core/cache/info_cache.dart';
import '../../../../core/protocol/packet.dart';
import '../../../../core/storage/chat_members_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../models/admin_rights.dart';
import '../../../../models/chat_info.dart';
import '../../../../models/chat_reaction_settings.dart';
import '../../../../models/chat_restriction.dart';
import '../../../../models/member_permission.dart';
import '../../../widgets/custom_notification.dart';

class ChatAdminState extends ChangeNotifier {
  final int chatId;
  final int myId;
  final String _fallbackName;
  final String _fallbackImageUrl;
  final String? _openedTitle;
  final String? _openedIconUrl;
  ChatInfo _info;
  ChatReactionSettings? _reactions;

  ChatAdminState({
    required this.chatId,
    required this.myId,
    required String name,
    required String imageUrl,
    required ChatInfo info,
  }) : _fallbackName = name,
       _fallbackImageUrl = imageUrl,
       _openedTitle = info.title,
       _openedIconUrl = info.iconUrl,
       _info = info;

  ChatInfo get info => _info;

  ChatReactionSettings? get reactions => _reactions;

  AdminChatKind get kind => _info.adminKind;

  bool get isChannel => kind == AdminChatKind.channel;

  String get name {
    final title = _info.title;
    if (title == null || title.isEmpty || title == _openedTitle) {
      return _fallbackName;
    }
    return title;
  }

  String get imageUrl {
    final icon = _info.iconUrl;
    if (icon == null || icon.isEmpty || icon == _openedIconUrl) {
      return _fallbackImageUrl;
    }
    return icon;
  }

  bool get isOwner => _info.isOwner(myId);

  bool get isAdmin => isOwner || _info.isAdmin(myId);

  bool get canManageAdmins => _info.can(myId, AdminRight.manageAdmins);

  bool get canManageFollowers => _info.can(myId, AdminRight.manageFollowers);

  bool get canManageChat => _info.can(myId, AdminRight.editInfo);

  bool get canRemoveMembers => _info.can(
    myId,
    isChannel ? AdminRight.manageFollowers : AdminRight.manageMembers,
  );

  bool get canEditInfo =>
      canManageChat ||
      (!isChannel && MemberPermission.editInfo.allowedIn(_info));

  bool get hasSettings => isAdmin || canEditInfo;

  bool get canAddMembers => isChannel
      ? canManageFollowers
      : MemberPermission.addMembers.allowedIn(_info) ||
            _info.can(myId, AdminRight.manageMembers);

  List<int> get adminIds {
    final owner = _info.owner;
    return [
      if (owner != null && owner != 0) owner,
      for (final id in _info.adminIds)
        if (id != owner) id,
    ];
  }

  int? get followersCount =>
      ChatMembersStore.instance.count(chatId) ?? _info.participantsCount;

  bool get hasOtherMembers => (followersCount ?? 2) > 1;

  String? get inviteLink {
    final link = _info.link;
    return link == null || link.isEmpty ? null : link;
  }

  bool canEditAdmin(int userId) =>
      canManageAdmins && userId != myId && !_info.isOwner(userId);

  bool canGrant(AdminRight right) => isOwner || _info.rightsOf(myId).has(right);

  void adopt(ChatInfo info) {
    _info = info;
    notifyListeners();
  }

  Future<void> refresh() async {
    final fresh = await ChatInfoFetch.get(chatId, forceRefresh: true);
    if (fresh != null) adopt(fresh);
  }

  Future<void> setAdmin(int userId, AdminRights rights) async =>
      adopt(await chatAdminModule.setAdmin(chatId, userId, rights));

  Future<void> removeAdmin(int userId) async =>
      adopt(await chatAdminModule.removeAdmin(chatId, userId));

  Future<void> removeMember(int userId) async {
    final info = await chatAdminModule.removeMember(chatId, userId);
    if (info.participantsCount == null) {
      ChatMembersStore.instance.adjust(chatId, -1);
    }
    adopt(info);
  }

  Future<void> setComments(bool enabled) async =>
      adopt(await chatAdminModule.setOptions(chatId, {'COMMENTS': enabled}));

  Future<void> transferOwnership(int userId) async =>
      adopt(await chatAdminModule.transferOwnership(chatId, userId));

  Future<void> revokeInviteLink() async =>
      adopt(await chatAdminModule.revokeInviteLink(chatId));

  Future<void> setJoinRequests(bool enabled) async => adopt(
    await chatAdminModule.setOptions(chatId, {'JOIN_REQUEST': enabled}),
  );

  Future<void> setMemberPermission(
    MemberPermission permission,
    bool allowed,
  ) async => adopt(
    await chatAdminModule.setOptions(chatId, permission.optionFor(allowed)),
  );

  Future<void> setRestriction(
    ChatRestriction restriction,
    bool enabled,
  ) async => adopt(
    await chatAdminModule.setOptions(chatId, restriction.optionFor(enabled)),
  );

  Future<void> updateInfo({
    required String title,
    required String description,
  }) async => adopt(
    await chatAdminModule.updateInfo(
      chatId,
      title: title,
      description: description,
    ),
  );

  Future<void> setPhoto(Uint8List bytes) async {
    final url = await chats.requestChatPhotoUploadUrl(api);
    if (url == null) throw StateError('no photo upload url');
    final token = await fileUploader.uploadImage(
      Uri.parse(url),
      bytes,
      filename: 'avatar.jpg',
    );
    if (token == null) throw StateError('photo upload failed');
    adopt(await chatAdminModule.setPhoto(chatId, token));
  }

  Future<void> loadReactions() async {
    final settings = await chatAdminModule.reactionSettingsFor(
      chatId,
      forceRefresh: true,
    );
    if (settings == null) throw StateError('no reaction settings');
    _adoptReactions(settings);
  }

  Future<void> disableReactions() async =>
      _adoptReactions(await chatAdminModule.disableReactions(chatId));

  Future<void> setReactions({
    required int count,
    required List<String> forbidden,
  }) async => _adoptReactions(
    await chatAdminModule.setReactions(
      chatId,
      count: count,
      forbidden: forbidden,
    ),
  );

  void _adoptReactions(ChatReactionSettings settings) {
    _reactions = settings;
    notifyListeners();
  }
}

Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final fallback = AppLocalizations.of(context)!.adminActionFailed;
  try {
    await action();
    return true;
  } on PacketError catch (e) {
    if (context.mounted) showCustomNotification(context, e.message);
  } catch (_) {
    if (context.mounted) showCustomNotification(context, fallback);
  }
  return false;
}
