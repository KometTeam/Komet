import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart' show ContactCache;
import '../../../../core/config/app_fonts.dart';
import '../../../../core/utils/format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/komet_avatar.dart';
import '../../../widgets/small_spinner.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface, weight: 400),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
        actions: actions,
      ),
      body: body,
    );
  }
}

class AdminSectionCaption extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AdminSectionCaption(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class AdminMemberTile extends StatelessWidget {
  final int id;
  final String? name;
  final String? avatarUrl;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AdminMemberTile({
    super.key,
    required this.id,
    this.name,
    this.avatarUrl,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = name ?? ContactCache.get(id) ?? '$id';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            KometAvatar(
              name: title,
              imageUrl: avatarUrl ?? ContactCache.getAvatar(id),
              size: 42,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class MemberSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const MemberSearchField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      onChanged: onChanged,
      style: TextStyle(color: cs.onSurface, fontSize: 15),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        prefixIcon: Icon(Symbols.search, size: 20, color: cs.onSurfaceVariant),
        hintText: AppLocalizations.of(context)!.membersSearchHint,
        hintStyle: TextStyle(color: cs.outline, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class MembersListFooter extends StatelessWidget {
  final bool loading;
  final String? message;
  final VoidCallback? onRetry;

  const MembersListFooter({
    super.key,
    required this.loading,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: loading ? null : onRetry,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(
          child: loading
              ? SmallSpinner(size: 24, color: cs.primary)
              : Text(
                  message ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: onRetry == null ? cs.onSurfaceVariant : cs.primary,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }
}

class AdminActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const AdminActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22, weight: 400),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String memberPresenceLabel(AppLocalizations l10n, ChatMemberEntry member) {
  if (member.blocked) return l10n.chatInfoMemberDeleted;
  if (member.presenceStatus == 1) return l10n.contactProfileOnline;
  final seen = member.seenTime;
  if (member.presenceStatus != 2 &&
      member.presenceStatus != 3 &&
      seen != null &&
      seen > 0) {
    return formatLastSeen(l10n, seen);
  }
  return l10n.contactProfileRecentlyActive;
}

String adminRoleLabel(
  AppLocalizations l10n, {
  required bool owner,
  required bool me,
}) {
  final role = owner ? l10n.chatInfoRoleOwner : l10n.chatInfoRoleAdmin;
  return me ? l10n.adminRoleYou(role) : role;
}
