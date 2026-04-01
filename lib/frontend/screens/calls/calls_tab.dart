import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Звонки (Заглушка)',
        style: GoogleFonts.inter(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
