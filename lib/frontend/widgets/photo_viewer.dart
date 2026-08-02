import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../backend/modules/messages.dart';
import '../../backend/modules/shared_content.dart';
import '../../core/cache/info_cache.dart';
import '../../core/config/app_frost.dart';
import '../../core/utils/download_history.dart';
import '../../core/utils/format.dart';
import '../../core/utils/media_cache.dart';
import '../../core/utils/media_saver.dart';
import '../../core/utils/save_file_as.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';
import '../../models/attachment.dart';
import 'attachment/photo_hero.dart';
import 'chat_menu_overlay.dart';
import 'custom_notification.dart';
import 'liquid_glass.dart';
import 'small_spinner.dart';

class PhotoViewerActions {
  final void Function(String messageId, int time)? goToMessage;
  final void Function(String messageId)? forward;
  final void Function(String messageId, int senderId)? delete;
  final VoidCallback? viewAllMedia;

  const PhotoViewerActions({
    this.goToMessage,
    this.forward,
    this.delete,
    this.viewAllMedia,
  });

  bool get isEmpty =>
      goToMessage == null &&
      forward == null &&
      delete == null &&
      viewAllMedia == null;
}

class _ViewerMedia {
  final String id;
  final MessageAttachment attachment;
  final String messageId;
  final int senderId;
  final int time;
  final String? caption;

  const _ViewerMedia({
    required this.id,
    required this.attachment,
    required this.messageId,
    required this.senderId,
    required this.time,
    this.caption,
  });

  factory _ViewerMedia.fromFeed(SharedMediaItem item) => _ViewerMedia(
    id: item.dedupKey,
    attachment: item.attachment,
    messageId: item.messageId,
    senderId: item.senderId,
    time: item.time,
    caption: item.text,
  );

  PhotoAttachment? get photo =>
      attachment is PhotoAttachment ? attachment as PhotoAttachment : null;

  VideoAttachment? get video =>
      attachment is VideoAttachment ? attachment as VideoAttachment : null;

  bool get isVideo => attachment is VideoAttachment;
}

