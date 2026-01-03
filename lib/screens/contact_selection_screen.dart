import 'package:flutter/material.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/contact.dart';
import 'package:gwid/widgets/contact_avatar_widget.dart';
import 'package:gwid/widgets/contact_name_widget.dart';

class ContactSelectionScreen extends StatefulWidget {
  const ContactSelectionScreen({super.key});

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final data = await ApiService.instance.getChatsAndContacts();
      final contactsJson = data['contacts'] as List<dynamic>;

      final contacts = contactsJson
          .map((json) => Contact.fromJson(json as Map<String, dynamic>))
          .toList();

      // Remove duplicates by contact ID
      final uniqueContacts = <int, Contact>{};
      for (final contact in contacts) {
        uniqueContacts[contact.id] = contact;
      }
      final deduplicatedContacts = uniqueContacts.values.toList();

      setState(() {
        _contacts = deduplicatedContacts;
        _filteredContacts = deduplicatedContacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          return contact.name.toLowerCase().contains(query) ||
              contact.firstName.toLowerCase().contains(query) ||
              contact.lastName.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите контакт')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск контакта',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                ? const Center(child: Text('Контакты не найдены'))
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      return ListTile(
                        leading: ContactAvatarWidget(
                          contactId: contact.id,
                          originalAvatarUrl: contact.photoBaseUrl,
                          radius: 24,
                        ),
                        title: ContactNameWidget(
                          contactId: contact.id,
                          originalName: contact.name,
                          originalFirstName: contact.firstName,
                          originalLastName: contact.lastName,
                        ),
                        subtitle:
                            contact.description != null &&
                                contact.description!.isNotEmpty
                            ? Text(contact.description!)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop(contact.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
