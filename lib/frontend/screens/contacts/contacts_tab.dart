import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../backend/modules/contacts.dart';
import '../../../main.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/sheet_helpers.dart';
import 'contact_profile_screen.dart';

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

  Future<void> _openSearchById() async {
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) => const _SearchContactSheet(),
    );
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactProfileScreen(
                contactId: contact.id,
                initialName: nameToDisplay,
                initialAvatarUrl: contact.baseUrl,
              ),
            ),
          );
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
                child: KometAvatar(
                  name: nameToDisplay,
                  imageUrl: contact.baseUrl,
                  size: 48,
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
                    onPressed: _openSearchById,
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

class _SearchContactSheet extends StatefulWidget {
  const _SearchContactSheet();

  @override
  State<_SearchContactSheet> createState() => _SearchContactSheetState();
}

class _SearchContactSheetState extends State<_SearchContactSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    final id = int.tryParse(raw);
    if (id == null) {
      setState(() => _error = 'Введите числовой ID');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packet = await api.sendRequest(Opcode.contactInfo, {
        'contactIds': [id],
      });
      final contacts = (packet.payload as Map?)?['contacts'] as List?;
      if (contacts == null || contacts.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Контакт с таким ID не найден';
          });
        }
        return;
      }
      final raw = Map<String, dynamic>.from(contacts.first as Map);
      String? name;
      final namesRaw = raw['names'];
      if (namesRaw is List && namesRaw.isNotEmpty) {
        final n = namesRaw.first;
        if (n is Map) name = n['name']?.toString();
      }
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ContactProfileScreen(
            contactId: id,
            initialName: name,
            initialAvatarUrl: raw['baseUrl'] as String?,
          ),
        ),
      );
    } on PacketError catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ошибка: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Поиск по ID',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Symbols.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: TextStyle(color: cs.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Введите ID контакта',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Symbols.tag,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Symbols.error_outline,
                        size: 18,
                        color: cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: cs.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Найти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
