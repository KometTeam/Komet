import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/messages.dart';
import '../../backend/modules/shared_content.dart';
import '../../core/cache/info_cache.dart';
import '../../core/config/app_frost.dart';
import 'liquid_glass.dart';
import '../../core/utils/format.dart';
import '../../core/utils/media_cache.dart';
import '../../core/utils/media_saver.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../models/attachment.dart';
import 'chat_menu_overlay.dart';
import 'custom_notification.dart';
import 'small_spinner.dart';

class PhotoViewerActions {
  final void Function(String messageId, int time)? goToMessage;
  final void Function(String messageId)? forward;
  final void Function(String messageId, int senderId)? delete;
  final VoidCallback? viewAllPhotos;

  const PhotoViewerActions({
    this.goToMessage,
    this.forward,
    this.delete,
    this.viewAllPhotos,
  });

  bool get isEmpty =>
      goToMessage == null &&
      forward == null &&
      delete == null &&
      viewAllPhotos == null;
}

class _ViewerPhoto {
  final String id;
  final PhotoAttachment photo;
  final String messageId;
  final int senderId;
  final int time;
  final String? caption;

  const _ViewerPhoto({
    required this.id,
    required this.photo,
    required this.messageId,
    required this.senderId,
    required this.time,
    this.caption,
  });

  factory _ViewerPhoto.fromFeed(SharedMediaItem item) {
    final photo = item.attachment as PhotoAttachment;
    return _ViewerPhoto(
      id: item.dedupKey,
      photo: photo,
      messageId: item.messageId,
      senderId: item.senderId,
      time: item.time,
      caption: item.text,
    );
  }
}

