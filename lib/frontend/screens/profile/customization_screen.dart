import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/haptics.dart';
import 'appearance_screen.dart';
import 'font_settings_screen.dart';

class _CustomizationCategory {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _CustomizationCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
}

class CustomizationScreen extends StatelessWidget {
  const CustomizationScreen({super.key});

  static const List<_CustomizationCategory> _categories = [
    _CustomizationCategory(
      icon: Symbols.palette,
      title: 'Внешний вид',
      subtitle: 'Акцентный цвет интерфейса',
      builder: _buildAppearance,
    ),
    _CustomizationCategory(
      icon: Symbols.text_fields,
      title: 'Шрифты',
      subtitle: 'Шрифт приложения, свои шрифты, размер текста',
      builder: _buildFontSettings,
    ),
  ];

  static Widget _buildAppearance(BuildContext context) =>
      const AppearanceScreen();

  static Widget _buildFontSettings(BuildContext context) =>
      const FontSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBarM3E(
        titleText: 'Кастомизация',
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            for (final category in _categories) ...[
              _CategoryCard(
                category: category,
                onTap: () {
                  Haptics.tap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: category.builder),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _CustomizationCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  category.icon,
                  color: cs.onPrimaryContainer,
                  size: 24,
                  weight: 500,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.subtitle,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Symbols.chevron_right, color: cs.outline, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
