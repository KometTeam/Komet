import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_icon.dart';
import '../../../core/utils/haptics.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  @override
  void initState() {
    super.initState();
    AppIconConfig.load();
  }

  Future<void> _select(AppIcon icon) async {
    if (!AppIconConfig.isSupported) {
      showCustomNotification(
        context,
        'Смена иконки доступна только на Android и iOS',
      );
      return;
    }
    if (AppIconConfig.current.value == icon) return;
    Haptics.selection();
    try {
      await AppIconConfig.apply(icon);
      if (!mounted) return;
      showCustomNotification(context, 'Иконка изменена на «${icon.title}»');
    } catch (e) {
      if (!mounted) return;
      showCustomNotification(context, 'Не удалось сменить иконку: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Иконка приложения',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            GlossyPill(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              depth: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Внешний вид иконки',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppIconConfig.isSupported
                        ? 'На Android приложение закроется — лаунчер подхватит новую иконку. На iOS — мгновенно с системным диалогом.'
                        : 'Доступно только на Android и iOS',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<AppIcon>(
                    valueListenable: AppIconConfig.current,
                    builder: (context, current, _) {
                      return Column(
                        children: [
                          for (final icon in AppIcon.values)
                            _IconTile(
                              icon: icon,
                              selected: current == icon,
                              onTap: () => _select(icon),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final AppIcon icon;
  final bool selected;
  final VoidCallback onTap;

  const _IconTile({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  icon.previewAsset,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  icon.title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Symbols.radio_button_checked
                    : Symbols.radio_button_unchecked,
                color: selected ? cs.primary : cs.outline,
                size: 22,
                fill: selected ? 1 : 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
