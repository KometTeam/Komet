import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/app_motion.dart';
import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/screens/profile/custom_gradient_editor_screen.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'chat_wallpaper_view.dart';
import 'mesh_gradient_background.dart';
import 'theme_wallpaper.dart';
import 'custom_notification.dart';
import '../../core/config/app_fonts.dart';
import '../../core/security/app_lock.dart';

enum WallpaperPickType { inherit, none, theme, gallery, gradient }

class WallpaperPick {
  final WallpaperPickType type;
  final ChatWallpaperTheme? theme;
  final List<Color>? gradientColors;
  final bool gradientAnimated;
  final double gradientRotation;

  const WallpaperPick.inherit()
    : type = WallpaperPickType.inherit,
      theme = null,
      gradientColors = null,
      gradientAnimated = false,
      gradientRotation = 0;
  const WallpaperPick.none()
    : type = WallpaperPickType.none,
      theme = null,
      gradientColors = null,
      gradientAnimated = false,
      gradientRotation = 0;
  const WallpaperPick.gallery()
    : type = WallpaperPickType.gallery,
      theme = null,
      gradientColors = null,
      gradientAnimated = false,
      gradientRotation = 0;
  const WallpaperPick.theme(this.theme)
    : type = WallpaperPickType.theme,
      gradientColors = null,
      gradientAnimated = false,
      gradientRotation = 0;
  const WallpaperPick.gradient(
    this.gradientColors, {
    this.gradientAnimated = false,
    this.gradientRotation = 0,
  }) : type = WallpaperPickType.gradient,
       theme = null;
}

Future<Uint8List?> pickWallpaperBytes(BuildContext context) async {
  final result = await AppLock.instance.external(
    () => FilePicker.platform.pickFiles(type: FileType.image),
  );
  final path = result?.files.firstOrNull?.path;
  if (path == null) return null;
  if (await File(path).length() > kMaxWallpaperBytes) {
    if (context.mounted) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.chatWallpaperSheetImageTooLarge,
      );
    }
    return null;
  }
  final bytes = await compressWallpaperFile(path);
  if (bytes == null && context.mounted) {
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.contactLocalPhotoFailed,
    );
  }
  return bytes;
}

Future<WallpaperPick?> showChatWallpaperSheet(
  BuildContext context, {
  required ChatWallpaper? current,
  ChatWallpaper? inherited,
  bool perChat = false,
}) {
  return Navigator.of(context).push<WallpaperPick>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChatWallpaperGalleryScreen(
        current: current,
        inherited: inherited,
        perChat: perChat,
      ),
    ),
  );
}

sealed class _Choice {
  const _Choice();
}

final class _InheritChoice extends _Choice {
  const _InheritChoice();
}

final class _NoneChoice extends _Choice {
  const _NoneChoice();
}

final class _CurrentChoice extends _Choice {
  const _CurrentChoice();
}

final class _PresetChoice extends _Choice {
  const _PresetChoice(this.theme);

  final ChatWallpaperTheme theme;

  @override
  bool operator ==(Object other) =>
      other is _PresetChoice && other.theme.id == theme.id;

  @override
  int get hashCode => theme.id.hashCode;
}

class ChatWallpaperGalleryScreen extends StatefulWidget {
  final ChatWallpaper? current;
  final ChatWallpaper? inherited;
  final bool perChat;

  const ChatWallpaperGalleryScreen({
    super.key,
    required this.current,
    this.inherited,
    this.perChat = false,
  });

  @override
  State<ChatWallpaperGalleryScreen> createState() =>
      _ChatWallpaperGalleryScreenState();
}

