import 'package:flutter/material.dart';

import '../../core/config/app_fonts.dart';
import '../../core/config/whats_new.dart';
import '../../l10n/app_localizations.dart';
import 'sheet_helpers.dart';

Future<void> showWhatsNewSheet(BuildContext context, String version) async {
  final cs = Theme.of(context).colorScheme;
  final notes = await WhatsNew.notes(
    Localizations.localeOf(context).languageCode,
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _WhatsNewSheet(version: version, notes: notes),
  );
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet({required this.version, required this.notes});

  final String version;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.center, child: SheetGrabber()),
              const SizedBox(height: 6),
              Text(
                l10n.whatsNewSheetTitle(version),
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: displayFontOf(context),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    notes.isEmpty ? l10n.whatsNewNoNotes : notes,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SheetButton(
                label: l10n.whatsNewDone,
                filled: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
