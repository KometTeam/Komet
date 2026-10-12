import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../core/cache/info_cache.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/contact_info.dart';
import '../../../widgets/settings_card.dart';
import '../../../widgets/swipe_route.dart';
import '../../contacts/open_contact_profile.dart';
import 'admin_rights_screen.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';
import 'member_picker_screen.dart';

class AdminsScreen extends StatefulWidget {
  final ChatAdminState state;

  const AdminsScreen({super.key, required this.state});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  final Map<int, ContactInfo> _profiles = {};
  final Set<int> _requested = {};

  ChatAdminState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    _state.addListener(_loadProfiles);
    _loadProfiles();
  }

  @override
  void dispose() {
    _state.removeListener(_loadProfiles);
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final missing = _state.adminIds.where(_requested.add).toList();
    if (missing.isEmpty) return;
    final loaded = await ContactInfoFetch.getMany(missing);
    if (!mounted || loaded.isEmpty) return;
    setState(() => _profiles.addAll(loaded));
  }

  String? _nameOf(int id) => _profiles[id]?.displayName ?? ContactCache.get(id);

  String? _avatarOf(int id) =>
      _profiles[id]?.avatarUrl ?? ContactCache.getAvatar(id);

  void _openAdmin(int id) {
    if (_state.canEditAdmin(id)) {
      pushSwipeable(
        context,
        (_) => AdminRightsScreen(
          state: _state,
          userId: id,
          name: _nameOf(id),
          avatarUrl: _avatarOf(id),
          appointing: false,
        ),
      );
      return;
    }
    if (id == _state.myId) return;
    openContactDialogProfile(
      context,
      contactId: id,
      name: _nameOf(id) ?? '$id',
      avatarUrl: _avatarOf(id),
    );
  }

  void _addAdmin() {
    final l10n = AppLocalizations.of(context)!;
    final info = _state.info;
    pushSwipeable(
      context,
      (_) => MemberPickerScreen(
        state: _state,
        title: _state.isChannel
            ? l10n.channelPickAdminTitle
            : l10n.groupPickAdminTitle,
        emptyLabel: l10n.adminsPickEmpty,
        include: (member) =>
            !member.blocked &&
            member.id != _state.myId &&
            !info.isOwner(member.id) &&
            !info.isAdmin(member.id),
        onPick: _appoint,
      ),
    );
  }

  Future<bool> _appoint(
    BuildContext pickerContext,
    ChatMemberEntry member,
  ) async {
    final appointed = await pushSwipeable<bool>(
      pickerContext,
      (_) => AdminRightsScreen(
        state: _state,
        userId: member.id,
        name: member.name,
        avatarUrl: member.avatarUrl,
        appointing: true,
      ),
    );
    return appointed == true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: l10n.adminsTitle,
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          final ids = _state.adminIds;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              SettingsCard(
                children: [
                  if (_state.canManageAdmins)
                    AdminActionTile(
                      icon: Symbols.person_add,
                      label: l10n.adminsAdd,
                      color: cs.primary,
                      onTap: _addAdmin,
                    ),
                  for (final id in ids)
                    AdminMemberTile(
                      key: ValueKey(id),
                      id: id,
                      name: _nameOf(id),
                      avatarUrl: _avatarOf(id),
                      subtitle: adminRoleLabel(
                        l10n,
                        owner: _state.info.isOwner(id),
                        me: id == _state.myId,
                      ),
                      trailing: _state.canEditAdmin(id)
                          ? Icon(
                              Symbols.chevron_right,
                              color: cs.outline,
                              size: 20,
                            )
                          : null,
                      onTap: id == _state.myId ? null : () => _openAdmin(id),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
