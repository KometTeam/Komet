import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/core/config/app_nav_pill_style.dart';
import 'package:komet/core/config/app_visual_style.dart';
import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/widgets/attachment/contact_picker_page.dart';
import 'package:komet/frontend/widgets/attachment/media_preview_screen.dart';
import 'package:komet/frontend/widgets/attachment/photo_editor.dart';
import 'package:komet/frontend/widgets/attachment/photo_hero.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/sheet_helpers.dart';
import 'package:komet/frontend/widgets/sliding_pill_nav.dart';
import 'package:komet/l10n/app_localizations.dart';

import '../small_spinner.dart';

const int _navItemCount = 5;

List<PillNavItem> _buildNavItems(AppLocalizations l10n) => [
  PillNavItem(icon: Symbols.image, label: l10n.attachSheetGallery),
  PillNavItem(icon: Symbols.description, label: l10n.scheduledAttachFile),
  PillNavItem(icon: Symbols.location_on, label: l10n.scheduledAttachLocation),
  PillNavItem(icon: Symbols.bar_chart, label: l10n.attachSheetPoll),
  PillNavItem(icon: Symbols.person, label: l10n.attachSheetContact),
];

Future<void> showAttachmentSheet(
  BuildContext context, {
  String? title,
  void Function(List<PickedPhoto> photos, String caption)? onSend,
  VoidCallback? onPickFile,
  VoidCallback? onShareLocation,
  VoidCallback? onCreatePoll,
  ValueChanged<CachedContact>? onSendContact,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    requestFocus: false,
    backgroundColor: Colors.transparent,
    barrierColor: AppFrost.scrim(),
    builder: (_) => AttachmentSheet(
      title: title,
      onSend: onSend,
      onPickFile: onPickFile,
      onShareLocation: onShareLocation,
      onCreatePoll: onCreatePoll,
      onSendContact: onSendContact,
    ),
  );
}

class AttachmentSheet extends StatefulWidget {
  final String? title;
  final void Function(List<PickedPhoto> photos, String caption)? onSend;
  final VoidCallback? onPickFile;
  final VoidCallback? onShareLocation;
  final VoidCallback? onCreatePoll;
  final ValueChanged<CachedContact>? onSendContact;

