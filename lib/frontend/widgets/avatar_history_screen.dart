import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/contacts.dart';
import '../../core/utils/media_saver.dart';
import '../../main.dart';
import 'custom_notification.dart';

class AvatarHistoryScreen extends StatefulWidget {
  final int contactId;
  final String? name;
  final String? currentAvatarUrl;

  const AvatarHistoryScreen({
    super.key,
    required this.contactId,
    this.name,
    this.currentAvatarUrl,
  });

  static Future<void> open(
    BuildContext context, {
    required int contactId,
    String? name,
    String? currentAvatarUrl,
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

  final PageController _pageController = PageController();
  String? _current;
  final List<String> _history = [];
  List<String> _pages = const [];
  int _historyTotal = 0;
  int _index = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.currentAvatarUrl;
    _current = (current != null && current.isNotEmpty) ? current : null;
    _rebuildPages();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _rebuildPages() {
    _pages = _current == null ? List.of(_history) : [_current!, ..._history];
  }

  void _addHistory(List<String> urls) {
    for (final url in urls) {
      if (url == _current || _history.contains(url)) continue;
      _history.add(url);
    }
  }

  Future<void> _load() async {
    final photos = await ContactsModule.fetchPhotos(
      api,
      widget.contactId,
      count: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _addHistory(photos.urls);
      _historyTotal = photos.total;
      _rebuildPages();
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _history.length >= _historyTotal) return;
    _loadingMore = true;
    final photos = await ContactsModule.fetchPhotos(
      api,
      widget.contactId,
      from: _history.length,
      count: _pageSize,
    );
    if (!mounted) {
      _loadingMore = false;
      return;
    }
    setState(() {
      _addHistory(photos.urls);
      if (photos.total > _historyTotal) _historyTotal = photos.total;
      _rebuildPages();
    });
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

  int get _count {
    final total = _historyTotal + (_current != null ? 1 : 0);
    return total > _pages.length ? total : _pages.length;
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
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
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
            '${_index + 1} из $_count',
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
            ? const CircularProgressIndicator(color: Colors.white)
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
          placeholder: (_, _) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
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
