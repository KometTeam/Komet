import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/modules/contacts.dart';
import '../../core/utils/text_entities.dart';
import '../../main.dart' show api;
import 'chat_menu_overlay.dart';
import 'custom_notification.dart';
import 'komet_avatar.dart';
import 'max_link_handler.dart';
import 'small_spinner.dart';

Future<void> openMentionProfile(BuildContext context, String nickname) async {
  final handled = await tryHandleMaxLink(context, 'https://max.ru/$nickname');
  if (handled || !context.mounted) return;
  showCustomNotification(context, 'Профиль @$nickname не найден');
}

Future<void> copyTextEntity(
  BuildContext context,
  String value,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  showCustomNotification(context, message);
}

void showPhoneEntityMenu(
  BuildContext context,
  String phone, {
  required Offset at,
}) {
  showChatMenu(
    context: context,
    anchorRect: Rect.fromLTWH(at.dx, at.dy, 0, 0),
    header: _PhoneOwnerHeader(phone: phone),
    items: [
      ChatMenuItem(
        icon: Symbols.content_copy,
        label: 'Скопировать номер телефона',
        onTap: () => copyTextEntity(context, phone, 'Номер скопирован'),
      ),
      if (defaultTargetPlatform == TargetPlatform.android)
        ChatMenuItem(
          icon: Symbols.call,
          label: 'Позвонить',
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
  showChatMenu(
    context: context,
    anchorRect: Rect.fromLTWH(at.dx, at.dy, 0, 0),
    items: [
      ChatMenuItem(
        icon: Symbols.content_copy,
        label: 'Скопировать номер карты',
        onTap: () => copyTextEntity(context, digits, 'Номер карты скопирован'),
      ),
    ],
    footer: _CardFooter(digits: digits),
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
  showCustomNotification(context, 'Не удалось открыть приложение звонков');
}

class _CardFooter extends StatelessWidget {
  final String digits;

  const _CardFooter({required this.digits});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = cardBrandTitle(digits);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cardMask(digits),
            style: TextStyle(color: cs.onSurface, fontSize: 15),
          ),
          if (title != null) ...[
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhoneOwnerHeader extends StatefulWidget {
  final String phone;

  const _PhoneOwnerHeader({required this.phone});

  @override
  State<_PhoneOwnerHeader> createState() => _PhoneOwnerHeaderState();
}

class _PhoneOwnerHeaderState extends State<_PhoneOwnerHeader> {
  late final Future<PhoneLookupResult?> _lookup = ContactsModule.findByPhone(
    api,
    widget.phone,
    silent: true,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PhoneLookupResult?>(
      future: _lookup,
      builder: (context, snapshot) {
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
          final found = snapshot.data;
          content = found == null
              ? Text(
                  'Человека ещё нет в MAX',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                )
              : _OwnerRow(found: found, phone: widget.phone);
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: content,
        );
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
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
