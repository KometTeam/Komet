import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart';

enum EditContactAction { updated, removed }

class EditContactResult {
  final EditContactAction action;
  final String firstName;
  final String lastName;

  const EditContactResult(
    this.action, {
    this.firstName = '',
    this.lastName = '',
  });
}

Future<EditContactResult?> showEditContactSheet(
  BuildContext context, {
  required int contactId,
  required String avatarUrl,
  required String customFirst,
  required String customLast,
  required String onemeFirst,
  required String onemeLast,
}) {
  return showGeneralDialog<EditContactResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (_, anim, _, _) {
      final t = Curves.easeOutCubic.transform(anim.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
        child: Opacity(
          opacity: anim.value,
          child: Transform.scale(
            scale: 0.94 + 0.06 * t,
            child: _EditContactCard(
              contactId: contactId,
              avatarUrl: avatarUrl,
              customFirst: customFirst,
              customLast: customLast,
              onemeFirst: onemeFirst,
              onemeLast: onemeLast,
            ),
          ),
        ),
      );
    },
  );
}

class _EditContactCard extends StatefulWidget {
  final int contactId;
  final String avatarUrl;
  final String customFirst;
  final String customLast;
  final String onemeFirst;
  final String onemeLast;

  const _EditContactCard({
    required this.contactId,
    required this.avatarUrl,
    required this.customFirst,
    required this.customLast,
    required this.onemeFirst,
    required this.onemeLast,
  });

  @override
  State<_EditContactCard> createState() => _EditContactCardState();
}

class _EditContactCardState extends State<_EditContactCard> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.customFirst);
    _lastCtrl = TextEditingController(text: widget.customLast);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  bool get _busy => _saving || _deleting;

  bool get _dirty =>
      _firstCtrl.text.trim() != widget.customFirst.trim() ||
      _lastCtrl.text.trim() != widget.customLast.trim();

  Future<void> _save() async {
    if (!_dirty || _busy) return;
    setState(() => _saving = true);

    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final sendFirst = first.isEmpty ? widget.onemeFirst : first;
    final sendLast = last.isEmpty ? widget.onemeLast : last;

    final updated = await ContactsModule.updateContact(
      api,
      contactId: widget.contactId,
      firstName: sendFirst,
      lastName: sendLast,
    );
    if (!mounted) return;

    if (updated == null) {
      setState(() => _saving = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.editContactError,
      );
      return;
    }

    Navigator.of(context).pop(
      EditContactResult(
        EditContactAction.updated,
        firstName: updated.firstName,
        lastName: updated.lastName ?? '',
      ),
    );
  }

  Future<void> _delete() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editContactDeleteConfirmTitle),
        content: Text(l10n.editContactDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.editContactDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.editContactDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final ok = await ContactsModule.removeContact(api, widget.contactId);
    if (!mounted) return;

    if (!ok) {
      setState(() => _deleting = false);
      showCustomNotification(context, l10n.editContactError);
      return;
    }

    Navigator.of(context).pop(
      const EditContactResult(EditContactAction.removed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final avatarName = widget.customFirst.isNotEmpty
        ? widget.customFirst
        : widget.onemeFirst;

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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: KometAvatar(
                      name: avatarName,
                      size: 88,
                      imageUrl: widget.avatarUrl.isEmpty
                          ? null
                          : widget.avatarUrl,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _inputRow(
                    cs,
                    controller: _firstCtrl,
                    hint: l10n.editContactFirstName,
                  ),
                  _divider(cs),
                  _inputRow(
                    cs,
                    controller: _lastCtrl,
                    hint: l10n.editContactLastName,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _dirty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _saveButton(cs, l10n),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 4),
                  _deleteButton(cs, l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputRow(
    ColorScheme cs, {
    required TextEditingController controller,
    required String hint,
  }) {
    final hasText = controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLength: 60,
              enabled: !_busy,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: cs.onSurface, fontSize: 16),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: hint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
              ),
            ),
          ),
          if (hasText)
            InkWell(
              onTap: _busy
                  ? null
                  : () => setState(() => controller.clear()),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _saveButton(ColorScheme cs, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _save,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                l10n.editContactSave,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _deleteButton(ColorScheme cs, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _busy ? null : _delete,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: cs.error,
        ),
        child: _deleting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.error),
              )
            : Text(
                l10n.editContactDelete,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) =>
      Divider(height: 1, thickness: 0.5, color: cs.outlineVariant);
}
