import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_fonts.dart';
import '../../core/config/app_shape.dart';
import '../../core/links/link_inspector.dart';
import '../../core/links/visited_link_sites.dart';
import '../../core/utils/link_opener.dart';
import '../../l10n/app_localizations.dart';
import 'alert_note.dart';
import 'sheet_helpers.dart';

Future<void> openMessageLink(
  BuildContext context,
  String url, {
  String? shownText,
}) async {
  final target = linkWithScheme(url);
  if (linkStaysInApp(target)) {
    await openExternalUrl(context, target);
    return;
  }
  final inspection = inspectLink(target, shownText: shownText);
  if (inspection.suspicious || !await VisitedLinkSites.contains(target)) {
    if (!context.mounted) return;
    if (!await _showLinkConfirmSheet(context, inspection)) return;
  }
  if (!context.mounted) return;
  if (!inspection.suspicious) unawaited(VisitedLinkSites.remember(target));
  await openExternalUrl(context, target);
}

Future<void> previewLinkCheck(BuildContext context, String url) =>
    _showLinkConfirmSheet(context, inspectLink(url));

Future<bool> _showLinkConfirmSheet(
  BuildContext context,
  LinkInspection inspection,
) async {
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _LinkConfirmSheet(inspection: inspection),
  );
  return confirmed == true;
}

String _warningText(
  AppLocalizations l10n,
  LinkWarning warning,
  LinkInspection inspection,
) {
  switch (warning.kind) {
    case LinkWarningKind.textMismatch:
      return l10n.linkWarningTextMismatch(warning.value, inspection.host);
    case LinkWarningKind.userInfo:
      return l10n.linkWarningUserInfo(warning.value);
    case LinkWarningKind.mixedScripts:
      return l10n.linkWarningMixedScripts(_letters(l10n, warning.letters));
    case LinkWarningKind.lookalikeScript:
      return l10n.linkWarningLookalike(
        _scriptName(l10n, warning.letters.first.script),
      );
    case LinkWarningKind.invisibleCharacters:
      return l10n.linkWarningInvisible;
    case LinkWarningKind.ipAddress:
      return l10n.linkWarningIpAddress;
    case LinkWarningKind.unusualScheme:
      return l10n.linkWarningScheme(warning.value);
  }
}

String _letters(AppLocalizations l10n, List<LinkLetter> letters) {
  final byScript = <LinkScript, List<String>>{};
  for (final letter in letters) {
    (byScript[letter.script] ??= []).add(l10n.linkWarningLetter(letter.letter));
  }
  return [
    for (final entry in byScript.entries)
      l10n.linkWarningLetters(
        entry.value.join(', '),
        _scriptName(l10n, entry.key),
      ),
  ].join('; ');
}

String _scriptName(AppLocalizations l10n, LinkScript script) {
  switch (script) {
    case LinkScript.latin:
      return l10n.linkScriptLatin;
    case LinkScript.cyrillic:
      return l10n.linkScriptCyrillic;
    case LinkScript.greek:
      return l10n.linkScriptGreek;
    case LinkScript.armenian:
      return l10n.linkScriptArmenian;
  }
}

class _LinkConfirmSheet extends StatelessWidget {
  const _LinkConfirmSheet({required this.inspection});

  final LinkInspection inspection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final suspicious = inspection.suspicious;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.center, child: SheetGrabber()),
            const SizedBox(height: 6),
            Text(
              suspicious
                  ? l10n.linkConfirmSuspiciousTitle
                  : l10n.linkConfirmTitle,
              style: TextStyle(
                color: suspicious ? cs.error : cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: displayFontOf(context),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: AppShape.buttonRadius,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    suspicious ? Symbols.gpp_maybe : Symbols.link,
                    color: suspicious ? cs.error : cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _LinkAddress(inspection: inspection)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (suspicious)
              AlertNote.all([
                for (final warning in inspection.warnings)
                  _warningText(l10n, warning, inspection),
              ], icon: Symbols.warning)
            else
              Text(
                l10n.linkConfirmBody,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: suspicious
                  ? [
                      Expanded(
                        child: SheetButton(
                          label: l10n.linkConfirmOpenAnyway,
                          filled: false,
                          color: cs.error,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SheetButton(
                          label: l10n.linkConfirmDontOpen,
                          filled: true,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                    ]
                  : [
                      Expanded(
                        child: SheetButton(
                          label: l10n.linkConfirmCancel,
                          filled: false,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SheetButton(
                          label: l10n.linkConfirmOpen,
                          filled: true,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddressPart { plain, host, flagged }

class _LinkAddress extends StatelessWidget {
  const _LinkAddress({required this.inspection});

  final LinkInspection inspection;

  _AddressPart _partAt(int index) {
    if (inspection.flagged.contains(index)) return _AddressPart.flagged;
    if (index >= inspection.hostStart && index < inspection.hostEnd) {
      return _AddressPart.host;
    }
    return _AddressPart.plain;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final styles = {
      _AddressPart.plain: TextStyle(color: cs.onSurfaceVariant),
      _AddressPart.host: TextStyle(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      _AddressPart.flagged: TextStyle(
        color: cs.error,
        fontWeight: FontWeight.w700,
        backgroundColor: cs.error.withValues(alpha: 0.16),
      ),
    };
    final address = inspection.address;
    final spans = <TextSpan>[];
    var start = 0;
    while (start < address.length) {
      final part = _partAt(start);
      var end = start + 1;
      while (end < address.length && _partAt(end) == part) {
        end++;
      }
      spans.add(
        TextSpan(text: address.substring(start, end), style: styles[part]),
      );
      start = end;
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 14.5, height: 1.3),
        children: spans,
      ),
      maxLines: inspection.suspicious ? 6 : 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}
