import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/storage/app_database.dart';
import '../screens/calls/call_screen.dart';
import '../widgets/auth_limits_sheet.dart';
import '../widgets/login_success_screen.dart';
import 'dev_menu_widgets.dart';

class DebugPreviewsSection extends StatelessWidget {
  final bool micSignalOn;
  final ValueChanged<bool> onMicSignalChanged;

  const DebugPreviewsSection({
    super.key,
    required this.micSignalOn,
    required this.onMicSignalChanged,
  });

  Future<void> _openLoginSuccess(BuildContext context) async {
    final profile = await AppDatabase.loadActiveProfile();
    if (!context.mounted) return;
    final avatar = await precacheLoginAvatar(context, profile?.baseUrl);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginSuccessScreen(preview: true, avatar: avatar),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DevGroup(
          children: [
            DevRow(
              icon: Symbols.celebration,
              caption: 'Приветственная анимация входа',
              title: 'test hello',
              onTap: () => _openLoginSuccess(context),
            ),
            DevRow(
              icon: Symbols.phone,
              caption: 'Превью',
              title: 'Экран звонка',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CallScreen(name: 'Кирил Г.'),
                ),
              ),
            ),
            DevRow(
              icon: Symbols.lock_clock,
              caption: 'Ограничения аккаунта',
              title: 'После входа',
              onTap: () => showAuthLimitsSheet(context, AuthEntry.login),
            ),
            DevRow(
              icon: Symbols.hourglass_top,
              caption: 'Ограничения аккаунта',
              title: 'После регистрации',
              onTap: () => showAuthLimitsSheet(context, AuthEntry.registration),
            ),
          ],
        ),
        DevGroup(
          children: [
            DevSwitchRow(
              title: 'Сигнал микрофона (тест)',
              description:
                  'Шлёт change-media-settings в активный звонок, '
                  'не меняя реальный микрофон',
              value: micSignalOn,
              onChanged: onMicSignalChanged,
            ),
          ],
        ),
      ],
    );
  }
}
