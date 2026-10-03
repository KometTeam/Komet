import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/swipe_route.dart';
import '../../contacts/open_contact_profile.dart';
import '../group_invite_sheets.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';
import 'member_actions.dart';
import 'channel_type_link_screen.dart';
import 'members_pager.dart';
import 'members_list.dart';

class ChannelFollowersScreen extends StatefulWidget {
  final ChatAdminState state;

  const ChannelFollowersScreen({super.key, required this.state});

  @override
  State<ChannelFollowersScreen> createState() => _ChannelFollowersScreenState();
}

class _ChannelFollowersScreenState extends State<ChannelFollowersScreen> {
  late final MembersPager _members = MembersPager(chatId: widget.state.chatId);

  ChatAdminState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _members.loadMore();
  }

  @override
  void dispose() {
    _members.dispose();
    super.dispose();
  }

  Future<void> _addFollowers() async {
    final added = await showAddMembersSheet(
      context,
      chatId: _state.chatId,
      excludeIds: {_state.myId, ..._state.adminIds, ..._members.loadedIds},
    );
    if (added != true || !mounted) return;
    await _members.reload();
    await _state.refresh();
  }

  void _openInviteLink() {
    pushSwipeable(context, (_) => ChannelTypeLinkScreen(state: _state));
  }

  String _nameOf(ChatMemberEntry member) =>
      member.name ?? ContactCache.get(member.id) ?? '${member.id}';

  void _openProfile(ChatMemberEntry member) {
    openContactDialogProfile(
      context,
      contactId: member.id,
      name: _nameOf(member),
      avatarUrl: member.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: l10n.channelFollowersTitle,
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: MemberSearchField(
                onChanged: (value) => _members.query = value,
              ),
            ),
            Expanded(
              child: MembersList(
                controller: _members,
                emptyLabel: l10n.channelFollowersEmpty,
                header: [
                  if (_state.canManageFollowers)
                    AdminActionTile(
                      icon: Symbols.person_add,
                      label: l10n.channelAddFollowers,
                      color: cs.primary,
                      onTap: _addFollowers,
                    ),
                  if (_state.inviteLink != null)
                    AdminActionTile(
                      icon: Symbols.link,
                      label: l10n.chatInfoInviteByLink,
                      color: cs.primary,
                      onTap: _openInviteLink,
                    ),
                ],
                itemBuilder: (context, member) => _tile(l10n, member),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppLocalizations l10n, ChatMemberEntry member) {
    final info = _state.info;
    final me = member.id == _state.myId;
    final leader = info.isOwner(member.id) || info.isAdmin(member.id);
    return AdminMemberTile(
      id: member.id,
      name: member.name,
      avatarUrl: member.avatarUrl,
      subtitle: leader
          ? adminRoleLabel(l10n, owner: info.isOwner(member.id), me: me)
          : me
          ? l10n.callParticipantYou
          : memberPresenceLabel(l10n, member),
      trailing: MemberActionsButton(
        state: _state,
        userId: member.id,
        name: member.name,
        avatarUrl: member.avatarUrl,
        isContact: member.isContact,
        onDone: (action) {
          if (action != MemberAction.appointAdmin) _members.reload();
        },
      ),
      onTap: me ? null : () => _openProfile(member),
    );
  }
}
