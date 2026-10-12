import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/contacts.dart';
import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart' show api;
import '../../../widgets/chat_menu_overlay.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/hint_bubble.dart';
import '../../../widgets/swipe_route.dart';
import 'admin_rights_screen.dart';
import 'chat_admin_state.dart';

enum MemberAction { addContact, appointAdmin, remove }

List<MemberAction> memberActionsFor(
  ChatAdminState state, {
  required int userId,
  required bool isContact,
}) {
  final info = state.info;
  if (userId == state.myId || info.isOwner(userId)) return const [];
  final leader = info.isAdmin(userId);
  return [
    if (!isContact) MemberAction.addContact,
    if (state.canManageAdmins && !leader) MemberAction.appointAdmin,
    if (state.canRemoveMembers && !leader) MemberAction.remove,
  ];
}

class MemberActionsButton extends StatelessWidget {
  final ChatAdminState state;
  final int userId;
  final String? name;
  final String? avatarUrl;
  final bool isContact;
  final ValueChanged<MemberAction> onDone;

  const MemberActionsButton({
    super.key,
    required this.state,
    required this.userId,
    this.name,
    this.avatarUrl,
    required this.isContact,
    required this.onDone,
  });

  String get _displayName => name ?? ContactCache.get(userId) ?? '$userId';

  @override
  Widget build(BuildContext context) {
    final actions = memberActionsFor(
      state,
      userId: userId,
      isContact: isContact,
    );
    if (actions.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(
        Symbols.more_horiz,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => _show(context, actions),
    );
  }

  void _show(BuildContext context, List<MemberAction> actions) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final l10n = AppLocalizations.of(context)!;
    final removable = actions.contains(MemberAction.remove);
    final lastBeforeRemove = actions.lastWhere(
      (action) => action != MemberAction.remove,
      orElse: () => MemberAction.remove,
    );
    showChatMenu(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      compact: true,
      items: [
        for (final action in actions)
          ChatMenuItem(
            icon: switch (action) {
              MemberAction.addContact => Symbols.person_add,
              MemberAction.appointAdmin => Symbols.shield_person,
              MemberAction.remove => Symbols.delete,
            },
            label: switch (action) {
              MemberAction.addContact => l10n.contactProfileActionAddContact,
              MemberAction.appointAdmin => l10n.adminAppointAction,
              MemberAction.remove => l10n.followerRemove,
            },
            destructive: action == MemberAction.remove,
            dividerAfter:
                removable &&
                action != MemberAction.remove &&
                action == lastBeforeRemove,
            onTap: () => _run(context, action),
          ),
      ],
    );
  }

  void _run(BuildContext context, MemberAction action) {
    switch (action) {
      case MemberAction.addContact:
        _addContact(context);
      case MemberAction.appointAdmin:
        pushSwipeable(
          context,
          (_) => AdminRightsScreen(
            state: state,
            userId: userId,
            name: name,
            avatarUrl: avatarUrl,
            appointing: true,
          ),
        );
      case MemberAction.remove:
        _remove(context);
    }
  }

  Future<void> _addContact(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    CachedContact? contact;
    try {
      contact = await ContactsModule.addContact(api, userId, name ?? '');
    } catch (_) {}
    if (contact == null) {
      showCustomNotificationOnOverlay(overlay, l10n.addContactError);
      return;
    }
    if (context.mounted) {
      showHintBubble(context, l10n.nfcContactAdded);
    } else {
      showCustomNotificationOnOverlay(overlay, l10n.nfcContactAdded);
    }
    onDone(MemberAction.addContact);
  }

  Future<void> _remove(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    final channel = state.isChannel;
    final confirmed = await showConfirmDialog(
      context,
      title: channel ? l10n.followerRemoveTitle : l10n.memberRemoveTitle,
      message: channel
          ? l10n.followerRemoveConfirm(_displayName)
          : l10n.memberRemoveConfirm(_displayName),
      confirmLabel: l10n.followerRemove,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runAdminAction(context, () => state.removeMember(userId));
    if (!ok) return;
    showCustomNotificationOnOverlay(
      overlay,
      channel ? l10n.followerRemoved : l10n.memberRemoved,
    );
    onDone(MemberAction.remove);
  }
}
