import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/contacts.dart';
import '../../core/utils/media_saver.dart';
import '../../main.dart';
import 'custom_notification.dart';
import 'small_spinner.dart';

class AvatarHistoryScreen extends StatefulWidget {
  final int contactId;
  final String? name;
  final String? currentAvatarUrl;
  final String? initialUrl;

  const AvatarHistoryScreen({
    super.key,
    required this.contactId,
    this.name,
    this.currentAvatarUrl,
    this.initialUrl,
  });

  static Future<void> open(
    BuildContext context, {
    required int contactId,
    String? name,
    String? currentAvatarUrl,
    String? initialUrl,
  }) {
    final url = currentAvatarUrl;
    if (url == null || url.isEmpty) return Future.value();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AvatarHistoryScreen(
          contactId: contactId,
          name: name,
          currentAvatarUrl: url,
          initialUrl: initialUrl,
        ),
      ),
    );
  }

  @override
  State<AvatarHistoryScreen> createState() => _AvatarHistoryScreenState();
}

class _AvatarHistoryScreenState extends State<AvatarHistoryScreen> {
  static const int _pageSize = 50;
  static const int _maxDots = 10;

  late final PageController _pageController;
  String? _current;
  final List<String> _history = [];
  List<String> _pages = const [];
  int _historyTotal = 0;
  int _total = 0;
  int _index = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _historyDone = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.currentAvatarUrl;
    _current = (current != null && current.isNotEmpty) ? current : null;
    final cached = _hasHistory
        ? ContactsModule.cachedPhotos(widget.contactId)
        : null;
    if (cached != null) _mergeHistory(cached);
    _rebuild();
    _index = _indexOfUrl(widget.initialUrl ?? _current);
    _pageController = PageController(initialPage: _index);
    if (_hasHistory) {
      _load();
    } else {
      _loading = false;
    }
  }

  bool get _hasHistory => widget.contactId > 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _indexOfUrl(String? url) {
    if (url == null || _pages.isEmpty) return 0;
    final at = _pages.indexOf(url);
    return at < 0 ? 0 : at;
  }

  String? _anchorUrl() =>
      _index < _pages.length ? _pages[_index] : (widget.initialUrl ?? _current);

  void _mergeHistory(ContactPhotos photos) {
    for (final url in photos.urls) {
      if (url.isEmpty || _history.contains(url)) continue;
      _history.add(url);
    }
    if (photos.total > _historyTotal) _historyTotal = photos.total;
  }

  void _rebuild() {
    final current = _current;
    final extra = current != null && !_history.contains(current);
    _pages = extra ? [current, ..._history] : List.of(_history);
    final counted = _historyTotal + (extra ? 1 : 0);
    _total = counted > _pages.length ? counted : _pages.length;
  }

  void _restoreIndex(String? anchor) {
    if (_pages.isEmpty) return;
    final at = anchor == null ? -1 : _pages.indexOf(anchor);
    final next = at >= 0 ? at : _index.clamp(0, _pages.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(next);
    });
  }

  Future<void> _load() async {
    final photos = await ContactsModule.fetchPhotos(
      api,
      widget.contactId,
      count: _pageSize,
    );
    if (!mounted) return;
    final anchor = _anchorUrl();
    setState(() {
      _mergeHistory(photos);
      _rebuild();
      _loading = false;
    });
    _restoreIndex(anchor);
  }

  Future<void> _loadMore() async {
    if (!_hasHistory ||
        _loadingMore ||
        _historyDone ||
        _history.length >= _historyTotal) {
      return;
    }
    _loadingMore = true;
    final before = _history.length;
    final photos = await ContactsModule.fetchPhotos(
      api,
      widget.contactId,
      from: before,
      count: _pageSize,
    );
    if (!mounted) {
      _loadingMore = false;
      return;
    }
    final anchor = _anchorUrl();
    setState(() {
      _mergeHistory(photos);
      if (_history.length == before) _historyDone = true;
      _rebuild();
    });
    _restoreIndex(anchor);
    _loadingMore = false;
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    if (index >= _pages.length - 2) _loadMore();
  }

  void _prev() {
    if (_index <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_index >= _pages.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _save() async {
    if (_saving || _index >= _pages.length) return;
    setState(() => _saving = true);
    final result = await saveImageFromUrl(_pages[_index]);
    if (!mounted) return;
    setState(() => _saving = false);
    final message = result.ok
        ? (result.toGallery
              ? 'Сохранено в галерею'
              : 'Сохранено: ${result.location}')
        : 'Не удалось сохранить: ${result.error}';
    showCustomNotification(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody()),
          if (_pages.length > 1 && _index > 0)
            _navButton(
              alignLeft: true,
              icon: Symbols.chevron_left,
              onTap: _prev,
            ),
          if (_pages.length > 1 && _index < _pages.length - 1)
            _navButton(
              alignLeft: false,
              icon: Symbols.chevron_right,
              onTap: _next,
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: topPad + 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 4,
            left: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Symbols.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(child: _buildCounter()),
                IconButton(
                  icon: _saving
                      ? const SmallSpinner(size: 22, color: Colors.white)
                      : const Icon(Symbols.download, color: Colors.white),
                  onPressed: _pages.isEmpty || _saving ? null : _save,
                ),
              ],
            ),
          ),
          if (_pages.length > 1 && _pages.length <= _maxDots)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 18,
              left: 0,
              right: 0,
              child: _buildDots(),
            ),
        ],
      ),
    );
  }

  Widget _buildCounter() {
    final hasName = widget.name != null && widget.name!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pages.length > 1)
          Text(
            '${_index + 1} из $_total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (hasName)
          Text(
            widget.name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (_pages.length > 1 && hasName)
          Text(
            widget.name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_pages.isEmpty) {
      return Center(
        child: _loading
            ? const SmallSpinner(size: 36, color: Colors.white)
            : const Text(
                'Нет фотографий',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
      );
    }
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _pages.length,
      itemBuilder: (context, i) => Center(
        child: CachedNetworkImage(
          imageUrl: _pages[i],
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, _) =>
              const Center(child: SmallSpinner(size: 36, color: Colors.white)),
          errorWidget: (_, _, _) =>
              const Icon(Symbols.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }

  Widget _navButton({
    required bool alignLeft,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: alignLeft ? 8 : null,
      right: alignLeft ? null : 8,
      child: Center(
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _pages.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _index ? 8 : 6,
            height: i == _index ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _index ? Colors.white : Colors.white38,
            ),
          ),
      ],
    );
  }
}
