import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/account.dart' show BlockedContact;
import '../../../backend/modules/contacts.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';
import '../../../core/utils/names.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/small_spinner.dart';
import '../contacts/open_contact_profile.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key, this.initialContacts});

  final List<BlockedContact>? initialContacts;

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen>
    with ReloadOnReconnect {
  late List<BlockedContact> _contacts = widget.initialContacts ?? const [];
  late bool _isLoading = widget.initialContacts == null;
  final Set<int> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reloadAfterReconnect() => _load();

  Future<void> _load() async {
    try {
      final contacts = await accountModule.getBlockedContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.blacklistLoadError,
      );
    }
  }

  String _nameOf(BlockedContact contact) => displayName(
    contact.firstName,
    contact.lastName,
    fallback: 'ID ${contact.id}',
  );

  Future<void> _unblock(BlockedContact contact) async {
    if (_pending.contains(contact.id)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending.add(contact.id));
    final ok = await ContactsModule.setBlocked(api, contact.id, false);
    if (!mounted) return;
    setState(() {
      _pending.remove(contact.id);
      if (ok) _contacts = _contacts.where((c) => c.id != contact.id).toList();
    });
    showCustomNotification(
      context,
      ok ? l10n.chatInfoUnblockDone : l10n.chatInfoBlockFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(cs),
            Expanded(child: _buildBody(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Symbols.arrow_back,
              color: cs.onSurface,
              size: 24,
              weight: 400,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          ConnectionTitleText(
            AppLocalizations.of(context)!.securityBlacklistTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) return const Center(child: SmallSpinner(size: 36));
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.block, size: 48, color: cs.outline, weight: 400),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.blacklistEmpty,
              style: TextStyle(color: cs.outline, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: _contacts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildTile(cs, _contacts[index]),
    );
  }

  Widget _buildTile(ColorScheme cs, BlockedContact contact) {
    final name = _nameOf(contact);
    final busy = _pending.contains(contact.id);
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: AppShape.cardRadius,
      depth: 6,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openContactDialogProfile(
            context,
            contactId: contact.id,
            name: name,
            avatarUrl: contact.baseUrl,
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                KometAvatar(name: name, size: 44, imageUrl: contact.baseUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                busy
                    ? SmallSpinner(size: 20, color: cs.primary)
                    : TextButton(
                        onPressed: () => _unblock(contact),
                        child: Text(
                          AppLocalizations.of(context)!.chatInfoMenuUnblock,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
