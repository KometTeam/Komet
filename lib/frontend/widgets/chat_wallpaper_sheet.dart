import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';

enum WallpaperPickType { none, theme, gallery }

class WallpaperPick {
  final WallpaperPickType type;
  final ChatWallpaperTheme? theme;

  const WallpaperPick.none()
      : type = WallpaperPickType.none,
        theme = null;
  const WallpaperPick.gallery()
      : type = WallpaperPickType.gallery,
        theme = null;
  const WallpaperPick.theme(this.theme) : type = WallpaperPickType.theme;
}

Future<WallpaperPick?> showChatWallpaperSheet(
  BuildContext context, {
  required ChatWallpaper? current,
}) {
  return Navigator.of(context).push<WallpaperPick>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChatWallpaperGalleryScreen(current: current),
    ),
  );
}

class ChatWallpaperGalleryScreen extends StatefulWidget {
  final ChatWallpaper? current;

  const ChatWallpaperGalleryScreen({super.key, required this.current});

  @override
  State<ChatWallpaperGalleryScreen> createState() =>
      _ChatWallpaperGalleryScreenState();
}

class _ChatWallpaperGalleryScreenState
    extends State<ChatWallpaperGalleryScreen> {
  ChatWallpaperTheme? _selected;
  bool _isImage = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _isImage = current?.isImage ?? false;
    _selected = current == null || current.isImage
        ? null
        : chatWallpaperThemeById(current.themeId);
  }

  bool get _changed {
    if (_isImage) return _selected != null;
    return _selected?.id != chatWallpaperThemeById(widget.current?.themeId)?.id;
  }

  void _apply() {
    if (_selected == null) {
      Navigator.pop(context, const WallpaperPick.none());
    } else {
      Navigator.pop(context, WallpaperPick.theme(_selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Обои',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _preview(cs)),
          _panel(cs),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme cs) {
    final theme = _selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (theme != null)
              theme.buildBackground()
            else
              ColoredBox(color: cs.surfaceContainerHighest),
            const IgnorePointer(child: _PreviewScrim()),
            _SampleBubbles(theme: theme),
          ],
        ),
      ),
    );
  }

  Widget _panel(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _NoneTile(
                    selected: _selected == null && !_isImage,
                    onTap: () => setState(() {
                      _selected = null;
                      _isImage = false;
                    }),
                  ),
                  for (final theme in kChatWallpaperThemes)
                    _ThemeTile(
                      theme: theme,
                      selected: _selected?.id == theme.id,
                      onTap: () => setState(() {
                        _selected = theme;
                        _isImage = false;
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _GalleryButton(
                      onTap: () =>
                          Navigator.pop(context, const WallpaperPick.gallery()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _ApplyButton(enabled: _changed, onTap: _apply)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewScrim extends StatelessWidget {
  const _PreviewScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14000000), Color(0x00000000), Color(0x1F000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _SampleBubbles extends StatelessWidget {
  final ChatWallpaperTheme? theme;

  const _SampleBubbles({required this.theme});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bubble(
              text: 'Как насчёт новых обоев для этого чата?',
              color: cs.surfaceContainerHighest.withValues(alpha: 0.94),
              textColor: cs.onSurface,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 8),
            _bubble(
              text: 'Выглядит отлично 🔥',
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

class _TileFrame extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String label;

  const _TileFrame({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 116,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? cs.primary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      if (selected)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Symbols.check,
                              size: 16,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoneTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _NoneTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      label: 'Без обоев',
      child: ColoredBox(
        color: cs.surfaceContainerHighest,
        child: const Center(
          child: Icon(Symbols.block, color: Color(0xFFFF3B30), size: 34),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ChatWallpaperTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      label: theme.name,
      child: theme.buildPreview(),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GalleryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.image, color: cs.onSurface, size: 22),
            const SizedBox(width: 8),
            Text(
              'Из галереи',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ApplyButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              'Применить',
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
    );
  }
}
