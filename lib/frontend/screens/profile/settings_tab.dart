import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

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
            SliverToBoxAdapter(child: _buildHeader(context, cs)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildSection(
                  context,
                  cs,
                  items: const [
                    _SettingsItem(icon: Symbols.badge, label: 'Цифровой ID'),
                    _SettingsItem(
                      icon: Symbols.language,
                      label: 'Войти в сферум',
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildSection(
                  context,
                  cs,
                  items: const [
                    _SettingsItem(
                      icon: Symbols.notifications_active,
                      label: 'Уведомления и звук',
                    ),
                    _SettingsItem(icon: Symbols.lock, label: 'Безопасность'),
                    _SettingsItem(icon: Symbols.devices, label: 'Устройства'),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Symbols.qr_code_2,
                  color: cs.onSurfaceVariant,
                  size: 26,
                  weight: 400,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(
                  Symbols.edit,
                  color: cs.onSurfaceVariant,
                  size: 22,
                  weight: 400,
                ),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.5),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: Image.network(
                'https://i.pravatar.cc/150?u=ilya',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Symbols.person,
                    color: cs.onPrimaryContainer,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Илья Беларуских',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '@everrnyan',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    ColorScheme cs, {
    required List<_SettingsItem> items,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return _buildSettingsRow(context, cs, item, isLast: isLast);
          }),
        ),
      ),
    );
  }

  Widget _buildSettingsRow(
    BuildContext context,
    ColorScheme cs,
    _SettingsItem item, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: cs.onSurfaceVariant,
                    size: 22,
                    weight: 400,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right,
                    color: cs.outline,
                    size: 20,
                    weight: 400,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String label;

  const _SettingsItem({required this.icon, required this.label});
}
