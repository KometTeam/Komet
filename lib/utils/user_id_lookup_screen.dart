import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/contact.dart';

class UserIdLookupScreen extends StatefulWidget {
  const UserIdLookupScreen({super.key});

  @override
  State<UserIdLookupScreen> createState() => _UserIdLookupScreenState();
}

class _UserIdLookupScreenState extends State<UserIdLookupScreen> {
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();
  bool _isLoading = false;
  Contact? _foundContact;
  bool _searchAttempted = false;

  Future<void> _searchById() async {
    final String idText = _idController.text.trim();
    if (idText.isEmpty) {
      return;
    }

    final int? contactId = int.tryParse(idText);
    if (contactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, введите корректный ID (только цифры)'),
        ),
      );
      return;
    }

    _idFocusNode.unfocus();

    setState(() {
      _isLoading = true;
      _searchAttempted = true;
      _foundContact = null;
    });

    try {
      final List<Contact> contacts = await ApiService.instance
          .fetchContactsByIds([contactId]);

      if (mounted) {
        setState(() {
          _foundContact = contacts.isNotEmpty ? contacts.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при поиске: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _idFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Поиск по ID')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              focusNode: _idFocusNode,
              decoration: InputDecoration(
                labelText: 'Введите ID пользователя',
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.person_search_outlined),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchById,
                      ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _searchById(),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? const Center(
                      key: ValueKey('loading'),
                      child: CircularProgressIndicator(),
                    )
                  : _searchAttempted
                  ? _foundContact != null
                        ? _buildContactCard(_foundContact!, colors)
                        : _buildEmptyState(
                            key: const ValueKey('not_found'),
                            colors: colors,
                            icon: Icons.search_off_rounded,
                            title: 'Пользователь не найден',
                            subtitle:
                                'Аккаунт с ID "${_idController.text}" не существует или скрыт.',
                          )
                  : _buildEmptyState(
                      key: const ValueKey('initial'),
                      colors: colors,
                      icon: Icons.person_search_rounded,
                      title: 'Введите ID для поиска',
                      subtitle: 'Найдем пользователя в системе по его ID',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(Contact contact, ColorScheme colors) {
    return Column(
      key: const ValueKey('contact_card'),
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: colors.primaryContainer,
          backgroundImage: contact.photoBaseUrl != null
              ? NetworkImage(contact.photoBaseUrl!)
              : null,
          child: contact.photoBaseUrl == null
              ? Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          contact.name,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'ID: ${contact.id}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildInfoTile(
                colors: colors,
                icon: Icons.person_outlined,
                title: 'Имя',
                subtitle: contact.firstName,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildInfoTile(
                colors: colors,
                icon: Icons.badge_outlined,
                title: 'Фамилия',
                subtitle: contact.lastName,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildInfoTile(
                colors: colors,
                icon: Icons.notes_rounded,
                title: 'Описание',
                subtitle: contact.description,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required ColorScheme colors,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final bool hasData = subtitle != null && subtitle.isNotEmpty;

    return ListTile(
      leading: Icon(icon, color: colors.primary),
      title: Text(title),
      subtitle: Text(
        hasData ? subtitle : '(не указано)',
        style: TextStyle(
          color: hasData
              ? colors.onSurfaceVariant
              : colors.onSurfaceVariant.withValues(alpha: 0.7),
          fontStyle: hasData ? FontStyle.normal : FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required Key key,
    required ColorScheme colors,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 64,
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
