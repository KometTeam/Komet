import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../models/chat_restriction.dart';
import '../../../widgets/custom_notification.dart';
import '../../../widgets/komet_avatar.dart';
import '../../../widgets/settings_card.dart';
import '../../../widgets/small_spinner.dart';
import '../../../widgets/swipe_route.dart';
import '../profile_action_sheets.dart';
import 'channel_type_link_screen.dart';
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';
import 'member_permissions_screen.dart';
import 'ownership_transfer.dart';
import 'reaction_settings_screen.dart';

enum _ChannelDeletion { transferAndLeave, delete }

class ChatSettingsScreen extends StatefulWidget {
  static const int descriptionLimit = 400;

  final ChatAdminState state;
  final VoidCallback onLeave;
  final VoidCallback? onClearHistory;
  final VoidCallback? onDelete;

  const ChatSettingsScreen({
    super.key,
    required this.state,
    required this.onLeave,
    this.onClearHistory,
    this.onDelete,
  });

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  late final TextEditingController _title = TextEditingController(
    text: _state.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: _state.info.description ?? '',
  );
  bool _saving = false;
  bool _photoBusy = false;
  bool _optionBusy = false;
  ChatRestriction? _pendingRestriction;

  ChatAdminState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    if (_state.canManageChat) unawaited(_loadReactions());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadReactions() async {
    try {
      await Future.wait([_state.loadReactions(), animojiModule.ensureLoaded()]);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  bool get _dirty =>
      _title.text.trim() != _state.name ||
      _description.text.trim() != (_state.info.description ?? '');

  bool get _canSave =>
      _state.canEditInfo && _dirty && _title.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => _state.updateInfo(
        title: _title.text.trim(),
        description: _description.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) showCustomNotification(context, l10n.groupSettingsSaved);
  }

  Future<void> _changePhoto() async {
    if (_photoBusy || !_state.canEditInfo) return;
    final l10n = AppLocalizations.of(context)!;
    final picked = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = picked?.files.firstOrNull?.path;
    if (path == null || !mounted) return;
    if (await File(path).length() > kMaxAvatarBytes) {
      if (mounted) {
        showCustomNotification(context, l10n.groupSettingsPhotoTooLarge);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _photoBusy = true);
    final ok = await runAdminAction(context, () async {
      final bytes = await compressAvatarFile(path);
      if (bytes == null) throw StateError('avatar not processed');
      await _state.setPhoto(bytes);
    });
    if (!mounted) return;
    setState(() => _photoBusy = false);
    if (ok) showCustomNotification(context, l10n.groupSettingsPhotoUpdated);
  }

  Future<void> _toggleRestriction(
    ChatRestriction restriction,
    bool enabled,
  ) async {
    if (_pendingRestriction != null) return;
    setState(() => _pendingRestriction = restriction);
    await runAdminAction(
      context,
      () => _state.setRestriction(restriction, enabled),
    );
    if (mounted) setState(() => _pendingRestriction = null);
  }

  void _leave() {
    Navigator.of(context).pop();
    widget.onLeave();
  }

  void _closeThen(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  Future<void> _setComments(bool enabled) async {
    if (_optionBusy) return;
    if (enabled) {
      final l10n = AppLocalizations.of(context)!;
      final cs = Theme.of(context).colorScheme;
      final confirmed = await showActionCard<bool>(
        context,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Symbols.chat, fill: 1, color: cs.primary, size: 28),
        ),
        title: l10n.channelCommentsEnableTitle,
        message: l10n.channelCommentsEnableMessage,
        actions: [
          CardAction(
            l10n.channelCommentsEnable,
            true,
            tone: CardActionTone.primary,
          ),
          CardAction(l10n.channelCommentsKeepOff, false),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _optionBusy = true);
    await runAdminAction(context, () => _state.setComments(enabled));
    if (mounted) setState(() => _optionBusy = false);
  }

  Future<void> _deleteChannel() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    final l10n = AppLocalizations.of(context)!;
    final choice = await showActionCard<_ChannelDeletion>(
      context,
      title: l10n.channelDeleteTitle,
      message: l10n.channelDeleteMessage,
      stacked: true,
      actions: [
        if (_state.hasOtherMembers)
          CardAction(
            l10n.channelDeleteTransfer,
            _ChannelDeletion.transferAndLeave,
          ),
        CardAction(
          l10n.channelDelete,
          _ChannelDeletion.delete,
          tone: CardActionTone.destructive,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _ChannelDeletion.transferAndLeave:
        if (await pickNewOwner(context, _state) && mounted) _leave();
      case _ChannelDeletion.delete:
        _closeThen(onDelete);
    }
  }

  String? _reactionsSummary(AppLocalizations l10n) {
    final settings = _state.reactions;
    if (settings == null) return null;
    if (!settings.isActive) return l10n.reactionsSummaryOff;
    if (!settings.restricted) return l10n.reactionsSummaryAll;
    final catalog = animojiModule.emojis;
    if (catalog.isEmpty) return null;
    return l10n.reactionsSummaryCount(
      settings.allowedOf(catalog).length,
      catalog.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AdminScaffold(
      title: _state.isChannel
          ? l10n.channelSettingsTitle
          : l10n.groupSettingsTitle,
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: SmallSpinner(size: 22)),
          )
        else if (_state.canEditInfo)
          ListenableBuilder(
            listenable: Listenable.merge([_title, _description, _state]),
            builder: (context, _) => IconButton(
              tooltip: l10n.adminSave,
              icon: const Icon(Symbols.check),
              onPressed: _canSave ? _save : null,
            ),
          ),
      ],
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => _body(l10n),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final editable = _state.canEditInfo && !_saving;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Center(child: _avatar(cs)),
        const SizedBox(height: 20),
        AdminSectionCaption(
          _state.isChannel ? l10n.channelSettingsName : l10n.groupSettingsName,
        ),
        _field(cs, _title, enabled: editable),
        const SizedBox(height: 16),
        AdminSectionCaption(
          _state.isChannel
              ? l10n.channelSettingsDescription
              : l10n.groupSettingsDescription,
        ),
        _field(
          cs,
          _description,
          enabled: editable,
          minLines: 3,
          maxLength: ChatSettingsScreen.descriptionLimit,
        ),
        const SizedBox(height: 16),
        if (_state.isChannel)
          ..._channelSections(cs, l10n)
        else
          ..._groupSections(cs, l10n),
      ],
    );
  }

  List<Widget> _channelSections(ColorScheme cs, AppLocalizations l10n) {
    final info = _state.info;
    return [
      if (_state.canManageChat) ...[
        SettingsCard(
          children: [
            SettingsToggleTile(
              icon: Symbols.error,
              label: l10n.channelConfirmPosting,
              value: ChatRestriction.confirmBeforeSend.enabledIn(info),
              enabled: _pendingRestriction == null,
              onChanged: (enabled) => _toggleRestriction(
                ChatRestriction.confirmBeforeSend,
                enabled,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Text(
            l10n.channelConfirmPostingHint,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
      ],
      if (_state.inviteLink != null || _state.canManageFollowers) ...[
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.campaign,
              label: l10n.channelTypeTitle,
              value: info.isPublic
                  ? l10n.channelTypePublic
                  : l10n.channelTypePrivate,
              onTap: () => pushSwipeable(
                context,
                (_) => ChannelTypeLinkScreen(state: _state),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (_state.canManageChat) ...[
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.add_reaction,
              label: l10n.reactionsTitle,
              value: _reactionsSummary(l10n),
              onTap: () => pushSwipeable(
                context,
                (_) => ReactionSettingsScreen(state: _state),
              ),
            ),
            SettingsToggleTile(
              icon: Symbols.chat,
              label: l10n.channelComments,
              value: info.commentsEnabled,
              enabled: !_optionBusy,
              onChanged: _setComments,
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      SettingsCard(
        children: [
          if (_state.isOwner)
            AdminActionTile(
              icon: Symbols.crown,
              label: l10n.ownershipTransfer,
              color: cs.onSurface,
              onTap: () => pickNewOwner(context, _state),
            ),
          if (widget.onClearHistory case final clear? when _state.isAdmin)
            AdminActionTile(
              icon: Symbols.delete_history,
              label: l10n.chatInfoMenuClearHistory,
              color: cs.onSurface,
              onTap: () => _closeThen(clear),
            ),
          AdminActionTile(
            icon: Symbols.logout,
            label: l10n.chatInfoLeaveChannelTitle,
            color: cs.error,
            onTap: _leave,
          ),
        ],
      ),
      if (_state.isOwner && widget.onDelete != null) ...[
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            AdminActionTile(
              icon: Symbols.delete,
              label: l10n.channelDelete,
              color: cs.error,
              onTap: _deleteChannel,
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _groupSections(ColorScheme cs, AppLocalizations l10n) {
    return [
      if (_state.canManageChat) ...[
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.add_reaction,
              label: l10n.reactionsTitle,
              value: _reactionsSummary(l10n),
              onTap: () => pushSwipeable(
                context,
                (_) => ReactionSettingsScreen(state: _state),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      SettingsCard(
        children: [
          if (_state.isOwner)
            AdminActionTile(
              icon: Symbols.crown,
              label: l10n.ownershipTransfer,
              color: cs.onSurface,
              onTap: () => pickNewOwner(context, _state),
            ),
          AdminActionTile(
            icon: Symbols.logout,
            label: l10n.groupSettingsLeave,
            color: cs.error,
            onTap: _leave,
          ),
        ],
      ),
      if (_state.canManageChat) ...[
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsNavTile(
              icon: Symbols.verified_user,
              label: l10n.memberPermissionsTitle,
              onTap: () => pushSwipeable(
                context,
                (_) => MemberPermissionsScreen(state: _state),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AdminSectionCaption(l10n.groupRestrictionsTitle),
        SettingsCard(
          children: [
            for (final restriction in ChatRestriction.values)
              SettingsToggleTile(
                icon: _restrictionIcon(restriction),
                label: _restrictionLabel(l10n, restriction),
                subtitle: _restrictionHint(l10n, restriction),
                value: restriction.enabledIn(_state.info),
                enabled: _pendingRestriction == null,
                onChanged: (enabled) =>
                    _toggleRestriction(restriction, enabled),
              ),
          ],
        ),
      ],
    ];
  }

  static IconData _restrictionIcon(ChatRestriction restriction) =>
      switch (restriction) {
        ChatRestriction.forwardDisabled => Symbols.block,
        ChatRestriction.copyDisabled => Symbols.content_copy,
        ChatRestriction.confirmBeforeSend => Symbols.task_alt,
      };

  static String _restrictionLabel(
    AppLocalizations l10n,
    ChatRestriction restriction,
  ) => switch (restriction) {
    ChatRestriction.forwardDisabled => l10n.groupRestrictionForward,
    ChatRestriction.copyDisabled => l10n.groupRestrictionCopy,
    ChatRestriction.confirmBeforeSend => l10n.groupRestrictionConfirmSend,
  };

  static String _restrictionHint(
    AppLocalizations l10n,
    ChatRestriction restriction,
  ) => switch (restriction) {
    ChatRestriction.forwardDisabled => l10n.groupRestrictionForwardHint,
    ChatRestriction.copyDisabled => l10n.groupRestrictionCopyHint,
    ChatRestriction.confirmBeforeSend => l10n.groupRestrictionConfirmSendHint,
  };

  Widget _avatar(ColorScheme cs) {
    return GestureDetector(
      onTap: _state.canEditInfo ? _changePhoto : null,
      child: SizedBox.square(
        dimension: 96,
        child: Stack(
          children: [
            KometAvatar(name: _state.name, imageUrl: _state.imageUrl, size: 96),
            if (_photoBusy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.scrim.withValues(alpha: 0.4),
                  ),
                  child: const Center(child: SmallSpinner(size: 28)),
                ),
              ),
            if (_state.canEditInfo)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Icon(
                    Symbols.photo_camera,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    ColorScheme cs,
    TextEditingController controller, {
    required bool enabled,
    int minLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: minLines == 1 ? 1 : 6,
      maxLength: maxLength,
      style: TextStyle(color: cs.onSurface, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
