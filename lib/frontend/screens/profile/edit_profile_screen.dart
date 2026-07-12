import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/image_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show accountModule, fileUploader, KometApp;
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _avatarUrl;
  int? _photoId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    if (profile != null) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName ?? '';
      _avatarUrl = profile.baseUrl;
      _photoId = profile.photoId;
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveName() async {
    if (_isSaving) return;
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) {
      if (mounted) showCustomNotification(context, 'Имя не может быть пустым');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final newProfile = await accountModule.updateProfileName(
        firstName,
        _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
      );
      _avatarUrl = newProfile.baseUrl;
      _photoId = newProfile.photoId;
      if (!mounted) return;
      KometApp.stateOf(context)?.notifyProfileUpdate();
      if (mounted) {
        showCustomNotification(context, 'Имя сохранено');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (!mounted) return;
      showCustomNotification(context, 'Ошибка: $e');
      setState(() => _isSaving = false);
    }
  }

  Future<void> _changeAvatar() async {
    if (_isSaving) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      if (mounted) showCustomNotification(context, 'Не удалось прочитать файл');
      return;
    }
    if (bytes.length > kMaxAvatarBytes) {
      if (mounted) {
        showCustomNotification(context, 'Картинка слишком большая (макс 8 МБ)');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final processed = await compressAvatar(bytes);
      if (processed == null) {
        if (!mounted) return;
        showCustomNotification(context, 'Не удалось обработать изображение');
        setState(() => _isSaving = false);
        return;
      }
      final url = await accountModule.getAvatarUploadUrl();
      final token = await fileUploader.uploadImage(
        Uri.parse(url),
        processed,
        filename: 'avatar.jpg',
      );
      if (token == null) {
        if (!mounted) return;
        showCustomNotification(context, 'Не удалось загрузить аватарку');
        setState(() => _isSaving = false);
        return;
      }
      final newProfile = await accountModule.updateProfileAvatar(token);
      if (!mounted) return;
      setState(() {
        _avatarUrl = newProfile.baseUrl;
        _photoId = newProfile.photoId;
        _isSaving = false;
      });
      KometApp.stateOf(context)?.notifyProfileUpdate();
      showCustomNotification(context, 'Аватарка обновлена');
    } catch (e) {
      if (!mounted) return;
      showCustomNotification(context, 'Ошибка: $e');
      setState(() => _isSaving = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_isSaving || _photoId == null) return;
    setState(() => _isSaving = true);
    try {
      final newProfile = await accountModule.removeProfilePhoto(_photoId!);
      _avatarUrl = newProfile.baseUrl;
      _photoId = newProfile.photoId;
      if (!mounted) return;
      KometApp.stateOf(context)?.notifyProfileUpdate();
      if (mounted) {
        showCustomNotification(context, 'Фото удалено');
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (!mounted) return;
      showCustomNotification(context, 'Ошибка: $e');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: ConnectionTitleText(
          l10n?.editProfileTitle ?? 'Edit Profile',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _saveName,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    l10n?.editProfileSave ?? 'Save',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                        child: KometAvatar(
                          name: _firstNameController.text,
                          imageUrl: _avatarUrl,
                          size: 88,
                          fontSize: 32,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Symbols.camera_alt,
                              color: cs.onPrimary,
                              size: 20,
                            ),
                            onPressed: _changeAvatar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_photoId != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _removeAvatar,
                      child: Text(
                        l10n?.editProfileRemovePhoto ?? 'Remove photo',
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildTextField(
                  l10n?.editProfileFirstName ?? 'First name',
                  _firstNameController,
                  cs,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  l10n?.editProfileLastName ?? 'Last name',
                  _lastNameController,
                  cs,
                  enabled: !_isSaving,
                ),
                const SizedBox(height: 120),
              ],
            ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    ColorScheme cs, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
