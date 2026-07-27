import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/contacts.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart' show api;
import '../../../../models/attachment.dart';
import '../../../screens/contacts/open_contact_profile.dart';
import '../../custom_notification.dart';
import '../../komet_avatar.dart';
import '../../small_spinner.dart';
import 'bubble_context.dart';

Widget buildContactCard(
  BubbleContext ctx, {
  String? firstName,
  String? lastName,
  String? name,
  String? photoUrl,
  String? phoneNumber,
  int? contactId,
  String? userId,
}) {
  return _ContactCard(
    ctx: ctx,
    firstName: firstName,
    lastName: lastName,
    name: name,
    photoUrl: photoUrl,
    phoneNumber: phoneNumber,
    contactId: contactId,
    userId: userId,
  );
}

class _ContactCard extends StatefulWidget {
  final BubbleContext ctx;
  final String? firstName;
  final String? lastName;
  final String? name;
  final String? photoUrl;
  final String? phoneNumber;
  final int? contactId;
  final String? userId;

  const _ContactCard({
    required this.ctx,
    this.firstName,
    this.lastName,
    this.name,
    this.photoUrl,
    this.phoneNumber,
    this.contactId,
    this.userId,
  });

  int? get resolvedContactId => contactId ?? int.tryParse(userId?.trim() ?? '');

  String get resolvedName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;
    final fallback = name?.trim() ?? '';
    return fallback.isEmpty ? 'Contact' : fallback;
  }

  String get nameForAdd {
    final first = firstName?.trim() ?? '';
    return first.isEmpty ? resolvedName : first;
  }

  int get resolvedPhone {
    final digits = phoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    return int.tryParse(digits) ?? 0;
  }

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool? _isContact;
  bool _adding = false;
  int _statusGeneration = 0;

  @override
  void initState() {
    super.initState();
    ContactsModule.revision.addListener(_onContactsChanged);
    unawaited(_refreshContactStatus());
  }

  @override
  void didUpdateWidget(_ContactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolvedContactId != widget.resolvedContactId ||
        oldWidget.ctx.message.accountId != widget.ctx.message.accountId ||
        oldWidget.ctx.myId != widget.ctx.myId) {
      _isContact = null;
      unawaited(_refreshContactStatus());
    }
  }

  @override
  void dispose() {
    ContactsModule.revision.removeListener(_onContactsChanged);
    super.dispose();
  }

  void _onContactsChanged() {
    unawaited(_refreshContactStatus());
  }

  Future<void> _refreshContactStatus() async {
    final generation = ++_statusGeneration;
    final contactId = widget.resolvedContactId;
    if (contactId == null) {
      if (mounted && generation == _statusGeneration) {
        setState(() => _isContact = false);
      }
      return;
    }
    if (contactId == widget.ctx.myId) {
      if (mounted && generation == _statusGeneration) {
        setState(() => _isContact = true);
      }
      return;
    }

    CachedContact? contact;
    try {
      contact = await ContactsModule.getContact(
        widget.ctx.message.accountId,
        contactId,
      );
    } catch (_) {}
    if (!mounted || generation != _statusGeneration) return;
    setState(() => _isContact = contact != null);
  }

  Future<void> _addContact() async {
    final contactId = widget.resolvedContactId;
    if (contactId == null || _adding || _isContact != false) return;
    Haptics.tap();
    setState(() => _adding = true);
    try {
      final contact = await ContactsModule.addContact(
        api,
        contactId,
        widget.nameForAdd,
        phone: widget.resolvedPhone,
      );
      if (!mounted) return;
      if (contact == null) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.addContactError,
        );
        return;
      }
      setState(() => _isContact = true);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.nfcContactAdded,
      );
    } catch (_) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.addContactError,
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _openProfile() {
    final contactId = widget.resolvedContactId;
    if (contactId == null) return;
    Haptics.tap();
    unawaited(
      openContactDialogProfile(
        context,
        contactId: contactId,
        name: widget.resolvedName,
        avatarUrl: widget.photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.ctx;
    final l10n = AppLocalizations.of(context)!;
    final canAdd =
        widget.resolvedContactId != null &&
        widget.resolvedContactId != ctx.myId &&
        _isContact != true;
    final buttonColor = ctx.isMe
        ? Colors.black.withValues(alpha: 0.16)
        : ctx.cs.onSurface.withValues(alpha: 0.08);

    return SizedBox(
      key: const ValueKey('contact-card'),
      width: 320,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KometAvatar(
                  name: widget.resolvedName,
                  imageUrl: widget.photoUrl,
                  size: 48,
                  fadeIn: false,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.resolvedName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ctx.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isContact == true
                            ? l10n.contactBubbleAlreadyAdded
                            : l10n.contactBubbleNew,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ctx.dim,
                          fontSize: 12,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canAdd) ...[
                  const SizedBox(width: 6),
                  _ContactActionButton(
                    key: const ValueKey('contact-add-button'),
                    tooltip: l10n.nfcAddContact,
                    icon: Symbols.person_add,
                    color: buttonColor,
                    foreground: ctx.text,
                    loading: _adding || _isContact == null,
                    onPressed: _isContact == false && !_adding
                        ? _addContact
                        : null,
                  ),
                ],
                const SizedBox(width: 6),
                _ContactActionButton(
                  key: const ValueKey('contact-profile-button'),
                  tooltip: l10n.contactBubbleOpenProfile,
                  icon: Symbols.chat_bubble,
                  color: buttonColor,
                  foreground: ctx.text,
                  onPressed: widget.resolvedContactId == null
                      ? null
                      : _openProfile,
                ),
              ],
            ),
            Align(alignment: Alignment.centerRight, child: ctx.meta()),
          ],
        ),
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final Color foreground;
  final bool loading;
  final VoidCallback? onPressed;

  const _ContactActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.foreground,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: loading
              ? SmallSpinner(size: 17, color: foreground)
              : Icon(icon, color: foreground, size: 20, fill: 1),
        ),
      ),
    );
  }
}

class ContactBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ContactAttachment contact;

  const ContactBubble({super.key, required this.ctx, required this.contact});

  @override
  Widget build(BuildContext context) {
    return buildContactCard(
      ctx,
      firstName: contact.firstName,
      lastName: contact.lastName,
      name: contact.name,
      photoUrl: contact.photoUrl ?? contact.baseUrl,
      phoneNumber: contact.phoneNumber,
      contactId: contact.contactId,
      userId: contact.userId,
    );
  }
}
