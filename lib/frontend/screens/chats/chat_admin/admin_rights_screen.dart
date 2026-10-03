import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../l10n/app_localizations.dart';
import '../../../../models/admin_rights.dart';
import '../../../../models/member_permission.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/komet_avatar.dart';
import '../../../widgets/primary_loading_button.dart';
import '../../../widgets/settings_card.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';
import 'ownership_transfer.dart';

class AdminRightsScreen extends StatefulWidget {
  final ChatAdminState state;
  final int userId;
  final String? name;
  final String? avatarUrl;
  final bool appointing;

  const AdminRightsScreen({
    super.key,
    required this.state,
    required this.userId,
    this.name,
    this.avatarUrl,
    required this.appointing,
  });

  @override
  State<AdminRightsScreen> createState() => _AdminRightsScreenState();
}

class _AdminRightsScreenState extends State<AdminRightsScreen> {
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  late final AdminRights _initial = widget.appointing
      ? _grantableDefaults()
      : widget.state.info.rightsOf(widget.userId);
  late AdminRights _rights = _initial;
  bool _busy = false;

  ChatAdminState get _state => widget.state;

  AdminChatKind get _kind => _state.kind;

  String get _name =>
      widget.name ?? ContactCache.get(widget.userId) ?? '${widget.userId}';

  bool get _canSave =>
      !_rights.isEmptyFor(_kind) && (widget.appointing || _rights != _initial);

  @override
  void dispose() {
    _saving.dispose();
    super.dispose();
  }

  bool _lockedOn(AdminRight right) =>
      _kind == AdminChatKind.group &&
      right == AdminRight.pinMessages &&
      MemberPermission.pinMessages.allowedIn(_state.info);

  bool _editable(AdminRight right) =>
      !_busy && !_lockedOn(right) && _state.canGrant(right);

  AdminRights _grantableDefaults() => AdminRights.layoutOf(_kind)
      .expand((group) => group)
      .where((right) => !_state.canGrant(right))
      .fold(
        AdminRights.appointDefaults(_kind),
        (rights, right) => rights.withRight(right, false),
      );

  Future<void> _save() {
    final l10n = AppLocalizations.of(context)!;
    final rights = _rights;
    return _runAndClose(
      () => _state.setAdmin(widget.userId, rights),
      widget.appointing ? l10n.adminAppointed : l10n.adminSaved,
      spinner: true,
    );
  }

  Future<void> _transferOwnership() async {
    if (_busy) return;
    setState(() => _busy = true);
    final transferred = await confirmOwnershipTransfer(
      context,
      _state,
      userId: widget.userId,
      name: _name,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (transferred) Navigator.of(context).pop(true);
  }

  Future<void> _removeAdmin() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminRemove,
      message: l10n.adminRemoveConfirm(_name),
      confirmLabel: l10n.adminRemoveAction,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _runAndClose(
      () => _state.removeAdmin(widget.userId),
      l10n.adminRemoved,
    );
  }

  Future<void> _runAndClose(
    Future<void> Function() action,
    String done, {
    bool spinner = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    _saving.value = spinner;
    final ok = await runAdminAction(context, action);
    if (!mounted) return;
    _saving.value = false;
    setState(() => _busy = false);
    if (!ok) return;
    showCustomNotification(context, done);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: widget.appointing ? l10n.adminAppointTitle : l10n.adminEditTitle,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _header(cs),
          const SizedBox(height: 20),
          for (final group in AdminRights.layoutOf(_kind)) ...[
            SettingsCard(
              children: [
                for (final right in group)
                  SettingsToggleTile(
                    icon: _iconOf(right),
                    label: _labelOf(l10n, right),
                    subtitle: _hintOf(l10n, right),
                    value: _rights.has(right) || _lockedOn(right),
                    enabled: _editable(right),
                    onChanged: (value) => setState(
                      () => _rights = _rights.withRight(right, value),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PrimaryLoadingButton(
              loading: _saving,
              onPressed: _canSave && !_busy ? _save : null,
              child: Text(
                widget.appointing ? l10n.adminAppointAction : l10n.adminSave,
              ),
            ),
          ),
          if (!widget.appointing) ...[
            const SizedBox(height: 20),
            SettingsCard(
              children: [
                if (_state.isOwner)
                  AdminActionTile(
                    icon: Symbols.crown,
                    label: l10n.ownershipTransfer,
                    color: cs.primary,
                    onTap: _busy ? null : _transferOwnership,
                  ),
                AdminActionTile(
                  icon: Symbols.person_remove,
                  label: l10n.adminRemove,
                  color: cs.error,
                  onTap: _busy ? null : _removeAdmin,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    return Column(
      children: [
        KometAvatar(
          name: _name,
          imageUrl: widget.avatarUrl ?? ContactCache.getAvatar(widget.userId),
          size: 88,
        ),
        const SizedBox(height: 12),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static IconData _iconOf(AdminRight right) => switch (right) {
    AdminRight.editInfo => Symbols.edit,
    AdminRight.createPosts => Symbols.post_add,
    AdminRight.editPosts => Symbols.edit_note,
    AdminRight.deletePosts || AdminRight.deleteMessages => Symbols.delete,
    AdminRight.pinMessages => Symbols.push_pin,
    AdminRight.manageFollowers || AdminRight.manageMembers => Symbols.group_add,
    AdminRight.editLink => Symbols.link,
    AdminRight.viewStats => Symbols.monitoring,
    AdminRight.manageAdmins => Symbols.shield_person,
  };

  String _labelOf(AppLocalizations l10n, AdminRight right) {
    final channel = _kind == AdminChatKind.channel;
    return switch (right) {
      AdminRight.editInfo =>
        channel ? l10n.channelRightEditChannel : l10n.groupRightEditInfo,
      AdminRight.createPosts => l10n.channelRightCreatePosts,
      AdminRight.editPosts => l10n.channelRightEditPosts,
      AdminRight.deletePosts => l10n.channelRightDeletePosts,
      AdminRight.deleteMessages => l10n.groupRightDeleteMessages,
      AdminRight.pinMessages =>
        channel ? l10n.channelRightPinPosts : l10n.groupRightPinMessages,
      AdminRight.manageFollowers => l10n.channelRightManageFollowers,
      AdminRight.manageMembers => l10n.groupRightManageMembers,
      AdminRight.editLink => l10n.groupRightEditLink,
      AdminRight.viewStats => l10n.channelRightViewStats,
      AdminRight.manageAdmins => l10n.adminRightManageAdmins,
    };
  }

  static String? _hintOf(AppLocalizations l10n, AdminRight right) =>
      switch (right) {
        AdminRight.editInfo => l10n.adminRightEditInfoHint,
        AdminRight.manageAdmins => l10n.adminRightManageAdminsHint,
        _ => null,
      };
}
