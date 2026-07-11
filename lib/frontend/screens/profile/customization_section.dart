import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/haptics.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/settings_card.dart';
import 'app_icon_screen.dart';
import 'appearance_screen.dart';
import 'chat_background_screen.dart';
import 'font_settings_screen.dart';
import 'message_actions_screen.dart';
import 'theme_settings_screen.dart';

class _CustomizationCategory {
  final IconData icon;
  final String title;
  final WidgetBuilder builder;

  const _CustomizationCategory({
    required this.icon,
    required this.title,
    required this.builder,
  });
}

class CustomizationSection extends StatefulWidget {
  const CustomizationSection({super.key});

  @override
  State<CustomizationSection> createState() => _CustomizationSectionState();
}

class _CustomizationSectionState extends State<CustomizationSection> {
  bool _expanded = false;

  static final List<_CustomizationCategory> _categories = [
    _CustomizationCategory(
      icon: Symbols.dark_mode,
      title: 'Тема',
      builder: (context) => const ThemeSettingsScreen(),
    ),
    _CustomizationCategory(
      icon: Symbols.palette,
      title: 'Внешний вид',
      builder: (context) => const AppearanceScreen(),
    ),
    _CustomizationCategory(
      icon: Symbols.wallpaper,
      title: 'Фон чатов',
      builder: (context) => const ChatBackgroundScreen(),
    ),
    _CustomizationCategory(
      icon: Symbols.text_fields,
      title: 'Шрифты',
      builder: (context) => const FontSettingsScreen(),
    ),
    _CustomizationCategory(
      icon: Symbols.touch_app,
      title: 'Меню действий',
      builder: (context) => const MessageActionsScreen(),
    ),
    _CustomizationCategory(
      icon: Symbols.apps,
      title: 'Иконка приложения',
      builder: (context) => const AppIconScreen(),
    ),
  ];

  void _toggle() {
    Haptics.tap();
    setState(() => _expanded = !_expanded);
  }

  void _open(_CustomizationCategory category) {
    Haptics.tap();
    Navigator.push(context, MaterialPageRoute(builder: category.builder));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      child: Column(
        children: [
          _buildHeader(cs),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(children: _buildCategoryTiles(cs))
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Icon(
                Symbols.palette,
                color: cs.onSurfaceVariant,
                size: 22,
                weight: 400,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Кастомизация',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _expanded ? 0.5 : 0,
                child: Icon(
                  Symbols.expand_more,
                  color: cs.outline,
                  size: 22,
                  weight: 400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryTiles(ColorScheme cs) {
    final tiles = <Widget>[];
    for (var i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(left: 58),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      );
      tiles.add(
        SettingsNavTile(
          icon: category.icon,
          label: category.title,
          onTap: () => _open(category),
          isLast: i == _categories.length - 1,
        ),
      );
    }
    return tiles;
  }
}
