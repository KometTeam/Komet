import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/chats.dart';
import '../../../backend/modules/cloud_storage.dart';
import '../../../backend/modules/upload_manager.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';

enum _EnvState { loading, notConfigured, ready }

class CloudStorageScreen extends StatefulWidget {
  const CloudStorageScreen({super.key});

  @override
  State<CloudStorageScreen> createState() => _CloudStorageScreenState();
}

class _CloudStorageScreenState extends State<CloudStorageScreen>
    with SingleTickerProviderStateMixin {
  static const _translateFactor = 0.7;
  static const _horizontalPadding = 32.0;
  static const _hintSidePadding = 35.0;
  static const _cornerSidePadding = 16.0;
  static const _cornerBottomPadding = 24.0;
  static const _cornerSlideAmount = 28.0;
  static const _cardViewportFraction = 0.42;

  late final _UploadModeController _mode;
  late final PageController _pageController;
  final _currentFilePage = ValueNotifier<int>(0);

  _EnvState _envState = _EnvState.loading;
  bool _isCreatingEnv = false;
  int? _envGroupId;
  int? _accountId;
  List<CloudFile> _files = [];
  bool _isUploading = false;
  final ValueNotifier<double> _uploadProgress = ValueNotifier(0);
  bool _animateNewCard = false;

  @override
  void initState() {
    super.initState();
    _mode = _UploadModeController(this);
    _pageController = PageController(viewportFraction: _cardViewportFraction);
    _pageController.addListener(_onPageScroll);
    _checkEnv();
    _bindUploadManager();
  }

  void _onPageScroll() {
    _currentFilePage.value = _pageController.page?.round() ?? 0;
  }

  void _bindUploadManager() {
    final mgr = UploadManager.instance;
    if (mgr.isActive) {
      setState(() => _isUploading = true);
      _mode.open();
    }
    mgr.onProgress = (progress, _) {
      if (!mounted) return;
      if (!_isUploading) setState(() => _isUploading = true);
      _uploadProgress.value = progress;
    };
    mgr.onDone = (file) {
      if (!mounted) return;
      _uploadProgress.value = 0;
      setState(() => _isUploading = false);
      _prependFile(file);
    };
    mgr.onError = (msg) {
      if (!mounted) return;
      _uploadProgress.value = 0;
      setState(() => _isUploading = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.devicesGenericError(msg),
      );
    };
  }

  @override
  void dispose() {
    final mgr = UploadManager.instance;
    mgr.onProgress = null;
    mgr.onDone = null;
    mgr.onError = null;
    _mode.dispose();
    _pageController.dispose();
    _currentFilePage.dispose();
    _uploadProgress.dispose();
    super.dispose();
  }

  Future<void> _checkEnv() async {
    final profile = await AppDatabase.loadActiveProfile();
    if (profile == null) {
      if (mounted) setState(() => _envState = _EnvState.notConfigured);
      return;
    }

    final cachedId = await CloudStorageModule.getCachedEnvGroupId(profile.id);
    if (cachedId != null) {
      final rows = await chats.getChat(profile.id, cachedId);
      if (rows.isNotEmpty &&
          CloudStorageModule.isCloudStorageGroup(rows.first)) {
        if (!mounted) return;
        setState(() {
          _envState = _EnvState.ready;
          _envGroupId = cachedId;
          _accountId = profile.id;
        });
        _loadFiles(profile.id, cachedId);
        _handleOrphansBackground(profile.id);
        return;
      }
      await CloudStorageModule.clearEnvGroupCache(profile.id);
    }

    final cachedChats = await chats.getChats(profile.id);
    CachedChat? envGroup = CloudStorageModule.findEnvGroup(cachedChats);
    final orphans = CloudStorageModule.findOrphanGroups(cachedChats);

    if (envGroup == null && orphans.isNotEmpty) {
      final repaired = await CloudStorageModule.repairOrphan(
        api,
        orphans.first,
      );
      if (repaired != null) {
        envGroup = repaired;
        await CloudStorageModule.cacheEnvGroupId(profile.id, repaired.id);
      }
      for (final orphan in orphans.skip(1)) {
        _deleteOrLeave(profile.id, orphan);
      }
    } else if (envGroup != null) {
      await CloudStorageModule.cacheEnvGroupId(profile.id, envGroup.id);
      for (final orphan in orphans) {
        _deleteOrLeave(profile.id, orphan);
      }
    }

    if (!mounted) return;
    setState(() {
      _envState = envGroup != null ? _EnvState.ready : _EnvState.notConfigured;
      _envGroupId = envGroup?.id;
      _accountId = profile.id;
    });
    if (envGroup != null) _loadFiles(profile.id, envGroup.id);
  }

  void _handleOrphansBackground(int accountId) async {
    final cachedChats = await chats.getChats(accountId);
    for (final orphan in CloudStorageModule.findOrphanGroups(cachedChats)) {
      _deleteOrLeave(accountId, orphan);
    }
  }

  void _deleteOrLeave(int accountId, CachedChat chat) async {
    final isAdmin = chat.owner == accountId || chat.admins.contains(accountId);
    if (isAdmin) {
      await chats.deleteChat(
        api,
        chatId: chat.id,
        lastEventTime: chat.lastEventTime,
        forAll: true,
      );
    } else {
      await chats.leaveChat(api, chatId: chat.id);
    }
  }

  Future<void> _loadFiles(int accountId, int chatId) async {
    final files = await CloudStorageModule.fetchFiles(
      messagesModule,
      accountId,
      chatId,
    );
    if (!mounted) return;
    setState(() => _files = files.reversed.toList());
  }

  void _prependFile(CloudFile file) {
    setState(() {
      _files = [file, ..._files];
      _animateNewCard = true;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _animateNewCard = false);
    });
  }

  Future<void> _setupEnv() async {
    final profile = await AppDatabase.loadActiveProfile();
    if (!mounted) return;
    if (profile == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.cloudStorageNoActiveProfile,
      );
      return;
    }
    setState(() => _isCreatingEnv = true);
    final result = await CloudStorageModule.setupEnv(api);
    if (!mounted) return;
    if (result == null) {
      setState(() => _isCreatingEnv = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.cloudStorageSetupFailed,
      );
      return;
    }
    await CloudStorageModule.cacheEnvGroupId(profile.id, result.id);
    setState(() {
      _isCreatingEnv = false;
      _envState = _EnvState.ready;
      _envGroupId = result.id;
      _accountId = profile.id;
    });
    _loadFiles(profile.id, result.id);
  }

  Future<void> _pickAndUploadFile() async {
    final chatId = _envGroupId;
    final accountId = _accountId;
    if (chatId == null || accountId == null) return;

    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    _uploadProgress.value = 0;
    setState(() => _isUploading = true);

    await UploadManager.instance.start(
      chatId: chatId,
      accountId: accountId,
      file: File(picked.path!),
      filename: picked.name,
      totalSize: picked.size,
    );
  }

  void _showSendByIdSheet() {
    final chatId = _envGroupId;
    final accountId = _accountId;
    if (chatId == null || accountId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SendByIdSheet(
        onSend: (id) async {
          final ok = await messagesModule.sendFileMessage(chatId, id);
          if (!ok) return false;
          final newest = await CloudStorageModule.fetchLatestFile(
            messagesModule,
            accountId,
            chatId,
            expectedFileId: id,
          );
          if (mounted) {
            if (newest != null) {
              _prependFile(newest);
            } else {
              _loadFiles(accountId, chatId);
            }
          }
          return true;
        },
      ),
    );
  }

  void _onCardTap(CloudFile file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FileDetailsSheet(file: file),
    );
  }

  void _onBack() {
    if (_mode.isOpen) {
      _mode.close();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: _onBack,
        ),
        title: ConnectionTitleText(
          l10n.cloudStorageTitle,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
      body: switch (_envState) {
        _EnvState.loading => const Center(child: CircularProgressIndicator()),
        _EnvState.notConfigured => _buildNotConfigured(cs),
        _EnvState.ready => _buildReady(cs),
      },
    );
  }

  Widget _buildNotConfigured(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.cloudStorageNotConfiguredTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.cloudStorageNotConfiguredSubtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isCreatingEnv ? null : _setupEnv,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isCreatingEnv
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : Text(
                      l10n.cloudStorageStart,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReady(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) => _mode.handleDragUpdate(d, h),
          onVerticalDragEnd: _mode.handleDragEnd,
          child: AnimatedBuilder(
            animation: _mode.anim,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_mode.anim.value);
              return Stack(
                fit: StackFit.expand,
                children: [
                  _buildHint(cs, t),
                  _buildUploadingCenterHint(cs, t, constraints.maxWidth),
                  _buildEmptyState(cs, t, h),
                  ..._buildCornerActions(cs, t),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHint(ColorScheme cs, double t) {
    return Positioned(
      top: 0,
      left: _hintSidePadding,
      right: _hintSidePadding,
      child: IgnorePointer(
        child: Opacity(
          opacity: t,
          child: _DragDownHint(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildUploadingCenterHint(
    ColorScheme cs,
    double t,
    double availableWidth,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final cardSide = availableWidth * _cardViewportFraction;
    return Center(
      child: Opacity(
        opacity: t,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_files.isNotEmpty) ...[
                SizedBox(
                  height: cardSide,
                  width: availableWidth,
                  child: ScrollConfiguration(
                    behavior: _MouseDragScrollBehavior(),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _files.length,
                      itemBuilder: (_, i) {
                        final card = _CloudFileCard(
                          file: _files[i],
                          onTap: () => _onCardTap(_files[i]),
                        );
                        final padded = Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: card,
                        );
                        if (i == 0 && _animateNewCard) {
                          return _FadeScaleEntry(
                            key: ValueKey(
                              '${_files[0].messageId}_${_files[0].time}',
                            ),
                            child: padded,
                          );
                        }
                        return padded;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _currentFilePage,
                  builder: (context, page, child) => Text(
                    '${page + 1} / ${_files.length}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isUploading) ...[
                ValueListenableBuilder<double>(
                  valueListenable: _uploadProgress,
                  builder: (context, progress, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 5,
                        color: cs.primary,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.cloudStorageUploadingPercent(
                          (progress * 100).toStringAsFixed(0),
                        ),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_files.isEmpty) ...[
                Text(
                  l10n.cloudStorageStartUploadHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, double t, double availableHeight) {
    final l10n = AppLocalizations.of(context)!;
    return Transform.translate(
      offset: Offset(0, -t * availableHeight * _translateFactor),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.cloudStorageEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.cloudStorageEmptySubtitle,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _mode.isOpen ? null : _mode.open,
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                l10n.cloudStorageUpload,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerActions(ColorScheme cs, double t) {
    final l10n = AppLocalizations.of(context)!;
    final slide = (1 - t) * _cornerSlideAmount;
    return [
      Positioned(
        bottom: _cornerBottomPadding,
        left: _cornerSidePadding - slide,
        child: Opacity(
          opacity: t,
          child: _CornerAction(
            icon: Symbols.upload_file,
            label: l10n.cloudStorageFromFile,
            onTap: _pickAndUploadFile,
          ),
        ),
      ),
      Positioned(
        bottom: _cornerBottomPadding,
        right: _cornerSidePadding - slide,
        child: Opacity(
          opacity: t,
          child: _CornerAction(
            icon: Symbols.tag,
            label: l10n.cloudStorageById,
            onTap: _showSendByIdSheet,
          ),
        ),
      ),
    ];
  }
}

class _UploadModeController {
  static const _openDuration = Duration(milliseconds: 480);
  static const _closeDuration = Duration(milliseconds: 320);
  static const _dragRangeFactor = 0.55;
  static const _flingVelocityThreshold = 280.0;
  static const _snapMidpoint = 0.5;

  final AnimationController anim;

  _UploadModeController(TickerProvider vsync)
    : anim = AnimationController(
        vsync: vsync,
        duration: _openDuration,
        reverseDuration: _closeDuration,
      );

  bool get isOpen => anim.value > 0;

  void open() => anim.forward();
  void close() => anim.reverse();

  void handleDragUpdate(DragUpdateDetails d, double availableHeight) {
    if (anim.value == 0) return;
    final delta = d.primaryDelta ?? 0;
    final next = anim.value - delta / (availableHeight * _dragRangeFactor);
    anim.value = next.clamp(0.0, 1.0);
  }

  void handleDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() > _flingVelocityThreshold) {
      v > 0 ? close() : open();
      return;
    }
    anim.value < _snapMidpoint ? close() : open();
  }

  void dispose() => anim.dispose();
}

class _CornerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CornerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: GlossyPill(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          depth: 6,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cs.onSurface, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragDownHint extends StatefulWidget {
  final Color color;

  const _DragDownHint({required this.color});

  @override
  State<_DragDownHint> createState() => _DragDownHintState();
}

class _DragDownHintState extends State<_DragDownHint>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 2800);
  static const _activeFraction = 0.4;
  static const _height = 3.0;
  static const _slotHeight = 28.0;
  static const _startY = -6.0;
  static const _travel = 16.0;
  static const _peakOpacity = 0.32;

  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slotHeight,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ghost = _ghostFor(_c.value);
          if (ghost.opacity <= 0) return const SizedBox.shrink();
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: ghost.dy,
                height: _height,
                child: Opacity(
                  opacity: ghost.opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  ({double dy, double opacity}) _ghostFor(double phase) {
    if (phase > _activeFraction) return (dy: 0, opacity: 0);
    final local = phase / _activeFraction;
    final eased = Curves.easeOutCubic.transform(local);
    return (dy: _startY + eased * _travel, opacity: (1 - local) * _peakOpacity);
  }
}

class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class _FadeScaleEntry extends StatefulWidget {
  final Widget child;
  const _FadeScaleEntry({super.key, required this.child});

  @override
  State<_FadeScaleEntry> createState() => _FadeScaleEntryState();
}

class _FadeScaleEntryState extends State<_FadeScaleEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    _opacity = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.4, curve: Curves.easeIn),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}

class _CloudFileCard extends StatelessWidget {
  final CloudFile file;
  final VoidCallback onTap;

  const _CloudFileCard({required this.file, required this.onTap});

  static IconData _icon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => Symbols.picture_as_pdf,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' => Symbols.image,
      'mp4' || 'mov' || 'avi' || 'mkv' => Symbols.video_file,
      'mp3' || 'wav' || 'ogg' || 'flac' => Symbols.audio_file,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Symbols.folder_zip,
      'doc' || 'docx' => Symbols.description,
      'xls' || 'xlsx' => Symbols.table_chart,
      'ppt' || 'pptx' => Symbols.slideshow,
      'txt' => Symbols.text_snippet,
      _ => Symbols.insert_drive_file,
    };
  }

  static String _formatTime(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return formatClock(d);
    }
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: GlossyPill(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          depth: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Icon(_icon(file.name), color: cs.primary, size: 34),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(file.time),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileDetailsSheet extends StatefulWidget {
  final CloudFile file;
  const _FileDetailsSheet({required this.file});

  @override
  State<_FileDetailsSheet> createState() => _FileDetailsSheetState();
}

class _FileDetailsSheetState extends State<_FileDetailsSheet> {
  ({String url, int expires})? _link;
  bool _loading = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    final f = widget.file;
    if (f.fileId != null) {
      _link = CloudStorageModule.getCachedLink(f.accountId, f.fileId!);
    }
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateLink() async {
    final f = widget.file;
    if (f.fileId == null) return;
    setState(() => _loading = true);
    final result = await CloudStorageModule.fetchFileUrl(
      api,
      accountId: f.accountId,
      fileId: f.fileId!,
      chatId: f.chatId,
      messageId: f.messageId,
    );
    if (mounted) {
      setState(() {
        _link = result;
        _loading = false;
      });
    }
  }

  static String _formatSize(int? bytes) {
    if (bytes == null) return '—';
    return formatBytes(bytes);
  }

  static String _formatExpiry(int expiresMs) {
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      expiresMs,
    ).difference(DateTime.now());
    if (remaining.isNegative) return 'истекла';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h >= 24) return 'через ${remaining.inDays} д';
    if (h > 0) return 'через $h ч $m мин';
    return 'через $m мин';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final f = widget.file;
    final isExpired =
        _link == null ||
        _link!.expires <= DateTime.now().millisecondsSinceEpoch;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: SheetGrabber(margin: EdgeInsets.zero)),
          const SizedBox(height: 20),
          Text(
            f.name,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: l10n.cloudStorageFileIdLabel,
            value: f.fileId?.toString() ?? '—',
          ),
          const SizedBox(height: 6),
          _InfoRow(
            label: l10n.cloudStorageSizeLabel,
            value: _formatSize(f.size),
          ),
          const SizedBox(height: 20),
          Container(height: 0.5, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: isExpired
                    ? Text(
                        l10n.cloudStorageNoLinkYet,
                        style: TextStyle(color: cs.error, fontSize: 13),
                      )
                    : Text(
                        l10n.cloudStorageLinkExpiresIn(
                          _formatExpiry(_link!.expires),
                        ),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        isExpired ? Symbols.add_link : Symbols.content_copy,
                        color: isExpired ? cs.error : cs.onSurfaceVariant,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: isExpired
                          ? _generateLink
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: _link!.url),
                              );
                              showCustomNotification(
                                context,
                                l10n.cloudStorageLinkCopied,
                              );
                            },
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SendByIdSheet extends StatefulWidget {
  final Future<bool> Function(int fileId) onSend;
  const _SendByIdSheet({required this.onSend});

  @override
  State<_SendByIdSheet> createState() => _SendByIdSheetState();
}

class _SendByIdSheetState extends State<_SendByIdSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = int.tryParse(_controller.text.trim());
    if (id == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.cloudStorageInvalidId,
      );
      return;
    }
    setState(() => _sending = true);
    final ok = await widget.onSend(id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _sending = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.cloudStorageSendError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: SheetGrabber(margin: EdgeInsets.zero)),
          const SizedBox(height: 20),
          Text(
            l10n.cloudStorageSendByIdTitle,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: cs.onSurface, fontSize: 15),
            onSubmitted: (_) => _sending ? null : _submit(),
            decoration: InputDecoration(
              hintText: 'fileId',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : Text(
                    l10n.cloudStorageSend,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
