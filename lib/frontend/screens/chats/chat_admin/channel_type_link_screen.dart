import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/config/app_fonts.dart';
import '../../../../core/utils/link_opener.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../widgets/animoji_glyph.dart';
import '../../../widgets/chat_menu_overlay.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/hint_bubble.dart';
import '../../../widgets/max_link_handler.dart';
import '../../../widgets/settings_card.dart';
import '../../profile/profile_qr_sheet.dart';
import '../chat_list_screen.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';

class ChannelTypeLinkScreen extends StatefulWidget {
  static const String businessBotLink = 'https://max.ru/business_channel_bot';

  final ChatAdminState state;
  final bool justCreated;

  const ChannelTypeLinkScreen({
    super.key,
    required this.state,
    this.justCreated = false,
  });

  @override
  State<ChannelTypeLinkScreen> createState() => _ChannelTypeLinkScreenState();
}

class _ChannelTypeLinkScreenState extends State<ChannelTypeLinkScreen> {
  bool _busy = false;

  ChatAdminState get _state => widget.state;

  Future<void> _copy(BuildContext anchor, String link) async {
    final message = AppLocalizations.of(context)!.sharedLinkCopied;
    await Clipboard.setData(ClipboardData(text: link));
    if (anchor.mounted) showHintBubble(anchor, message);
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

  Future<void> _openBusinessBot() async {
    const link = ChannelTypeLinkScreen.businessBotLink;
    if (await tryHandleMaxLink(context, link) || !mounted) return;
    await openExternalUrl(context, link);
  }

  void _showLinkMenu(BuildContext anchor) {
    final box = anchor.findRenderObject();
    if (box is! RenderBox) return;
    final l10n = AppLocalizations.of(context)!;
    showChatMenu(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      compact: true,
      items: [
        ChatMenuItem(
          icon: Symbols.autorenew,
          label: l10n.channelInviteRevoke,
          onTap: _revoke,
        ),
      ],
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
      title: l10n.channelTypeTitle,
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => _body(l10n),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final hintStyle = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    final link = _state.inviteLink;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (widget.justCreated) _createdHeader(cs, l10n),
        SettingsCard(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _typeOption(
                  cs,
                  title: l10n.channelTypePrivate,
                  hint: l10n.channelTypePrivateHint,
                  selected: !_state.info.isPublic,
                ),
                Builder(
                  builder: (anchor) => _typeOption(
                    cs,
                    title: l10n.channelTypePublic,
                    hint: l10n.channelTypePublicHint,
                    selected: _state.info.isPublic,
                    onTap: () => showHintBubble(
                      anchor,
                      l10n.channelTypePublicUnavailable,
                    ),
                  ),
                ),
                if (link != null) _linkField(cs, link),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: Text(
                    link == null
                        ? l10n.linkQrUnavailable
                        : l10n.channelInviteLinkCaption,
                    style: hintStyle,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(children: [_businessTile(cs, l10n)]),
        if (link != null) ...[
          const SizedBox(height: 12),
          SettingsCard(
            children: [
              Builder(
                builder: (anchor) => AdminActionTile(
                  icon: Symbols.content_copy,
                  label: l10n.sharedCopyLink,
                  color: cs.onSurface,
                  onTap: () => _copy(anchor, link),
                ),
              ),
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
        ],
        if (!widget.justCreated && _state.canManageFollowers) ...[
          const SizedBox(height: 12),
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

  Widget _createdHeader(ColorScheme cs, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        children: [
          const AnimojiGlyph(emoji: '🎉', size: 96),
          const SizedBox(height: 16),
          Text(
            l10n.channelCreatedTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.channelCreatedSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _typeOption(
    ColorScheme cs, {
    required String title,
    required String hint,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: selected ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: selected
                  ? Icon(Symbols.check, color: cs.primary, size: 22)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkField(ColorScheme cs, String link) {
    final canRevoke = _state.canManageFollowers && !_state.info.isPublic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 4, canRevoke ? 4 : 14, 4),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                link.replaceFirst(RegExp(r'^https?://'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.primary, fontSize: 15),
              ),
            ),
            if (canRevoke)
              Builder(
                builder: (anchor) => IconButton(
                  icon: Icon(Symbols.more_horiz, color: cs.onSurfaceVariant),
                  onPressed: _busy ? null : () => _showLinkMenu(anchor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _businessTile(ColorScheme cs, AppLocalizations l10n) {
    return InkWell(
      onTap: _openBusinessBot,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
        child: Row(
          children: [
            Icon(Symbols.business_center, color: cs.onSurfaceVariant, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.channelBusinessTitle,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.channelBusinessHint,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Symbols.chevron_right, color: cs.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
