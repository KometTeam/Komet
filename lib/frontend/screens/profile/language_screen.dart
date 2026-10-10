import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_language.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/settings_card.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  void _select(BuildContext context, String code) {
    if (AppLanguage.current.value.languageCode == code) return;
    Haptics.selection();
    unawaited(KometApp.stateOf(context)?.applyLocale(Locale(code)));
  }

  Future<void> _setAppliesToServer(bool value) async {
    await AppLanguage.setAppliesToServer(value);
    await accountModule.refreshServerLanguage();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final languages = [
      ('ru', l10n.languageNameRu),
      ('en', l10n.languageNameEn),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.loginLanguage,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            ValueListenableBuilder<Locale>(
              valueListenable: AppLanguage.current,
              builder: (context, locale, _) => SettingsCard(
                children: [
                  for (final (code, name) in languages)
                    _LanguageTile(
                      label: name,
                      selected: locale.languageCode == code,
                      onTap: () => _select(context, code),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: AppLanguage.appliesToServer,
              builder: (context, value, _) => SettingsCard(
                children: [
                  SettingsToggleTile(
                    icon: Symbols.dns,
                    label: l10n.languageServerTitle,
                    subtitle: l10n.languageServerSubtitle,
                    value: value,
                    onChanged: (v) => unawaited(_setAppliesToServer(v)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: selected ? 1 : 0,
                child: Icon(Symbols.check, color: cs.primary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
