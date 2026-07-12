import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_wallpaper_tint.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/chat_wallpaper_store.dart';
import '../../widgets/chat_wallpaper_sheet.dart';
import '../../widgets/chat_wallpaper_view.dart';
import '../../widgets/custom_notification.dart';
import '../chats/chat_wallpaper_preview_screen.dart';

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
      _wallpaper = ChatWallpaperStore.instance
          .get(_accountId, kGlobalWallpaperChatId);
      _ready = true;
    });
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _wallpaper = ChatWallpaperStore.instance
          .get(_accountId, kGlobalWallpaperChatId);
    });
  }

  Future<void> _openPicker() async {
    if (_accountId == 0) return;
    final pick = await showChatWallpaperSheet(context, current: _wallpaper);
    if (pick == null || !mounted) return;
    final store = ChatWallpaperStore.instance;
    switch (pick.type) {
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
    }
  }

  Future<void> _pickFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) showCustomNotification(context, 'Не удалось прочитать файл');
      return;
    }
    if (!mounted) return;
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
      showCustomNotification(context, 'Не удалось сохранить обои');
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
        title: const Text(
          'Фон чатов',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_wallpaper != null)
              ChatWallpaperView(wallpaper: _wallpaper!)
            else
              ColoredBox(color: cs.surfaceContainerHighest),
            _SampleBubbles(cs: cs),
          ],
        ),
      ),
    );
  }

  Widget _panel(ColorScheme cs) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Эти обои применяются ко всем чатам, где не выбран свой фон.',
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
                        'Подстраивать интерфейс под обои',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Акцентный цвет приложения возьмётся из фона',
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
          GestureDetector(
            onTap: _ready ? _openPicker : null,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Выбрать обои',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleBubbles extends StatelessWidget {
  final ColorScheme cs;

  const _SampleBubbles({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bubble(
              text: 'Единый фон для всех чатов',
              color: cs.surfaceContainerHighest.withValues(alpha: 0.94),
              textColor: cs.onSurface,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 8),
            _bubble(
              text: 'Красиво ✨',
              color: cs.primary,
              textColor: cs.onPrimary,
              alignment: Alignment.centerRight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble({
    required String text,
    required Color color,
    required Color textColor,
    required Alignment alignment,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ),
    );
  }
}
