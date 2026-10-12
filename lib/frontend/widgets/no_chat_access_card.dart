import 'package:flutter/material.dart';

import '../../core/config/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../screens/contacts/contact_sheet_common.dart';
import 'animoji_glyph.dart';

Future<void> showNoChatAccessCard(BuildContext context) =>
    showBlurredCard<void>(context, (_) => const _NoChatAccessCard());

class _NoChatAccessCard extends StatelessWidget {
  const _NoChatAccessCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 340 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnimojiGlyph(emoji: '🛑', size: 112),
                const SizedBox(height: 16),
                Text(
                  l10n.chatNoAccessMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    fontFamily: displayFontOf(context),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.chatNoAccessOk),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
