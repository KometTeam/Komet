import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/storage/app_database.dart';
import '../screens/calls/call_screen.dart';
import '../widgets/glossy_pill.dart';
import '../widgets/login_success_screen.dart';

class DebugPreviewsSection extends StatelessWidget {
  final bool micSignalOn;
  final ValueChanged<bool> onMicSignalChanged;

  const DebugPreviewsSection({
    super.key,
    required this.micSignalOn,
    required this.onMicSignalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final profile = await AppDatabase.loadActiveProfile();
                if (!context.mounted) return;
                final avatar = await precacheLoginAvatar(
                  context,
                  profile?.baseUrl,
                );
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LoginSuccessScreen(preview: true, avatar: avatar),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      Symbols.celebration,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'test hello',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Показать приветственную анимацию входа',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right,
                      color: cs.onSurfaceVariant,
                      size: 22,
                      weight: 400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GlossyPill(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            depth: 6,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Экран звонка',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Превью экранов звонков',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _DebugCallButton(
                  label: 'Экран звонка (превью)',
                  icon: Symbols.phone,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CallScreen(name: 'Кирил Г.'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сигнал микрофона (тест)',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Шлёт change-media-settings в активный звонок, '
                            'не меняя реальный микрофон',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(value: micSignalOn, onChanged: onMicSignalChanged),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DebugCallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DebugCallButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cs.onSurfaceVariant, size: 22, fill: 1),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
