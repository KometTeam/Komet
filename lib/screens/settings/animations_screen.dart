import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gwid/utils/theme_provider.dart';

class AnimationsScreen extends StatelessWidget {
  const AnimationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Настройки анимаций"),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _ModernSection(
            title: "Анимации сообщений",
            children: [
              _DropdownSettingTile(
                icon: Icons.chat_bubble_outline,
                title: "Стиль появления",
                items: TransitionOption.values,
                value: theme.messageTransition,
                onChanged: (value) {
                  if (value != null) theme.setMessageTransition(value);
                },
                itemToString: (item) => item.displayName,
              ),
              const Divider(height: 24),
              _CustomSettingTile(
                icon: Icons.photo_library_outlined,
                title: "Анимация фото",
                subtitle: "Плавное появление фото в чате",
                child: Switch(
                  value: theme.animatePhotoMessages,
                  onChanged: (value) => theme.setAnimatePhotoMessages(value),
                ),
              ),
              if (theme.messageTransition == TransitionOption.slide) ...[
                const SizedBox(height: 8),
                _SliderTile(
                  icon: Icons.open_in_full_rounded,
                  label: "Расстояние слайда",
                  value: theme.messageSlideDistance,
                  min: 1.0,
                  max: 200.0,
                  divisions: 20,
                  onChanged: (value) => theme.setMessageSlideDistance(value),
                  displayValue: "${theme.messageSlideDistance.round()}px",
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          _ModernSection(
            title: "Переходы и эффекты",
            children: [
              _DropdownSettingTile(
                icon: Icons.swap_horiz_rounded,
                title: "Переход между чатами",
                items: TransitionOption.values,
                value: theme.chatTransition,
                onChanged: (value) {
                  if (value != null) theme.setChatTransition(value);
                },
                itemToString: (item) => item.displayName,
              ),
              const Divider(height: 24),
              _DropdownSettingTile(
                icon: Icons.auto_awesome_motion_outlined,
                title: "Дополнительные эффекты",
                subtitle: "Для диалогов и других элементов",
                items: TransitionOption.values,
                value: theme.extraTransition,
                onChanged: (value) {
                  if (value != null) theme.setExtraTransition(value);
                },
                itemToString: (item) => item.displayName,
              ),
              if (theme.extraTransition == TransitionOption.slide) ...[
                const SizedBox(height: 8),
                _SliderTile(
                  icon: Icons.bolt_rounded,
                  label: "Сила эффекта",
                  value: theme.extraAnimationStrength,
                  min: 1.0,
                  max: 400.0,
                  divisions: 20,
                  onChanged: (value) => theme.setExtraAnimationStrength(value),
                  displayValue: "${theme.extraAnimationStrength.round()}",
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          _ModernSection(
            title: "Управление",
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                leading: Icon(Icons.restore_rounded, color: colors.error),
                title: Text(
                  "Сбросить настройки анимаций",
                  style: TextStyle(color: colors.error),
                ),
                subtitle: const Text("Вернуть все значения по умолчанию"),
                onTap: () => _showResetDialog(context, theme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Сбросить настройки?'),
        content: const Text(
          'Все параметры анимаций на этом экране будут возвращены к значениям по умолчанию.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              theme.resetAnimationsToDefault();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Настройки анимаций сброшены'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.restore),
            label: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }
}

class _ModernSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ModernSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _CustomSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _CustomSettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _DropdownSettingTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) itemToString;

  const _DropdownSettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemToString,
  });

  @override
  Widget build(BuildContext context) {
    return _CustomSettingTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        onChanged: onChanged,
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(itemToString(item)));
        }).toList(),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String displayValue;

  const _SliderTile({
    this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
              Text(
                displayValue,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 30,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
