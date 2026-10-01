import 'chat_info.dart';

enum MemberPermission {
  editInfo('ONLY_OWNER_CAN_CHANGE_ICON_TITLE', inverted: true),
  addMembers('ONLY_ADMIN_CAN_ADD_MEMBER', inverted: true),
  pinMessages('ALL_CAN_PIN_MESSAGE'),
  inviteByLink('MEMBERS_CAN_SEE_PRIVATE_LINK'),
  call('ONLY_ADMIN_CAN_CALL', inverted: true);

  const MemberPermission(this.option, {this.inverted = false});

  final String option;
  final bool inverted;

  bool allowedIn(ChatInfo info) => info.option(option) != inverted;

  Map<String, bool> optionFor(bool allowed) => {option: allowed != inverted};
}