class PhotoViewerScreen extends StatefulWidget {
  final List<PhotoAttachment> photos;
  final VideoAttachment? video;
  final Map<String, String> initialVideoSources;
  final String? initialVideoQuality;
  final int initialIndex;
  final int? chatId;
  final CachedMessage? message;
  final PhotoViewerActions? actions;
  final PhotoHeroController? hero;
  final bool isFile;
  final String? sourceName;

  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.chatId,
    this.message,
    this.actions,
    this.hero,
    this.isFile = false,
    this.sourceName,
  }) : video = null,
       initialVideoSources = const {},
       initialVideoQuality = null;

  const PhotoViewerScreen.video({
    super.key,
    required VideoAttachment attachment,
    required this.initialVideoSources,
    this.initialVideoQuality,
    this.chatId,
    this.message,
    this.actions,
    this.sourceName,
  }) : photos = const [],
       video = attachment,
       initialIndex = 0,
       hero = null,
       isFile = false;

  PhotoViewerScreen.single(String baseUrl, {super.key})
    : photos = [PhotoAttachment(baseUrl: baseUrl)],
      video = null,
      initialVideoSources = const {},
      initialVideoQuality = null,
      initialIndex = 0,
      chatId = null,
      message = null,
      actions = null,
      hero = null,
      isFile = false,
      sourceName = null;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  static const int _prefetchThreshold = 3;
  static const int _maxCachedVideoPlayers = 5;

  late PageController _controller;
  late List<_ViewerMedia> _items;
  late int _index;
  late final String _heroId;
  late final String _initialMediaId;
  int _pager = 0;
  final Map<String, int> _quarterTurns = {};
  final LinkedHashMap<String, _VideoPlaybackSession> _videoSessions =
      LinkedHashMap();
  final Map<String, Map<String, String>> _videoSourceCache = {};
  final Map<String, Future<Map<String, String>>> _videoSourceLoads = {};
  final TransformationController _heroTransform = TransformationController();
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
    _heroTransform.addListener(_syncHero);
    _items = _localItems();
    _index = widget.video == null
        ? (_items.length - 1 - widget.initialIndex).clamp(0, _items.length - 1)
        : 0;
    _heroId = _items[_index].id;
    _initialMediaId = _heroId;
    _controller = PageController(initialPage: _index);
    unawaited(_loadFeed());
  }

  void _syncHero() {
    final hero = widget.hero;
    if (hero == null) return;
    hero.enabled =
        _current.id == _heroId &&
        !_current.isVideo &&
        (_quarterTurns[_heroId] ?? 0) == 0 &&
        _heroTransform.value.getMaxScaleOnAxis() <= 1.01;
  }

  @override
  void dispose() {
    _controller.dispose();
    _heroTransform.dispose();
    for (final session in _videoSessions.values) {
      session.dispose();
    }
    super.dispose();
  }

  List<_ViewerMedia> _localItems() {
    final message = widget.message;
    final video = widget.video;
    if (video != null) {
      return [
        _ViewerMedia(
          id: _localId(video, message, 0),
          attachment: video,
          messageId: message?.id ?? '',
          senderId: message?.senderId ?? 0,
          time: message?.time ?? 0,
          caption: message?.text,
        ),
      ];
    }
    return [
      for (var i = widget.photos.length - 1; i >= 0; i--)
        _ViewerMedia(
          id: _localId(widget.photos[i], message, i),
          attachment: widget.photos[i],
          messageId: message?.id ?? '',
          senderId: message?.senderId ?? 0,
          time: message?.time ?? 0,
          caption: message?.text,
        ),
    ];
  }

  List<_ViewerMedia> _feedItems(List<SharedMediaItem> items) {
    final out = <_ViewerMedia>[];
    var start = 0;
    while (start < items.length) {
      var end = start;
      while (end + 1 < items.length &&
          items[end + 1].messageId == items[start].messageId) {
        end++;
      }
      for (var i = end; i >= start; i--) {
        out.add(_ViewerMedia.fromFeed(items[i]));
      }
      start = end + 1;
    }
    return out;
  }

  String _localId(
    MessageAttachment attachment,
    CachedMessage? message,
    int at,
  ) {
    return _feedKey(attachment, message) ?? 'local:${message?.id ?? ''}:$at';
  }

  String? _feedKey(MessageAttachment attachment, CachedMessage? message) {
    if (message == null || widget.chatId == null) return null;
    if (attachment is PhotoAttachment &&
        attachment.photoId == null &&
        (attachment.baseUrl ?? '').isEmpty) {
      return null;
    }
    if (attachment is VideoAttachment &&
        attachment.videoId == null &&
        (attachment.baseUrl ?? '').isEmpty) {
      return null;
    }
    return mediaDedupKey(message.id, attachment);
  }

  _ViewerMedia get _current => _items[_index];

  bool get _feedPending =>
      !_feedLoaded &&
      !_feedFailed &&
      widget.chatId != null &&
      _feedKey(_items[_index].attachment, widget.message) != null;

  Future<void> _loadFeed() async {
    final chatId = widget.chatId;
    final key = _feedKey(_items[_index].attachment, widget.message);
    if (chatId == null || key == null) return;

    final feed = await sharedContentModule.mediaFeedFor(
      chatId: chatId,
      mediaKey: key,
      resolveAnchor: () => _resolveAnchor(chatId),
    );
    if (!mounted) return;
    if (feed == null) {
      setState(() => _feedFailed = true);
      return;
    }

    final items = _feedItems(feed.items);
    final at = items.indexWhere((i) => i.id == key);
    if (at == -1) {
      setState(() => _feedFailed = true);
      return;
    }

    _adoptFeed(items, at, feed);
  }

  void _adoptFeed(List<_ViewerMedia> items, int at, ChatMediaFeed feed) {
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

    _syncHero();
    if (movesPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  Future<void> _loadMore() async {
    final chatId = widget.chatId;
    if (chatId == null || _loadingMore || _reachedEnd || !_feedLoaded) return;
    _loadingMore = true;
    try {
      final feed = await sharedContentModule.loadMoreMedia(
        chatId: chatId,
        resolveAnchor: () => _resolveAnchor(chatId),
      );
      if (!mounted) return;

      final items = _feedItems(feed.items);
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

  Future<Map<String, String>> _loadVideoSources(_ViewerMedia item) async {
    final cached = _videoSourceCache[item.id];
    if (cached != null) return cached;
    final pending = _videoSourceLoads[item.id];
    if (pending != null) return pending;
    if (item.id == _initialMediaId && widget.initialVideoSources.isNotEmpty) {
      _videoSourceCache[item.id] = widget.initialVideoSources;
      return widget.initialVideoSources;
    }
    final video = item.video;
    final videoId = video?.videoId;
    final token = video?.videoToken;
    final chatId = widget.chatId;
    if (videoId == null || token == null || chatId == null) return const {};
    final load = messagesModule.getVideoSources(
      messageId: item.messageId,
      chatId: chatId,
      token: token,
      videoId: videoId,
    );
    _videoSourceLoads[item.id] = load;
    try {
      final sources = await load;
      if (sources.isNotEmpty) _videoSourceCache[item.id] = sources;
      return sources;
    } finally {
      if (identical(_videoSourceLoads[item.id], load)) {
        _videoSourceLoads.remove(item.id);
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _activateVideoSessions();
    _syncHero();
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
    final delta = _current.isVideo ? 3 : 1;
    setState(() {
      _quarterTurns[_current.id] =
          ((_quarterTurns[_current.id] ?? 0) + delta) % 4;
    });
    _syncHero();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  _VideoPlaybackSession _videoSessionFor(_ViewerMedia item) {
    final cached = _videoSessions.remove(item.id);
    if (cached != null) {
      _videoSessions[item.id] = cached;
      return cached;
    }
    final session = _VideoPlaybackSession(
      attachment: item.video!,
      initialQuality: item.id == _initialMediaId
          ? widget.initialVideoQuality
          : null,
      loadSources: () => _loadVideoSources(item),
      active: item.id == _current.id,
    );
    _videoSessions[item.id] = session;
    _trimVideoSessions();
    return session;
  }

  void _activateVideoSessions() {
    for (final entry in _videoSessions.entries) {
      entry.value.setActive(entry.key == _current.id);
    }
  }

  void _trimVideoSessions() {
    while (_videoSessions.length > _maxCachedVideoPlayers) {
      final candidate = _videoSessions.entries.firstWhere(
        (entry) => !entry.value.active,
        orElse: () => _videoSessions.entries.first,
      );
      _videoSessions.remove(candidate.key)?.dispose();
    }
  }

  String _cacheNameFor(PhotoAttachment photo, String url) =>
      'photo_${photo.photoId ?? (url.hashCode & 0x7fffffff)}.jpg';

  String _downloadSource(_ViewerMedia item) {
    final sourceName = widget.sourceName?.trim();
    if (sourceName != null && sourceName.isNotEmpty) return sourceName;
    return ContactCache.get(item.senderId) ?? '';
  }

  DownloadMetadata _photoDownload(
    _ViewerMedia item,
    PhotoAttachment photo,
    String cacheName,
  ) => DownloadMetadata(
    cacheName: cacheName,
    kind: DownloadKind.photo,
    sourceName: _downloadSource(item),
    thumbnailUrl: photo.baseUrl ?? photo.previewData,
    expectedSize: photo.size ?? 0,
    chatId: widget.chatId,
    messageId: item.messageId.isEmpty ? null : item.messageId,
    messageTime: item.time,
  );

  String _videoCacheName(_ViewerMedia item, VideoAttachment video) =>
      'video_${video.videoId ?? item.messageId}.mp4';

  DownloadMetadata _videoDownload(
    _ViewerMedia item,
    VideoAttachment video,
    String cacheName,
  ) => DownloadMetadata(
    cacheName: cacheName,
    kind: DownloadKind.video,
    sourceName: _downloadSource(item),
    thumbnailUrl: video.thumbnail ?? video.baseUrl ?? video.previewData,
    expectedSize: video.size ?? 0,
    chatId: widget.chatId,
    messageId: item.messageId.isEmpty ? null : item.messageId,
    messageTime: item.time,
  );

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

  Future<File?> _videoFileFor(_ViewerMedia item) async {
    final video = item.video;
    if (video == null) return null;
    final sources = await _loadVideoSources(item);
    if (sources.isEmpty) return null;
    final sessionQuality = _videoSessions[item.id]?.quality;
    final url = sessionQuality != null
        ? sources[sessionQuality] ?? sources.values.first
        : sources.values.first;
    return MediaCache.getOrDownload(_videoCacheName(item, video), url);
  }

  Future<void> _save() async {
    final photo = _current.photo;
    if (photo == null || _saving) return;
    setState(() => _saving = true);
    final localPath = photo.localPath;
    final url = photo.baseUrl ?? '';
    final cacheName = _cacheNameFor(photo, url);

    final MediaSaveResult result;
    if (localPath != null) {
      result = await saveLocalImage(localPath);
    } else if (url.isEmpty) {
      result = const MediaSaveResult(ok: false, error: 'нет ссылки');
    } else {
      result = await saveMediaFile(
        cacheName: cacheName,
        resolveUrl: () async => url,
        saveName: 'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg',
        kind: SaveMediaKind.image,
        download: _photoDownload(_current, photo, cacheName),
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
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final item = _current;
      final now = DateTime.now().millisecondsSinceEpoch;
      File? file;
      DownloadMetadata? download;
      String saveName;

      final photo = item.photo;
      final video = item.video;
      if (photo != null) {
        file = await _fileFor(photo);
        final url = photo.baseUrl ?? '';
        final cacheName = _cacheNameFor(photo, url);
        if (url.isNotEmpty) download = _photoDownload(item, photo, cacheName);
        saveName = 'IMG_$now.jpg';
      } else if (video != null) {
        file = await _videoFileFor(item);
        final cacheName = _videoCacheName(item, video);
        download = _videoDownload(item, video, cacheName);
        saveName = 'VID_$now.mp4';
      } else {
        file = null;
        saveName = 'media_$now';
      }

      if (!mounted) return;
      if (file == null) {
        showCustomNotification(context, 'Не удалось загрузить медиа');
        return;
      }
      final result = await saveFileAs(
        source: file,
        fileName: saveName,
        dialogTitle: AppLocalizations.of(context)!.photoViewerSaveAs,
      );
      if (!mounted || result.cancelled) return;
      if (!result.saved) {
        showCustomNotification(context, 'Не удалось сохранить файл');
        return;
      }
      if (download != null) {
        try {
          await DownloadHistory.record(download, file);
        } catch (_) {}
      }
      if (mounted) showCustomNotification(context, 'Файл сохранён');
    } catch (_) {
      if (mounted) showCustomNotification(context, 'Не удалось сохранить файл');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openMenu(BuildContext anchorContext) {
    final actions = widget.actions;
    if (actions == null && !_current.isVideo) return;
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final l10n = AppLocalizations.of(context)!;
    final item = _current;

    showChatMenu(
      context: context,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      items: [
        if (actions?.goToMessage != null)
          ChatMenuItem(
            icon: Symbols.visibility,
            label: l10n.sharedGoToMessage,
            onTap: () => _popThen(
              () => actions!.goToMessage!(item.messageId, item.time),
            ),
          ),
        if (actions?.forward != null)
          ChatMenuItem(
            icon: Symbols.forward,
            label: l10n.msgActionsForward,
            onTap: () => _popThen(() => actions!.forward!(item.messageId)),
          ),
        if (actions?.delete != null)
          ChatMenuItem(
            icon: Symbols.delete,
            label: l10n.msgActionsDelete,
            destructive: true,
            dividerAfter: true,
            onTap: () =>
                _popThen(() => actions!.delete!(item.messageId, item.senderId)),
          ),
        ChatMenuItem(
          icon: Symbols.download,
          label: l10n.photoViewerSaveAs,
          onTap: _saveAs,
        ),
        if (actions?.viewAllMedia != null)
          ChatMenuItem(
            icon: Symbols.grid_view,
            label: l10n.mediaViewerViewAll,
            onTap: () => _popThen(actions!.viewAllMedia!),
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
    final hasMenu = _current.isVideo || !(widget.actions?.isEmpty ?? true);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(-1),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageView.builder(
                  key: ValueKey(_pager),
                  controller: _controller,
                  reverse: true,
                  itemCount: _items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => _buildPage(i),
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
                        if (_index < _items.length - 1)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _arrow(Symbols.chevron_left, () => _step(1)),
                          ),
                        if (_index > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: _arrow(
                              Symbols.chevron_right,
                              () => _step(-1),
                            ),
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

  Widget _buildPage(int i) {
    final item = _items[i];
    final video = item.video;
    if (video != null) {
      return _VideoSurface(
        key: ValueKey('video:${item.id}'),
        session: _videoSessionFor(item),
        quarterTurns: _quarterTurns[item.id] ?? 0,
        onSurfaceTap: _toggleChrome,
      );
    }

    final isHero = widget.hero != null && item.id == _heroId;
    final page = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleChrome,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        transformationController: isHero ? _heroTransform : null,
        child: Center(
          child: RotatedBox(
            quarterTurns: _quarterTurns[item.id] ?? 0,
            child: _buildImage(item.photo!),
          ),
        ),
      ),
    );
    return isHero ? PhotoHeroTarget(child: page) : page;
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
    final videoSession = _current.isVideo ? _videoSessionFor(_current) : null;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 10),
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
          if (videoSession != null) ...[
            _buildVideoAttachment(videoSession, caption),
            const SizedBox(height: 12),
          ] else if (caption != null && caption.isNotEmpty) ...[
            _buildCaption(caption),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildInfo(l10n)),
              if (!_current.isVideo)
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
    return _ViewerGlassSurface(child: _buildCaptionContent(caption));
  }

  Widget _buildVideoAttachment(_VideoPlaybackSession session, String? caption) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => _ViewerGlassSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _VideoControlPanel(
              value: session.value,
              fallbackDuration: Duration(
                milliseconds: session.attachment.duration ?? 0,
              ),
              dragValue: session.dragValue,
              volume: session.volume,
              speed: session.speed,
              quality: session.quality,
              qualities: session.qualities,
              onTogglePlay: session.togglePlay,
              onVolumeChanged: session.setVolume,
              onSpeedChanged: session.setSpeed,
              onQualityChanged: session.switchQuality,
              onSeekChanged: session.setDragValue,
              onSeekEnd: session.seekTo,
            ),
            if (caption != null && caption.isNotEmpty) ...[
              Divider(
                height: 1,
                thickness: 0.5,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              _buildCaptionContent(caption),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionContent(String caption) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      width: double.infinity,
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
    );
  }

  Widget _buildInfo(AppLocalizations l10n) {
    final item = _current;
    if (item.messageId.isEmpty) return const SizedBox.shrink();
    final total = _feedLoaded ? _total : _items.length;
    final position = _feedLoaded ? _total - _index : _items.length - _index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_feedPending)
          const _CounterShimmer()
        else
          Text(
            widget.isFile
                ? l10n.photoViewerCounterFile(total)
                : l10n.mediaViewerCounter(position, total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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

  String _sentLine(AppLocalizations l10n, _ViewerMedia item) {
    final sourceName = widget.sourceName?.trim();
    final sender = sourceName != null && sourceName.isNotEmpty
        ? sourceName
        : ContactCache.get(item.senderId) ?? '';
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

class _VideoPlaybackSession extends ChangeNotifier {
  final VideoAttachment attachment;
  final String? initialQuality;
  final Future<Map<String, String>> Function() loadSources;

  VideoPlayerController? _controller;
  Map<String, String> _sources = const {};
  String? _quality;
  bool _error = false;
  bool _loading = true;
  double? _dragValue;
  double _volume = 1;
  double _speed = 1;
  int _loadGeneration = 0;
  bool _active;
  late bool _hasBeenActive = _active;
  late bool _playWhenActive = _active;
  bool _wasCompleted = false;
  bool _disposed = false;

  _VideoPlaybackSession({
    required this.attachment,
    required this.initialQuality,
    required this.loadSources,
    required bool active,
  }) : _active = active {
    unawaited(_prepare());
  }

  VideoPlayerValue? get value {
    final controller = _controller;
    return controller != null && controller.value.isInitialized
        ? controller.value
        : null;
  }

  bool get loading => _loading;
  bool get error => _error;
  bool get completed => value?.isCompleted ?? false;
  bool get buffering => (value?.isBuffering ?? false) && !completed;
  bool get active => _active;
  double? get dragValue => _dragValue;
  double get volume => _volume;
  double get speed => _speed;
  String? get quality => _quality;
  List<String> get qualities => _sources.keys.toList(growable: false);

  Future<void> _prepare() async {
    final sources = await loadSources();
    if (_disposed) return;
    if (sources.isEmpty) {
      _error = true;
      _loading = false;
      _notify();
      return;
    }
    _sources = sources;
    final initial = initialQuality;
    final quality = initial != null && sources.containsKey(initial)
        ? initial
        : sources.keys.first;
    await _load(quality, wasPlaying: _active);
  }

  Future<void> _load(
    String quality, {
    Duration? position,
    bool wasPlaying = true,
  }) async {
    final url = _sources[quality];
    if (url == null) return;
    final generation = ++_loadGeneration;
    final old = _controller;
    final previousQuality = _quality;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    var installed = false;
    _quality = quality;
    _error = false;
    _loading = true;
    _notify();

    try {
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      if (generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(_volume);
      await controller.setPlaybackSpeed(_speed);
      if (position != null) await controller.seekTo(position);
      if (generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onTick);
      _controller = controller;
      _wasCompleted = controller.value.isCompleted;
      installed = true;
      old?.removeListener(_onTick);
      try {
        await old?.dispose();
      } catch (_) {}
      _playWhenActive = wasPlaying || _playWhenActive;
      if (_playWhenActive && _active) await controller.play();
      _loading = false;
      _notify();
    } catch (_) {
      if (!installed) await controller.dispose();
      if (generation == _loadGeneration && !_disposed) {
        if (!installed) {
          _quality = previousQuality;
          _error = old == null || !old.value.isInitialized;
        }
        _loading = false;
        _notify();
      }
    }
  }

  void _onTick() {
    final isCompleted = completed;
    if (isCompleted && !_wasCompleted) _playWhenActive = false;
    _wasCompleted = isCompleted;
    _notify();
  }

  Future<void> switchQuality(String quality) async {
    if (quality == _quality) return;
    final controller = _controller;
    await _load(
      quality,
      position: controller?.value.position,
      wasPlaying: controller?.value.isPlaying ?? _active,
    );
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    _notify();
    await _controller?.setPlaybackSpeed(speed);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    _notify();
    await _controller?.setVolume(volume);
  }

  void togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      _playWhenActive = false;
      controller.pause();
    } else {
      _playWhenActive = true;
      controller.play();
    }
  }

  void setDragValue(double value) {
    _dragValue = value;
    _notify();
  }

  void seekTo(double value) {
    _controller?.seekTo(Duration(milliseconds: value.round()));
    _dragValue = null;
    _notify();
  }

  void setActive(bool active) {
    if (_active == active) return;
    _active = active;
    final controller = _controller;
    if (!active) {
      if (controller != null && controller.value.isInitialized) {
        _playWhenActive = controller.value.isPlaying;
        controller.pause();
      }
      return;
    }
    if (!_hasBeenActive) {
      _hasBeenActive = true;
      _playWhenActive = true;
    }
    if (_playWhenActive &&
        controller != null &&
        controller.value.isInitialized) {
      controller.play();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }
}

class _VideoSurface extends StatelessWidget {
  final _VideoPlaybackSession session;
  final int quarterTurns;
  final VoidCallback onSurfaceTap;

  const _VideoSurface({
    super.key,
    required this.session,
    required this.quarterTurns,
    required this.onSurfaceTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSurfaceTap,
        child: Stack(
          children: [
            Center(
              child: RotatedBox(
                key: const ValueKey('video-rotation'),
                quarterTurns: quarterTurns,
                child: session.error
                    ? const Icon(Symbols.error, color: Colors.white54, size: 64)
                    : session.value != null
                    ? AspectRatio(
                        aspectRatio: session.value!.aspectRatio,
                        child: VideoPlayer(session._controller!),
                      )
                    : _buildVideoPreview(session.attachment),
              ),
            ),
            if (session.loading || session.buffering)
              const Center(child: SmallSpinner(size: 36, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview(VideoAttachment attachment) {
    final url =
        attachment.thumbnail ??
        attachment.baseUrl ??
        attachment.previewData ??
        '';
    if (url.isEmpty) {
      return const Icon(Symbols.videocam, color: Colors.white38, size: 64);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) =>
          const Icon(Symbols.videocam, color: Colors.white38, size: 64),
    );
  }
}

class _ViewerGlassSurface extends StatelessWidget {
  final Widget child;

  const _ViewerGlassSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          width: double.infinity,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(12),
            frostTint: Colors.black.withValues(alpha: 0.28),
            frostSigma: AppFrost.panelSigma,
            liquidTint: Colors.black.withValues(alpha: 0.28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _VideoControlPanel extends StatelessWidget {
  final VideoPlayerValue? value;
  final Duration fallbackDuration;
  final double? dragValue;
  final double volume;
  final double speed;
  final String? quality;
  final List<String> qualities;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;

  const _VideoControlPanel({
    required this.value,
    required this.fallbackDuration,
    required this.dragValue,
    required this.volume,
    required this.speed,
    required this.quality,
    required this.qualities,
    required this.onTogglePlay,
    required this.onVolumeChanged,
    required this.onSpeedChanged,
    required this.onQualityChanged,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    final duration = value?.duration ?? fallbackDuration;
    final position = value?.position ?? Duration.zero;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = position.inMilliseconds.toDouble().clamp(0, maxMs);
    final sliderValue = dragValue ?? positionMs.toDouble();
    final isPlaying = value?.isPlaying ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        volume == 0 ? Symbols.volume_off : Symbols.volume_up,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(
                        width: 112,
                        child: _ViewerSlider(
                          value: volume,
                          max: 1,
                          onChanged: onVolumeChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: IconButton(
                    key: const ValueKey('video-play-toggle'),
                    icon: Icon(
                      isPlaying ? Symbols.pause : Symbols.play_arrow,
                      color: Colors.white,
                      fill: 1,
                    ),
                    onPressed: onTogglePlay,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _VideoSettingsButton(
                    speed: speed,
                    quality: quality,
                    qualities: qualities,
                    onSpeedChanged: onSpeedChanged,
                    onQualityChanged: onQualityChanged,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  _formatViewerDuration(position),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              Expanded(
                child: _ViewerSlider(
                  value: maxMs <= 0
                      ? 0
                      : sliderValue.clamp(0, maxMs).toDouble(),
                  max: maxMs <= 0 ? 1 : maxMs,
                  onChanged: maxMs <= 0 ? null : onSeekChanged,
                  onChangeEnd: maxMs <= 0 ? null : onSeekEnd,
                ),
              ),
              SizedBox(
                width: 42,
                child: Text(
                  _formatViewerDuration(duration),
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewerSlider extends StatelessWidget {
  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _ViewerSlider({
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white30,
        thumbColor: Colors.white,
      ),
      child: Slider(
        min: 0,
        max: max,
        value: value.clamp(0, max).toDouble(),
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

String _formatViewerDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final minutes = seconds ~/ 60;
  if (minutes >= 60) {
    return '${minutes ~/ 60}:${pad2(minutes % 60)}:${pad2(seconds % 60)}';
  }
  return '${pad2(minutes)}:${pad2(seconds % 60)}';
}

class _VideoSettingsButton extends StatelessWidget {
  static const speeds = [0.5, 1.0, 1.2, 1.5, 1.7, 2.0];

  final double speed;
  final String? quality;
  final List<String> qualities;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<String> onQualityChanged;

  const _VideoSettingsButton({
    required this.speed,
    required this.quality,
    required this.qualities,
    required this.onSpeedChanged,
    required this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      key: const ValueKey('video-settings'),
      color: const Color(0xFF292326),
      tooltip: l10n.videoViewerSettings,
      icon: const Icon(Symbols.settings, color: Colors.white),
      onSelected: (value) {
        if (value.startsWith('speed:')) {
          onSpeedChanged(double.parse(value.substring(6)));
        } else if (value.startsWith('quality:')) {
          onQualityChanged(value.substring(8));
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 38,
          child: Text(
            l10n.videoViewerSpeed,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        for (final value in speeds)
          PopupMenuItem<String>(
            value: 'speed:$value',
            height: 38,
            child: _SettingChoice(
              label: value == 1
                  ? '1.0x'
                  : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}x',
              selected: value == speed,
            ),
          ),
        if (qualities.length > 1) const PopupMenuDivider(),
        if (qualities.length > 1)
          PopupMenuItem<String>(
            enabled: false,
            height: 38,
            child: Text(
              l10n.videoViewerQuality,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        if (qualities.length > 1)
          for (final value in qualities)
            PopupMenuItem<String>(
              value: 'quality:$value',
              height: 38,
              child: _SettingChoice(label: value, selected: value == quality),
            ),
      ],
    );
  }
}

class _SettingChoice extends StatelessWidget {
  final String label;
  final bool selected;

  const _SettingChoice({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
        if (selected)
          const Icon(Symbols.check, color: Color(0xFFE68ABA), size: 18),
      ],
    );
  }
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
          width: 112,
          height: 17,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}
