import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/komet_avatar.dart';
import '../../../widgets/settings_card.dart';
import '../../profile/profile_qr_sheet.dart';
import '../chat_list_screen.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';

class ChannelInviteLinkScreen extends StatefulWidget {
  final ChatAdminState state;

  const ChannelInviteLinkScreen({super.key, required this.state});

  @override
  State<ChannelInviteLinkScreen> createState() =>
      _ChannelInviteLinkScreenState();
}

class _ChannelInviteLinkScreenState extends State<ChannelInviteLinkScreen> {
  bool _busy = false;

  ChatAdminState get _state => widget.state;

  Future<void> _copy(String link) async {
    final message = AppLocalizations.of(context)!.sharedLinkCopied;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showCustomNotification(context, message);
  }

  Future<void> _sendInMax(String link) async {
    final l10n = AppLocalizations.of(context)!;
    final target = await openForwardScreen(context: context);
    if (target == null || !mounted) return;
    final ok = await messagesModule.sendLinkMessage(target.chatId, link);
    if (!mounted) return;
    showCustomNotification(
      context,
      ok ? l10n.callLinkSent : l10n.callLinkSendFailed,
    );
  }

  void _showQr(String link) {
    final l10n = AppLocalizations.of(context)!;
    showLinkQrSheet(
      context,
      name: _state.name,
      avatarUrl: _state.imageUrl,
      title: l10n.chatQrTitle,
      hint: l10n.chatQrHint,
      unavailable: l10n.linkQrUnavailable,
      loadLink: () async => link,
    );
  }

  Future<void> _revoke() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.channelInviteRevoke,
      message: l10n.channelInviteRevokeConfirm,
      confirmLabel: l10n.channelInviteRevokeAction,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    if (await _run(_state.revokeInviteLink) && mounted) {
      showCustomNotification(context, l10n.channelInviteRevoked);
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final ok = await runAdminAction(context, action);
    if (mounted) setState(() => _busy = false);
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: l10n.chatInfoInviteLink,
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          final link = _state.inviteLink;
          if (link == null) {
            return MembersListFooter(
              loading: false,
              message: l10n.linkQrUnavailable,
            );
          }
          return _body(l10n, link);
        },
      ),
    );
  }

  Widget _body(AppLocalizations l10n, String link) {
    final cs = Theme.of(context).colorScheme;
    final hintStyle = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        AdminSectionCaption(l10n.chatInfoInviteLink),
        SettingsCard(children: [_linkRow(cs, l10n, link)]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Text(l10n.chatInfoInviteLinkHint, style: hintStyle),
        ),
        SettingsCard(
          children: [
            AdminActionTile(
              icon: Symbols.forward,
              label: l10n.channelInviteSendInMax,
              color: cs.onSurface,
              onTap: () => _sendInMax(link),
            ),
            AdminActionTile(
              icon: Symbols.qr_code_2,
              label: l10n.channelInviteShowQr,
              color: cs.onSurface,
              onTap: () => _showQr(link),
            ),
          ],
        ),
        if (_state.canManageFollowers) ...[
          const SizedBox(height: 16),
          SettingsCard(
            children: [
              SettingsToggleTile(
                icon: Symbols.how_to_reg,
                label: l10n.channelJoinRequests,
                value: _state.info.joinRequests,
                enabled: !_busy,
                onChanged: (value) => _run(() => _state.setJoinRequests(value)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(l10n.channelJoinRequestsHint, style: hintStyle),
          ),
        ],
      ],
    );
  }

  Widget _linkRow(ColorScheme cs, AppLocalizations l10n, String link) {
    final canRevoke = _state.canManageFollowers && !_state.info.isPublic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      child: Row(
        children: [
          KometAvatar(name: _state.name, imageUrl: _state.imageUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  link.replaceFirst(RegExp(r'^https?://'), ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _state.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.sharedCopyLink,
            icon: Icon(Symbols.content_copy, color: cs.onSurfaceVariant),
            onPressed: () => _copy(link),
          ),
          if (canRevoke)
            PopupMenuButton<VoidCallback>(
              enabled: !_busy,
              icon: Icon(Symbols.more_vert, color: cs.onSurfaceVariant),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem<VoidCallback>(
                  value: _revoke,
                  child: Row(
                    children: [
                      Icon(Symbols.autorenew, size: 20, color: cs.onSurface),
                      const SizedBox(width: 12),
                      Flexible(child: Text(l10n.channelInviteRevoke)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
