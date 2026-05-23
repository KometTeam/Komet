import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_message_actions_style.dart';
import '../../../core/utils/haptics.dart';

class MessageActionsScreen extends StatelessWidget {
  const MessageActionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBarM3E(
        titleText: 'Меню действий',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: const [
            _StyleCard(),
          ],
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
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
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
                      _StyleTile(
                        icon: item.icon,
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
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _StyleTile({
    required this.icon,
    required this.label,
    required this.description,
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
              Icon(icon, color: cs.onSurface, size: 22, weight: 500),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
