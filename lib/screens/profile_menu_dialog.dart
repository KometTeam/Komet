
import 'package:flutter/material.dart';
import 'package:gwid/screens/manage_account_screen.dart';
import 'package:gwid/models/profile.dart';
import 'package:gwid/screens/settings/settings_screen.dart';
import 'package:gwid/screens/phone_entry_screen.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';
import 'package:gwid/api/api_service.dart';

class ProfileMenuDialog extends StatefulWidget {
  final Profile? myProfile;
  final void Function(Profile updatedProfile)? onProfileUpdated;

  const ProfileMenuDialog({super.key, this.myProfile, this.onProfileUpdated});

  @override
  State<ProfileMenuDialog> createState() => _ProfileMenuDialogState();
}

class _ProfileMenuDialogState extends State<ProfileMenuDialog> {
  bool _isAvatarExpanded = false;

  void _toggleAvatar() {
    setState(() {
      _isAvatarExpanded = !_isAvatarExpanded;
    });
  }

  void _collapseAvatar() {
    if (_isAvatarExpanded) {
      setState(() {
        _isAvatarExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final String subtitle = "Профиль";

    final Profile? myProfile = widget.myProfile;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 60.0, left: 16.0, right: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Komet",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0x0ff33333),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: GestureDetector(
                              onTap: _toggleAvatar,
                              child: Opacity(
                                opacity: _isAvatarExpanded ? 0 : 1,
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundImage:
                                      myProfile?.photoBaseUrl != null
                                      ? NetworkImage(myProfile!.photoBaseUrl!)
                                      : null,
                                  child: myProfile?.photoBaseUrl == null
                                      ? Text(
                                          myProfile?.displayName.isNotEmpty ==
                                                  true
                                              ? myProfile!.displayName[0]
                                                    .toUpperCase()
                                              : '?',
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            title: Text(
                              myProfile?.displayName ?? "Загрузка...",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(subtitle),
                            trailing: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final extra = context
                                  .read<ThemeProvider>()
                                  .extraTransition;
                              final strength = context
                                  .read<ThemeProvider>()
                                  .extraAnimationStrength;
                              final panel = SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    side: BorderSide(color: colors.outline),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push<Profile?>(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ManageAccountScreen(
                                              myProfile: myProfile,
                                            ),
                                      ),
                                    ).then((updatedProfile) {
                                      if (updatedProfile != null && widget.onProfileUpdated != null) {
                                        widget.onProfileUpdated!(updatedProfile);
                                      }
                                    });
                                  },
                                  child: const Text("Управление аккаунтом"),
                                ),
                              );
                              if (extra == TransitionOption.slide &&
                                  _isAvatarExpanded) {
                                return AnimatedSlide(
                                  offset: _isAvatarExpanded
                                      ? Offset.zero
                                      : Offset(0, strength / 400.0),
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeInOut,
                                  child: AnimatedOpacity(
                                    opacity: _isAvatarExpanded ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeInOut,
                                    child: panel,
                                  ),
                                );
                              }
                              return panel;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    _SettingsTile(
                      icon: Icons.settings_outlined,
                      title: "Настройки",
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _SettingsTile(
                      icon: Icons.logout,
                      title: "Выйти",
                      onTap: () async {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          try {
                            await ApiService.instance.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const PhoneEntryScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка при выходе: $e'),
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),


            if (_isAvatarExpanded)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _collapseAvatar,
                  child: const SizedBox.expand(),
                ),
              ),


            AnimatedAlign(
              alignment: _isAvatarExpanded
                  ? Alignment.center
                  : Alignment.topLeft,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: !_isAvatarExpanded,
                child: GestureDetector(
                  onTap: () {},
                  child: Builder(
                    builder: (context) {
                      final extra = context
                          .read<ThemeProvider>()
                          .extraTransition;
                      final avatar = CircleAvatar(
                        radius: 80,
                        backgroundImage: widget.myProfile?.photoBaseUrl != null
                            ? NetworkImage(widget.myProfile!.photoBaseUrl!)
                            : null,
                        child: widget.myProfile?.photoBaseUrl == null
                            ? Text(
                                widget.myProfile?.displayName.isNotEmpty == true
                                    ? widget.myProfile!.displayName[0]
                                          .toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 36),
                              )
                            : null,
                      );
                      if (extra == TransitionOption.slide) {
                        return AnimatedSlide(
                          offset: _isAvatarExpanded
                              ? Offset.zero
                              : const Offset(0, -1),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: avatar,
                        );
                      }
                      return AnimatedScale(
                        scale: _isAvatarExpanded ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: avatar,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
