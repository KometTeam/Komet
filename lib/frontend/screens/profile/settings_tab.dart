import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/storage/app_database.dart';
import 'devices_screen.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  ProfileData? _profile;
  bool _isPhoneVisible = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await AppDatabase.loadActiveProfile();
    if (mounted) setState(() => _profile = p);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final String fullName =
        '${_profile!.firstName}${_profile!.lastName != null ? ' ${_profile!.lastName}' : ''}';
    final String phone = '+${_profile!.phone}';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context, cs, fullName, phone),
            ),
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
                      label: 'Войти в Сферум',
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
                  items: [
                    const _SettingsItem(
                      icon: Symbols.notifications_active,
                      label: 'Уведомления и звук',
                    ),
                    const _SettingsItem(
                      icon: Symbols.lock,
                      label: 'Безопасность',
                    ),
                    _SettingsItem(
                      icon: Symbols.devices,
                      label: 'Устройства',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DevicesScreen(),
                          ),
                        );
                      },
                    ),
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

  Widget _buildHeader(
    BuildContext context,
    ColorScheme cs,
    String name,
    String phone,
  ) {
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
              child: _profile?.baseUrl != null && _profile!.baseUrl!.isNotEmpty
                  ? Image.network(
                      _profile!.baseUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholderAvatar(cs, name),
                    )
                  : _buildPlaceholderAvatar(cs, name),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isPhoneVisible = !_isPhoneVisible),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: _PhoneSpoiler(
                    text: phone,
                    isVisible: _isPhoneVisible,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isPhoneVisible ? Symbols.visibility : Symbols.visibility_off,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar(ColorScheme cs, String name) {
    return Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    ColorScheme cs, {
    required List<_SettingsItem> items,
  }) {
    return Container(
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
            onTap: item.onTap ?? () {},
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(20))
                : null,
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
  final VoidCallback? onTap;

  const _SettingsItem({required this.icon, required this.label, this.onTap});
}

class _PhoneSpoiler extends StatefulWidget {
  final String text;
  final bool isVisible;
  final TextStyle style;

  const _PhoneSpoiler({
    required this.text,
    required this.isVisible,
    required this.style,
  });

  @override
  State<_PhoneSpoiler> createState() => _PhoneSpoilerState();
}

class _PhoneSpoilerState extends State<_PhoneSpoiler>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState: widget.isVisible
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: SizedBox(
        child: CustomPaint(
          size: const Size(110, 16),
          painter: _SpoilerPainter(_controller, widget.style.color!),
        ),
      ),
      secondChild: Text(widget.text, style: widget.style),
    );
  }
}

class _SpoilerPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _SpoilerPainter(this.animation, this.color) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Draw the background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      paint,
    );

    // Draw "noisy" particles
    final particlePaint = Paint()..style = PaintingStyle.fill;

    // Simple noise effect with dots using animation value for movement
    for (int i = 0; i < 60; i++) {
      double dx = (i * 17.5 + animation.value * 20) % size.width;
      double dy = (i * 13.7 + animation.value * 15) % size.height;
      double opacity = (0.2 + 0.3 * (i % 5) / 5.0).clamp(0.0, 1.0);
      particlePaint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), 1.2, particlePaint);
    }
  }

  @override
  bool shouldRepaint(_SpoilerPainter oldDelegate) => true;
}
