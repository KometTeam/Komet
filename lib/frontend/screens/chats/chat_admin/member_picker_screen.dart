import 'package:flutter/material.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';
import 'members_list.dart';
import 'members_pager.dart';

class MemberPickerScreen extends StatefulWidget {
  final ChatAdminState state;
  final String title;
  final String emptyLabel;
  final bool Function(ChatMemberEntry member) include;
  final Future<bool> Function(BuildContext context, ChatMemberEntry member)
  onPick;

  const MemberPickerScreen({
    super.key,
    required this.state,
    required this.title,
    required this.emptyLabel,
    required this.include,
    required this.onPick,
  });

  @override
  State<MemberPickerScreen> createState() => _MemberPickerScreenState();
}

class _MemberPickerScreenState extends State<MemberPickerScreen> {
  late final MembersPager _members = MembersPager(chatId: widget.state.chatId);
  bool _picking = false;

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

  Future<void> _pick(ChatMemberEntry member) async {
    if (_picking) return;
    _picking = true;
    final done = await widget.onPick(context, member);
    _picking = false;
    if (done && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: widget.title,
      body: Column(
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
              include: widget.include,
              emptyLabel: widget.emptyLabel,
              itemBuilder: (context, member) => AdminMemberTile(
                id: member.id,
                name: member.name,
                avatarUrl: member.avatarUrl,
                subtitle: memberPresenceLabel(l10n, member),
                onTap: () => _pick(member),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
