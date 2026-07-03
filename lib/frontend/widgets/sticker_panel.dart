import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../main.dart' show stickersModule;
import '../../models/sticker.dart';
import 'sticker_image.dart';
import 'sticker_lottie.dart';
import 'sticker_peek.dart';

class _DragScrollBehavior extends MaterialScrollBehavior {
  const _DragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}

class _Section {
  final String title;
  final List<int> stickerIds;
  final IconData? icon;
  final String? iconUrl;

  const _Section({
    required this.title,
    required this.stickerIds,
    this.icon,
    this.iconUrl,
  });
}

class StickerPanel extends StatefulWidget {
  final double height;
  final void Function(StickerItem sticker) onStickerTap;

  const StickerPanel({
    super.key,
    required this.height,
    required this.onStickerTap,
  });

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel>
    with SingleTickerProviderStateMixin {
  static const double _tabBarHeight = 52;
  static const double _headerHeight = 34;

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);
  late final AnimationController _shimmer;
  bool _loading = true;
  Object? _error;
  int _selectedTab = 0;
  List<_Section> _sections = const [];
  List<double> _heights = const [];
  List<double> _offsets = const [];

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrolling.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await stickersModule.ensureLoaded();
      if (!mounted) return;
      _buildSections();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _buildSections() {
    final sections = <_Section>[];
    final recents = stickersModule.recentStickerIds;
    if (recents.isNotEmpty) {
      sections.add(
        _Section(
          title: 'Недавние',
          stickerIds: recents,
          icon: Symbols.schedule,
        ),
      );
    }
    for (final set in stickersModule.sets) {
      if (set.stickerIds.isEmpty) continue;
      sections.add(
        _Section(
          title: set.name,
          stickerIds: set.stickerIds,
          iconUrl: set.iconUrl,
        ),
      );
    }
    _sections = sections;
  }

  void _onScroll() {
    if (_offsets.isEmpty) return;
    final pixels = _scroll.position.pixels;
    var index = 0;
    for (var i = 0; i < _offsets.length; i++) {
      if (pixels + 1 >= _offsets[i]) index = i;
    }
    if (index != _selectedTab) setState(() => _selectedTab = index);
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
      if (!_scrolling.value) _scrolling.value = true;
    } else if (n is ScrollEndNotification) {
      if (_scrolling.value) _scrolling.value = false;
    }
    return false;
  }

  void _jumpTo(int index) {
    if (index < 0 || index >= _offsets.length) return;
    setState(() => _selectedTab = index);
    final max = _scroll.position.maxScrollExtent;
    _scroll.animateTo(
      _offsets[index].clamp(0.0, max),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: widget.height,
      color: cs.surface,
      child: _loading
          ? Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary),
              ),
            )
          : _error != null || _sections.isEmpty
          ? Center(
              child: Text(
                _error != null ? 'Не удалось загрузить стикеры' : 'Нет стикеров',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            )
          : ScrollConfiguration(
              behavior: const _DragScrollBehavior(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = (width / 84).floor().clamp(4, 8);
                  final cell = width / columns;

                  final heights = <double>[];
                  final offsets = <double>[];
                  var acc = 0.0;
                  for (final s in _sections) {
                    final rows = (s.stickerIds.length / columns).ceil();
                    final h = _headerHeight + rows * cell;
                    offsets.add(acc);
                    heights.add(h);
                    acc += h;
                  }
                  _heights = heights;
                  _offsets = offsets;

                  return Column(
                    children: [
                      _buildTabBar(cs),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                      Expanded(
                        child: StickerScrollScope(
                          isScrolling: _scrolling,
                          child: StickerPeekScope(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _onScrollNotification,
                              child: ListView.builder(
                                controller: _scroll,
                                padding: EdgeInsets.zero,
                                itemCount: _sections.length,
                                itemExtentBuilder: (i, _) => _heights[i],
                                itemBuilder: (context, i) => _StickerSection(
                                  key: ValueKey(
                                    _sections[i].title + i.toString(),
                                  ),
                                  title: _sections[i].title,
                                  stickerIds: _sections[i].stickerIds,
                                  columns: columns,
                                  cell: cell,
                                  headerHeight: _headerHeight,
                                  shimmer: _shimmer,
                                  onTap: widget.onStickerTap,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return SizedBox(
      height: _tabBarHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: _sections.length,
        itemBuilder: (context, i) {
          final s = _sections[i];
          final selected = i == _selectedTab;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _jumpTo(i),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? cs.surfaceContainerHighest : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: s.icon != null
                  ? Icon(s.icon, size: 24, color: selected ? cs.primary : cs.onSurfaceVariant)
                  : CachedNetworkImage(
                      imageUrl: s.iconUrl ?? '',
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) =>
                          Icon(Symbols.image, size: 20, color: cs.onSurfaceVariant),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _StickerSection extends StatefulWidget {
  final String title;
  final List<int> stickerIds;
  final int columns;
  final double cell;
  final double headerHeight;
  final Animation<double> shimmer;
  final void Function(StickerItem sticker) onTap;

  const _StickerSection({
    super.key,
    required this.title,
    required this.stickerIds,
    required this.columns,
    required this.cell,
    required this.headerHeight,
    required this.shimmer,
    required this.onTap,
  });

  @override
  State<_StickerSection> createState() => _StickerSectionState();
}

class _StickerSectionState extends State<_StickerSection> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await stickersModule.ensureStickers(widget.stickerIds);
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = widget.stickerIds;
    final columns = widget.columns;
    final cell = widget.cell;
    final rows = (ids.length / columns).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.headerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < columns; c++)
                SizedBox(
                  width: cell,
                  height: cell,
                  child: r * columns + c < ids.length
                      ? _cell(ids[r * columns + c])
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(int id) {
    if (!_loaded) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: _ShimmerBox(shimmer: widget.shimmer),
      );
    }
    final item = stickersModule.cachedSticker(id);
    if (item == null || item.url.isEmpty) return const SizedBox.shrink();
    return StickerPeekable(
      peekId: item.id,
      url: item.url,
      lottieUrl: item.lottieUrl,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(item),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: StickerImage(
            url: item.url,
            lottieUrl: item.lottieUrl,
            memCacheWidth: 220,
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final Animation<double> shimmer;

  const _ShimmerBox({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.35 + 0.4 * shimmer.value),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
