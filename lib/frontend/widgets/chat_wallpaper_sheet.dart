import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/frontend/widgets/sheet_helpers.dart';

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
  return showModalBottomSheet<WallpaperPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _ChatWallpaperSheet(current: current),
  );
}

class _ChatWallpaperSheet extends StatelessWidget {
  final ChatWallpaper? current;

  const _ChatWallpaperSheet({required this.current});

  bool get _isNoneSelected => current == null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetGrabber(),
            _header(context, cs),
            const SizedBox(height: 12),
            _themeRow(context, cs),
            const SizedBox(height: 20),
            _galleryButton(context, cs),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Symbols.close, color: cs.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Выбрать тему',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeRow(BuildContext context, ColorScheme cs) {
    return SizedBox(
      height: 172,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _NoneTile(
            selected: _isNoneSelected,
            onTap: () => Navigator.pop(context, const WallpaperPick.none()),
          ),
          for (final theme in kChatWallpaperThemes)
            _ThemeTile(
              theme: theme,
              selected: current?.themeId == theme.id,
              onTap: () =>
                  Navigator.pop(context, WallpaperPick.theme(theme)),
            ),
        ],
      ),
    );
  }

  Widget _galleryButton(BuildContext context, ColorScheme cs) {
    return TextButton(
      onPressed: () => Navigator.pop(context, const WallpaperPick.gallery()),
      child: Text(
        'Выбрать обои из галереи',
        style: TextStyle(
          color: cs.primary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}

class _TileFrame extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _TileFrame({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 112,
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
            child: child,
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
      child: ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Без\nтемы',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 14),
            const Icon(Symbols.close, color: Color(0xFFFF3B30), size: 40),
          ],
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
      child: theme.buildPreview(),
    );
  }
}
