import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_fonts.dart';
import '../../core/config/whats_new.dart';
import '../../core/utils/haptics.dart';
import '../../core/whats_new/whats_new_document.dart';
import '../../l10n/app_localizations.dart';
import 'sheet_helpers.dart';
import 'whats_new_runner.dart';

Future<void> showWhatsNewSheet(BuildContext context, String version) async {
  final cs = Theme.of(context).colorScheme;
  final document = await WhatsNew.document(
    Localizations.localeOf(context).languageCode,
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _WhatsNewSheet(version: version, document: document),
  );
}

class _WhatsNewSheet extends StatefulWidget {
  const _WhatsNewSheet({required this.version, required this.document});

  final String version;
  final WhatsNewDocument document;

  @override
  State<_WhatsNewSheet> createState() => _WhatsNewSheetState();
}

class _WhatsNewSheetState extends State<_WhatsNewSheet> {
  static const double _rowInset = 12;

  late final WhatsNewRunner _runner = WhatsNewRunner(
    widget.document,
    closeSheet: _close,
  );
  final Map<WhatsNewLinkSpan, TapGestureRecognizer> _recognizers = {};
  ModalRoute<Object?>? _route;

  @override
  void initState() {
    super.initState();
    for (final note in widget.document.notes) {
      for (final span in note.spans.whereType<WhatsNewLinkSpan>()) {
        _recognizers[span] = TapGestureRecognizer()
          ..onTap = () => _run(span.target);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  void _run(WhatsNewTarget target) {
    Haptics.tap();
    unawaited(_runner.run(target));
  }

  Future<void> _close() async {
    if (!mounted) return;
    final animation = _route?.animation;
    Navigator.of(context).pop();
    if (animation == null || animation.isDismissed) return;
    final dismissed = Completer<void>();
    void listener(AnimationStatus status) {
      if (status.isDismissed && !dismissed.isCompleted) dismissed.complete();
    }

    animation.addStatusListener(listener);
    await dismissed.future.timeout(
      const Duration(milliseconds: 600),
      onTimeout: () {},
    );
    animation.removeStatusListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final notes = widget.document.notes;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20 - _rowInset,
            0,
            20 - _rowInset,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.center, child: SheetGrabber()),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _rowInset),
                child: Text(
                  l10n.whatsNewSheetTitle(widget.version),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: displayFontOf(context),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: notes.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _rowInset,
                          ),
                          child: Text(
                            l10n.whatsNewNoNotes,
                            style: _bodyStyle(cs),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final note in notes) _buildNote(cs, note),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _rowInset),
                child: SheetButton(
                  label: l10n.whatsNewDone,
                  filled: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _bodyStyle(ColorScheme cs) =>
      TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.45);

  Widget _buildNote(ColorScheme cs, WhatsNewNote note) {
    final text = Text.rich(
      TextSpan(
        style: _bodyStyle(cs),
        children: [
          for (final span in note.spans)
            switch (span) {
              WhatsNewPlainSpan() => TextSpan(text: span.text),
              WhatsNewLinkSpan() => TextSpan(
                text: span.text,
                recognizer: _recognizers[span],
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            },
        ],
      ),
    );

    final target = note.target;
    if (target == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _rowInset, vertical: 4),
        child: text,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _run(target),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_rowInset, 8, 6, 8),
            child: Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 6),
                Icon(Symbols.chevron_right, size: 20, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
