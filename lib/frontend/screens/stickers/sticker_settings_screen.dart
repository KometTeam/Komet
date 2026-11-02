import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../backend/modules/stickers.dart';
import '../../../main.dart' show stickersModule;
import '../../widgets/settings_card.dart';
import '../../widgets/swipe_route.dart';
import 'sticker_collection_screen.dart';
import 'sticker_screen_bar.dart';

class StickerSettingsScreen extends StatefulWidget {
  const StickerSettingsScreen({super.key, this.module});

  final StickersModule? module;

  @override
  State<StickerSettingsScreen> createState() => _StickerSettingsScreenState();
}

class _StickerSettingsScreenState extends State<StickerSettingsScreen> {
  StickersModule get _stickers => widget.module ?? stickersModule;

  @override
  void initState() {
    super.initState();
    unawaited(_stickers.ensureLoaded().then((_) {}, onError: (_) {}));
  }

  void _open(StickerCollection collection) {
    pushSwipeable(
      context,
      (_) => StickerCollectionScreen(
        collection: collection,
        module: widget.module,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: stickerScreenBar(context, title: Text(l10n.stickerSettingsTitle)),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SettingsCard(
            children: [
              ValueListenableBuilder<List<int>>(
                valueListenable: _stickers.recentStickerIds,
                builder: (context, ids, _) => SettingsNavTile(
                  key: const ValueKey('sticker-settings-recent'),
                  icon: Symbols.history,
                  label: l10n.stickerSettingsRecent,
                  subtitle: l10n.stickerPackSheetStickerCount(ids.length),
                  onTap: () => _open(StickerCollection.recent),
                ),
              ),
              ValueListenableBuilder<List<int>>(
                valueListenable: _stickers.favoriteStickerIds,
                builder: (context, ids, _) => SettingsNavTile(
                  key: const ValueKey('sticker-settings-favorites'),
                  icon: Symbols.bookmark,
                  label: l10n.stickerSettingsFavorites,
                  subtitle: l10n.stickerPackSheetStickerCount(ids.length),
                  onTap: () => _open(StickerCollection.favorites),
                  isLast: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
