import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../main.dart' show animojiModule;
import '../../models/animoji.dart';
import 'lottie_image.dart';
import 'small_spinner.dart';

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

class _EmojiSection {
  final String title;
  final IconData icon;
  final List<Animoji> items;

  const _EmojiSection({
    required this.title,
    required this.icon,
    required this.items,
  });
}

class EmojiPanel extends StatefulWidget {
  final void Function(Animoji animoji) onEmojiTap;

  const EmojiPanel({super.key, required this.onEmojiTap});

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  static const double _tabBarHeight = 46;
  static const double _headerHeight = 30;

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);
  bool _loading = true;
  Object? _error;
  int _selectedTab = 0;
  List<_EmojiSection> _sections = const [];
  List<double> _heights = const [];
  List<double> _offsets = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrolling.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await animojiModule.ensureRecentsLoaded();
      await animojiModule.ensureLoaded();
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
    final sections = <_EmojiSection>[];
    final recent = animojiModule.recentAnimojis;
    if (recent.isNotEmpty) {
      sections.add(
        _EmojiSection(
          title: 'Недавние',
          icon: Symbols.schedule,
          items: recent,
        ),
      );
    }
    final all = animojiModule.animojis;
    if (all.isNotEmpty) {
      sections.add(
        _EmojiSection(
          title: 'Animated',
          icon: Symbols.animation,
          items: all,
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
    if (_loading) return const Center(child: SmallSpinner());
    if (_error != null || _sections.isEmpty) {
      return Center(
        child: Text(
          _error != null ? 'Не удалось загрузить эмодзи' : 'Нет эмодзи',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const _DragScrollBehavior(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = (width / 44).floor().clamp(6, 10);
          final cell = width / columns;

          final heights = <double>[];
          final offsets = <double>[];
          var acc = 0.0;
          for (final s in _sections) {
            final rows = (s.items.length / columns).ceil();
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
              Expanded(child: _buildContent(columns, cell)),
            ],
          );
        },
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
              width: 40,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? cs.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                s.icon,
                size: 22,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(int columns, double cell) {
    return LottieScrollScope(
      isScrolling: _scrolling,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverVariedExtentList(
              itemExtentBuilder: (i, _) => _heights[i],
              delegate: SliverChildBuilderDelegate(
                (context, i) => _EmojiSectionView(
                  key: ValueKey(_sections[i].title + i.toString()),
                  section: _sections[i],
                  columns: columns,
                  cell: cell,
                  headerHeight: _headerHeight,
                  onTap: widget.onEmojiTap,
                ),
                childCount: _sections.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiSectionView extends StatelessWidget {
  final _EmojiSection section;
  final int columns;
  final double cell;
  final double headerHeight;
  final void Function(Animoji animoji) onTap;

  const _EmojiSectionView({
    super.key,
    required this.section,
    required this.columns,
    required this.cell,
    required this.headerHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = section.items;
    final rows = (items.length / columns).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: headerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                section.title,
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
                  child: r * columns + c < items.length
                      ? _cell(items[r * columns + c])
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(Animoji animoji) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(animoji),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: LottieImage(
          url: animoji.iconUrl,
          lottieUrl: animoji.lottieUrl,
          memCacheWidth: 120,
        ),
      ),
    );
  }
}
