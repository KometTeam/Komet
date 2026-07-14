import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/debouncer.dart';
import '../../core/utils/emoji_keyword_index.dart';
import '../../main.dart' show stickersModule;
import '../../models/animoji.dart';
import '../../models/sticker.dart';
import 'emoji_panel.dart';
import 'segmented_pill_toggle.dart';
import 'small_spinner.dart';
import 'lottie_image.dart';
import 'sticker_peek.dart';
import '../../core/config/app_frost.dart';
import 'liquid_glass.dart';

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
  final void Function(Animoji animoji)? onEmojiTap;

  const StickerPanel({
    super.key,
    required this.height,
    required this.onStickerTap,
    this.onEmojiTap,
  });

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel>
    with SingleTickerProviderStateMixin {
  static const double _tabBarHeight = 52;
  static const double _headerHeight = 34;
  static const double _searchFieldHeight = 50;
  static const double _toggleBarHeight = 48;
  static const int _modeEmoji = 0;
  static const int _modeStickers = 1;
  static const String _modePrefKey = 'komet_panel_mode';
  static int _persistedMode = _modeStickers;
  static bool _persistedModeLoaded = false;

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Debouncer _searchDebouncer = Debouncer(
    const Duration(milliseconds: 220),
  );
  late final AnimationController _shimmer;
  bool _loading = true;
  Object? _error;
  late int _mode;
  bool _modeUserChosen = false;
  int _selectedTab = 0;
  List<_Section> _sections = const [];
  List<double> _heights = const [];
  List<double> _offsets = const [];
  String _query = '';
  bool _searchLoading = false;
  List<StickerItem> _results = const [];

  @override
  void initState() {
    super.initState();
    _mode = widget.onEmojiTap == null ? _modeStickers : _persistedMode;
    if (!_persistedModeLoaded) unawaited(_loadPersistedMode());
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scroll.addListener(_onScroll);
    EmojiKeywordIndex.instance.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrolling.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _searchDebouncer.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    if (query == _query) return;
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _results = const [];
        _searchLoading = false;
      } else {
        _searchLoading = true;
      }
    });
    if (query.isEmpty) {
      _searchDebouncer.cancel();
      return;
    }
    _searchDebouncer.run(() => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    await EmojiKeywordIndex.instance.ensureLoaded();
    await stickersModule.ensureAllStickersLoaded();
    if (!mounted || _query != query) return;
    final targets = EmojiKeywordIndex.instance.resolve(query);
    final results = stickersModule.searchByTags(targets);
    setState(() {
      _results = results;
      _searchLoading = false;
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    _searchDebouncer.cancel();
    setState(() {
      _query = '';
      _results = const [];
      _searchLoading = false;
    });
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
    if (_offsets.isEmpty || _query.isNotEmpty) return;
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
    if (index < 0 || index >= _sections.length) return;
    if (_query.isEmpty) {
      _scrollToSection(index);
    } else {
      _clearSearch();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSection(index),
      );
    }
  }

  void _scrollToSection(int index) {
    if (!mounted || index >= _offsets.length || !_scroll.hasClients) return;
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
    return SizedBox(
      height: widget.height,
      child: GlassSurface(
        liquid: false,
        frostTint: AppFrost.panelTint(cs),
        border: Border(top: AppFrost.hairline(cs)),
        child: Column(
          children: [
            Expanded(
              child: _mode == _modeEmoji && widget.onEmojiTap != null
                  ? EmojiPanel(onEmojiTap: widget.onEmojiTap!)
                  : _buildStickerBody(cs),
            ),
            if (widget.onEmojiTap != null) _buildToggleBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildStickerBody(ColorScheme cs) {
    if (_loading) return Center(child: SmallSpinner());
    if (_error != null || _sections.isEmpty) {
      return Center(
        child: Text(
          _error != null ? 'Не удалось загрузить стикеры' : 'Нет стикеров',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: const _DragScrollBehavior(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = (width / 84).floor().clamp(4, 8);
          final cell = width / columns;

          final heights = <double>[];
          final offsets = <double>[];
          var acc = _searchFieldHeight;
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
              Expanded(child: _buildContent(cs, columns, cell)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadPersistedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_modePrefKey);
      _persistedModeLoaded = true;
      if (value != _modeEmoji && value != _modeStickers) return;
      _persistedMode = value!;
      if (!mounted || _modeUserChosen || widget.onEmojiTap == null) return;
      if (_mode != value) setState(() => _mode = value);
    } catch (_) {
      _persistedModeLoaded = true;
    }
  }

  void _setMode(int mode) {
    if (mode == _mode) return;
    _modeUserChosen = true;
    _persistedMode = mode;
    setState(() => _mode = mode);
    unawaited(_persistMode(mode));
  }

  Future<void> _persistMode(int mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_modePrefKey, mode);
    } catch (_) {}
  }

  Widget _buildToggleBar(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
        SizedBox(
          height: _toggleBarHeight,
          child: Center(
            child: SegmentedPillToggle(
              labels: const ['Эмодзи', 'Стикеры'],
              selected: _mode,
              onChanged: _setMode,
            ),
          ),
        ),
      ],
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
                color: selected
                    ? cs.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: s.icon != null
                  ? Icon(
                      s.icon,
                      size: 24,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    )
                  : CachedNetworkImage(
                      imageUrl: s.iconUrl ?? '',
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => Icon(
                        Symbols.image,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, int columns, double cell) {
    return LottieScrollScope(
      isScrolling: _scrolling,
      child: StickerPeekScope(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(child: _buildSearchField(cs)),
              if (_query.isEmpty)
                SliverVariedExtentList(
                  itemExtentBuilder: (i, _) => _heights[i],
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _StickerSection(
                      key: ValueKey(_sections[i].title + i.toString()),
                      title: _sections[i].title,
                      stickerIds: _sections[i].stickerIds,
                      columns: columns,
                      cell: cell,
                      headerHeight: _headerHeight,
                      shimmer: _shimmer,
                      onTap: widget.onStickerTap,
                    ),
                    childCount: _sections.length,
                  ),
                )
              else if (_searchLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: SmallSpinner()),
                )
              else if (_results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Ничего не найдено',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _resultCell(_results[i]),
                      childCount: _results.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Symbols.search, size: 22, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                cursorColor: cs.primary,
                style: TextStyle(color: cs.onSurface, fontSize: 15),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Поиск',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (_query.isEmpty)
              const SizedBox(width: 12)
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clearSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Symbols.close,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultCell(StickerItem item) {
    return StickerPeekable(
      peekId: item.id,
      url: item.url,
      lottieUrl: item.lottieUrl,
      tags: item.tags,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onStickerTap(item),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: LottieImage(
            url: item.url,
            lottieUrl: item.lottieUrl,
            memCacheWidth: 220,
          ),
        ),
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
      tags: item.tags,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(item),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: LottieImage(
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
