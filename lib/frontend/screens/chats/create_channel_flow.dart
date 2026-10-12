import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/chats.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/utils/image_utils.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/attachment/avatar_editor.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/swipe_route.dart';
import 'chat_admin/channel_type_link_screen.dart';
import 'chat_admin/chat_admin_state.dart';
import 'chat_screen.dart';
import '../../../l10n/app_localizations.dart';

Future<void> showCreateChannelFlow(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => const _CreateChannelFlow(),
  );
}

class _CreateChannelFlow extends StatefulWidget {
  const _CreateChannelFlow();

  @override
  State<_CreateChannelFlow> createState() => _CreateChannelFlowState();
}

class _CreateChannelFlowState extends State<_CreateChannelFlow> {
  final TextEditingController _title = TextEditingController();
  File? _avatar;
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_creating) return;
    final file = await pickAvatarImage(context);
    if (file == null) return;
    final size = await file.length();
    if (size > kMaxAvatarBytes) {
      if (!mounted) return;
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.groupSettingsPhotoTooLarge,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _avatar = file);
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      final chat = await chats.createChannel(api, title: title);
      if (!mounted) return;
      if (chat == null) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.createChannelFailed,
        );
        setState(() => _creating = false);
        return;
      }

      if (_avatar != null) {
        final url = await chats.requestChatPhotoUploadUrl(api);
        if (url != null) {
          final bytes = await compressAvatarFile(_avatar!.path);
          if (bytes == null) {
            if (mounted) {
              showCustomNotification(
                context,
                AppLocalizations.of(context)!.createChannelAvatarProcessFailed,
              );
            }
          } else {
            final token = await fileUploader.uploadImage(
              Uri.parse(url),
              bytes,
              filename: 'avatar.jpg',
            );
            if (token != null) {
              await chats.setChatPhoto(api, chatId: chat.id, photoToken: token);
            } else if (mounted) {
              showCustomNotification(
                context,
                AppLocalizations.of(context)!.createChannelAvatarUploadFailed,
              );
            }
          }
        }
      }

      final info = await ChatInfoFetch.get(chat.id, forceRefresh: true);
      if (!mounted) return;
      final name = chat.title ?? title;
      final imageUrl = chat.iconUrl ?? '';
      navigator.pop();
      navigator.push(
        SwipeRoute(
          builder: (_) => ChatScreen(
            chatId: chat.id,
            name: name,
            imageUrl: imageUrl,
            chatType: chat.type,
          ),
        ),
      );
      if (info == null) return;
      navigator.push(
        SwipeRoute(
          builder: (_) => ChannelTypeLinkScreen(
            justCreated: true,
            state: ChatAdminState(
              chatId: chat.id,
              myId: chat.accountId,
              name: name,
              imageUrl: imageUrl,
              info: info,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.devicesGenericError('$e'),
        );
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final canCreate = _title.text.trim().isNotEmpty && !_creating;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.chatListCreateChannel,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _creating ? null : () => Navigator.pop(context),
                    icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatar != null
                          ? Image.file(_avatar!, fit: BoxFit.cover)
                          : Icon(
                              Symbols.add_a_photo,
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _title,
                      onChanged: (_) => setState(() {}),
                      enabled: !_creating,
                      autofocus: true,
                      style: TextStyle(color: cs.onSurface, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: l10n.channelSettingsName,
                        hintStyle: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                l10n.createChannelDescription,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _PillButton(
                      label: l10n.createChannelCancel,
                      filled: false,
                      onTap: _creating ? null : () => Navigator.pop(context),
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PillButton(
                      label: _creating
                          ? l10n.createChannelCreating
                          : l10n.createChannelCreate,
                      filled: true,
                      onTap: canCreate ? _create : null,
                      cs: cs,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final ColorScheme cs;
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (disabled ? cs.primary.withValues(alpha: 0.4) : cs.primary)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled
                ? cs.onPrimary
                : (disabled
                      ? cs.onSurface.withValues(alpha: 0.4)
                      : cs.onSurface),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