class _ChatWallpaperGalleryScreenState
    extends State<ChatWallpaperGalleryScreen> {
  late final _Choice _initial = _choiceFor(widget.current);
  late _Choice _choice = _initial;

  _Choice _choiceFor(ChatWallpaper? wallpaper) {
    if (wallpaper == null) {
      return widget.perChat ? const _InheritChoice() : const _NoneChoice();
    }
    if (wallpaper.isNone) return const _NoneChoice();
    if (!wallpaper.isImage && !wallpaper.isGradient) {
      final theme = chatWallpaperThemeById(wallpaper.themeId);
      if (theme != null) return _PresetChoice(theme);
    }
    return const _CurrentChoice();
  }

  ChatWallpaper? get _ownCustom {
    final current = widget.current;
    if (current == null || current.isNone) return null;
    return _choiceFor(current) is _CurrentChoice ? current : null;
  }

  void _select(_Choice choice) {
    if (choice == _choice) return;
    Haptics.selection();
    setState(() => _choice = choice);
  }

  void _apply() {
    final pick = switch (_choice) {
      _InheritChoice() => const WallpaperPick.inherit(),
      _NoneChoice() => const WallpaperPick.none(),
      _PresetChoice(:final theme) => WallpaperPick.theme(theme),
      _CurrentChoice() => null,
    };
    Navigator.pop(context, pick);
  }

  Future<void> _openGradientEditor() async {
    final current = widget.current;
    final gradient = current != null && current.isGradient ? current : null;
    final result = await Navigator.of(context).push<CustomGradientResult>(
      MaterialPageRoute(
        builder: (_) => CustomGradientEditorScreen(
          initialColors: gradient?.gradientColors,
          initialAnimated: gradient?.gradientAnimated ?? false,
          initialRotation: gradient?.gradientRotation ?? 0,
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

  Widget _previewLayer() => switch (_choice) {
    _InheritChoice() => _layerFor(widget.inherited),
    _NoneChoice() => const SizedBox.shrink(),
    _CurrentChoice() => _layerFor(widget.current),
    _PresetChoice(:final theme) => ThemeWallpaper(theme: theme),
  };

  Widget _layerFor(ChatWallpaper? wallpaper) => wallpaper == null
      ? const SizedBox.shrink()
      : ChatWallpaperView(wallpaper: wallpaper);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
          l10n.chatWallpaperSheetTitle,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: WallpaperPreview(
                layer: AnimatedSwitcher(
                  duration: AppMotion.of(const Duration(milliseconds: 260)),
                  child: KeyedSubtree(
                    key: ValueKey(_choice),
                    child: _previewLayer(),
                  ),
                ),
                incoming: l10n.chatWallpaperSheetSampleIncoming,
                outgoing: l10n.chatWallpaperSheetSampleOutgoing,
              ),
            ),
          ),
          _panel(context),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final inherited = widget.inherited;
    final custom = _ownCustom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: _WallpaperTile.height,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (widget.perChat)
                    _WallpaperTile(
                      label: l10n.chatWallpaperSheetInherit,
                      selected: _choice is _InheritChoice,
                      onTap: () => _select(const _InheritChoice()),
                      child: inherited == null
                          ? const _TileIcon(Symbols.forum)
                          : _TileWallpaper(wallpaper: inherited),
                    ),
                  _WallpaperTile(
                    label: l10n.chatWallpaperSheetNone,
                    selected: _choice is _NoneChoice,
                    onTap: () => _select(const _NoneChoice()),
                    child: const _TileIcon(Symbols.hide_image),
                  ),
                  if (custom != null)
                    _WallpaperTile(
                      label: custom.isImage
                          ? l10n.chatWallpaperSheetYourPhoto
                          : l10n.chatWallpaperSheetCurrent,
                      selected: _choice is _CurrentChoice,
                      onTap: () => _select(const _CurrentChoice()),
                      child: _TileWallpaper(wallpaper: custom),
                    ),
                  for (final theme in kChatWallpaperThemes)
                    _WallpaperTile(
                      label: _presetName(l10n, theme),
                      selected: _choice == _PresetChoice(theme),
                      onTap: () => _select(_PresetChoice(theme)),
                      child: ThemeWallpaper(
                        theme: theme,
                        patternScale: _WallpaperTile.patternScale,
                      ),
                    ),
                  _WallpaperTile(
                    label: l10n.chatWallpaperSheetCustomGradient,
                    selected: false,
                    onTap: _openGradientEditor,
                    child: const _TileIcon(Symbols.gradient),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: wallpaperButtonStyle(context),
                      onPressed: () =>
                          Navigator.pop(context, const WallpaperPick.gallery()),
                      icon: const Icon(Symbols.add_photo_alternate, size: 20),
                      label: Text(l10n.chatWallpaperSheetFromGallery),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: wallpaperButtonStyle(context),
                      onPressed: _choice == _initial ? null : _apply,
                      child: Text(l10n.chatWallpaperSheetApply),
                    ),
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

ButtonStyle wallpaperButtonStyle(BuildContext context) =>
    FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: const StadiumBorder(),
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );

String _presetName(AppLocalizations l10n, ChatWallpaperTheme theme) =>
    switch (theme.id) {
      'komet' => l10n.chatWallpaperPresetKomet,
      'graphite' => l10n.chatWallpaperPresetGraphite,
      'ink' => l10n.chatWallpaperPresetInk,
      'pine' => l10n.chatWallpaperPresetPine,
      'plum' => l10n.chatWallpaperPresetPlum,
      'umber' => l10n.chatWallpaperPresetUmber,
      'paper' => l10n.chatWallpaperPresetPaper,
      'fog' => l10n.chatWallpaperPresetFog,
      'sage' => l10n.chatWallpaperPresetSage,
      'sand' => l10n.chatWallpaperPresetSand,
      'powder' => l10n.chatWallpaperPresetPowder,
      _ => theme.id,
    };

class WallpaperPreview extends StatelessWidget {
  const WallpaperPreview({
    super.key,
    required this.layer,
    required this.incoming,
    required this.outgoing,
  });

  final Widget layer;
  final String incoming;
  final String outgoing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: cs.surface),
          layer,
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SampleBubble(
                    text: incoming,
                    color: cs.surfaceContainerHighest,
                    textColor: cs.onSurface,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(height: 6),
                  _SampleBubble(
                    text: outgoing,
                    color: cs.primaryContainer,
                    textColor: cs.onPrimaryContainer,
                    alignment: Alignment.centerRight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleBubble extends StatelessWidget {
  const _SampleBubble({
    required this.text,
    required this.color,
    required this.textColor,
    required this.alignment,
  });

  final String text;
  final Color color;
  final Color textColor;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  static const double width = 76;
  static const double patternScale = 0.6;
  static const double frameHeight = 104;
  static const double height = frameHeight + 30;
  static const double _ringGap = 3;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = AppMotion.of(const Duration(milliseconds: 220));
    final outer = selected ? 26.0 : 18.0;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  height: frameHeight,
                  padding: const EdgeInsets.all(_ringGap),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(outer),
                    border: Border.all(
                      color: selected ? cs.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: outer - _ringGap),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, radius, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                            ),
                            child: child,
                          ),
                          AnimatedScale(
                            scale: selected ? 1 : 0,
                            duration: duration,
                            curve: Curves.easeOutBack,
                            alignment: Alignment.topRight,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Symbols.check,
                                      size: 14,
                                      weight: 600,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedDefaultTextStyle(
                  duration: duration,
                  style: DefaultTextStyle.of(context).style.merge(
                    TextStyle(
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      icon,
      size: 26,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _TileWallpaper extends StatelessWidget {
  const _TileWallpaper({required this.wallpaper});

  final ChatWallpaper wallpaper;

  @override
  Widget build(BuildContext context) {
    final path = wallpaper.imagePath;
    if (wallpaper.isImage && path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 240,
        errorBuilder: (_, _, _) => const _TileIcon(Symbols.image),
      );
    }
    final colors = wallpaper.gradientColors;
    if (wallpaper.isGradient && colors != null && colors.isNotEmpty) {
      return MeshGradientBackground(
        colors: colors,
        animate: false,
        rotation: wallpaper.gradientRotation,
      );
    }
    final theme = chatWallpaperThemeById(wallpaper.themeId);
    if (theme == null) return const _TileIcon(Symbols.wallpaper);
    return ThemeWallpaper(
      theme: theme,
      patternScale: _WallpaperTile.patternScale,
    );
  }
}
