import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../models/member_permission.dart';
import '../../../widgets/settings_card.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';

class MemberPermissionsScreen extends StatefulWidget {
  final ChatAdminState state;

  const MemberPermissionsScreen({super.key, required this.state});

  @override
  State<MemberPermissionsScreen> createState() =>
      _MemberPermissionsScreenState();
}

class _MemberPermissionsScreenState extends State<MemberPermissionsScreen> {
  MemberPermission? _pending;

  ChatAdminState get _state => widget.state;

  Future<void> _toggle(MemberPermission permission, bool allowed) async {
    if (_pending != null) return;
    setState(() => _pending = permission);
    await runAdminAction(
      context,
      () => _state.setMemberPermission(permission, allowed),
    );
    if (mounted) setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: l10n.memberPermissionsTitle,
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            AdminSectionCaption(l10n.memberPermissionsTitle),
            SettingsCard(
              children: [
                for (final permission in MemberPermission.values)
                  SettingsToggleTile(
                    icon: _iconOf(permission),
                    label: _labelOf(l10n, permission),
                    value: permission.allowedIn(_state.info),
                    enabled: _pending == null,
                    onChanged: (allowed) => _toggle(permission, allowed),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconOf(MemberPermission permission) => switch (permission) {
    MemberPermission.editInfo => Symbols.auto_fix_high,
    MemberPermission.addMembers => Symbols.group_add,
    MemberPermission.pinMessages => Symbols.push_pin,
    MemberPermission.inviteByLink => Symbols.link,
    MemberPermission.call => Symbols.call,
  };

  static String _labelOf(AppLocalizations l10n, MemberPermission permission) =>
      switch (permission) {
        MemberPermission.editInfo => l10n.memberPermissionEditInfo,
        MemberPermission.addMembers => l10n.memberPermissionAddMembers,
        MemberPermission.pinMessages => l10n.memberPermissionPin,
        MemberPermission.inviteByLink => l10n.memberPermissionInvite,
        MemberPermission.call => l10n.memberPermissionCall,
      };
}
