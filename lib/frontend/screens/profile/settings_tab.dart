import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Настройки (Заглушка)',
        style: GoogleFonts.inter(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
