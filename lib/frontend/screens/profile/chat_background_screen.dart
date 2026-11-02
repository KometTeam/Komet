import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_wallpaper_tint.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/chat_wallpaper_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/chat_wallpaper_sheet.dart';
import '../../widgets/chat_wallpaper_view.dart';
import '../../widgets/custom_notification.dart';
import '../chats/chat_wallpaper_preview_screen.dart';
import '../../../core/config/app_fonts.dart';

class ChatBackgroundScreen extends StatefulWidget {
  const ChatBackgroundScreen({super.key});

  @override
  State<ChatBackgroundScreen> createState() => _ChatBackgroundScreenState();
}

class _ChatBackgroundScreenState extends State<ChatBackgroundScreen> {
  int _accountId = 0;
  ChatWallpaper? _wallpaper;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ChatWallpaperStore.instance.load();
    final profile = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    setState(() {
      _accountId = profile?.id ?? 0;
      _wallpaper = ChatWallpaperStore.instance.effective(
        _accountId,
        kGlobalWallpaperChatId,
      );
      _ready = true;
    });
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _wallpaper = ChatWallpaperStore.instance.effective(
        _accountId,
        kGlobalWallpaperChatId,
      );
    });
  }

  Future<void> _openPicker() async {
    if (_accountId == 0) return;
    final pick = await showChatWallpaperSheet(context, current: _wallpaper);
    if (pick == null || !mounted) return;
    final store = ChatWallpaperStore.instance;
    switch (pick.type) {
      case WallpaperPickType.inherit:
      case WallpaperPickType.none:
        await store.clear(_accountId, kGlobalWallpaperChatId);
        _refresh();
        break;
      case WallpaperPickType.theme:
        final theme = pick.theme;
        if (theme == null) break;
        await store.setTheme(_accountId, kGlobalWallpaperChatId, theme.id);
        _refresh();
        break;
      case WallpaperPickType.gallery:
        await _pickFromGallery();
        break;
      case WallpaperPickType.gradient:
        final colors = pick.gradientColors;
        if (colors == null || colors.isEmpty) break;
        await store.setGradient(
          _accountId,
          kGlobalWallpaperChatId,
          colors,
          animated: pick.gradientAnimated,
          rotation: pick.gradientRotation,
        );
        _refresh();
        break;
    }
  }

  Future<void> _pickFromGallery() async {
    final bytes = await pickWallpaperBytes(context);
    if (bytes == null || !mounted) return;
    final settings = await Navigator.of(context).push<WallpaperImageSettings>(
      MaterialPageRoute(
        builder: (_) => ChatWallpaperPreviewScreen(imageBytes: bytes),
      ),
    );
    if (settings == null || !mounted) return;
    final wp = await ChatWallpaperStore.instance.setImage(
      _accountId,
      kGlobalWallpaperChatId,
      bytes,
      settings: settings,
    );
    if (!mounted) return;
    if (wp == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.chatBackgroundSaveFailed,
      );
      return;
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppLocalizations.of(context)!.chatBackgroundTitle,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _preview(cs)),
            _panel(cs),
          ],
        ),
      ),
    );
  }

  Widget _preview(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final wallpaper = _wallpaper;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: WallpaperPreview(
        layer: wallpaper == null
            ? const SizedBox.shrink()
            : ChatWallpaperView(wallpaper: wallpaper),
        incoming: l10n.chatBackgroundSampleIncoming,
        outgoing: l10n.chatBackgroundSampleOutgoing,
      ),
    );
  }

  Widget _panel(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.chatBackgroundDescription,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: AppWallpaperTint.current,
            builder: (context, enabled, _) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chatBackgroundTintTitle,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.chatBackgroundTintSubtitle,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: enabled,
                  onChanged: (v) => AppWallpaperTint.save(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: wallpaperButtonStyle(context),
            onPressed: _ready ? _openPicker : null,
            icon: const Icon(Symbols.wallpaper, size: 20),
            label: Text(l10n.chatBackgroundPick),
          ),
        ],
      ),
    );
  }
}
