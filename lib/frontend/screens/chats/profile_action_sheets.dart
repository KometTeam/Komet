import 'package:flutter/material.dart';

import '../contacts/contact_sheet_common.dart';
import '../../../core/config/app_fonts.dart';

class ConfirmChoice {
  final bool confirmed;
  final bool checked;

  const ConfirmChoice({required this.confirmed, required this.checked});

  static const cancelled = ConfirmChoice(confirmed: false, checked: false);
}

Future<ConfirmChoice> showBlurredConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  String? checkboxLabel,
  bool checkboxInitial = false,
}) async {
  final result = await showBlurredCard<ConfirmChoice>(
    context,
    (_) => _ConfirmCard(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      checkboxLabel: checkboxLabel,
      checkboxInitial: checkboxInitial,
    ),
  );
  return result ?? ConfirmChoice.cancelled;
}

enum CardActionTone { primary, neutral, destructive }

class CardAction<T> {
  final String label;
  final T value;
  final CardActionTone tone;

  const CardAction(
    this.label,
    this.value, {
    this.tone = CardActionTone.neutral,
  });
}

Future<T?> showActionCard<T>(
  BuildContext context, {
  Widget? leading,
  required String title,
  required String message,
  required List<CardAction<T>> actions,
  bool stacked = false,
}) => showBlurredCard<T>(
  context,
  (_) => _ActionCard<T>(
    leading: leading,
    title: title,
    message: message,
    actions: actions,
    stacked: stacked,
  ),
);

Future<void> showComplaintCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String sendLabel,
  required String closeLabel,
  required String emptyLabel,
  required Future<List<({int id, String title})>> Function() loadReasons,
  required Future<bool> Function(int reasonId) onSend,
}) {
  return showBlurredCard<void>(
    context,
    (_) => _ComplaintCard(
      title: title,
      subtitle: subtitle,
      sendLabel: sendLabel,
      closeLabel: closeLabel,
      emptyLabel: emptyLabel,
      loadReasons: loadReasons,
      onSend: onSend,
    ),
  );
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width > 420 ? 380 : double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmCard extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final String? checkboxLabel;
  final bool checkboxInitial;

  const _ConfirmCard({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.checkboxLabel,
    required this.checkboxInitial,
  });

  @override
  State<_ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends State<_ConfirmCard> {
  late bool _checked = widget.checkboxInitial;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checkboxLabel = widget.checkboxLabel;

    return _CardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (checkboxLabel != null) ...[
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _checked = !_checked),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checked,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        checkboxLabel,
                        style: TextStyle(color: cs.onSurface, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(ConfirmChoice.cancelled),
                child: Text(
                  widget.cancelLabel,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: widget.destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: cs.errorContainer,
                        foregroundColor: cs.onErrorContainer,
                      )
                    : null,
                onPressed: () => Navigator.of(
                  context,
                ).pop(ConfirmChoice(confirmed: true, checked: _checked)),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard<T> extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String message;
  final List<CardAction<T>> actions;
  final bool stacked;

  const _ActionCard({
    required this.leading,
    required this.title,
    required this.message,
    required this.actions,
    required this.stacked,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lead = leading;
    final centered = lead != null;
    final align = centered ? TextAlign.center : TextAlign.start;
    final buttons = [for (final action in actions) _button(context, action)];
    return _CardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (lead != null) ...[lead, const SizedBox(height: 14)],
          Text(
            title,
            textAlign: align,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: align,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          if (stacked)
            for (final (index, button) in buttons.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: button),
            ]
          else
            Row(
              children: [
                for (final (index, button) in buttons.indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(child: button),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, CardAction<T> action) {
    final cs = Theme.of(context).colorScheme;
    void pick() => Navigator.of(context).pop(action.value);
    const size = Size.fromHeight(48);
    return switch (action.tone) {
      CardActionTone.primary => FilledButton(
        style: FilledButton.styleFrom(minimumSize: size),
        onPressed: pick,
        child: Text(action.label),
      ),
      CardActionTone.neutral => FilledButton.tonal(
        style: FilledButton.styleFrom(minimumSize: size),
        onPressed: pick,
        child: Text(action.label),
      ),
      CardActionTone.destructive => FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: size,
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
        ),
        onPressed: pick,
        child: Text(action.label),
      ),
    };
  }
}

class _ComplaintCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String sendLabel;
  final String closeLabel;
  final String emptyLabel;
  final Future<List<({int id, String title})>> Function() loadReasons;
  final Future<bool> Function(int reasonId) onSend;

  const _ComplaintCard({
    required this.title,
    required this.subtitle,
    required this.sendLabel,
    required this.closeLabel,
    required this.emptyLabel,
    required this.loadReasons,
    required this.onSend,
  });

  @override
  State<_ComplaintCard> createState() => _ComplaintCardState();
}

class _ComplaintCardState extends State<_ComplaintCard> {
  List<({int id, String title})>? _reasons;
  int? _selected;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<({int id, String title})> loaded;
    try {
      loaded = await widget.loadReasons();
    } catch (_) {
      loaded = const [];
    }
    if (!mounted) return;
    setState(() => _reasons = loaded);
  }

  Future<void> _send() async {
    final reasonId = _selected;
    if (reasonId == null || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(reasonId);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reasons = _reasons;

    return _CardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: displayFontOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (reasons == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (reasons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  widget.emptyLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: SingleChildScrollView(
                child: RadioGroup<int>(
                  groupValue: _selected,
                  onChanged: (v) {
                    if (_sending) return;
                    setState(() => _selected = v);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final reason in reasons)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _sending
                              ? null
                              : () => setState(() => _selected = reason.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: reason.id,
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reason.title,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: Text(
                  widget.closeLabel,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.errorContainer,
                  foregroundColor: cs.onErrorContainer,
                ),
                onPressed: _selected == null || _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.sendLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
