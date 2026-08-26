import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/core/config/debug_test.dart';
import 'package:komet/core/contacts/device_contacts_service.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';
import 'package:komet/frontend/widgets/small_spinner.dart';
import 'package:komet/frontend/widgets/springy_tap.dart';
import 'package:komet/l10n/app_localizations.dart';

class ContactPickerPage extends StatefulWidget {
  final double bottomReserve;
  final ValueChanged<CachedContact> onPick;

  const ContactPickerPage({
    super.key,
    required this.bottomReserve,
    required this.onPick,
  });

  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  final TextEditingController _queryCtrl = TextEditingController();

  List<CachedContact> _contacts = const [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await _fetch();
    if (!mounted) return;
    setState(() {
      _contacts = loaded;
      _loading = false;
    });
  }

  Future<List<CachedContact>> _fetch() async {
    if (DebugTest.enabled) {
      return ContactsModule.debugContacts()
        ..sort((a, b) => a.firstName.compareTo(b.firstName));
    }
    final profile = await AppDatabase.loadActiveProfile();
    if (profile == null) return const [];
    final contacts = await ContactsModule.getContacts(profile.id);
    contacts.sort((a, b) => _displayName(a).compareTo(_displayName(b)));
    return contacts;
  }

  String _displayName(CachedContact contact) {
    final book = DeviceContactsService.nameForPhone(contact.phone);
    if (book != null && book.isNotEmpty) return book;
    final last = contact.lastName;
    final full = (last != null && last.isNotEmpty)
        ? '${contact.firstName} $last'
        : contact.firstName;
    final trimmed = full.trim();
    return trimmed.isEmpty ? '+${contact.phone}' : trimmed;
  }

  List<CachedContact> get _visible {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where(
          (c) =>
              _displayName(c).toLowerCase().contains(query) ||
              c.phone.toString().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomReserve),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _queryCtrl,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(color: cs.onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: l10n.attachSheetContactSearchHint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                prefixIcon: Icon(
                  Symbols.search,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(cs, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, AppLocalizations l10n) {
    if (_loading) {
      return Center(child: SmallSpinner(size: 36, color: cs.primary));
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.person_off, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                _contacts.isEmpty
                    ? l10n.attachSheetNoContacts
                    : l10n.attachSheetNoContactsFound,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final contact = visible[index];
        return _buildTile(cs, contact);
      },
    );
  }

  Widget _buildTile(ColorScheme cs, CachedContact contact) {
    final name = _displayName(contact);
    return SpringyTap(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            widget.onPick(contact);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                KometAvatar(name: name, imageUrl: contact.baseUrl, size: 44),
                const SizedBox(width: 14),
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '+${contact.phone}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
