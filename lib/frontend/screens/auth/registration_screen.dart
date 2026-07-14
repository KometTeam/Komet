import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:komet/l10n/app_localizations.dart';

import '../../../backend/modules/account.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/login_success_screen.dart';
import '../../widgets/small_spinner.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;
  final String registerToken;
  final List<PresetAvatarCategory> presetAvatars;

  const RegistrationScreen({
    super.key,
    required this.phoneNumber,
    required this.registerToken,
    required this.presetAvatars,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  int? _selectedPhotoId;
  String? _selectedAvatarUrl;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isSubmitting && _firstNameController.text.trim().isNotEmpty;

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    if (firstName.isEmpty) return;
    final lastName = _lastNameController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final accountId = await accountModule.completeRegistration(
        token: widget.registerToken,
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        photoId: _selectedPhotoId,
      );

      final loginResult = await accountModule.login(
        accountId: accountId,
        token: '',
      );

      if (!mounted) return;

      final avatar = await precacheLoginAvatar(
        context,
        loginResult.profile.baseUrl,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (_, __, ___) => LoginSuccessScreen(avatar: avatar),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showCustomNotification(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final firstName = _firstNameController.text.trim();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurfaceVariant),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _canSubmit ? _submit : null,
        backgroundColor: _canSubmit
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: _isSubmitting
            ? SmallSpinner(size: 22, color: cs.onSurfaceVariant)
            : Icon(
                Icons.arrow_forward,
                color: _canSubmit ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            Text(
              l10n.registrationTitle,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.registrationSubtitle,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.5),
                    width: 2.5,
                  ),
                ),
                child: ClipOval(
                  child: _selectedAvatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _selectedAvatarUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: cs.primaryContainer,
                          alignment: Alignment.center,
                          child: Text(
                            firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildTextField(
              cs,
              label: l10n.editProfileFirstName,
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              cs,
              label: l10n.editProfileLastName,
              controller: _lastNameController,
              textInputAction: TextInputAction.done,
            ),
            if (widget.presetAvatars.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                l10n.registrationChooseAvatar,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              for (final category in widget.presetAvatars)
                _buildAvatarCategory(cs, category),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    ColorScheme cs, {
    required String label,
    required TextEditingController controller,
    required TextInputAction textInputAction,
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
          enabled: !_isSubmitting,
          textInputAction: textInputAction,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: cs.onSurface, fontSize: 15),
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

  Widget _buildAvatarCategory(ColorScheme cs, PresetAvatarCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (category.name.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              category.name,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: category.avatars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final avatar = category.avatars[index];
              final selected = _selectedPhotoId == avatar.id;
              return GestureDetector(
                onTap: _isSubmitting
                    ? null
                    : () => setState(() {
                        _selectedPhotoId = avatar.id;
                        _selectedAvatarUrl = avatar.url;
                      }),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? cs.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatar.url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: cs.surfaceContainerHigh),
                        errorWidget: (_, __, ___) =>
                            Container(color: cs.surfaceContainerHigh),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
