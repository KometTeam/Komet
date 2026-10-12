import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/connection_status.dart';

import '../../../core/config/app_icon.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/settings_radio_tile.dart';
import '../../widgets/settings_card.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  @override
  void initState() {
    super.initState();
    AppIconConfig.load();
  }

  Future<void> _select(AppIcon icon) async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppIconConfig.isSupported) {
      showCustomNotification(context, l10n.appIconScreenUnsupported);
      return;
    }
    if (AppIconConfig.current.value == icon) return;
    Haptics.selection();
    try {
      await AppIconConfig.apply(icon);
      if (!mounted) return;
      showCustomNotification(context, l10n.appIconScreenChanged(icon.title));
    } catch (e) {
      if (!mounted) return;
      final reason = e is PlatformException ? (e.message ?? e.code) : '$e';
      showCustomNotification(context, l10n.appIconScreenChangeFailed(reason));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.appIconScreenTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            SettingsPanel(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appIconScreenAppearance,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppIconConfig.isSupported
                        ? l10n.appIconScreenHint
                        : l10n.appIconScreenOnlyMobile,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<AppIcon>(
                    valueListenable: AppIconConfig.current,
                    builder: (context, current, _) {
                      return Column(
                        children: [
                          for (final icon in AppIcon.values)
                            SettingsRadioTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  icon.previewAsset,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              leadingGap: 16,
                              label: icon.title,
                              labelStyle: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              selected: current == icon,
                              onTap: () => _select(icon),
                            ),
                        ],
                      );
                    },
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
