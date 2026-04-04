import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../widgets/custom_notification.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _safeMode = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildAppBar(context, cs)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildTopSection(cs),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildSafeModeSection(cs),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _buildInfoLabel(cs),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildOnlineSection(cs),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: _buildBlacklistSection(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Symbols.arrow_back, color: cs.onSurface, size: 24, weight: 400),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Безопасность',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildNavRow(
            cs,
            icon: Symbols.key,
            label: 'Пароль для входа',
            subtitle: 'Отключён',
            trailing: _buildWarningBadge(cs),
            isLast: false,
          ),
          _buildNavRow(
            cs,
            icon: Symbols.shield,
            label: 'Семейная защита',
            subtitle: 'Отключена',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSafeModeSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                Icon(Symbols.lock, color: cs.onSurfaceVariant, size: 22, weight: 400),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Безопасный режим',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Доступно только в мобильном приложении',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _safeMode,
                  onChanged: (v) => setState(() => _safeMode = v),
                ),
              ],
            ),
          ),
          if (_safeMode) ...[
            Padding(
              padding: const EdgeInsets.only(left: 58),
              child: Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
            _buildSubRow(cs, label: 'Найти меня по номеру', value: 'Могут все', isLast: false),
            _buildSubRow(cs, label: 'Позвонить', value: 'Могут все', isLast: false),
            _buildSubRow(cs, label: 'Пригласить в чат', value: 'Могут контакты', isLast: false),
            _buildSubRow(cs, label: 'Показывать контент', value: 'Весь', isLast: true),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoLabel(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        'ИНФОРМАЦИЯ',
        style: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildOnlineSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _buildNavRow(
        cs,
        icon: null,
        label: 'Видеть статус «в сети»',
        value: 'Никто',
        isLast: true,
        noIcon: true,
      ),
    );
  }

  Widget _buildBlacklistSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showCustomNotification(context, 'Чёрный список'),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Чёрный список',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Список тех, кто не может вам писать, звонить и добавлять в чаты',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Symbols.chevron_right, color: cs.outline, size: 20, weight: 400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavRow(
    ColorScheme cs, {
    required IconData? icon,
    required String label,
    String? subtitle,
    String? value,
    Widget? trailing,
    required bool isLast,
    bool noIcon = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showCustomNotification(context, label),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  if (!noIcon) ...[
                    Icon(icon, color: cs.onSurfaceVariant, size: 22, weight: 400),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: subtitle != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                  if (value != null)
                    Text(
                      value,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  if (trailing != null) trailing,
                  const SizedBox(width: 4),
                  Icon(Symbols.chevron_right, color: cs.outline, size: 20, weight: 400),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
      ],
    );
  }

  Widget _buildSubRow(
    ColorScheme cs, {
    required String label,
    required String value,
    required bool isLast,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showCustomNotification(context, label),
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: cs.onSurface, fontSize: 15),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Icon(Symbols.chevron_right, color: cs.outline, size: 18, weight: 400),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
            indent: 20,
            endIndent: 20,
          ),
      ],
    );
  }

  Widget _buildWarningBadge(ColorScheme cs) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: cs.error,
        shape: BoxShape.circle,
      ),
      child: Icon(Symbols.priority_high, color: cs.onError, size: 14, weight: 700),
    );
  }
}
