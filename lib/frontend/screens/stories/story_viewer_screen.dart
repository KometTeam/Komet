import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/haptics.dart';
import '../../../backend/modules/complaints.dart';
import '../../../backend/modules/stories.dart';
import '../../../backend/modules/story_reply_sender.dart';
import '../../../core/media/thumbhash.dart';
import '../../../core/media/video_preloader.dart';
import '../../../core/utils/media_saver.dart';
import '../../../core/media/video_request_headers.dart';
import '../../../core/utils/media_cache.dart';
import '../../../main.dart' show api, appRouteObserver, storiesModule;
import '../../../models/story.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import '../../widgets/max_link_nav.dart';
import '../../widgets/route_probe.dart';
import '../chats/profile_action_sheets.dart';
import '../../widgets/small_spinner.dart';
import 'story_owner_info.dart';
import '../../../core/config/app_frost.dart';
import '../../../core/config/app_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/official_name.dart';

const Duration _photoDuration = Duration(seconds: 5);

Offset? storyOriginOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// Открывает вьюер историй. Если задан [origin] (глобальный центр нажатого
/// кольца) — открытие анимируется расширяющимся из этой точки кругом; иначе —
/// масштабным «зумом».
Future<void> openStoryViewer(
  BuildContext context, {
  required List<StoryPreview> previews,
  int initialIndex = 0,
  Map<int, StoryOwnerInfo> ownerOverrides = const {},
  Map<int, List<Story>> initialStories = const {},
  Offset? origin,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      allowSnapshotting: false,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => StoryViewerScreen(
        previews: previews,
        initialIndex: initialIndex,
        ownerOverrides: ownerOverrides,
        initialStories: initialStories,
      ),
      transitionsBuilder: (context, animation, _, child) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final closing =
                animation.status == AnimationStatus.reverse ||
                animation.status == AnimationStatus.dismissed;
            // Круговое раскрытие — только на открытии; закрытие всегда
            // мягким fade + scale (круг «схлопыванием» резал кадр).
            if (origin != null && !closing) {
              final f = Curves.easeOutCubic.transform(animation.value);
              return ClipPath(
                clipper: _CircleRevealClipper(center: origin, fraction: f),
                child: child,
              );
            }
            final v = animation.value;
            return Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.92 + 0.08 * v, child: child),
            );
          },
        );
      },
    ),
  );
}

class _CircleRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double fraction;

  const _CircleRevealClipper({required this.center, required this.fraction});

  @override
  Path getClip(Size size) {
    final farthest = Offset(
      center.dx < size.width / 2 ? size.width : 0,
      center.dy < size.height / 2 ? size.height : 0,
    );
    final maxRadius = (farthest - center).distance;
    final radius = ui.lerpDouble(28, maxRadius, fraction.clamp(0.0, 1.0))!;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircleRevealClipper oldClipper) =>
      oldClipper.fraction != fraction || oldClipper.center != center;
}

class StoryViewerScreen extends StatefulWidget {
  final List<StoryPreview> previews;
  final int initialIndex;
  final Map<int, StoryOwnerInfo> ownerOverrides;
  final Map<int, List<Story>> initialStories;

  const StoryViewerScreen({
    super.key,
    required this.previews,
    this.initialIndex = 0,
    this.ownerOverrides = const {},
    this.initialStories = const {},
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late final PageController _ownerController;
  late int _ownerIndex;
  late final AnimationController _photoProgress;

  final Map<int, List<Story>> _stories = {};
  final Map<int, bool> _loading = {};
  final Set<int> _marked = {};

  final ValueNotifier<double> _segment = ValueNotifier<double>(0);
  int _storyIndex = 0;
  bool _paused = false;

  double _dragDy = 0;
  bool _dragging = false;
  static const double _dismissThreshold = 120;

  VideoPlayerController? _video;
  final ValueNotifier<double?> _videoLoading = ValueNotifier<double?>(null);
  int _videoEpoch = 0;

  int _myId = 0;
  bool _deleting = false;
  ModalRoute<Object?>? _route;
  bool _resumeWhenUncovered = false;

  StoryPreview get _owner => widget.previews[_ownerIndex];

  List<Story> get _ownerStories => _stories[_owner.owner.ownerId] ?? const [];

  Story? get _currentStory {
    final list = _ownerStories;
    if (_storyIndex < 0 || _storyIndex >= list.length) return null;
    return list[_storyIndex];
  }

  @override
  void initState() {
    super.initState();
    _ownerIndex = widget.initialIndex.clamp(0, widget.previews.length - 1);
    _ownerController = PageController(initialPage: _ownerIndex);
    _stories.addAll(widget.initialStories);
    _photoProgress = AnimationController(vsync: this, duration: _photoDuration)
      ..addListener(() => _segment.value = _photoProgress.value)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      });
    _loadOwner(_ownerIndex, autostart: true);
    unawaited(_loadMyId());
  }

