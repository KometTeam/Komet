import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/chat_admin.dart';
import 'package:komet/core/cache/info_cache.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/frontend/screens/chats/chat_admin/chat_admin_state.dart';
import 'package:komet/models/admin_rights.dart';
import 'package:komet/models/chat_info.dart';
import 'package:komet/models/chat_reaction_settings.dart';
import 'package:komet/models/member_permission.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chatId = -1000;
const _ownerId = 11;
const _adminId = 22;
const _followerId = 33;

Map<String, dynamic> _chat({
  String type = 'CHANNEL',
  Map<String, dynamic> admins = const {},
  Map<String, bool> options = const {},
  String link = 'https://example.test/join/synthetic',
  String? title,
}) => {
  'id': _chatId,
  'type': type,
  'owner': _ownerId,
  'access': 'PRIVATE',
  'link': link,
  'title': ?title,
  'participantsCount': 3,
  'adminParticipants': {
    '$_ownerId': {'id': _ownerId, 'permissions': 4095},
    ...admins,
  },
  'options': options,
};

class _RecordingApi extends Api {
  final Map<String, dynamic> Function() reply;
  final List<(int, Map<dynamic, dynamic>, bool)> requests = [];

  _RecordingApi(this.reply);

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
  }) async {
    requests.add((opcode, payload, silent));
    return Packet(cmd: CmdType.ok, opcode: opcode, payload: reply());
  }
}

