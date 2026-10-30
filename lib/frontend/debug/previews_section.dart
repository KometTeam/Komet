import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/whats_new.dart';
import '../../core/storage/app_database.dart';
import '../../main.dart' show bannersModule;
import '../../models/informer_banner.dart';
import '../screens/auth/login_needs_2fa_screen.dart';
import '../screens/calls/call_screen.dart';
import '../widgets/auth_limits_sheet.dart';
import '../widgets/login_success_screen.dart';
import 'dev_menu_widgets.dart';

const InformerBanner _serverBannerPreview = InformerBanner(
  id: 'dev-preview-server-banner',
  title: 'Истории, опросы и не только',
  description: 'В новой версии MAX',
);

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
            DevRow(
              icon: Symbols.shield_person,
              caption: 'Вход',
              title: 'MAX требует 2FA',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginNeeds2faScreen()),
              ),
            ),
          ],
        ),
        DevGroup(
          children: [
            ValueListenableBuilder<InformerBanner?>(
              valueListenable: bannersModule.activeBanner,
              builder: (context, banner, _) => DevSwitchRow(
                title: 'Баннер от сервера MAX',
                description:
                    'Тестовое объявление над списком чатов, как приходит '
                    'от сервера, с подписью «К Komet не относятся»',
                value: banner?.id == _serverBannerPreview.id,
                onChanged: (on) =>
                    bannersModule.preview(on ? _serverBannerPreview : null),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: WhatsNew.pendingVersion,
              builder: (context, version, _) => DevSwitchRow(
                title: 'Плашка обновления Google Play',
                description:
                    'Над списком чатов «Комета обновилась», по нажатию '
                    'шторка «Что нового». Как после обновления из магазина',
                value: version != null,
                onChanged: (on) => WhatsNew.preview(on),
              ),
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
