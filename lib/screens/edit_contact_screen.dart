import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/services/contact_local_names_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:gwid/app_sizes.dart';

class EditContactScreen extends StatefulWidget {
  final int contactId;
  final String? originalFirstName;
  final String? originalLastName;
  final String? originalDescription;
  final String? originalAvatarUrl;

  const EditContactScreen({
    super.key,
    required this.contactId,
    this.originalFirstName,
    this.originalLastName,
    this.originalDescription,
    this.originalAvatarUrl,
  });

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _notesController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _localAvatarPath;
  bool _isLoadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.originalFirstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.originalLastName ?? '',
    );
    _notesController = TextEditingController();

    _loadContactData();
  }

  Future<void> _loadContactData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'contact_${widget.contactId}';
      final savedData = prefs.getString(key);

      if (savedData != null) {
        final data = jsonDecode(savedData) as Map<String, dynamic>;

        _firstNameController.text =
            data['firstName'] ?? widget.originalFirstName ?? '';
        _lastNameController.text =
            data['lastName'] ?? widget.originalLastName ?? '';
        _notesController.text = data['notes'] ?? '';

        final avatarPath = data['avatarPath'] as String?;
        if (avatarPath != null) {
          final file = File(avatarPath);
          if (await file.exists()) {
            if (mounted) {
              setState(() {
                _localAvatarPath = avatarPath;
              });
            }
          }
        }
      }

      if (_localAvatarPath == null && mounted) {
        final cachedPath = ContactLocalNamesService().getContactAvatarPath(
          widget.contactId,
        );
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (await file.exists()) {
            if (mounted) {
              setState(() {
                _localAvatarPath = cachedPath;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Ошибка загрузки локальных данных контакта: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveContactData() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final data = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'notes': _notesController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_localAvatarPath != null) {
        data['avatarPath'] = _localAvatarPath!;
      }
      await ContactLocalNamesService().saveContactData(widget.contactId, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Данные контакта сохранены'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearContactData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить данные?'),
        content: const Text(
          'Будут восстановлены оригинальные данные контакта с сервера.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ContactLocalNamesService().clearContactData(widget.contactId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Данные контакта очищены'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  ImageProvider? _getAvatarImage() {
    if (_localAvatarPath != null) {
      return FileImage(File(_localAvatarPath!));
    } else if (widget.originalAvatarUrl != null) {
      return NetworkImage(widget.originalAvatarUrl!);
    }
    return null;
  }

  Future<void> _pickAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isLoadingAvatar = true;
      });

      File imageFile = File(image.path);

      final localPath = await ContactLocalNamesService().saveContactAvatar(
        imageFile,
        widget.contactId,
      );

      if (localPath != null && mounted) {
        setState(() {
          _localAvatarPath = localPath;
          _isLoadingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аватар сохранен'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (mounted) {
          setState(() {
            _isLoadingAvatar = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки аватара: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аватар?'),
        content: const Text(
          'Локальный аватар будет удален, будет показан оригинальный.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ContactLocalNamesService().removeContactAvatar(widget.contactId);

        if (mounted) {
          setState(() {
            _localAvatarPath = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Аватар удален'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка удаления: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать контакт'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveContactData,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Сохранить',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Эти данные сохраняются только локально',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Аватар',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              backgroundImage: _getAvatarImage(),
                              child: _getAvatarImage() == null
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    )
                                  : null,
                            ),
                            if (_isLoadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_localAvatarPath != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _removeAvatar,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Удалить аватар'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Локальное имя',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _firstNameController,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: 'Имя',
                          hintText: widget.originalFirstName ?? 'Имя',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _lastNameController,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: 'Фамилия',
                          hintText: widget.originalLastName ?? 'Фамилия',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заметки',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        maxLength: 400,
                        decoration: InputDecoration(
                          labelText: 'Заметки о контакте',
                          hintText: 'Добавьте заметки...',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 60),
                            child: Icon(Icons.note_outlined),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _clearContactData,
                icon: const Icon(Icons.restore),
                label: const Text('Восстановить оригинальные данные'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

class ContactLocalDataHelper {
  static Future<Map<String, dynamic>?> getContactData(int contactId) async {
    return ContactLocalNamesService().getContactData(contactId);
  }

  static Future<void> clearContactData(int contactId) async {
    await ContactLocalNamesService().clearContactData(contactId);
  }
}
