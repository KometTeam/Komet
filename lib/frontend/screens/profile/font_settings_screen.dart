import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/config/app_shape.dart';
import '../../../core/config/custom_font_service.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_card.dart';
import '../../../core/security/app_lock.dart';

class FontSettingsScreen extends StatefulWidget {
  const FontSettingsScreen({super.key});

  @override
  State<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends State<FontSettingsScreen> {
  List<String> _custom = const [];
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _reloadCustom();
  }

  Future<void> _reloadCustom() async {
    final list = await CustomFontService.families();
    if (mounted) setState(() => _custom = list);
  }

  void _selectFont(String id) {
    final app = KometApp.stateOf(context);
    if (app == null || app.fontId == id) return;
    Haptics.selection();
    app.applyAppFont(id);
  }

  Future<void> _addFont(String raw) async {
    final parsed = AppFonts.familyFromInput(raw);
    if (parsed == null) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.fontSettingsInvalidInput,
        );
      }
      return;
    }
    setState(() => _adding = true);
    String? family;
    try {
      family = await CustomFontService.addFamily(parsed);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
    if (!mounted) return;
    if (family == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.fontSettingsFontNotFound(parsed),
      );
      return;
    }
    await _applyAdded(family);
  }

  Future<void> _applyAdded(String family) async {
    await _reloadCustom();
    if (!mounted) return;
    KometApp.stateOf(context)?.applyAppFont(AppFonts.customId(family));
    Haptics.success();
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.fontSettingsFontAdded(family),
    );
  }

  Future<void> _addFontFromFile() async {
    final result = await AppLock.instance.external(
      () => FilePicker.platform.pickFiles(type: FileType.any, withData: true),
    );
    final picked = result?.files.single;
    if (picked == null || !mounted) return;
    setState(() => _adding = true);
    String? family;
    try {
      final path = picked.path;
      final Uint8List? bytes =
          picked.bytes ??
          (path == null ? null : await File(path).readAsBytes());
      if (bytes != null) {
        family = await CustomFontService.addFromFile(bytes, picked.name);
      }
    } catch (_) {
      family = null;
    } finally {
      if (mounted) setState(() => _adding = false);
    }
    if (!mounted) return;
    if (family == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.fontSettingsNotAFont,
      );
      return;
    }
    await _applyAdded(family);
  }

  Future<void> _removeFont(String family) async {
    await CustomFontService.removeFamily(family);
    await _reloadCustom();
    if (!mounted) return;
    final app = KometApp.stateOf(context);
    if (app != null && app.fontId == AppFonts.customId(family)) {
      app.applyAppFont(AppFonts.fallback.id);
    }
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.fontSettingsFontRemoved(family),
    );
  }

  Future<void> _showAddFontDialog() async {
    final choice = await showDialog<_AddFontChoice>(
      context: context,
      builder: (_) => const _AddFontDialog(),
    );
    switch (choice) {
      case _AddFontByName(:final input):
        await _addFont(input);
      case _AddFontFromFile():
        await _addFontFromFile();
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final app = KometApp.stateOf(context);
    final currentId = app?.fontId ?? AppFonts.fallback.id;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.fontSettingsTitle,
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
            _SectionLabel(
              icon: Symbols.text_fields,
              text: l10n.fontSettingsSectionFont,
            ),
            const SizedBox(height: 14),
            for (final font in AppFonts.builtIn) ...[
              _FontOption(
                font: font,
                selected: font.id == currentId,
                onTap: () => _selectFont(font.id),
              ),
              const SizedBox(height: 8),
            ],
            for (final family in _custom) ...[
              _FontOption(
                font: AppFonts.resolve(AppFonts.customId(family)),
                selected: AppFonts.customId(family) == currentId,
                onTap: () => _selectFont(AppFonts.customId(family)),
                onDelete: () => _removeFont(family),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: ButtonM3E(
                onPressed: _adding ? null : _showAddFontDialog,
                style: ButtonM3EStyle.outlined,
                size: ButtonM3ESize.md,
                icon: Icon(_adding ? Symbols.hourglass_top : Symbols.add),
                label: Text(
                  _adding
                      ? l10n.fontSettingsLoading
                      : l10n.fontSettingsAddFontTitle,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _SectionLabel(
              icon: Symbols.format_size,
              text: l10n.fontSettingsSectionFontSize,
            ),
            const SizedBox(height: 6),
            if (app != null)
              ValueListenableBuilder<double>(
                valueListenable: app.fontScale,
                builder: (context, scale, _) => _FontSizeControl(
                  scale: scale,
                  onChanged: (v) => app.applyFontScale(v, persist: false),
                  onChangeEnd: (v) {
                    Haptics.selection();
                    app.applyFontScale(v);
                  },
                  onReset: () {
                    Haptics.selection();
                    app.applyFontScale(AppFonts.defaultScale);
                  },
                ),
              ),
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
    return SettingsPanel(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.fontSettingsPreviewLabel,
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
              style: AppFonts.sample(
                fontId,
                fontSize: 15,
              ).copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
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
  final VoidCallback? onDelete;

  const _FontOption({
    required this.font,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final button = ButtonM3E(
      onPressed: onTap,
      style: selected ? ButtonM3EStyle.filled : ButtonM3EStyle.tonal,
      size: ButtonM3ESize.md,
      shape: ButtonM3EShape.round,
      selected: selected,
      icon: Icon(
        selected
            ? Symbols.check_circle
            : (font.isSystem ? Symbols.smartphone : Symbols.font_download),
        fill: selected ? 1 : 0,
      ),
      label: Text(font.label, style: AppFonts.sample(font.id, fontSize: 16)),
    );

    if (onDelete == null) {
      return SizedBox(width: double.infinity, child: button);
    }

    return Row(
      children: [
        Expanded(child: button),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onDelete,
          tooltip: AppLocalizations.of(context)!.msgActionsDelete,
          icon: Icon(Symbols.delete, color: cs.onSurfaceVariant, weight: 500),
        ),
      ],
    );
  }
}

class _FontSizeControl extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onReset;

  const _FontSizeControl({
    required this.scale,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDefault = (scale - AppFonts.defaultScale).abs() < 0.001;
    return SettingsPanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'А',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SliderM3E(
                    value: AppFonts.clampScale(scale),
                    min: AppFonts.minScale,
                    max: AppFonts.maxScale,
                    divisions: ((AppFonts.maxScale - AppFonts.minScale) / 0.05)
                        .round(),
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
              ),
              Text(
                'А',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${(scale * 100).round()}%',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              ButtonM3E(
                onPressed: isDefault ? null : onReset,
                enabled: !isDefault,
                style: ButtonM3EStyle.text,
                size: ButtonM3ESize.sm,
                label: Text(AppLocalizations.of(context)!.fontSettingsReset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

sealed class _AddFontChoice {
  const _AddFontChoice();
}

class _AddFontByName extends _AddFontChoice {
  final String input;

  const _AddFontByName(this.input);
}

class _AddFontFromFile extends _AddFontChoice {
  const _AddFontFromFile();
}

class _AddFontDialog extends StatefulWidget {
  const _AddFontDialog();

  @override
  State<_AddFontDialog> createState() => _AddFontDialogState();
}

class _AddFontDialogState extends State<_AddFontDialog> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text.trim();
    Navigator.pop(context, text.isEmpty ? null : _AddFontByName(text));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      shape: AppShape.dialogBorder,
      title: Text(
        l10n.fontSettingsAddFontTitle,
        style: TextStyle(
          fontFamily: displayFontOf(context),
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: cs.onSurface,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fontSettingsAddFontDescription,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _input,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'fonts.google.com/specimen/Roboto',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, const _AddFontFromFile()),
              icon: const Icon(Symbols.upload_file, size: 20),
              label: Text(l10n.fontSettingsPickFile),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.fontSettingsPickFileHint,
            style: TextStyle(color: cs.outline, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.fontSettingsCancel,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.fontSettingsAddFontConfirm),
        ),
      ],
    );
  }
}