class PhotoViewerScreen extends StatefulWidget {
  final List<PhotoAttachment> photos;
  final int initialIndex;
  final int? chatId;
  final CachedMessage? message;
  final PhotoViewerActions? actions;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.chatId,
    this.message,
    this.actions,
  });

  PhotoViewerScreen.single(String baseUrl, {super.key})
    : photos = [PhotoAttachment(baseUrl: baseUrl)],
      initialIndex = 0,
      chatId = null,
      message = null,
      actions = null;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  static const int _prefetchThreshold = 3;

  late PageController _controller;
  late List<_ViewerPhoto> _items;
  late int _index;
  int _pager = 0;

  final Map<String, int> _quarterTurns = {};
  bool _feedLoaded = false;
  bool _feedFailed = false;
  bool _loadingMore = false;
  bool _reachedEnd = false;
  bool _chromeVisible = true;
  int _total = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = _localItems();
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _controller = PageController(initialPage: _index);
    unawaited(_loadFeed());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ViewerPhoto> _localItems() {
    final message = widget.message;
    return [
      for (var i = 0; i < widget.photos.length; i++)
        _ViewerPhoto(
          id: _localId(widget.photos[i], message, i),
          photo: widget.photos[i],
          messageId: message?.id ?? '',
          senderId: message?.senderId ?? 0,
          time: message?.time ?? 0,
          caption: message?.text,
        ),
    ];
  }

  String _localId(PhotoAttachment photo, CachedMessage? message, int at) {
    final key = _feedKey(photo, message);
    return key ?? 'local:${message?.id ?? ''}:$at';
  }

  String? _feedKey(PhotoAttachment photo, CachedMessage? message) {
    if (message == null || widget.chatId == null) return null;
    if (photo.photoId == null && (photo.baseUrl ?? '').isEmpty) return null;
    return photoDedupKey(message.id, photo);
  }

  _ViewerPhoto get _current => _items[_index];

  bool get _feedPending =>
      !_feedLoaded &&
      !_feedFailed &&
      widget.chatId != null &&
      _feedKey(_current.photo, widget.message) != null;

  Future<void> _loadFeed() async {
    final chatId = widget.chatId;
    final key = _feedKey(_items[_index].photo, widget.message);
    if (chatId == null || key == null) return;

    final feed = await sharedContentModule.photoFeedFor(
      chatId: chatId,
      photoKey: key,
      resolveAnchor: () => _resolveAnchor(chatId),
    );
    if (!mounted) return;
    if (feed == null) {
      setState(() => _feedFailed = true);
      return;
    }

    final items = feed.items.map(_ViewerPhoto.fromFeed).toList();
    final at = items.indexWhere((i) => i.id == key);
    if (at == -1) {
      setState(() => _feedFailed = true);
      return;
    }

    _adoptFeed(items, at, feed);
  }

  void _adoptFeed(List<_ViewerPhoto> items, int at, ChatPhotoFeed feed) {
    final movesPage = at != _index;
    final previous = _controller;

    setState(() {
      _items = items;
      _index = at;
      _total = feed.total;
      _reachedEnd = feed.reachedEnd;
      _feedLoaded = true;
      if (movesPage) {
        _pager++;
        _controller = PageController(initialPage: at);
      }
    });

    if (movesPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  Future<void> _loadMore() async {
    final chatId = widget.chatId;
    if (chatId == null || _loadingMore || _reachedEnd || !_feedLoaded) return;
    _loadingMore = true;
    try {
      final feed = await sharedContentModule.loadMorePhotos(
        chatId: chatId,
        resolveAnchor: () => _resolveAnchor(chatId),
      );
      if (!mounted) return;

      final items = feed.items.map(_ViewerPhoto.fromFeed).toList();
      final at = items.indexWhere((i) => i.id == _current.id);
      if (at == -1) {
        setState(() {
          _total = feed.total;
          _reachedEnd = feed.reachedEnd;
        });
        return;
      }

      _adoptFeed(items, at, feed);
    } finally {
      _loadingMore = false;
    }
  }

  Future<String?> _resolveAnchor(int chatId) async {
    final info = await ChatInfoFetch.get(chatId);
    final lastMessage = info?.raw['lastMessage'];
    if (lastMessage is Map) {
      final id = lastMessage['id']?.toString();
      if (id != null && id.isNotEmpty) return id;
    }
    return widget.message?.id;
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    if (index >= _items.length - _prefetchThreshold) unawaited(_loadMore());
  }

  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _items.length) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _rotate() {
    setState(() {
      _quarterTurns[_current.id] = ((_quarterTurns[_current.id] ?? 0) + 1) % 4;
    });
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  String _cacheNameFor(PhotoAttachment photo, String url) =>
      'photo_${photo.photoId ?? (url.hashCode & 0x7fffffff)}.jpg';

  Future<File?> _fileFor(PhotoAttachment photo) async {
    final localPath = photo.localPath;
    if (localPath != null) {
      final file = File(localPath);
      return await file.exists() ? file : null;
    }
    final url = photo.baseUrl ?? '';
    if (url.isEmpty) return null;
    return MediaCache.getOrDownload(_cacheNameFor(photo, url), url);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final photo = _current.photo;
    final localPath = photo.localPath;
    final url = photo.baseUrl ?? '';

    final MediaSaveResult result;
    if (localPath != null) {
      result = await saveLocalImage(localPath);
    } else if (url.isEmpty) {
      result = const MediaSaveResult(ok: false, error: 'нет ссылки');
    } else {
      result = await saveMediaFile(
        cacheName: _cacheNameFor(photo, url),
        resolveUrl: () async => url,
        saveName: 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg',
        kind: SaveMediaKind.image,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (result.ok) {
      showCustomNotification(
        context,
        result.toGallery ? 'Сохранено в галерею' : 'Файл сохранён',
      );
    } else {
      showCustomNotification(
        context,
        'Не удалось сохранить: ${result.error ?? ''}',
      );
    }
  }

  Future<void> _saveAs() async {
    final file = await _fileFor(_current.photo);
    if (!mounted) return;
    if (file == null) {
      showCustomNotification(context, 'Не удалось загрузить фото');
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: AppLocalizations.of(context)!.photoViewerSaveAs,
      fileName: 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg',
      type: FileType.any,
      bytes: isMobile ? bytes : null,
    );
    if (path == null || !mounted) return;

    if (!isMobile) {
      await File(path).writeAsBytes(bytes);
      if (!mounted) return;
    }
    showCustomNotification(context, 'Файл сохранён');
  }

  void _openMenu(BuildContext anchorContext) {
    final actions = widget.actions;
    if (actions == null) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final l10n = AppLocalizations.of(context)!;
    final item = _current;

    showChatMenu(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      items: [
        if (actions.goToMessage != null)
          ChatMenuItem(
            icon: Symbols.visibility,
            label: l10n.sharedGoToMessage,
            onTap: () =>
                _popThen(() => actions.goToMessage!(item.messageId, item.time)),
          ),
        if (actions.forward != null)
          ChatMenuItem(
            icon: Symbols.forward,
            label: l10n.msgActionsForward,
            onTap: () => _popThen(() => actions.forward!(item.messageId)),
          ),
        if (actions.delete != null)
          ChatMenuItem(
            icon: Symbols.delete,
            label: l10n.msgActionsDelete,
            destructive: true,
            dividerAfter: true,
            onTap: () =>
                _popThen(() => actions.delete!(item.messageId, item.senderId)),
          ),
        ChatMenuItem(
          icon: Symbols.download,
          label: l10n.photoViewerSaveAs,
          onTap: _saveAs,
        ),
        if (actions.viewAllPhotos != null)
          ChatMenuItem(
            icon: Symbols.grid_view,
            label: l10n.photoViewerViewAll,
            onTap: () => _popThen(actions.viewAllPhotos!),
          ),
      ],
    );
  }

  void _popThen(VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final hasMenu = !(widget.actions?.isEmpty ?? true);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  key: ValueKey(_pager),
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleChrome,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: _quarterTurns[_items[i].id] ?? 0,
                          child: _buildImage(_items[i].photo),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: AnimatedOpacity(
                    opacity: _chromeVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: Stack(
                      children: [
                        if (_index > 0)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _arrow(Symbols.chevron_left, () => _step(-1)),
                          ),
                        if (_index < _items.length - 1)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _arrow(Symbols.chevron_right, () => _step(1)),
                          ),
                        Positioned(
                          top: padding.top + 8,
                          left: 8,
                          right: 8,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Symbols.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const Spacer(),
                              if (hasMenu)
                                Builder(
                                  builder: (btnContext) => IconButton(
                                    icon: const Icon(
                                      Symbols.more_vert,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _openMenu(btnContext),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildBottomBar(padding.bottom),
                        ),
                      ],
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

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(double bottomInset) {
    final l10n = AppLocalizations.of(context)!;
    final caption = _current.caption;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 8, bottomInset + 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caption != null && caption.isNotEmpty) ...[
            _buildCaption(caption),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildInfo(l10n)),
              IconButton(
                icon: _saving
                    ? const SmallSpinner(size: 20, color: Colors.white)
                    : const Icon(Symbols.download, color: Colors.white),
                onPressed: _saving ? null : _save,
                tooltip: l10n.sharedDownload,
              ),
              IconButton(
                icon: const Icon(
                  Symbols.rotate_90_degrees_ccw,
                  color: Colors.white,
                ),
                onPressed: _rotate,
                tooltip: l10n.photoViewerRotate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaption(String caption) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(12),
      frostTint: Colors.black.withValues(alpha: 0.28),
      frostSigma: AppFrost.panelSigma,
      liquidTint: Colors.black.withValues(alpha: 0.28),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 0.5,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SingleChildScrollView(
          child: Text(
            caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(AppLocalizations l10n) {
    final item = _current;
    if (item.messageId.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_feedLoaded)
          Text(
            l10n.photoViewerCounter(_total - _index, _total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (_feedPending)
          const _CounterShimmer(),
        const SizedBox(height: 2),
        Text(
          _sentLine(l10n, item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  String _sentLine(AppLocalizations l10n, _ViewerPhoto item) {
    final sender = ContactCache.get(item.senderId) ?? '';
    final sentAt = DateTime.fromMillisecondsSinceEpoch(item.time);
    final now = DateTime.now();
    final time = formatClock(sentAt);
    final isToday =
        sentAt.year == now.year &&
        sentAt.month == now.month &&
        sentAt.day == now.day;
    return isToday
        ? l10n.photoViewerSentToday(sender, time)
        : l10n.photoViewerSentOn(sender, formatDateWords(sentAt), time);
  }

  Widget _buildImage(PhotoAttachment photo) {
    final localPath = photo.localPath;
    if (localPath != null) {
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _broken(),
      );
    }

    final url = photo.baseUrl ?? '';
    if (url.isEmpty) return _broken();

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) =>
          const Center(child: SmallSpinner(size: 36, color: Colors.white)),
      errorWidget: (_, _, _) => _broken(),
    );
  }

  Widget _broken() =>
      const Icon(Symbols.broken_image, color: Colors.white54, size: 64);
}

class _CounterShimmer extends StatefulWidget {
  const _CounterShimmer();

  @override
  State<_CounterShimmer> createState() => _CounterShimmerState();
}

class _CounterShimmerState extends State<_CounterShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: 0.25 + 0.35 * _controller.value,
        child: Container(
          width: 120,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