  const AttachmentSheet({
    super.key,
    this.title,
    this.onSend,
    this.onPickFile,
    this.onShareLocation,
    this.onCreatePoll,
    this.onSendContact,
  });

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet> {
  static List<GalleryItem>? _cachedItems;
  static GalleryPermission _cachedPermission = GalleryPermission.granted;

  final GallerySource _source = GallerySource.create();
  final ValueNotifier<Set<String>> _selected = ValueNotifier(<String>{});
  final Map<String, GlobalKey<_ThumbnailState>> _thumbKeys = {};
  final Map<String, PhotoEditState> _edits = {};
  final Set<String> _tempFiles = {};
  final Set<String> _sentFiles = {};
  final TextEditingController _captionCtrl = TextEditingController();
  final PageController _pageController = PageController();

  bool _navDragging = false;
  double _navDragBasePageT = 0;
  double _navDragAccumDx = 0;

  bool _loading = true;
  GalleryPermission _permission = GalleryPermission.granted;
  List<GalleryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    final cached = _cachedItems;
    if (cached != null) {
      _items = cached;
      _permission = _cachedPermission;
      _loading = false;
      _loadGallery(silent: true);
    } else {
      _loadGallery();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _selected.dispose();
    _captionCtrl.dispose();
    for (final path in _tempFiles) {
      if (_sentFiles.contains(path)) continue;
      File(path).delete().then((_) {}, onError: (_) {});
    }
    super.dispose();
  }

  Future<void> _loadGallery({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final permission = await _source.ensurePermission();
    if (!mounted) return;
    if (permission == GalleryPermission.denied) {
      _cachedItems = null;
      setState(() {
        _permission = permission;
        _items = const [];
        _loading = false;
      });
      return;
    }
    final items = await _source.load(limit: 120);
    if (!mounted) return;
    _cachedItems = items;
    _cachedPermission = permission;
    setState(() {
      _permission = permission;
      _items = items;
      _loading = false;
    });
  }

  void _toggleSelection(GalleryItem item) {
    final next = Set<String>.from(_selected.value);
    if (!next.remove(item.id)) next.add(item.id);
    _selected.value = next;
  }

  GlobalKey<_ThumbnailState> _thumbKey(String id) =>
      _thumbKeys.putIfAbsent(id, () => GlobalKey<_ThumbnailState>());

  void _openPreview(GalleryItem item) {
    if (item.isVideo) {
      _toggleSelection(item);
      return;
    }
    final thumbKey = _thumbKey(item.id);
    final hero = PhotoHeroController(
      origin: () => photoHeroRect(thumbKey),
      image: thumbKey.currentState?.provider,
    );
    Navigator.of(context).push(
      PhotoHeroRoute<void>(
        hero: hero,
        builder: (_) => MediaPreviewScreen(
          item: item,
          hero: hero,
          title: widget.title,
          selectedIds: _selected,
          onToggleSelection: () => _toggleSelection(item),
          onSend: () => _sendSelection(fallback: item),
          editState: _edits[item.id],
          onEditChanged: (state) {
            if (mounted) setState(() => _edits[item.id] = state);
          },
          initialCaption: _captionCtrl.text,
          onCaptionChanged: (text) => _captionCtrl.text = text,
          tempFiles: _tempFiles,
        ),
      ),
    );
  }

  void _onSectionTap(int index) {
    _pageController.animateToPage(
      index,
      duration: _navAnim,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _onCameraTap() async {
    final l10n = AppLocalizations.of(context)!;
    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(source: ImageSource.camera);
    } catch (_) {
      if (mounted) showCustomNotification(context, l10n.attachSheetCameraError);
      return;
    }
    if (shot == null || !mounted) return;
    _openPreview(GalleryItem.fromFile(File(shot.path)));
  }

  void _sendSelection({GalleryItem? fallback}) {
    final ids = _selected.value;
    var chosen = _items.where((it) => ids.contains(it.id)).toList();
    if (chosen.isEmpty && fallback != null) chosen = [fallback];
    if (chosen.isEmpty) return;
    final picked = chosen
        .map((it) => PickedPhoto(item: it, editedFile: _edits[it.id]?.working))
        .toList();
    final callback = widget.onSend;
    if (callback != null) {
      for (final photo in picked) {
        final path = photo.editedFile?.path;
        if (path != null) _sentFiles.add(path);
      }
    }
    final caption = _captionCtrl.text.trim();
    Navigator.of(context).pop();
    callback?.call(picked, caption);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      snap: true,
      snapSizes: const [0.62, 0.94],
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        final barReserve = _barHeight + bottomInset;
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SheetGrabber(),
              Expanded(
                child: Stack(
                  children: [
                    _buildPages(scrollController, cs, barReserve),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomBar(),
                    ),
                    Positioned(
                      right: 16,
                      bottom:
                          barReserve +
                          8 +
                          MediaQuery.viewInsetsOf(context).bottom,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _selected,
                          _pageController,
                        ]),
                        builder: (context, _) {
                          final count = _selected.value.length;
                          final galleryT = (1 - _currentPageT()).clamp(
                            0.0,
                            1.0,
                          );
                          if (count == 0 || galleryT == 0) {
                            return const SizedBox.shrink();
                          }
                          return Opacity(
                            opacity: galleryT,
                            child: IgnorePointer(
                              ignoring: galleryT < 0.5,
                              child: _buildSendButton(cs),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const double _pillMargin = 10;
  static const double _barHeight = SlidingPillNav.height + _pillMargin;
  static const Duration _navAnim = Duration(milliseconds: 300);

  Color _composerColor(ColorScheme cs) => Color.alphaBlend(
    cs.surfaceContainerHighest.withValues(alpha: 0.92),
    cs.surface,
  );

  Color _composerBorderColor(ColorScheme cs) =>
      cs.outlineVariant.withValues(alpha: 0.5);

  Widget _buildPages(
    ScrollController scrollController,
    ColorScheme cs,
    double bottomReserve,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return PageView(
      controller: _pageController,
      children: [
        _KeepAlivePage(
          child: _buildGalleryPage(scrollController, cs, bottomReserve),
        ),
        _buildActionPage(
          cs,
          bottomReserve,
          icon: Symbols.description,
          title: l10n.attachSheetSendFileTitle,
          subtitle: l10n.attachSheetSendFileSubtitle,
          buttonLabel: l10n.attachSheetChooseFileButton,
          onTap: widget.onPickFile,
        ),
        _buildActionPage(
          cs,
          bottomReserve,
          icon: Symbols.location_on,
          title: l10n.attachSheetShareLocationTitle,
          subtitle: l10n.attachSheetShareLocationSubtitle,
          buttonLabel: l10n.attachSheetSendLocationButton,
          onTap: widget.onShareLocation,
        ),
        _buildActionPage(
          cs,
          bottomReserve,
          icon: Symbols.bar_chart,
          title: l10n.attachSheetCreatePoll,
          subtitle: l10n.attachSheetCreatePollSubtitle,
          buttonLabel: l10n.attachSheetCreatePoll,
          onTap: widget.onCreatePoll,
        ),
        _buildContactPage(cs, bottomReserve),
      ],
    );
  }

  Widget _buildContactPage(ColorScheme cs, double bottomReserve) {
    final onSendContact = widget.onSendContact;
    if (onSendContact == null) return _buildPlaceholderPage(cs, bottomReserve);
    return ContactPickerPage(
      bottomReserve: bottomReserve,
      onPick: onSendContact,
    );
  }

  Widget _buildActionPage(
    ColorScheme cs,
    double bottomReserve, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomReserve),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onTap == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        onTap();
                      },
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryPage(
    ScrollController scrollController,
    ColorScheme cs,
    double bottomReserve,
  ) {
    if (_loading) {
      return Center(child: SmallSpinner(size: 36, color: cs.primary));
    }
    if (_permission == GalleryPermission.denied) {
      return _buildDenied(scrollController, cs, bottomReserve);
    }
    if (_items.isEmpty) {
      return _buildMessage(
        scrollController,
        cs,
        AppLocalizations.of(context)!.attachSheetNoImagesFound,
        bottomReserve,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 2.0;
        const hpad = 2.0;
        final cell = (constraints.maxWidth - hpad * 2 - spacing * 2) / 3;
        final headerHeight = cell * 2 + spacing;
        final headerPhotos = _items.take(4).toList();
        final gridPhotos = _items.length > 4
            ? _items.sublist(4)
            : const <GalleryItem>[];

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            if (_permission == GalleryPermission.limited)
              SliverToBoxAdapter(child: _buildLimitedBanner(cs)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(hpad, hpad, hpad, 0),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: headerHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: cell,
                        child: _CameraTile(onTap: _onCameraTap, cs: cs),
                      ),
                      const SizedBox(width: spacing),
                      Expanded(child: _buildHeaderPhotos(headerPhotos, cs)),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                hpad,
                spacing,
                hpad,
                bottomReserve + 6,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = gridPhotos[index];
                  return _GalleryTile(
                    key: ValueKey(item.id),
                    thumbKey: _thumbKey(item.id),
                    item: item,
                    selectedIds: _selected,
                    onOpen: () => _openPreview(item),
                    onToggle: () => _toggleSelection(item),
                    editedFile: _edits[item.id]?.working,
                    cs: cs,
                  );
                }, childCount: gridPhotos.length),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderPhotos(List<GalleryItem> photos, ColorScheme cs) {
    const spacing = 2.0;
    Widget tile(int i) {
      if (i >= photos.length) return const SizedBox.expand();
      final item = photos[i];
      return _GalleryTile(
        key: ValueKey(item.id),
        thumbKey: _thumbKey(item.id),
        item: item,
        selectedIds: _selected,
        onOpen: () => _openPreview(item),
        onToggle: () => _toggleSelection(item),
        editedFile: _edits[item.id]?.working,
        cs: cs,
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: tile(0)),
              const SizedBox(width: spacing),
              Expanded(child: tile(1)),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Expanded(
          child: Row(
            children: [
              Expanded(child: tile(2)),
              const SizedBox(width: spacing),
              Expanded(child: tile(3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLimitedBanner(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => _source.manageAccess().then((_) => _loadGallery()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: cs.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(Symbols.info, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.attachSheetLimitedAccessInfo,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
            Text(
              l10n.loginEdit,
              style: TextStyle(
                color: cs.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPage(ColorScheme cs, double bottomReserve) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomReserve),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.construction, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.attachSheetSectionInProgress,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDenied(
    ScrollController scrollController,
    ColorScheme cs,
    double bottomReserve,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return _scrollableCenter(
      scrollController,
      bottomReserve,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.no_photography, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              l10n.attachSheetNoGalleryAccessTitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.attachSheetNoGalleryAccessSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _loadGallery,
                  child: Text(l10n.attachSheetAllow),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _source.openSettings(),
                  child: Text(l10n.attachSheetSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
    ScrollController scrollController,
    ColorScheme cs,
    String text,
    double bottomReserve,
  ) {
    return _scrollableCenter(
      scrollController,
      bottomReserve,
      Text(text, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
    );
  }

  Widget _scrollableCenter(
    ScrollController scrollController,
    double bottomReserve,
    Widget child,
  ) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomReserve),
            child: Center(child: child),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(ColorScheme cs) {
    return Material(
      color: cs.primary,
      shape: const StadiumBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _sendSelection(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(Symbols.send, color: cs.onPrimary, size: 24, weight: 500),
        ),
      ),
    );
  }

  double _currentPageT() {
    if (!_pageController.hasClients) return 0;
    return _pageController.page ?? 0;
  }

  void _onPillDragStart() {
    _navDragging = true;
    _navDragBasePageT = _currentPageT();
    _navDragAccumDx = 0;
  }

  void _onPillDragUpdate(double dx, double inactiveWidth) {
    if (!_navDragging || !_pageController.hasClients) return;
    _navDragAccumDx += dx;
    final pageT = (_navDragBasePageT + _navDragAccumDx / inactiveWidth).clamp(
      0.0,
      (_navItemCount - 1).toDouble(),
    );
    _pageController.jumpTo(pageT * _pageController.position.viewportDimension);
  }

  void _onPillDragEnd() {
    if (!_navDragging) return;
    _navDragging = false;
    final target = _currentPageT().round().clamp(0, _navItemCount - 1);
    _pageController.animateToPage(
      target,
      duration: _navAnim,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildBottomBar() {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, _pillMargin),
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: _selected,
            builder: (context, selected, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: selected.isEmpty
                    ? _buildPillNav()
                    : _buildCaptionBar(Theme.of(context).colorScheme),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPillNav() {
    final navItems = _buildNavItems(AppLocalizations.of(context)!);
    return LayoutBuilder(
      key: const ValueKey('nav'),
      builder: (context, constraints) {
        final geometry = PillNavGeometry.fromInnerWidth(
          constraints.maxWidth - 4,
          navItems.length,
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _onPillDragStart(),
          onHorizontalDragUpdate: (d) =>
              _onPillDragUpdate(d.delta.dx, geometry.inactiveWidth),
          onHorizontalDragEnd: (_) => _onPillDragEnd(),
          onHorizontalDragCancel: _onPillDragEnd,
          child: AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              final cs = Theme.of(context).colorScheme;
              return ValueListenableBuilder<VisualStyle>(
                valueListenable: AppVisualStyle.current,
                builder: (context, style, _) =>
                    ValueListenableBuilder<NavPillStyle>(
                      valueListenable: AppNavPillStyle.current,
                      builder: (context, navStyle, _) {
                        final frost =
                            style.glossyChrome &&
                            NavPillMaterial.isFrost(navStyle);
                        final liquid =
                            style.glossyChrome &&
                            NavPillMaterial.isLiquid(navStyle);
                        return SlidingPillNav(
                          items: navItems,
                          position: _currentPageT(),
                          geometry: geometry,
                          onTap: _onSectionTap,
                          backgroundColor: liquid
                              ? null
                              : (frost
                                    ? AppFrost.glassTint(cs)
                                    : _composerColor(cs)),
                          borderColor: _composerBorderColor(cs),
                        );
                      },
                    ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCaptionBar(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      key: const ValueKey('caption'),
      height: SlidingPillNav.height,
      child: Center(
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _composerColor(cs),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _composerBorderColor(cs), width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _captionCtrl,
                  style: TextStyle(color: cs.onSurface, fontSize: 15),
                  cursorColor: cs.primary,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: l10n.attachSheetAddCaptionHint,
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _CameraTile extends StatefulWidget {
  final VoidCallback onTap;
  final ColorScheme cs;

  const _CameraTile({required this.onTap, required this.cs});

  @override
  State<_CameraTile> createState() => _CameraTileState();
}

class _CameraTileState extends State<_CameraTile> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maybeStartPreview();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeStartPreview();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopPreview();
    }
  }

  Future<void> _maybeStartPreview() async {
    if (_starting || _controller != null) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (!await Permission.camera.status.isGranted) return;
    _starting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
    } finally {
      _starting = false;
    }
  }

  void _stopPreview() {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final controller = _controller;
    final hasPreview = controller != null && controller.value.isInitialized;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPreview)
            _buildPreview(controller)
          else
            Container(color: cs.surfaceContainerHighest),
          if (hasPreview)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x66000000)],
                ),
              ),
            ),
          Align(
            alignment: hasPreview ? Alignment.bottomLeft : Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: hasPreview
                  ? const Icon(
                      Symbols.photo_camera,
                      size: 22,
                      color: Colors.white,
                      weight: 500,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.photo_camera,
                          size: 34,
                          color: cs.onSurface,
                          weight: 400,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)!.attachSheetCamera,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    final size = controller.value.previewSize;
    if (size == null) {
      return Container(color: widget.cs.surfaceContainerHighest);
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final GlobalKey<_ThumbnailState> thumbKey;
  final GalleryItem item;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final File? editedFile;
  final ColorScheme cs;

  const _GalleryTile({
    super.key,
    required this.thumbKey,
    required this.item,
    required this.selectedIds,
    required this.onOpen,
    required this.onToggle,
    this.editedFile,
    required this.cs,
  });

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIds.value.contains(widget.item.id);
    widget.selectedIds.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.selectedIds.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    final selected = widget.selectedIds.value.contains(widget.item.id);
    if (selected != _selected) setState(() => _selected = selected);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: widget.onOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            scale: _selected ? 0.86 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: _Thumbnail(
              key: widget.thumbKey,
              item: item,
              editedFile: widget.editedFile,
              cs: widget.cs,
            ),
          ),
          if (item.isVideo)
            Positioned(
              left: 6,
              bottom: 6,
              child: Row(
                children: [
                  Icon(
                    Symbols.play_arrow,
                    size: 16,
                    color: Colors.white,
                    fill: 1,
                  ),
                  if (item.duration != null)
                    Text(
                      formatDurationMmSs(item.duration!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                      ),
                    ),
                ],
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: widget.selectedIds,
                  builder: (context, ids, _) {
                    final index = ids.toList().indexOf(widget.item.id);
                    return _SelectionCheck(
                      number: index >= 0 ? index + 1 : null,
                      cs: widget.cs,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionCheck extends StatelessWidget {
  final int? number;
  final ColorScheme cs;

  const _SelectionCheck({required this.number, required this.cs});

  @override
  Widget build(BuildContext context) {
    final selected = number != null;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.black.withValues(alpha: 0.25),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: selected
          ? Text(
              '$number',
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            )
          : null,
    );
  }
}

class _Thumbnail extends StatefulWidget {
  final GalleryItem item;
  final File? editedFile;
  final ColorScheme cs;

  const _Thumbnail({
    super.key,
    required this.item,
    this.editedFile,
    required this.cs,
  });

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  static const int _pixelSize = 320;
  ImageProvider? _provider;

  ImageProvider? get provider => _provider;

  @override
  void initState() {
    super.initState();
    _resolveProvider();
  }

  @override
  void didUpdateWidget(covariant _Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editedFile?.path != oldWidget.editedFile?.path ||
        widget.item.id != oldWidget.item.id) {
      setState(_resolveProvider);
    }
  }

  void _resolveProvider() {
    final file =
        widget.editedFile ??
        (widget.item.isVideo ? null : widget.item.localFile);
    if (file != null) {
      _provider = ResizeImage(
        FileImage(file),
        width: _pixelSize,
        allowUpscaling: false,
      );
      return;
    }
    _provider = null;
    final id = widget.item.id;
    widget.item.thumbnail(_pixelSize).then((data) {
      if (!mounted || data == null || widget.item.id != id) return;
      if (widget.editedFile != null) return;
      setState(() => _provider = MemoryImage(data));
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return _placeholder();
    return Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: widget.cs.surfaceContainerHighest,
    child: widget.item.isVideo
        ? Center(
            child: Icon(
              Symbols.movie,
              size: 28,
              color: widget.cs.onSurfaceVariant,
            ),
          )
        : null,
  );
}
