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
import 'chat_admin_state.dart';
import 'chat_admin_widgets.dart';
import 'member_permissions_screen.dart';
import 'ownership_transfer.dart';
import 'reaction_settings_screen.dart';

class GroupSettingsScreen extends StatefulWidget {
  static const int descriptionLimit = 400;

  final ChatAdminState state;
  final VoidCallback onLeave;

  const GroupSettingsScreen({
    super.key,
    required this.state,
    required this.onLeave,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late final TextEditingController _title = TextEditingController(
    text: _state.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: _state.info.description ?? '',
  );
  bool _saving = false;
  bool _photoBusy = false;
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
      title: l10n.groupSettingsTitle,
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
        AdminSectionCaption(l10n.groupSettingsName),
        _field(cs, _title, enabled: editable),
        const SizedBox(height: 16),
        AdminSectionCaption(l10n.groupSettingsDescription),
        _field(
          cs,
          _description,
          enabled: editable,
          minLines: 3,
          maxLength: GroupSettingsScreen.descriptionLimit,
        ),
        const SizedBox(height: 16),
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
      ],
    );
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
