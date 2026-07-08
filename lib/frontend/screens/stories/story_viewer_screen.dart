import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/haptics.dart';
import '../../../main.dart' show storiesModule;
import '../../../models/story.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/komet_avatar.dart';
import 'story_owner_info.dart';

const _quickReactions = ['❤️', '🔥', '😍', '👏', '😂', '😮'];
const Duration _photoDuration = Duration(seconds: 5);

/// Открывает вьюер историй. Если задан [origin] (глобальный центр нажатого
/// кольца) — открытие анимируется расширяющимся из этой точки кругом; иначе —
/// масштабным «зумом».
void openStoryViewer(
  BuildContext context, {
  required List<StoryPreview> previews,
  int initialIndex = 0,
  Map<int, StoryOwnerInfo> ownerOverrides = const {},
  Offset? origin,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => StoryViewerScreen(
        previews: previews,
        initialIndex: initialIndex,
        ownerOverrides: ownerOverrides,
      ),
      transitionsBuilder: (context, animation, _, child) {
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final closing = animation.status == AnimationStatus.reverse ||
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

  const StoryViewerScreen({
    super.key,
    required this.previews,
    this.initialIndex = 0,
    this.ownerOverrides = const {},
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
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

  final List<_Burst> _bursts = [];
  int _burstSeq = 0;

  VideoPlayerController? _video;

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
    _photoProgress = AnimationController(vsync: this, duration: _photoDuration)
      ..addListener(() => _segment.value = _photoProgress.value)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _advance();
      });
    _loadOwner(_ownerIndex, autostart: true);
  }

  @override
  void dispose() {
    _disposeVideo();
    _photoProgress.dispose();
    _segment.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  void _disposeVideo() {
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
    final stories = await storiesModule.getByOwner(widget.previews[index].owner);
    if (!mounted) return;
    setState(() {
      _stories[ownerId] = stories;
      _loading[ownerId] = false;
    });
    if (autostart && index == _ownerIndex) {
      _startStory(_resumeIndex(index, stories));
    }
  }

  /// Индекс, с которого начать показ: сначала — сохранённая позиция просмотра,
  /// иначе — первая непрочитанная.
  int _resumeIndex(int index, List<Story> stories) {
    if (stories.isEmpty) return 0;
    final ownerId = widget.previews[index].owner.ownerId;
    final savedId = storiesModule.lastViewedStoryId(ownerId);
    if (savedId != null) {
      final i = stories.indexWhere((s) => s.id == savedId);
      if (i >= 0) return i;
    }
    final read = widget.previews[index].readCount;
    if (read > 0 && read < stories.length) return read;
    return 0;
  }

  void _startStory(int index) {
    _disposeVideo();
    _photoProgress.stop();
    _segment.value = 0;
    _paused = false;
    setState(() => _storyIndex = index);

    final story = _currentStory;
    if (story == null) return;
    _markViewed(story);
    storiesModule.setLastViewed(story.owner.ownerId, story.id);

    final media = story.media;
    if (media != null && media.isVideo && (media.url?.isNotEmpty ?? false)) {
      _startVideo(media.url!);
    } else {
      _photoProgress.forward(from: 0);
    }
  }

  Future<void> _startVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = controller;
    try {
      await controller.initialize();
      if (!mounted || _video != controller) {
        controller.dispose();
        return;
      }
      controller.addListener(_onVideoTick);
      await controller.play();
      setState(() {});
    } catch (_) {
      if (_video == controller) {
        _disposeVideo();
        _photoProgress.forward(from: 0);
      }
    }
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
      Navigator.of(context).maybePop();
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
    } else {
      paused ? _photoProgress.stop() : _photoProgress.forward();
    }
  }

  void _spawnBurst(String emoji, Alignment from) {
    final id = _burstSeq++;
    setState(() => _bursts.add(_Burst(id, emoji, from)));
  }

  void _removeBurst(int id) {
    if (!mounted) return;
    setState(() => _bursts.removeWhere((b) => b.id == id));
  }

  Future<void> _toggleReaction(String emoji) async {
    final story = _currentStory;
    if (story == null || story.id == 0) return;
    final isSame = story.reaction?.id == emoji;
    if (!isSame) {
      Haptics.medium();
      _spawnBurst(emoji, const Alignment(0, 0.55));
    } else {
      Haptics.tap();
    }
    final ok = await storiesModule.react(
      story.owner,
      story.id,
      isSame ? null : StoryReaction(id: emoji),
    );
    if (!mounted) return;
    if (ok) {
      setState(() {});
    } else {
      showCustomNotification(context, 'Не удалось отправить реакцию');
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
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _dragDy = 0;
    });
    _setPaused(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                        overrideInfo: widget.ownerOverrides[
                            widget.previews[index].owner.ownerId],
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
          for (final burst in _bursts)
            _FloatingReaction(
              key: ValueKey(burst.id),
              emoji: burst.emoji,
              alignment: burst.from,
              onDone: () => _removeBurst(burst.id),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveOwner() {
    final ownerId = _owner.owner.ownerId;
    final loading = _loading[ownerId] ?? false;
    final stories = _ownerStories;
    final story = _currentStory;

    return GestureDetector(
      onTapUp: (details) {
        final width = MediaQuery.of(context).size.width;
        if (details.localPosition.dx < width * 0.32) {
          _rewind();
        } else {
          _advance();
        }
      },
      onLongPressStart: (_) => _setPaused(true),
      onLongPressEnd: (_) => _setPaused(false),
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
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
                    child: _StoryMediaView(media: story.media!, video: _video),
                  )
                : (loading
                      ? const SizedBox.expand(key: ValueKey('loading'))
                      : const Center(
                          key: ValueKey('empty'),
                          child: Text(
                            'Историй нет',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )),
          ),
          const _TopScrim(),
          if (loading)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                _buildProgressBars(stories.length),
                _buildHeader(),
                const Spacer(),
                if (story != null) _buildReactionBar(story),
              ],
            ),
          ),
        ],
      ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    info?.name.isNotEmpty == true ? info!.name : '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  if (story != null && story.time > 0)
                    Text(
                      _timeAgo(story.time),
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
            _RoundIconButton(
              icon: Symbols.close,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionBar(Story story) {
    final current = story.reaction?.id;
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in _quickReactions)
                        _ReactionButton(
                          emoji: emoji,
                          selected: current == emoji,
                          onTap: () => _toggleReaction(emoji),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

// ─── Reaction emoji button ────────────────────────────────────────────────
class _ReactionButton extends StatefulWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    lowerBound: 0.0,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onTap() {
    _c.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final pop = 1.0 + math.sin(_c.value * math.pi) * 0.4;
          final scale = (widget.selected ? 1.15 : 1.0) * pop;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Transform.scale(
              scale: scale,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        },
      ),
    );
  }
}

