import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/storage/app_database.dart';
import '../../../backend/modules/contacts.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  List<CachedContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final p = await AppDatabase.loadActiveProfile();
    if (p == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final contacts = await ContactsModule.getContacts(p.id);
    // Sort contacts by first name
    contacts.sort((a, b) => a.firstName.compareTo(b.firstName));
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  Widget _buildPlaceholderAvatar(ColorScheme cs, String name) {
    return Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    ColorScheme cs,
    CachedContact contact,
  ) {
    final fullName =
        '${contact.firstName}${contact.lastName != null ? ' ${contact.lastName}' : ''}'
            .trim();
    final nameToDisplay = fullName.isEmpty ? '+${contact.phone}' : fullName;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Open contact details or chat
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                child: ClipOval(
                  child: contact.baseUrl != null && contact.baseUrl!.isNotEmpty
                      ? Image.network(
                          contact.baseUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderAvatar(cs, nameToDisplay),
                        )
                      : _buildPlaceholderAvatar(cs, nameToDisplay),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameToDisplay,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.updateTime > 0
                          ? 'Был(а) недавно'
                          : '+${contact.phone}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Контакты',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Symbols.person_add, color: cs.onSurface),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Symbols.search, color: cs.onSurface),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _contacts.isEmpty
                  ? Center(
                      child: Text(
                        'Нет контактов',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        return _buildContactItem(context, cs, contact);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
