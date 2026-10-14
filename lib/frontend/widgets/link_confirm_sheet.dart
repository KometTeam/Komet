import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_fonts.dart';
import '../../core/config/app_shape.dart';
import '../../core/links/visited_link_sites.dart';
import '../../core/utils/link_opener.dart';
import '../../l10n/app_localizations.dart';
import 'sheet_helpers.dart';

bool linkShowsItsTarget(String text, String url) {
  String bare(String value) => value
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '')
      .replaceFirst(RegExp(r'^www\.'), '')
      .replaceFirst(RegExp(r'/+$'), '');
  return bare(text) == bare(url);
}

Future<void> openMessageLink(
  BuildContext context,
  String url, {
  required bool hidden,
}) async {
  final external = !linkStaysInApp(url);
  if (external && hidden && !await VisitedLinkSites.contains(url)) {
    if (!context.mounted) return;
    if (!await showLinkConfirmSheet(context, url)) return;
  }
  if (!context.mounted) return;
  if (external) unawaited(VisitedLinkSites.remember(url));
  await openExternalUrl(context, url);
}

Future<bool> showLinkConfirmSheet(BuildContext context, String url) async {
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _LinkConfirmSheet(url: url),
  );
  return confirmed == true;
}

class _LinkConfirmSheet extends StatelessWidget {
  const _LinkConfirmSheet({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
              l10n.linkConfirmTitle,
              style: TextStyle(
                color: cs.onSurface,
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
                  Icon(Symbols.link, color: cs.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: _LinkAddress(url: url)),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
              children: [
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

class _LinkAddress extends StatelessWidget {
  const _LinkAddress({required this.url});

  final String url;

  int _hostStart(String host) {
    final schemeEnd = url.indexOf('://');
    final authorityStart = schemeEnd < 0 ? 0 : schemeEnd + 3;
    final at = url.indexOf('@', authorityStart);
    final slash = url.indexOf('/', authorityStart);
    final from = at >= 0 && (slash < 0 || at < slash) ? at + 1 : authorityStart;
    return url.toLowerCase().indexOf(host, from);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: 14.5,
      height: 1.3,
    );
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final start = host.isEmpty ? -1 : _hostStart(host);
    if (start < 0) {
      return Text(
        url,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: muted.copyWith(color: cs.onSurface),
      );
    }
    final end = start + host.length;
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          TextSpan(text: url.substring(0, start)),
          TextSpan(
            text: url.substring(start, end),
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: url.substring(end)),
        ],
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
}