// ─── Round icon button (close) ────────────────────────────────────────────
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

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

// ─── Floating reaction burst ──────────────────────────────────────────────
class _Burst {
  final int id;
  final String emoji;
  final Alignment from;
  const _Burst(this.id, this.emoji, this.from);
}

class _FloatingReaction extends StatefulWidget {
  final String emoji;
  final Alignment alignment;
  final VoidCallback onDone;

  const _FloatingReaction({
    super.key,
    required this.emoji,
    required this.alignment,
    required this.onDone,
  });

  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final double _drift = (widget.emoji.hashCode % 40 - 20).toDouble();

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final rise = -160.0 * Curves.easeOut.transform(t);
          final scale = t < 0.3
              ? Curves.easeOutBack.transform(t / 0.3) * 1.2
              : 1.2 - 0.2 * ((t - 0.3) / 0.7);
          final opacity = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
          return Align(
            alignment: widget.alignment,
            child: Transform.translate(
              offset: Offset(_drift * t, rise),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _timeAgo(int epochTime) {
  final ms = epochTime < 1000000000000 ? epochTime * 1000 : epochTime;
  final diff = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
  if (diff < 60) return 'только что';
  if (diff < 3600) return '${diff ~/ 60} мин';
  if (diff < 86400) return '${diff ~/ 3600} ч';
  return '${diff ~/ 86400} дн';
}

ImageProvider? _previewProvider(String? previewData) {
  if (previewData == null) return null;
  final comma = previewData.indexOf(',');
  if (comma < 0) return null;
  try {
    return MemoryImage(base64Decode(previewData.substring(comma + 1)));
  } catch (_) {
    return null;
  }
}

class _StoryMediaView extends StatelessWidget {
  final StoryMedia media;
  final VideoPlayerController? video;

  const _StoryMediaView({required this.media, this.video});

  @override
  Widget build(BuildContext context) {
    final preview = _previewProvider(media.previewData);
    final Widget blurBg = preview != null
        ? Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image(image: preview, fit: BoxFit.cover),
            ),
          )
        : const SizedBox.shrink();

    if (media.isVideo) {
      final c = video;
      Widget fg;
      if (c != null && c.value.isInitialized) {
        fg = Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        );
      } else if (media.thumbnailUrl?.isNotEmpty ?? false) {
        fg = CachedNetworkImage(
          imageUrl: media.thumbnailUrl!,
          fit: BoxFit.contain,
        );
      } else if (preview != null) {
        fg = Center(child: Image(image: preview, fit: BoxFit.contain));
      } else {
        fg = const SizedBox.shrink();
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          blurBg,
          fg,
        ],
      );
    }

    final url = media.url;
    Widget fg;
    if (url == null || url.isEmpty) {
      fg = preview != null
          ? Center(child: Image(image: preview, fit: BoxFit.contain))
          : const SizedBox.shrink();
    } else {
      fg = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: preview != null
            ? (context, _) => Center(child: Image(image: preview, fit: BoxFit.contain))
            : null,
        errorWidget: (context, _, _) => preview != null
            ? Center(child: Image(image: preview, fit: BoxFit.contain))
            : const Center(
                child: Icon(Symbols.broken_image, color: Colors.white54, size: 48),
              ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        blurBg,
        fg,
      ],
    );
  }
}

class _OwnerCover extends StatelessWidget {
  final StoryPreview preview;
  final StoryOwnerInfo? overrideInfo;

  const _OwnerCover({required this.preview, this.overrideInfo});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
