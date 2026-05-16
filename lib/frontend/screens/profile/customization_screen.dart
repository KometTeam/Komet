import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/utils/haptics.dart';
import '../../../main.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  void _selectFont(String id) {
    final app = KometApp.stateOf(context);
    if (app == null || app.fontId == id) return;
    Haptics.selection();
    app.applyAppFont(id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentId = KometApp.stateOf(context)?.fontId ?? AppFonts.fallback.id;

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _PreviewCard(fontId: currentId),
            const SizedBox(height: 28),
            const _SectionLabel(icon: Symbols.text_fields, text: 'Шрифт'),
            const SizedBox(height: 14),
            for (final font in AppFonts.all) ...[
              _FontOption(
                font: font,
                selected: font.id == currentId,
                onTap: () => _selectFont(font.id),
              ),
              if (font != AppFonts.all.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String fontId;

  const _PreviewCard({required this.fontId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ПРЕДПРОСМОТР',
            style: TextStyle(
              color: cs.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Съешь ещё этих мягких булок',
            style: AppFonts.sample(fontId, fontSize: 22).copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'The quick brown fox 0123',
            style: AppFonts.sample(fontId, fontSize: 15).copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant, weight: 500),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _FontOption extends StatelessWidget {
  final AppFont font;
  final bool selected;
  final VoidCallback onTap;

  const _FontOption({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ButtonM3E(
        onPressed: onTap,
        style: selected ? ButtonM3EStyle.filled : ButtonM3EStyle.tonal,
        size: ButtonM3ESize.xl,
        shape: ButtonM3EShape.round,
        selected: selected,
        icon: Icon(
          selected ? Symbols.check_circle : Symbols.font_download,
          fill: selected ? 1 : 0,
        ),
        label: Text(
          font.label,
          style: AppFonts.sample(font.id, fontSize: 18),
        ),
      ),
    );
  }
}
