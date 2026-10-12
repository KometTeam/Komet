import 'package:flutter/material.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/swipe_route.dart';
import 'chat_admin_state.dart';
import 'member_picker_screen.dart';

Future<bool> confirmOwnershipTransfer(
  BuildContext context,
  ChatAdminState state, {
  required int userId,
  required String name,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.ownershipTransfer,
    message: l10n.ownershipTransferConfirm(name),
    confirmLabel: l10n.ownershipTransferAction,
    cancelLabel: l10n.chatInfoActionCancel,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  final ok = await runAdminAction(
    context,
    () => state.transferOwnership(userId),
  );
  if (ok && context.mounted) {
    showCustomNotification(context, l10n.ownershipTransferred);
  }
  return ok;
}

Future<bool> pickNewOwner(BuildContext context, ChatAdminState state) async {
  final l10n = AppLocalizations.of(context)!;
  final transferred = await pushSwipeable<bool>(
    context,
    (_) => MemberPickerScreen(
      state: state,
      title: l10n.ownershipPickTitle,
      emptyLabel: l10n.ownershipPickEmpty,
      include: (member) => !member.blocked && member.id != state.myId,
      onPick: (pickerContext, member) => confirmOwnershipTransfer(
        pickerContext,
        state,
        userId: member.id,
        name: _nameOf(member),
      ),
    ),
  );
  return transferred == true;
}

Future<bool> transferBeforeLeaving(
  BuildContext context,
  ChatAdminState state,
) async {
  if (!state.isOwner || !state.hasOtherMembers) return true;
  final l10n = AppLocalizations.of(context)!;
  final wantsTransfer = await showConfirmDialog(
    context,
    title: l10n.ownerLeaveTitle,
    message: state.isChannel
        ? l10n.ownerLeaveChannelMessage
        : l10n.ownerLeaveGroupMessage,
    confirmLabel: l10n.ownershipTransfer,
    cancelLabel: l10n.chatInfoActionCancel,
  );
  if (!wantsTransfer || !context.mounted) return false;
  return pickNewOwner(context, state);
}

String _nameOf(ChatMemberEntry member) =>
    member.name ?? ContactCache.get(member.id) ?? '${member.id}';
