import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/config/debug_test.dart';
import '../../../core/config/ios_release.dart';
import '../../../core/contacts/contact_labels.dart';
import '../../../core/contacts/device_contacts_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../backend/modules/contacts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show api;
import '../../widgets/chat_menu_overlay.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/spectrum_tint.dart';
import '../../widgets/springy_tap.dart';
import '../chats/chat_info_screen.dart';
import 'find_user_sheet.dart';
import 'nfc_exchange_sheet.dart';
import 'open_contact_profile.dart';
import '../../../core/config/app_frost.dart';
import '../../../core/config/app_fonts.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> with SpectrumSurface {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<CachedContact> _contacts = [];
  bool _isLoading = true;
  bool _searching = false;
  final Set<int> _deleting = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    ContactsModule.revision.addListener(_loadContacts);
    _loadDeviceContacts();
  }

  Future<void> _loadDeviceContacts() async {
    final changed = await DeviceContactsService.ensureLoadedInteractive();
    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    ContactsModule.revision.removeListener(_loadContacts);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _openNfcExchange() async {
    if (!IosRelease.nfcContactExchange) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppFrost.scrim(),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => const Align(
        alignment: Alignment.topCenter,
        child: NfcExchangeSheet(),
      ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Future<void> _openFindUser() async {
    final l10n = AppLocalizations.of(context)!;
    final found = await showFindUserSheet(
      context,
      title: l10n.contactsTabFindContact,
      actionLabel: l10n.contactsTabFind,
    );
    if (found == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          chatId: found.chatId,
          name: found.name,
          imageUrl: found.avatarUrl,
          chatType: 'DIALOG',
          dialogPeerId: found.userId,
        ),
      ),
    );
  }

  void _startSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _stopSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() => _searching = false);
  }

  Future<void> _loadContacts() async {
    if (DebugTest.enabled) {
      final debug = ContactsModule.debugContacts()
        ..sort((a, b) => a.firstName.compareTo(b.firstName));
      if (mounted) {
        setState(() {
          _contacts = debug;
          _isLoading = false;
        });
      }
      return;
    }

    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    unawaited(ContactsModule.ensureBlockedLoaded(api));
    final blocked = ContactsModule.blockedIds;
    final contacts = (await ContactsModule.getContacts(
      p.id,
    )).where((c) => !blocked.contains(c.id)).toList();
    contacts.sort((a, b) => a.firstName.compareTo(b.firstName));
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  ContactLabels _labelsOf(CachedContact contact) => contactLabels(
    idLabel: AppLocalizations.of(context)!.contactIdFallback('${contact.id}'),
    firstName: contact.firstName,
    lastName: contact.lastName,
    phone: contact.phone,
  );

  List<CachedContact> get _visibleContacts {
    final query = _searchController.text;
    if (!_searching || query.trim().isEmpty) return _contacts;
    return [
      for (final contact in _contacts)
        if (contactMatchesQuery(
          query,
          title: _labelsOf(contact).title,
          firstName: contact.firstName,
          lastName: contact.lastName,
          phone: contact.phone,
        ))
          contact,
    ];
  }

  void _showContactMenu(BuildContext anchorContext, CachedContact contact) {
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final l10n = AppLocalizations.of(context)!;
    showChatMenu(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      items: [
        ChatMenuItem(
          icon: Symbols.delete,
          label: l10n.editContactDelete,
          destructive: true,
          onTap: () => _deleteContact(contact),
        ),
      ],
    );
  }

  Future<void> _deleteContact(CachedContact contact) async {
    if (_deleting.contains(contact.id)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.editContactDeleteConfirmTitle,
      message: l10n.editContactDeleteConfirmBody,
      confirmLabel: l10n.editContactDelete,
      cancelLabel: l10n.editContactDeleteCancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting.add(contact.id));
    final ok = await ContactsModule.removeContact(api, contact.id);
    if (!mounted) return;
    setState(() => _deleting.remove(contact.id));
    showCustomNotification(
      context,
      ok ? l10n.contactDeleted : l10n.contactDeleteFailed,
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    ColorScheme cs,
    CachedContact contact,
  ) {
    final labels = _labelsOf(contact);
    final nameToDisplay = labels.title;
    final subtitle = contact.updateTime > 0
        ? AppLocalizations.of(context)!.contactsTabLastSeenRecently
        : labels.subtitle;
    final deleting = _deleting.contains(contact.id);

    return SpringyTap(
      key: ValueKey(contact.id),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openContactDialogProfile(
            context,
            contactId: contact.id,
            name: nameToDisplay,
            avatarUrl: contact.baseUrl,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: KometAvatar(
                    name: nameToDisplay,
                    imageUrl: contact.baseUrl,
                    size: 48,
                    userId: contact.id,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              nameToDisplay,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (contact.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Symbols.verified,
                              color: cs.primary,
                              size: 16,
                              weight: 600,
                              fill: 1,
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (deleting)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SmallSpinner(size: 20),
                  )
                else
                  Builder(
                    builder: (anchorContext) => IconButton(
                      icon: Icon(
                        Symbols.more_vert,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showContactMenu(anchorContext, contact),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, AppLocalizations l10n) {
    if (_searching) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: TextStyle(color: cs.onSurface, fontSize: 18),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l10n.contactsSearchHint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 18),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Symbols.close, color: cs.onSurface),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _stopSearch,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.contactsTabTitle,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFamily: displayFontOf(context),
                ),
              ),
              const ConnectionStatusLine(),
            ],
          ),
        ),
        ContactsNfcExchangeButton(
          tooltip: l10n.contactsNfcExchange,
          onPressed: _openNfcExchange,
        ),
        IconButton(
          icon: Icon(Symbols.person_add, color: cs.onSurface),
          tooltip: l10n.contactsFindUser,
          onPressed: _openFindUser,
        ),
        IconButton(
          icon: Icon(Symbols.search, color: cs.onSurface),
          tooltip: l10n.contactsSearchHint,
          onPressed: _startSearch,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final visible = _visibleContacts;

    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopSearch();
      },
      child: Scaffold(
        backgroundColor: spectrumSurfaceColor(cs),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: _buildHeader(cs, l10n),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: SmallSpinner(size: 36))
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          _contacts.isEmpty
                              ? l10n.contactsTabEmpty
                              : l10n.contactsSearchEmpty,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: visible.length,
                        itemBuilder: (context, index) =>
                            _buildContactItem(context, cs, visible[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the contact exchange sheet. Hidden on iOS, where the exchange is
/// not available.
class ContactsNfcExchangeButton extends StatelessWidget {
  const ContactsNfcExchangeButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!IosRelease.nfcContactExchange) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      key: const ValueKey('contacts-nfc-exchange'),
      icon: Icon(Symbols.nfc, color: cs.onSurface),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