void main() {
  group('channel admin rights', () {
    test('read the captured appoint request', () {
      const rights = AdminRights(1958);

      expect(rights.has(AdminRight.createPosts), isTrue);
      expect(rights.has(AdminRight.editPosts), isTrue);
      expect(rights.has(AdminRight.deletePosts), isTrue);
      expect(rights.has(AdminRight.manageFollowers), isTrue);
      expect(rights.has(AdminRight.manageAdmins), isTrue);
      expect(rights.has(AdminRight.editInfo), isFalse);
      expect(rights.has(AdminRight.pinMessages), isFalse);
      expect(rights.has(AdminRight.viewStats), isFalse);
    });

    test('dropping followers reproduces the captured edit request', () {
      final edited = const AdminRights(
        1958,
      ).withRight(AdminRight.manageFollowers, false);

      expect(edited.bits, 1828);
    });

    test('a new channel admin starts with every switch on', () {
      final defaults = AdminRights.appointDefaults(AdminChatKind.channel);

      for (final right in AdminRights.layoutOf(
        AdminChatKind.channel,
      ).expand((group) => group)) {
        expect(defaults.has(right), isTrue, reason: right.name);
      }
      expect(defaults.bits & (1 | 64), 0);
    });
  });

  group('group admin rights', () {
    test('a new group admin matches the plain captured appoint', () {
      expect(AdminRights.appointDefaults(AdminChatKind.group).bits, 123);
    });

    test('granting admins on top gives the captured 127', () {
      final rights = AdminRights.appointDefaults(
        AdminChatKind.group,
      ).withRight(AdminRight.manageAdmins, true);

      expect(rights.bits, 127);
    });

    test('dropping edit chat and then deleting reproduces 119 and 118', () {
      final withoutEdit = const AdminRights(
        127,
      ).withRight(AdminRight.editInfo, false);
      final withoutDelete = withoutEdit.withRight(
        AdminRight.deleteMessages,
        false,
      );

      expect(withoutEdit.bits, 119);
      expect(withoutDelete.bits, 118);
    });

    test('the link switch is separate from members', () {
      const rights = AdminRights(127);

      expect(rights.has(AdminRight.manageMembers), isTrue);
      expect(rights.has(AdminRight.editLink), isFalse);
    });

    test('is empty only when no group switch is on', () {
      expect(
        const AdminRights(32 | 64).isEmptyFor(AdminChatKind.group),
        isTrue,
      );
      expect(const AdminRights(1).isEmptyFor(AdminChatKind.group), isFalse);
    });
  });

  group('rights toggling', () {
    test('keeps bits no switch controls', () {
      final rights = const AdminRights(
        1 | 64,
      ).withRight(AdminRight.pinMessages, true);

      expect(rights.bits, 1 | 64 | 16);
      expect(rights.withRight(AdminRight.pinMessages, false).bits, 1 | 64);
    });
  });

  group('ChatInfo rights', () {
    final info = ChatInfo.fromMap(
      _chat(
        admins: {
          '$_adminId': {'id': _adminId, 'permissions': 1828},
        },
        options: {'JOIN_REQUEST': true},
      ),
    );

    test('the owner holds every right', () {
      expect(info.rightsOf(_ownerId).bits, AdminRights.ownerBits);
      expect(info.can(_ownerId, AdminRight.manageAdmins), isTrue);
    });

    test('an admin holds what the server granted', () {
      expect(info.rightsOf(_adminId).bits, 1828);
      expect(info.can(_adminId, AdminRight.manageAdmins), isTrue);
      expect(info.can(_adminId, AdminRight.manageFollowers), isFalse);
    });

    test('a follower holds nothing', () {
      expect(info.rightsOf(_followerId).bits, 0);
      expect(info.can(_followerId, AdminRight.createPosts), isFalse);
    });

    test('reads join requests and the chat kind', () {
      expect(info.joinRequests, isTrue);
      expect(info.adminKind, AdminChatKind.channel);
      expect(
        ChatInfo.fromMap(_chat(type: 'CHAT')).adminKind,
        AdminChatKind.group,
      );
    });
  });

  group('MemberPermission', () {
    test('reads inverted and direct options', () {
      final info = ChatInfo.fromMap(
        _chat(
          type: 'CHAT',
          options: {
            'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': true,
            'ONLY_ADMIN_CAN_ADD_MEMBER': false,
            'ALL_CAN_PIN_MESSAGE': true,
            'MEMBERS_CAN_SEE_PRIVATE_LINK': false,
            'ONLY_ADMIN_CAN_CALL': true,
          },
        ),
      );

      expect(MemberPermission.editInfo.allowedIn(info), isFalse);
      expect(MemberPermission.addMembers.allowedIn(info), isTrue);
      expect(MemberPermission.pinMessages.allowedIn(info), isTrue);
      expect(MemberPermission.inviteByLink.allowedIn(info), isFalse);
      expect(MemberPermission.call.allowedIn(info), isFalse);
    });

    test('writes the captured option values', () {
      expect(MemberPermission.editInfo.optionFor(false), {
        'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': true,
      });
      expect(MemberPermission.pinMessages.optionFor(false), {
        'ALL_CAN_PIN_MESSAGE': false,
      });
      expect(MemberPermission.call.optionFor(false), {
        'ONLY_ADMIN_CAN_CALL': true,
      });
      expect(MemberPermission.addMembers.optionFor(false), {
        'ONLY_ADMIN_CAN_ADD_MEMBER': true,
      });
      expect(MemberPermission.pinMessages.optionFor(true), {
        'ALL_CAN_PIN_MESSAGE': true,
      });
    });
  });

  group('ChatReactionSettings', () {
    const catalog = ['👍', '❤️', '⚡️', '😴'];

    test('treats listed reactions as forbidden by default', () {
      final settings = ChatReactionSettings.fromMap({
        'isActive': true,
        'count': 8,
        'included': false,
        'reactionIds': ['😴', '⚡'],
      })!;

      expect(settings.allowedOf(catalog), {'👍', '❤️'});
      expect(settings.restricted, isTrue);
    });

    test('treats listed reactions as the only allowed when included', () {
      final settings = ChatReactionSettings.fromMap({
        'isActive': true,
        'count': 4,
        'included': true,
        'reactionIds': ['👍'],
      })!;

      expect(settings.allowedOf(catalog), {'👍'});
    });

    test('an empty forbidden list allows everything', () {
      final settings = ChatReactionSettings.fromMap({
        'isActive': true,
        'count': 4,
        'included': false,
        'reactionIds': const [],
      })!;

      expect(settings.allowedOf(catalog), catalog.toSet());
      expect(settings.restricted, isFalse);
    });

    test('forbids whatever is not allowed', () {
      expect(ChatReactionSettings.forbiddenOf(catalog, {'👍', '❤️'}), [
        '⚡️',
        '😴',
      ]);
    });
  });

  group('ChatAdminState', () {
    ChatAdminState state(
      int myId, {
      String type = 'CHANNEL',
      int adminPermissions = 1828,
      Map<String, bool> options = const {},
    }) => ChatAdminState(
      chatId: _chatId,
      myId: myId,
      name: 'Synthetic chat',
      imageUrl: '',
      info: ChatInfo.fromMap(
        _chat(
          type: type,
          options: options,
          admins: {
            '$_adminId': {'id': _adminId, 'permissions': adminPermissions},
          },
        ),
      ),
    );

    test('lists the owner first', () {
      expect(state(_ownerId).adminIds, [_ownerId, _adminId]);
    });

    test('the owner manages everyone but themselves', () {
      final owner = state(_ownerId);

      expect(owner.isOwner, isTrue);
      expect(owner.canEditAdmin(_adminId), isTrue);
      expect(owner.canEditAdmin(_ownerId), isFalse);
      expect(owner.canManageFollowers, isTrue);
    });

    test('an admin follows the rights the owner granted', () {
      final admin = state(_adminId);

      expect(admin.isAdmin, isTrue);
      expect(admin.canManageAdmins, isTrue);
      expect(admin.canManageFollowers, isFalse);
      expect(admin.canEditAdmin(_ownerId), isFalse);
      expect(admin.canEditAdmin(_adminId), isFalse);
    });

    test('channels have no group settings', () {
      expect(state(_ownerId).hasSettings, isFalse);
    });

    test('a group admin with edit rights gets the settings', () {
      final admin = state(_adminId, type: 'CHAT', adminPermissions: 123);

      expect(admin.hasSettings, isTrue);
      expect(admin.canManageChat, isTrue);
      expect(admin.canEditInfo, isTrue);
    });

    test('a member edits the group only when members may', () {
      final locked = state(
        _followerId,
        type: 'CHAT',
        options: {'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': true},
      );
      final open = state(
        _followerId,
        type: 'CHAT',
        options: {'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': false},
      );

      expect(locked.hasSettings, isFalse);
      expect(open.hasSettings, isTrue);
      expect(open.canEditInfo, isTrue);
      expect(open.canManageChat, isFalse);
    });

    test('keeps the opened avatar until the server changes it', () {
      final opened = ChatAdminState(
        chatId: _chatId,
        myId: _ownerId,
        name: 'Synthetic chat',
        imageUrl: 'https://example.test/list.jpg',
        info: ChatInfo.fromMap({
          ..._chat(type: 'CHAT', title: 'Synthetic chat'),
          'baseIconUrl': 'https://example.test/server.jpg',
        }),
      );

      expect(opened.imageUrl, 'https://example.test/list.jpg');
      expect(opened.name, 'Synthetic chat');

      opened.adopt(
        ChatInfo.fromMap({
          ..._chat(type: 'CHAT', title: 'Synthetic chat'),
          'baseIconUrl': 'https://example.test/fresh.jpg',
        }),
      );

      expect(opened.imageUrl, 'https://example.test/fresh.jpg');
    });

    test('takes the name from the server answer', () {
      final owner = state(_ownerId);
      var notified = 0;
      owner.addListener(() => notified++);

      owner.adopt(ChatInfo.fromMap(_chat(title: 'Synthetic renamed')));

      expect(notified, 1);
      expect(owner.name, 'Synthetic renamed');
      expect(owner.adminIds, [_ownerId]);
    });
  });

  group('ChatAdminModule', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(ChatInfoFetch.clear);

    test('appoints an admin with the chosen permissions', () async {
      final api = _RecordingApi(
        () => {
          'chat': _chat(
            type: 'CHAT',
            admins: {
              '$_followerId': {'id': _followerId, 'permissions': 123},
            },
          ),
        },
      );

      final info = await ChatAdminModule(
        api,
      ).setAdmin(_chatId, _followerId, const AdminRights(123));

      final (opcode, payload, silent) = api.requests.single;
      expect(opcode, Opcode.chatMembersUpdate);
      expect(payload, {
        'chatId': _chatId,
        'userIds': [_followerId],
        'type': 'ADMIN',
        'operation': 'add',
        'permissions': 123,
      });
      expect(silent, isTrue);
      expect(info.isAdmin(_followerId), isTrue);
      expect(ChatInfoFetch.peek(_chatId)?.isAdmin(_followerId), isTrue);
    });

    test('removes an admin', () async {
      final api = _RecordingApi(() => {'chat': _chat()});

      final info = await ChatAdminModule(api).removeAdmin(_chatId, _adminId);

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatMembersUpdate);
      expect(payload, {
        'chatId': _chatId,
        'userIds': [_adminId],
        'type': 'ADMIN',
        'operation': 'remove',
      });
      expect(info.isAdmin(_adminId), isFalse);
    });

    test('transfers ownership', () async {
      final api = _RecordingApi(() => {'chat': _chat()});

      await ChatAdminModule(api).transferOwnership(_chatId, _adminId);

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatUpdate);
      expect(payload, {'chatId': _chatId, 'changeOwnerId': _adminId});
    });

    test('revokes the invite link and adopts the new one', () async {
      final api = _RecordingApi(
        () => {'chat': _chat(link: 'https://example.test/join/fresh')},
      );

      final info = await ChatAdminModule(api).revokeInviteLink(_chatId);

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatUpdate);
      expect(payload, {'chatId': _chatId, 'revokePrivateLink': true});
      expect(info.link, 'https://example.test/join/fresh');
    });

    test('switches chat options', () async {
      final api = _RecordingApi(
        () => {
          'chat': _chat(type: 'CHAT', options: {'ALL_CAN_PIN_MESSAGE': false}),
        },
      );

      final info = await ChatAdminModule(
        api,
      ).setOptions(_chatId, {'ALL_CAN_PIN_MESSAGE': false});

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatUpdate);
      expect(payload, {
        'chatId': _chatId,
        'options': {'ALL_CAN_PIN_MESSAGE': false},
      });
      expect(MemberPermission.pinMessages.allowedIn(info), isFalse);
    });

    test('renames the chat with its description', () async {
      final api = _RecordingApi(
        () => {'chat': _chat(type: 'CHAT', title: 'Synthetic title')},
      );

      final info = await ChatAdminModule(api).updateInfo(
        _chatId,
        title: 'Synthetic title',
        description: 'Synthetic about',
      );

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatUpdate);
      expect(payload, {
        'chatId': _chatId,
        'theme': 'Synthetic title',
        'description': 'Synthetic about',
      });
      expect(info.title, 'Synthetic title');
    });

    test('sets the chat photo by token', () async {
      final api = _RecordingApi(() => {'chat': _chat(type: 'CHAT')});

      await ChatAdminModule(api).setPhoto(_chatId, 'synthetic-photo-token');

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatUpdate);
      expect(payload, {
        'chatId': _chatId,
        'photoToken': 'synthetic-photo-token',
      });
    });

    test('reads reaction settings for the chat', () async {
      final api = _RecordingApi(
        () => {
          'chatReactionsSettings': [
            {
              'chatId': _chatId,
              'isActive': true,
              'count': 8,
              'included': false,
              'reactionIds': ['😴'],
            },
          ],
        },
      );

      final settings = await ChatAdminModule(api).reactionSettingsFor(_chatId);

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.reactionsSettingsGetByChatId);
      expect(payload, {
        'chatIds': [_chatId],
      });
      expect(settings?.count, 8);
      expect(settings?.reactionIds, ['😴']);
    });

    test('forbids reactions in the captured shape', () async {
      final api = _RecordingApi(
        () => {
          'chatReactionsSettings': {
            'chatId': _chatId,
            'isActive': true,
            'count': 8,
            'included': false,
            'reactionIds': ['😴', '😈'],
          },
        },
      );

      final settings = await ChatAdminModule(
        api,
      ).setReactions(_chatId, count: 8, forbidden: ['😴', '😈']);

      final (opcode, payload, _) = api.requests.single;
      expect(opcode, Opcode.chatReactionsSettingsSet);
      expect(payload, {
        'chatId': _chatId,
        'value': true,
        'count': 8,
        'reactionIds': ['😴', '😈'],
        'included': false,
      });
      expect(settings.reactionIds, ['😴', '😈']);
    });

    test('turns reactions off', () async {
      final api = _RecordingApi(
        () => {
          'chatReactionsSettings': {
            'chatId': _chatId,
            'isActive': false,
            'count': 4,
            'included': false,
            'reactionIds': const [],
          },
        },
      );

      final settings = await ChatAdminModule(api).disableReactions(_chatId);

      final (_, payload, _) = api.requests.single;
      expect(payload, {'chatId': _chatId, 'value': false});
      expect(settings.isActive, isFalse);
    });
  });
}