  Future<void> _loadMyId() async {
    final profile = await AppDatabase.loadActiveProfile();
    if (!mounted || profile == null) return;
    setState(() => _myId = profile.id);
  }

  bool _isOwnStory(Story? story) =>
      story != null &&
      _myId != 0 &&
      story.owner.isUser &&
      story.owner.ownerId == _myId;

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _disposeVideo();
    _videoLoading.dispose();
    _photoProgress.dispose();
    _segment.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  void _disposeVideo() {
    _videoEpoch++;
    _videoLoading.value = null;
    _video?.removeListener(_onVideoTick);
    _video?.dispose();
    _video = null;
  }

  Future<void> _loadOwner(int index, {bool autostart = false}) async {
    final ownerId = widget.previews[index].owner.ownerId;
    if (_stories.containsKey(ownerId)) {
      if (autostart) _startStory(_resumeIndex(index, _stories[ownerId]!));
      return;
    }
    setState(() => _loading[ownerId] = true);
    final stories = await storiesModule.getByOwner(
      widget.previews[index].owner,
    );
    if (!mounted) return;
    setState(() {
      _stories[ownerId] = stories;
      _loading[ownerId] = false;
    });
    if (autostart && index == _ownerIndex) {
      _startStory(_resumeIndex(index, stories));
    }
  }

  int _resumeIndex(int index, List<Story> stories) {
    if (stories.isEmpty) return 0;
    final preview = widget.previews[index];
    final read = preview.readCount;
    final firstUnread = (read > 0 && read < stories.length) ? read : 0;
    final savedId = storiesModule.lastViewedStoryId(preview.owner.ownerId);
    if (savedId == null) return firstUnread;
    final saved = stories.indexWhere((s) => s.id == savedId);
    if (saved <= firstUnread || saved >= stories.length - 1) return firstUnread;
    return saved;
  }

  void _startStory(int index) {
    _disposeVideo();
    _photoProgress.stop();
    _segment.value = 0;
    _paused = false;
    setState(() => _storyIndex = index);

    final story = _currentStory;
    if (story == null) return;
    storiesModule.setLastViewed(story.owner.ownerId, story.id);

    final media = story.media;
    if (media != null && media.isVideo && (media.url?.isNotEmpty ?? false)) {
      unawaited(_startVideo(story, media.url!));
    } else {
      _markViewed(story);
      _photoProgress.forward(from: 0);
    }
    _preloadAfter(index);
  }

  static Map<String, String> _cdnHeaders(Uri uri) =>
      videoRequestHeaders(uri, sessionUserAgent: api.session?.userAgent());

  static String _videoCacheName(Story story) =>
      'story_${story.owner.ownerId}_${story.id}.mp4';

  static const int _storyVideoMaxBytes = 64 * 1024 * 1024;

  void _cacheVideo(Story story, String url) {
    unawaited(
      VideoPreloader.load(
        _videoCacheName(story),
        () async => url,
        headers: _cdnHeaders,
        maxBytes: _storyVideoMaxBytes,
        cancelled: () => !mounted,
      ),
    );
  }

