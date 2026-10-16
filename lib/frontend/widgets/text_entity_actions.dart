import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/modules/contacts.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/text_entities.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show api;
import '../screens/contacts/open_contact_profile.dart';
import 'chat_menu_overlay.dart';
import 'custom_notification.dart';
import 'hint_bubble.dart';
import 'komet_avatar.dart';
import 'max_link_handler.dart';
import 'small_spinner.dart';

Future<void> openMentionProfile(BuildContext context, String nickname) async {
  final handled = await tryHandleMaxLink(context, 'https://max.ru/$nickname');
  if (handled || !context.mounted) return;
  showCustomNotification(
    context,
    AppLocalizations.of(context)!.textEntityProfileNotFound(nickname),
  );
}

Future<void> copyTextEntity(
  BuildContext context,
  String value,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  showHintBubble(context, message);
}

void showPhoneEntityMenu(
  BuildContext context,
  String phone, {
  required Offset at,
}) {
  final l10n = AppLocalizations.of(context)!;
  showChatMenu(
    context: context,
    anchorRect: Rect.fromLTWH(at.dx, at.dy, 0, 0),
    compact: true,
    header: _PhoneOwnerHeader(
      phone: phone,
      onOpen: (found) => _openPhoneOwner(context, found, phone),
    ),
    items: [
      ChatMenuItem(
        icon: Symbols.content_copy,
        label: l10n.textEntityCopyPhone,
        onTap: () => copyTextEntity(context, phone, l10n.textEntityPhoneCopied),
      ),
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)
        ChatMenuItem(
          icon: Symbols.call,
          label: l10n.textEntityCall,
          onTap: () => _dial(context, phone),
        ),
    ],
  );
}

void showCardEntityMenu(
  BuildContext context,
  String digits, {
  required Offset at,
}) {
  final l10n = AppLocalizations.of(context)!;
  showChatMenu(
    context: context,
    anchorRect: Rect.fromLTWH(at.dx, at.dy, 0, 0),
    compact: true,
    items: [
      ChatMenuItem(
        icon: Symbols.content_copy,
        label: l10n.textEntityCopyCard,
        onTap: () =>
            copyTextEntity(context, digits, l10n.textEntityCardCopied),
      ),
    ],
    footer: _CardFooter(digits: digits),
  );
}

void _openPhoneOwner(
  BuildContext context,
  PhoneLookupResult found,
  String phone,
) {
  if (!context.mounted) return;
  final resolved = found.name;
  unawaited(
    openContactDialogProfile(
      context,
      contactId: found.id,
      name: (resolved == null || resolved.isEmpty) ? phone : resolved,
      avatarUrl: found.avatarUrl,
    ),
  );
}

Future<void> _dial(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (launched || !context.mounted) return;
  showCustomNotification(
    context,
    AppLocalizations.of(context)!.textEntityDialFailed,
  );
}

class _CardFooter extends StatelessWidget {
  final String digits;

  const _CardFooter({required this.digits});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = cardBrandTitle(digits);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cardMask(digits),
            style: TextStyle(color: cs.onSurface, fontSize: 14),
          ),
          if (title != null) ...[
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneOwnerHeader extends StatefulWidget {
  final String phone;
  final ValueChanged<PhoneLookupResult> onOpen;

  const _PhoneOwnerHeader({required this.phone, required this.onOpen});

  @override
  State<_PhoneOwnerHeader> createState() => _PhoneOwnerHeaderState();
}

class _PhoneOwnerHeaderState extends State<_PhoneOwnerHeader> {
  late final Future<PhoneLookupResult?> _lookup = ContactsModule.findByPhone(
    api,
    widget.phone,
    silent: true,
  );

  void _open(BuildContext context, PhoneLookupResult found) {
    Haptics.tap();
    closeChatMenu(context).then((_) => widget.onOpen(found));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PhoneLookupResult?>(
      future: _lookup,
      builder: (context, snapshot) {
        final found = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        final Widget content;
        if (snapshot.connectionState != ConnectionState.done) {
          content = Row(
            children: [
              SmallSpinner(size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                widget.phone,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ],
          );
        } else {
          content = found == null
              ? Text(
                  AppLocalizations.of(context)!.textEntityNotOnMax,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                )
              : _OwnerRow(found: found, phone: widget.phone);
        }
        final padded = Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
          child: content,
        );
        if (found == null) return padded;
        return InkWell(onTap: () => _open(context, found), child: padded);
      },
    );
  }
}

class _OwnerRow extends StatelessWidget {
  final PhoneLookupResult found;
  final String phone;

  const _OwnerRow({required this.found, required this.phone});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resolved = found.name;
    final name = (resolved == null || resolved.isEmpty) ? phone : resolved;
    return Row(
      children: [
        KometAvatar(name: name, size: 36, imageUrl: found.avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                phone,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
        Icon(
          Symbols.chevron_right,
          size: 22,
          weight: 400,
          color: cs.onSurface.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
