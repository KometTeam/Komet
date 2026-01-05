import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gwid/api/api_service.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManageAccountScreen extends StatefulWidget {
  final Profile? myProfile;
  const ManageAccountScreen({super.key, this.myProfile});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _descriptionController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Profile? _actualProfile;
  bool _isLoading = false;

  bool? _hasDeleteRequest;
  bool _isDeleteStatusLoading = false;
  bool _isDeleteActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _initializeProfileData();
    _loadAccountDeleteStatus();
  }

  Future<void> _loadAccountDeleteStatus() async {
    if (_isDeleteStatusLoading) return;

    setState(() {
      _isDeleteStatusLoading = true;
    });

    try {
      final payload = await ApiService.instance.sendRequest(200, const {});
      final timestamp = (payload is Map)
          ? (payload['timestamp'] as int? ?? 0)
          : 0;

      if (mounted) {
        setState(() {
          _hasDeleteRequest = timestamp > 0;
        });
      }
    } catch (e) {
      // Log the detailed error for debugging without exposing it to the user.
      debugPrint('Failed to load account delete status: $e');
      if (mounted) {
        setState(() {
          _hasDeleteRequest = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось получить статус удаления аккаунта. Попробуйте позже.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleteStatusLoading = false;
        });
      }
    }
  }

  Future<void> _setAccountDeleteRequest(bool delete) async {
    if (_isDeleteActionInProgress) return;

    setState(() {
      _isDeleteActionInProgress = true;
    });

    try {
      await ApiService.instance.sendRequest(
        199,
        {
          'delete': delete,
          'type': 0,
        },
        timeout: const Duration(seconds: 30),
      );

      if (mounted) {
        setState(() {
          _hasDeleteRequest = delete;
        });
      }
    } catch (e) {
      // Log the detailed error for debugging without exposing it to the user.
      debugPrint('Failed to set account delete request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось выполнить запрос. Попробуйте позже.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isDeleteActionInProgress = false;
        });
      }
    }
  }

  Future<void> _onDeleteAccountPressed() async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Учетная запись в MAX будет удалена через 30 дней'),
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
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );

    if (confirmDelete != true || !mounted) return;

    try {
      await _setAccountDeleteRequest(true);
    } catch (_) {
      return;
    }

    if (!mounted) return;

    final confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Вы хотите выйти из аккаунта? Все локальные данные (токены, настройки, кэш чатов) будут удалены безвозвратно.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (confirmLogout == true && mounted) {
      await _wipeLocalDataAndGoToLogin();
    }
  }

  Future<void> _onCancelDeleteAccountPressed() async {
    try {
      await _setAccountDeleteRequest(false);
    } catch (_) {
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Заявка на удаление отменена'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _wipeLocalDataAndGoToLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (_) {}

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final imageCacheDir = Directory('${docsDir.path}/image_cache');
      if (await imageCacheDir.exists()) {
        await imageCacheDir.delete(recursive: true);
      }
    } catch (_) {}

    try {
      await ApiService.instance.clearAllData();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const PhoneEntryScreen()),
      (route) => false,
    );
  }

  Future<void> _initializeProfileData() async {
    _actualProfile = widget.myProfile;

    _firstNameController = TextEditingController(
      text: _actualProfile?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: _actualProfile?.lastName ?? '',
    );
    _descriptionController = TextEditingController(
      text: _actualProfile?.description ?? '',
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final description = _descriptionController.text.trim();

      final updatedProfile = await ApiService.instance.updateProfileText(
        firstName,
        lastName,
        description,
      );

      if (updatedProfile != null) {
        _actualProfile = updatedProfile;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Профиль обновлен"),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка сохранения: $e"),
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

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
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
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ApiService.instance.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const PhoneEntryScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка выхода: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickAndUpdateProfilePhoto() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      final updatedProfile = await ApiService.instance.updateProfilePhoto(
        firstName,
        lastName,
      );

      if (updatedProfile != null && mounted) {
        setState(() {
          _actualProfile = updatedProfile;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Фотография профиля обновлена"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка загрузки фото: $e"),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_actualProfile);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_actualProfile),
          ),
          title: const Text("Изменить профиль"),
          centerTitle: true,
          scrolledUnderElevation: 0,
          actions: [
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                "Сохранить",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAvatarSection(theme),
                const SizedBox(height: 32),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Основная информация",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _firstNameController,
                          maxLength: 60,
                          decoration: _buildInputDecoration(
                            "Имя",
                            Icons.person_outline,
                          ).copyWith(counterText: ""),
                          validator: (value) =>
                              value!.isEmpty ? 'Введите ваше имя' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          maxLength: 60,
                          decoration: _buildInputDecoration(
                            "Фамилия",
                            Icons.person_outline,
                          ).copyWith(counterText: ""),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Дополнительно",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 400,
                          decoration: _buildInputDecoration(
                            "О себе",
                            Icons.edit_note_outlined,
                            alignLabel: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (widget.myProfile != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildInfoTile(
                          icon: Icons.phone_outlined,
                          title: "Телефон",
                          subtitle: widget.myProfile!.formattedPhone,
                        ),
                        const Divider(height: 1),
                        _buildTappableInfoTile(
                          icon: Icons.tag,
                          title: "Ваш ID",
                          subtitle: widget.myProfile!.id.toString(),
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: widget.myProfile!.id.toString(),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ID скопирован в буфер обмена'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogoutButton(),
                    const SizedBox(height: 12),
                    _buildDeleteAccountButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(ThemeData theme) {
    ImageProvider? avatarImage;

    final photoUrl =
        _actualProfile?.photoBaseUrl ?? widget.myProfile?.photoBaseUrl;
    if (photoUrl != null) {
      avatarImage = NetworkImage(photoUrl);
    }

    return Center(
      child: GestureDetector(
        onTap: _showAvatarOptions,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.secondaryContainer,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Icon(
                      Icons.person,
                      size: 60,
                      color: theme.colorScheme.onSecondaryContainer,
                    )
                  : null,
            ),
            if (_isLoading)
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
                  child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Выбрать из заготовленных аватаров'),
                onTap: () {
                  Navigator.of(context).pop();
                  _choosePresetAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Загрузить своё фото'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndUpdateProfilePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _choosePresetAvatar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Выбор аватара',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Выбери картинку из коллекции, потом при желании можно загрузить своё фото.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>>(
                  future: ApiService.instance.fetchPresetAvatars(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Не удалось загрузить аватары: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data ?? {};
                    final List<dynamic> categories =
                        data['presetAvatars'] as List<dynamic>? ?? [];

                    if (categories.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Список заготовленных аватаров пуст.'),
                        ),
                      );
                    }

                    return StatefulBuilder(
                      builder: (context, setState) {
                        final scrollController = ScrollController();
                        return SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Scrollbar(
                            controller: scrollController,
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat =
                                    categories[index]
                                        as Map<String, dynamic>? ??
                                    {};
                                final String name =
                                    cat['name']?.toString() ?? '';
                                final List<dynamic> avatars =
                                    cat['avatars'] as List<dynamic>? ?? [];

                                if (avatars.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (name.isNotEmpty) ...[
                                        Text(
                                          name,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 4,
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
                                            ),
                                        itemCount: avatars.length,
                                        itemBuilder: (context, i) {
                                          final a =
                                              avatars[i]
                                                  as Map<String, dynamic>? ??
                                              {};
                                          final String url =
                                              a['url']?.toString() ?? '';
                                          final int? photoId = a['id'] as int?;

                                          if (url.isEmpty || photoId == null) {
                                            return const SizedBox.shrink();
                                          }

                                          return InkWell(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            onTap: () async {
                                              final firstName =
                                                  _firstNameController.text
                                                      .trim();
                                              final lastName =
                                                  _lastNameController.text
                                                      .trim();

                                              try {
                                                setState(() {
                                                  _isLoading = true;
                                                });
                                                final updatedProfile =
                                                    await ApiService.instance
                                                        .setPresetAvatar(
                                                          firstName: firstName,
                                                          lastName: lastName,
                                                          photoId: photoId,
                                                        );
                                                if (!mounted) return;

                                                if (updatedProfile != null) {
                                                  setState(() {
                                                    _actualProfile =
                                                        updatedProfile;
                                                  });
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Аватар обновлён',
                                                      ),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Ошибка смены аватара: $e',
                                                    ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    backgroundColor:
                                                        theme.colorScheme.error,
                                                  ),
                                                );
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isLoading = false;
                                                  });
                                                }
                                              }
                                            },
                                            child: CircleAvatar(
                                              backgroundImage: NetworkImage(
                                                url,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    bool alignLabel = false,
  }) {
    final prefixIcon = (label == "О себе")
        ? Padding(padding: const EdgeInsets.only(bottom: 60), child: Icon(icon))
        : Icon(icon);

    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      alignLabelWithHint: alignLabel,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildTappableInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.copy_outlined, size: 20),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      icon: const Icon(Icons.logout),
      label: const Text('Выйти из аккаунта'),
      onPressed: _logout,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade400,
        side: BorderSide(color: Colors.red.shade200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    final isRequested = _hasDeleteRequest == true;
    final label = isRequested ? 'Не удалять аккаунт' : 'Удалить аккаунт';

    final enabled =
        !_isDeleteStatusLoading && !_isDeleteActionInProgress && _hasDeleteRequest != null;

    return OutlinedButton.icon(
      icon: Icon(isRequested ? Icons.undo : Icons.delete_outline),
      label: Text(label),
      onPressed: !enabled
          ? null
          : (isRequested ? _onCancelDeleteAccountPressed : _onDeleteAccountPressed),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade400,
        side: BorderSide(color: Colors.red.shade200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
