import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/widgets/attachment/media_preview_screen.dart';
import 'package:komet/frontend/widgets/attachment/photo_editor.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/sheet_helpers.dart';
import 'package:komet/frontend/widgets/sliding_pill_nav.dart';

const List<PillNavItem> _navItems = [
  PillNavItem(icon: Symbols.image, label: 'Галерея'),
  PillNavItem(icon: Symbols.description, label: 'Файл'),
  PillNavItem(icon: Symbols.location_on, label: 'Геопозиция'),
  PillNavItem(icon: Symbols.person, label: 'Контакт'),
];

Future<void> showAttachmentSheet(
  BuildContext context, {
  String? title,
  void Function(List<PickedPhoto> photos, String caption)? onSend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    requestFocus: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => AttachmentSheet(title: title, onSend: onSend),
  );
}

class AttachmentSheet extends StatefulWidget {
  final String? title;
  final void Function(List<PickedPhoto> photos, String caption)? onSend;

  const AttachmentSheet({super.key, this.title, this.onSend});

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet> {
  static List<GalleryItem>? _cachedItems;
  static GalleryPermission _cachedPermission = GalleryPermission.granted;

  final GallerySource _source = GallerySource.create();
  final ValueNotifier<Set<String>> _selected = ValueNotifier(<String>{});
  final Map<String, PhotoEditState> _edits = {};
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

  void _openPreview(GalleryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaPreviewScreen(
          item: item,
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

  void _onCameraTap() {
    showCustomNotification(context, 'Камера скоро появится');
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
                          barReserve + 8 + MediaQuery.viewInsetsOf(context).bottom,
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
    return PageView(
      controller: _pageController,
      children: [
        _KeepAlivePage(
          child: _buildGalleryPage(scrollController, cs, bottomReserve),
        ),
        _buildPlaceholderPage(cs, bottomReserve),
        _buildPlaceholderPage(cs, bottomReserve),
        _buildPlaceholderPage(cs, bottomReserve),
      ],
    );
  }

  Widget _buildGalleryPage(
    ScrollController scrollController,
    ColorScheme cs,
    double bottomReserve,
  ) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }
    if (_permission == GalleryPermission.denied) {
      return _buildDenied(scrollController, cs, bottomReserve);
    }
    if (_items.isEmpty) {
      return _buildMessage(
        scrollController,
        cs,
        'Изображений не найдено',
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
              padding: EdgeInsets.fromLTRB(hpad, spacing, hpad, bottomReserve + 6),
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
                'Доступны не все фото',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
            Text(
              'Изменить',
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
              'Раздел в разработке',
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
              'Нет доступа к галерее',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Разрешите доступ к фото, чтобы выбрать их отсюда',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _loadGallery,
                  child: const Text('Разрешить'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _source.openSettings(),
                  child: const Text('Настройки'),
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
      3.0,
    );
    _pageController.jumpTo(pageT * _pageController.position.viewportDimension);
  }

  void _onPillDragEnd() {
    if (!_navDragging) return;
    _navDragging = false;
    final target = _currentPageT().round().clamp(0, 3);
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
    final geometry = PillNavGeometry.equal(54, _navItems.length);
    return Align(
      key: const ValueKey('nav'),
      child: GestureDetector(
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
            return SlidingPillNav(
              items: _navItems,
              position: _currentPageT(),
              geometry: geometry,
              onTap: _onSectionTap,
              iconsOnly: true,
              backgroundColor: _composerColor(cs),
              borderColor: _composerBorderColor(cs),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCaptionBar(ColorScheme cs) {
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
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Добавить подпись...',
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

class _CameraTile extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme cs;

  const _CameraTile({required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Column(
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
              'Камера',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final GalleryItem item;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final File? editedFile;
  final ColorScheme cs;

  const _GalleryTile({
    super.key,
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

  const _Thumbnail({required this.item, this.editedFile, required this.cs});

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  static const int _pixelSize = 320;
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.item.localFile == null) {
      _future = widget.item.thumbnail(_pixelSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edited = widget.editedFile;
    if (edited != null) {
      return Image.file(
        edited,
        fit: BoxFit.cover,
        cacheWidth: _pixelSize,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    final file = widget.item.localFile;
    if (file != null) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: _pixelSize,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return _placeholder();
        return Image.memory(
          data,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      },
    );
  }

  Widget _placeholder() => ColoredBox(color: widget.cs.surfaceContainerHighest);
}
