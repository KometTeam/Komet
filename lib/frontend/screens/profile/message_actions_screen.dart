import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_message_actions_style.dart';
import '../../../core/utils/haptics.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/settings_radio_tile.dart';

class MessageActionsScreen extends StatelessWidget {
  const MessageActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: 'Меню действий',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: const [_StyleCard()],
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard();

  static const _items = [
    (
      style: MessageActionsStyle.radial,
      icon: Symbols.bubble_chart,
      label: 'Радиальное',
      description: 'Дуга кнопок вокруг точки нажатия',
    ),
    (
      style: MessageActionsStyle.list,
      icon: Symbols.menu,
      label: 'Список',
      description: 'Вертикальное меню рядом с сообщением',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Стиль',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Как показывается меню при долгом нажатии на сообщение',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<MessageActionsStyle>(
            valueListenable: AppMessageActionsStyle.current,
            builder: (context, current, _) {
              return Column(
                children: [
                  for (final item in _items)
                    SettingsRadioTile(
                      leading: Icon(
                        item.icon,
                        color: cs.onSurface,
                        size: 22,
                        weight: 500,
                      ),
                      label: item.label,
                      description: item.description,
                      selected: current == item.style,
                      onTap: () {
                        if (current == item.style) return;
                        Haptics.selection();
                        AppMessageActionsStyle.save(item.style);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
