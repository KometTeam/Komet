import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/config/app_colors.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/screens/profile/custom_gradient_editor_screen.dart';
import 'chat_wallpaper_view.dart';
import 'mesh_gradient_background.dart';
import 'custom_notification.dart';
import '../../core/config/app_fonts.dart';

enum WallpaperPickType { none, theme, gallery, gradient }

class WallpaperPick {
  final WallpaperPickType type;
  final ChatWallpaperTheme? theme;
  final List<Color>? gradientColors;
  final bool gradientAnimated;
  final double gradientRotation;

  const WallpaperPick.none()
    : type = WallpaperPickType.none,
      theme = null,
      gradientColors = null,
      gradientAnimated = true,
      gradientRotation = 0;
  const WallpaperPick.gallery()
    : type = WallpaperPickType.gallery,
      theme = null,
      gradientColors = null,
      gradientAnimated = true,
      gradientRotation = 0;
  const WallpaperPick.theme(this.theme)
    : type = WallpaperPickType.theme,
      gradientColors = null,
      gradientAnimated = true,
      gradientRotation = 0;
  const WallpaperPick.gradient(
    this.gradientColors, {
    this.gradientAnimated = false,
    this.gradientRotation = 0,
  }) : type = WallpaperPickType.gradient,
       theme = null;
}

// #***! путь, а не байты: withData грузит файл в java-кучу и валит процесс на OOM
Future<Uint8List?> pickWallpaperBytes(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image);
  final path = result?.files.firstOrNull?.path;
  if (path == null) return null;
  if (await File(path).length() > kMaxWallpaperBytes) {
    if (context.mounted) {
      showCustomNotification(context, 'Картинка слишком большая (макс 16 МБ)');
    }
    return null;
  }
  final bytes = await compressWallpaperFile(path);
  if (bytes == null && context.mounted) {
    showCustomNotification(context, 'Не удалось обработать изображение');
  }
  return bytes;
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
  bool _keepsImage = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _keepsImage = current?.isImage ?? false;
    _selected = current == null || current.isImage
        ? null
        : chatWallpaperThemeById(current.themeId);
  }

  bool get _changed {
    if (_keepsImage) return false;
    if (widget.current?.isImage == true) return true;
    return _selected?.id != chatWallpaperThemeById(widget.current?.themeId)?.id;
  }

  void _apply() {
    if (_selected == null) {
      Navigator.pop(context, const WallpaperPick.none());
    } else {
      Navigator.pop(context, WallpaperPick.theme(_selected));
    }
  }

  Future<void> _openGradientEditor() async {
    final current = widget.current;
    final result = await Navigator.of(context).push<CustomGradientResult>(
      MaterialPageRoute(
        builder: (_) => CustomGradientEditorScreen(
          initialColors: current?.isGradient == true
              ? current!.gradientColors
              : null,
          initialAnimated: current?.isGradient == true
              ? current!.gradientAnimated
              : false,
          initialRotation: current?.isGradient == true
              ? current!.gradientRotation
              : 0,
        ),
      ),
    );
    if (result == null || !mounted) return;
    Navigator.pop(
      context,
      WallpaperPick.gradient(
        result.colors,
        gradientAnimated: result.animated,
        gradientRotation: result.rotation,
      ),
    );
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
        title: Text(
          'Обои',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
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
    final image = _keepsImage ? widget.current : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (theme != null)
              theme.buildBackground()
            else if (image != null)
              ChatWallpaperView(wallpaper: image)
            else
              ColoredBox(color: cs.surfaceContainerHighest),
            const IgnorePointer(child: _PreviewScrim()),
            _SampleBubbles(theme: theme),
          ],
        ),
      ),
    );
  }

  Widget? _currentImageTile() {
    final current = widget.current;
    if (current == null || !current.isImage) return null;
    return _CurrentImageTile(
      wallpaper: current,
      selected: _keepsImage,
      onTap: () => setState(() {
        _keepsImage = true;
        _selected = null;
      }),
    );
  }

  Widget _panel(ColorScheme cs) {
    final currentImage = _currentImageTile();
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
                  ?currentImage,
                  _NoneTile(
                    selected: _selected == null && !_keepsImage,
                    onTap: () => setState(() {
                      _selected = null;
                      _keepsImage = false;
                    }),
                  ),
                  _CustomGradientTile(
                    current: widget.current?.isGradient == true
                        ? widget.current
                        : null,
                    onTap: _openGradientEditor,
                  ),
                  for (final theme in kChatWallpaperThemes)
                    _ThemeTile(
                      theme: theme,
                      selected: _selected?.id == theme.id,
                      onTap: () => setState(() {
                        _selected = theme;
                        _keepsImage = false;
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
                  Expanded(
                    child: _ApplyButton(enabled: _changed, onTap: _apply),
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
              context,
              text: 'Как насчёт новых обоев для этого чата?',
              color: cs.surfaceContainerHighest.withValues(alpha: 0.94),
              textColor: cs.onSurface,
              alignment: Alignment.centerLeft,
            ),
            const SizedBox(height: 8),
            _bubble(
              context,
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

  Widget _bubble(
    BuildContext context, {
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
              fontFamily: displayFontOf(context),
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
                  fontFamily: displayFontOf(context),
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
          child: Icon(Symbols.block, color: kDangerRed, size: 34),
        ),
      ),
    );
  }
}

class _CurrentImageTile extends StatelessWidget {
  final ChatWallpaper wallpaper;
  final bool selected;
  final VoidCallback onTap;

  const _CurrentImageTile({
    required this.wallpaper,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = wallpaper.imagePath;
    return _TileFrame(
      selected: selected,
      onTap: onTap,
      label: 'Ваше фото',
      child: path == null
          ? ColoredBox(color: cs.surfaceContainerHighest)
          : Image.file(File(path), fit: BoxFit.cover),
    );
  }
}

class _CustomGradientTile extends StatelessWidget {
  final ChatWallpaper? current;
  final VoidCallback onTap;

  const _CustomGradientTile({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = current?.gradientColors;
    return _TileFrame(
      selected: false,
      onTap: onTap,
      label: 'Своя',
      child: colors != null && colors.isNotEmpty
          ? MeshGradientBackground(
              colors: colors,
              animate: false,
              rotation: current?.gradientRotation ?? 0,
            )
          : ColoredBox(
              color: cs.surfaceContainerHighest,
              child: Center(
                child: Icon(Symbols.palette, color: cs.onSurface, size: 30),
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
                fontFamily: displayFontOf(context),
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
                fontFamily: displayFontOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