  Future<void> _startVideo(Story story, String url) async {
    final epoch = _videoEpoch;
    _videoLoading.value = 0;
    final cached = await MediaCache.existing(_videoCacheName(story));
    if (!mounted || epoch != _videoEpoch) return;
    final uri = Uri.parse(url);
    final controller = cached != null
        ? VideoPlayerController.file(cached)
        : VideoPlayerController.networkUrl(uri, httpHeaders: _cdnHeaders(uri));
    if (cached == null) _cacheVideo(story, url);
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted || _video != controller) {
        controller.dispose();
        return;
      }
      controller.addListener(_onVideoTick);
      _videoLoading.value = null;
      _markViewed(story);
      if (!_paused) await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (_video == controller) {
        _disposeVideo();
        _markViewed(story);
        _photoProgress.forward(from: 0);
      }
    }
  }

  void _preloadAfter(int index) {
    final next = index + 1 < _ownerStories.length
        ? _ownerStories[index + 1]
        : null;
    final media = next?.media;
    final url = media?.url;
    if (next == null || media == null || !media.isVideo) return;
    if (url == null || url.isEmpty) return;
    _cacheVideo(next, url);
  }

  void _onVideoTick() {
    final c = _video;
    if (c == null || !c.value.isInitialized) return;
    final total = c.value.duration.inMilliseconds;
    if (total <= 0) return;
    _segment.value = (c.value.position.inMilliseconds / total).clamp(0.0, 1.0);
    if (c.value.position >= c.value.duration && !c.value.isPlaying) {
      _advance();
    }
  }

  void _markViewed(Story story) {
    if (story.id == 0 || _marked.contains(story.id)) return;
    _marked.add(story.id);
    storiesModule.mark(story.owner, story.id);
  }

  void _advance() {
    Haptics.selection();
    if (_storyIndex + 1 < _ownerStories.length) {
      _startStory(_storyIndex + 1);
    } else {
      storiesModule.clearLastViewed(_owner.owner.ownerId);
      _nextOwner();
    }
  }

  void _rewind() {
    Haptics.selection();
    if (_storyIndex > 0) {
      _startStory(_storyIndex - 1);
    } else {
      _prevOwner();
    }
  }

  void _nextOwner() {
    if (_ownerIndex + 1 < widget.previews.length) {
      _ownerController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _close();
    }
  }

  void _prevOwner() {
    if (_ownerIndex > 0) {
      _ownerController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onOwnerPageChanged(int index) {
    _disposeVideo();
    _photoProgress.stop();
    _segment.value = 0;
    setState(() {
      _ownerIndex = index;
      _storyIndex = 0;
    });
    _loadOwner(index, autostart: true);
  }

  void _setPaused(bool paused) {
    if (_paused == paused) return;
    setState(() => _paused = paused);
    final video = _video;
    if (video != null && video.value.isInitialized) {
      paused ? video.pause() : video.play();
    } else if (_videoLoading.value == null) {
      paused ? _photoProgress.stop() : _photoProgress.forward();
    }
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _setPaused(true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() => _dragDy = (_dragDy + d.delta.dy).clamp(-40.0, 600.0));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dragDy > _dismissThreshold || v > 700) {
      _close();
      return;
    }
    setState(() {
      _dragging = false;
      _dragDy = 0;
    });
    _setPaused(false);
  }

  void _onRoute(ModalRoute<Object?> route) {
    _route = route;
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _pauseUntilUncovered();

  @override
  void didPopNext() {
    if (!_resumeWhenUncovered) return;
    _resumeWhenUncovered = false;
    _setPaused(false);
  }

  void _pauseUntilUncovered() {
    if (_paused) return;
    _resumeWhenUncovered = true;
    _setPaused(true);
  }

  void _close() {
    final route = _route;
    if (route == null || route.isCurrent) {
      Navigator.of(context).maybePop();
    } else if (route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  Future<void> _openOwnerProfile() async {
    final owner = _owner.owner;
    _pauseUntilUncovered();
    final opened = owner.isUser
        ? await openContactById(context, owner.ownerId)
        : await openChatById(context, owner.ownerId);
    if (!mounted || (opened && _route?.isCurrent == false)) return;
    didPopNext();
  }

  // #***! меню своей истории, пока открыто — история на паузе
  Future<void> _openStoryMenu() async {
    final story = _currentStory;
    if (story == null || _deleting) return;
    final wasPaused = _paused;
    _setPaused(true);
    final delete = await _pickDelete();
    if (!mounted) return;
    final confirmed = delete && await _confirmDelete();
    if (!mounted) return;
    if (confirmed) {
      await _deleteStory(story);
      if (!mounted) return;
    }
    if (!wasPaused && _currentStory != null) _setPaused(false);
  }

  Future<bool> _pickDelete() async {
    final picked = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: ListTile(
            leading: Icon(Symbols.delete, color: cs.error),
            title: Text(
              AppLocalizations.of(sheetContext)!.msgActionsDelete,
              style: TextStyle(color: cs.error),
            ),
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
        );
      },
    );
    return picked ?? false;
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showBlurredConfirm(
      context,
      title: l10n.storyViewerDeleteTitle,
      message: l10n.storyViewerDeleteMessage,
      confirmLabel: l10n.msgActionsDelete,
      cancelLabel: l10n.chatInfoActionCancel,
      destructive: true,
    );
    return choice.confirmed;
  }

  // #***! после удаления идём к следующей истории, последнюю — закрываем
  Future<void> _deleteStory(Story story) async {
    setState(() => _deleting = true);
    try {
      await storiesModule.deleteStories(story.owner, [story.id]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      final reason = e is PacketError ? e.message : null;
      final l10n = AppLocalizations.of(context)!;
      showCustomNotification(
        context,
        reason == null || reason.isEmpty
            ? l10n.storyViewerDeleteFailed
            : l10n.storyViewerDeleteFailedWithReason(reason),
      );
      return;
    }
    if (!mounted) return;
    final ownerId = story.owner.ownerId;
    final left = _ownerStories.where((s) => s.id != story.id).toList();
    setState(() {
      _deleting = false;
      _stories[ownerId] = left;
    });
    if (left.isEmpty) {
      _disposeVideo();
      _photoProgress.stop();
      _nextOwner();
      return;
    }
    _startStory(_storyIndex.clamp(0, left.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return RouteProbe(
      onRoute: _onRoute,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _dragDy),
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: PageView.builder(
                controller: _ownerController,
                onPageChanged: _onOwnerPageChanged,
                itemCount: widget.previews.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final content = index == _ownerIndex
                      ? _buildActiveOwner()
                      : _OwnerCover(
                          preview: widget.previews[index],
                          overrideInfo:
                              widget.ownerOverrides[widget
                                  .previews[index]
                                  .owner
                                  .ownerId],
                        );
                  return _CubePage(
                    controller: _ownerController,
                    index: index,
                    fallbackPage: _ownerIndex.toDouble(),
                    child: content,
                  );
                },
              ),
              builder: (context, dy, child) {
                final p = (dy.abs() / 320).clamp(0.0, 1.0);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 1.0 - p * 0.7),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(
                        scale: 1.0 - p * 0.12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(p * 26),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOwner() {
    final ownerId = _owner.owner.ownerId;
    final loading = _loading[ownerId] ?? false;
    final stories = _ownerStories;
    final story = _currentStory;

    final card = LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapUp: (details) {
          if (details.localPosition.dx < constraints.maxWidth * 0.32) {
            _rewind();
          } else {
            _advance();
          }
        },
        onLongPressStart: (_) => _setPaused(true),
        onLongPressEnd: (_) => _setPaused(false),
        child: _buildCardContent(ownerId, loading, stories, story),
      ),
    );
    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: _StoryFrame(card: card, bottom: _buildBottomBar(story)),
    );
  }

  Widget _buildCardContent(
    int ownerId,
    bool loading,
    List<Story> stories,
    Story? story,
  ) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: story?.media != null
                ? KeyedSubtree(
                    key: ValueKey('$ownerId:${story!.id}'),
                    child: _StoryMediaView(
                      media: story.media!,
                      video: _video,
                      loading: _videoLoading,
                    ),
                  )
                : (loading
                      ? const SizedBox.expand(key: ValueKey('loading'))
                      : Center(
                          key: const ValueKey('empty'),
                          child: Text(
                            AppLocalizations.of(context)!.storyViewerEmpty,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )),
          ),
          const _TopScrim(),
          if (loading)
            const Center(child: SmallSpinner(size: 28, color: Colors.white)),
          Column(
            children: [
              _buildProgressBars(stories.length),
              _buildHeader(),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Story? story) {
    if (story == null) return const SizedBox.shrink();
    if (_isOwnStory(story)) {
      final views = story.viewsCount;
      if (views == null) return const SizedBox.shrink();
      return Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Symbols.visibility, color: Colors.white70, size: 20),
          const SizedBox(width: 6),
          Text(
            '$views',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    }
    if (!story.allowsReplies && !story.allowsReactions) {
      return const SizedBox.shrink();
    }
    return _StoryReplyBar(
      key: ValueKey('reply-${story.owner.ownerId}'),
      canReply: story.allowsReplies,
      canLike: story.allowsReactions,
      liked: story.liked,
      onLike: () => _toggleLike(story),
      onSend: (text) => _sendReply(story, text),
      onTyping: _holdForInput,
    );
  }

  bool _opensProfile(Story story) => !_isOwnStory(story) && story.allowsProfile;

  bool _hasMenu(Story story) =>
      _isOwnStory(story) ||
      _opensProfile(story) ||
      story.allowsHidingAuthor ||
      story.allowsSaving ||
      story.allowsComplaints;

  void _holdForInput(bool typing) {
    if (typing) {
      _pauseUntilUncovered();
    } else {
      didPopNext();
    }
  }

  void _replaceLocal(Story updated) {
    final ownerId = updated.owner.ownerId;
    final list = _stories[ownerId];
    if (list == null) return;
    final index = list.indexWhere((s) => s.id == updated.id);
    if (index < 0) return;
    setState(() => _stories[ownerId] = [...list]..[index] = updated);
  }

  Future<void> _toggleLike(Story story) async {
    Haptics.selection();
    final next = story.liked ? null : StoriesModule.like;
    _replaceLocal(
      next == null
          ? story.copyWith(clearReaction: true)
          : story.copyWith(reaction: next),
    );
    final ok = await storiesModule.react(story, next);
    if (!mounted || ok) return;
    _replaceLocal(story);
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.storyLikeFailed,
    );
  }

  Future<bool> _sendReply(Story story, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final result = await StoryReplySender.send(story, trimmed);
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    switch (result.outcome) {
      case StoryReplyOutcome.sent:
        final navigatorContext = Navigator.of(context).context;
        showCustomNotification(
          context,
          l10n.storyReplySent,
          action: (
            label: l10n.storyReplyOpenChat,
            onTap: () {
              if (mounted) _close();
              unawaited(openChatById(navigatorContext, result.chatId));
            },
          ),
        );
        return true;
      case StoryReplyOutcome.encryptedChat:
        showCustomNotification(context, l10n.storyReplyEncrypted);
        return false;
      case StoryReplyOutcome.failed:
        showCustomNotification(context, l10n.storyReplyFailed);
        return false;
    }
  }

  Future<void> _openForeignMenu() async {
    final story = _currentStory;
    if (story == null) return;
    _pauseUntilUncovered();
    final l10n = AppLocalizations.of(context)!;
    final action = await showModalBottomSheet<_StoryAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        Widget item(_StoryAction action, IconData icon, String label) =>
            ListTile(
              leading: Icon(
                icon,
                color: action == _StoryAction.report ? cs.error : null,
              ),
              title: Text(
                label,
                style: action == _StoryAction.report
                    ? TextStyle(color: cs.error)
                    : null,
              ),
              onTap: () => Navigator.of(sheetContext).pop(action),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_opensProfile(story))
                item(
                  _StoryAction.profile,
                  Symbols.account_circle,
                  l10n.storyMenuProfile,
                ),
              if (story.allowsHidingAuthor)
                item(
                  _StoryAction.hide,
                  Symbols.visibility_off,
                  l10n.storyMenuHide,
                ),
              if (story.allowsSaving)
                item(_StoryAction.save, Symbols.download, l10n.storyMenuSave),
              if (story.allowsComplaints)
                item(_StoryAction.report, Symbols.report, l10n.storyMenuReport),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case _StoryAction.profile:
        await _openOwnerProfile();
        return;
      case _StoryAction.hide:
        await _hideAuthor(story);
      case _StoryAction.save:
        await _saveStory(story);
      case _StoryAction.report:
        await _reportStory(story);
      case null:
        break;
    }
    if (mounted && _route?.isCurrent != false) didPopNext();
  }

  Future<void> _hideAuthor(Story story) async {
    final ownerId = story.owner.ownerId;
    final ok = await storiesModule.setAuthorHidden(ownerId, true);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (!ok) {
      showCustomNotification(context, l10n.storyHideFailed);
      return;
    }
    showCustomNotification(
      context,
      l10n.storyHiddenNotice,
      action: (
        label: l10n.storyHiddenUndo,
        onTap: () => unawaited(storiesModule.setAuthorHidden(ownerId, false)),
      ),
    );
    _nextOwner();
  }

  Future<void> _saveStory(Story story) async {
    final media = story.media;
    final url = media?.url;
    if (media == null || url == null || url.isEmpty) return;
    final MediaSaveResult result;
    if (media.isVideo) {
      final file = await VideoPreloader.load(
        _videoCacheName(story),
        () async => url,
        priority: true,
        headers: _cdnHeaders,
      );
      result = file == null
          ? const MediaSaveResult(ok: false, failure: MediaSaveFailure.noLink)
          : await saveLocalMedia(
              file,
              saveName: 'story_${story.id}.mp4',
              kind: SaveMediaKind.video,
            );
    } else {
      result = await saveImageFromUrl(url);
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(
      context,
      result.ok
          ? l10n.photoViewerSavedToGallery
          : l10n.notificationsSaveFailed(result.errorText(l10n)),
    );
  }

  Future<void> _reportStory(Story story) async {
    final l10n = AppLocalizations.of(context)!;
    await showComplaintCard(
      context,
      title: l10n.chatInfoComplaintTitle,
      subtitle: l10n.chatInfoComplaintSubtitle,
      sendLabel: l10n.chatInfoComplaintSend,
      closeLabel: l10n.chatInfoComplaintClose,
      emptyLabel: l10n.chatInfoComplaintEmpty,
      loadReasons: () async {
        final reasons = await ComplaintsModule.reasonsFor(
          api,
          ComplaintsModule.storyTypeId,
        );
        return reasons
            .map((r) => (id: r.reasonId, title: r.reasonTitle))
            .toList();
      },
      onSend: (reasonId) async {
        final ok = await ComplaintsModule.sendComplaint(
          api,
          reasonId: reasonId,
          typeId: ComplaintsModule.storyTypeId,
          ids: [story.id],
          parentId: story.owner.ownerId,
        );
        if (mounted) {
          showCustomNotification(
            context,
            ok ? l10n.chatInfoComplaintSent : l10n.chatInfoComplaintFailed,
          );
        }
        return ok;
      },
    );
  }

  Widget _buildProgressBars(int count) {
    if (count <= 0) count = 1;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _paused ? 0.35 : 1.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
        child: Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: _SegmentBar(
                    state: i < _storyIndex
                        ? _SegmentState.done
                        : i > _storyIndex
                        ? _SegmentState.upcoming
                        : _SegmentState.active,
                    progress: _segment,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final preview = _owner;
    final story = _currentStory;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
      child: StoryOwnerBuilder(
        owner: preview.owner,
        overrideInfo: widget.ownerOverrides[preview.owner.ownerId],
        builder: (context, info) => Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: story != null && _opensProfile(story)
                    ? _openOwnerProfile
                    : null,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(1.6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.6,
                        ),
                      ),
                      child: KometAvatar(
                        name: info?.name.isNotEmpty == true ? info!.name : '?',
                        size: 34,
                        imageUrl: info?.avatarUrl,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OfficialName(
                            contactId: preview.owner.ownerId,
                            text: info?.name.isNotEmpty == true
                                ? info!.name
                                : '…',
                            iconSize: 15,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontFamily: displayFontOf(context),
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                          ),
                          if (story != null && story.time > 0)
                            Text(
                              _timeAgo(
                                AppLocalizations.of(context)!,
                                story.time,
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (story != null && _hasMenu(story))
              _RoundIconButton(
                key: const ValueKey('story-more'),
                icon: Symbols.more_vert,
                onTap: _isOwnStory(story) ? _openStoryMenu : _openForeignMenu,
              ),
            _RoundIconButton(icon: Symbols.close, onTap: _close),
          ],
        ),
      ),
    );
  }
}

// ─── Cube (3D fold) page transform ────────────────────────────────────────
class _CubePage extends StatelessWidget {
  final PageController controller;
  final int index;
  final double fallbackPage;
  final Widget child;

  const _CubePage({
    required this.controller,
    required this.index,
    required this.fallbackPage,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        double page = fallbackPage;
        if (controller.hasClients && controller.position.haveDimensions) {
          page = controller.page ?? fallbackPage;
        }
        final delta = (index - page).clamp(-1.0, 1.0);
        final rotation = delta * (math.pi / 2.4);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(rotation);
        return Transform(
          alignment: delta >= 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: transform,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child!,
              if (delta != 0)
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (delta.abs() * 0.55).clamp(0.0, 0.55),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Segmented progress bar ───────────────────────────────────────────────
enum _SegmentState { done, active, upcoming }

class _SegmentBar extends StatelessWidget {
  final _SegmentState state;
  final ValueListenable<double> progress;

  const _SegmentBar({required this.state, required this.progress});

  @override
  Widget build(BuildContext context) {
    final track = Colors.white.withValues(alpha: 0.28);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 3,
        child: switch (state) {
          _SegmentState.done => const ColoredBox(color: Colors.white),
          _SegmentState.upcoming => ColoredBox(color: track),
          _SegmentState.active => ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) => Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: track)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value.clamp(0.0, 1.0),
                    heightFactor: 1.0,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.white54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

// ─── Round icon button (close) ────────────────────────────────────────────
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

// ─── Top scrim ────────────────────────────────────────────────────────────
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 150,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _timeAgo(AppLocalizations l10n, int epochTime) {
  final ms = epochTime < 1000000000000 ? epochTime * 1000 : epochTime;
  final diff = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
  if (diff < 60) return l10n.storyViewerJustNow;
  if (diff < 3600) return l10n.storyViewerMinutesAgo(diff ~/ 60);
  if (diff < 86400) return l10n.storyViewerHoursAgo(diff ~/ 3600);
  return l10n.storyViewerDaysAgo(diff ~/ 86400);
}

// #***! превью декодируется один раз на историю: вертикальный свайп гонит
// setState каждый кадр, а новый MemoryImage заставлял бы заново раскодировать
// картинку и пересобирать размытый фон
final Expando<ImageProvider> _storyPreviews = Expando('storyPreview');

ImageProvider? _previewProvider(StoryMedia media) {
  final cached = _storyPreviews[media];
  if (cached != null) return cached;
  final bytes = _previewBytes(media);
  if (bytes == null) return null;
  final provider = MemoryImage(bytes);
  _storyPreviews[media] = provider;
  return provider;
}

Uint8List? _previewBytes(StoryMedia media) {
  final previewData = media.previewData;
  final comma = previewData?.indexOf(',') ?? -1;
  if (previewData != null && comma >= 0) {
    try {
      return base64Decode(previewData.substring(comma + 1));
    } catch (_) {}
  }
  final thumbhash = media.thumbhash;
  return thumbhash == null ? null : thumbHashToPng(thumbhash);
}

class _StoryMediaView extends StatelessWidget {
  final StoryMedia media;
  final VideoPlayerController? video;
  final ValueListenable<double?> loading;

  const _StoryMediaView({
    required this.media,
    required this.loading,
    this.video,
  });

  static const double _portraitLimit = 0.8;

  double get _aspect {
    if ((media.width ?? 0) > 0 && (media.height ?? 0) > 0) {
      return media.aspectRatio;
    }
    final value = video?.value;
    if (value == null || !value.isInitialized) return media.aspectRatio;
    final raw = value.aspectRatio;
    return value.rotationCorrection % 180 == 0 ? raw : 1 / raw;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewProvider(media);
    final aspect = _aspect;
    final fit = aspect < _portraitLimit ? BoxFit.cover : BoxFit.contain;
    Widget framed(Widget child) => SizedBox.expand(
      child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: aspect * 1000, height: 1000, child: child),
      ),
    );
    final poster = media.thumbnailUrl?.isNotEmpty ?? false
        ? framed(
            CachedNetworkImage(
              imageUrl: media.thumbnailUrl!,
              fit: BoxFit.fill,
              placeholder: preview == null
                  ? null
                  : (_, _) => Image(image: preview, fit: BoxFit.fill),
              errorWidget: (_, _, _) => preview == null
                  ? const SizedBox.shrink()
                  : Image(image: preview, fit: BoxFit.fill),
            ),
          )
        : preview == null
        ? const SizedBox.shrink()
        : framed(Image(image: preview, fit: BoxFit.fill));

    final children = <Widget>[
      if (preview != null)
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: AppFrost.mediaBackdropSigma,
              sigmaY: AppFrost.mediaBackdropSigma,
            ),
            child: Image(image: preview, fit: BoxFit.cover),
          ),
        ),
    ];

    if (media.isVideo) {
      final c = video;
      children.add(
        c != null && c.value.isInitialized ? framed(VideoPlayer(c)) : poster,
      );
      children.add(
        ValueListenableBuilder<double?>(
          valueListenable: loading,
          builder: (context, progress, _) => progress == null
              ? const SizedBox.shrink()
              : Center(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ),
        ),
      );
      return Stack(fit: StackFit.expand, children: children);
    }

    final url = media.url;
    children.add(
      url == null || url.isEmpty
          ? poster
          : framed(
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.fill,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: preview != null
                    ? (_, _) => Image(image: preview, fit: BoxFit.fill)
                    : null,
                errorWidget: (_, _, _) => preview != null
                    ? Image(image: preview, fit: BoxFit.fill)
                    : const Center(
                        child: Icon(
                          Symbols.broken_image,
                          color: Colors.white54,
                          size: 48,
                        ),
                      ),
              ),
            ),
    );
    return Stack(fit: StackFit.expand, children: children);
  }
}

class _OwnerCover extends StatelessWidget {
  final StoryPreview preview;
  final StoryOwnerInfo? overrideInfo;

  const _OwnerCover({required this.preview, this.overrideInfo});

  @override
  Widget build(BuildContext context) {
    return _StoryFrame(
      card: ColoredBox(
        color: Colors.black,
        child: Center(
          child: StoryOwnerBuilder(
            owner: preview.owner,
            overrideInfo: overrideInfo,
            builder: (context, info) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KometAvatar(
                  name: info?.name.isNotEmpty == true ? info!.name : '?',
                  size: 92,
                  imageUrl: info?.avatarUrl,
                ),
                const SizedBox(height: 14),
                const SmallSpinner(size: 22, color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryFrame extends StatelessWidget {
  final Widget card;
  final Widget? bottom;

  const _StoryFrame({required this.card, this.bottom});

  static const double bottomBarHeight = 64;
  static const double _aspect = 9 / 16;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final lift = math.max(0.0, keyboard - padding.bottom);
    return Padding(
      padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardMaxHeight = constraints.maxHeight - bottomBarHeight;
          final width = math.min(constraints.maxWidth, cardMaxHeight * _aspect);
          final height = math.min(cardMaxHeight, width / _aspect);
          return Column(
            children: [
              SizedBox(
                width: width,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: card,
                ),
              ),
              const Spacer(),
              Transform.translate(
                offset: Offset(0, -lift),
                child: SizedBox(
                  width: width,
                  height: bottomBarHeight,
                  child: bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _StoryAction { profile, hide, save, report }

class _StoryReplyBar extends StatefulWidget {
  final bool canReply;
  final bool canLike;
  final bool liked;
  final VoidCallback onLike;
  final Future<bool> Function(String text) onSend;
  final ValueChanged<bool> onTyping;

  const _StoryReplyBar({
    super.key,
    required this.canReply,
    required this.canLike,
    required this.liked,
    required this.onLike,
    required this.onSend,
    required this.onTyping,
  });

  @override
  State<_StoryReplyBar> createState() => _StoryReplyBarState();
}

class _StoryReplyBarState extends State<_StoryReplyBar> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    _text.addListener(_onText);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _text.removeListener(_onText);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocus() => widget.onTyping(_focus.hasFocus);

  void _onText() => setState(() {});

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSend(_text.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) return;
    _text.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typed = _text.text.trim().isNotEmpty;
    final Widget trailing = typed || _sending
        ? IconButton(
            key: const ValueKey('story-reply-send'),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SmallSpinner(size: 20, color: Colors.white)
                : const Icon(Symbols.send, fill: 1, color: Colors.white),
          )
        : widget.canLike
        ? IconButton(
            key: const ValueKey('story-like'),
            onPressed: widget.onLike,
            icon: Icon(
              Symbols.favorite,
              fill: widget.liked ? 1 : 0,
              color: widget.liked ? const Color(0xFFFF3B5C) : Colors.white,
              size: 28,
            ),
          )
        : const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
      child: Row(
        children: [
          if (widget.canReply)
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                readOnly: _sending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: l10n.storyReplyHint,
                  hintStyle: const TextStyle(color: Colors.white60),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 4),
          trailing,
        ],
      ),
    );
  }
}
