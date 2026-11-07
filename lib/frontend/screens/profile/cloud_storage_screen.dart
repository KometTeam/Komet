import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/chats.dart';
import '../../../backend/modules/cloud_storage.dart';
import '../../../backend/modules/upload_service.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/reload_on_reconnect.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/hint_bubble.dart';
import '../../widgets/info_action_sheet.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/undo_notification.dart';
import '../../../core/config/app_shape.dart';
import '../../../core/security/app_lock.dart';

enum _EnvState { loading, notConfigured, ready }

class CloudStorageScreen extends StatefulWidget {
  const CloudStorageScreen({super.key});

  @override
  State<CloudStorageScreen> createState() => _CloudStorageScreenState();
}

class _CloudStorageScreenState extends State<CloudStorageScreen>
    with ReloadOnReconnect {
  static const _horizontalPadding = 32.0;
  static const _gridPadding = 16.0;
  static const _gridSpacing = 12.0;
  static const _maxCardExtent = 220.0;
  static const _actionsPadding = 16.0;
  static const _loadMoreExtent = 600.0;
  static const _emptyPagesPerLoad = 5;

  final ScrollController _gridController = ScrollController();
  bool _filesLoaded = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  int? _oldestTime;
  _EnvState _envState = _EnvState.loading;
  bool _isCreatingEnv = false;
  int? _envGroupId;
  int? _accountId;
  List<CloudFile> _files = [];
  bool _isUploading = false;
  final ValueNotifier<double> _uploadProgress = ValueNotifier(0);
  bool _animateNewCard = false;
  StreamSubscription<UploadJobEvent>? _uploadEventSub;
  UploadJob? _uploadJob;

  @override
  void initState() {
    super.initState();
    _gridController.addListener(_maybeLoadMore);
    _checkEnv();
    _uploadEventSub = UploadService.instance.events.listen(_onUploadEvent);
  }

  void _syncUploadJob() {
    final chatId = _envGroupId;
    final job = chatId == null
        ? null
        : UploadService.instance.activeFileJob(chatId);
    if (identical(job, _uploadJob)) return;

    _uploadJob?.progress.removeListener(_onUploadProgress);
    _uploadJob = job;

    if (job == null) {
      _uploadProgress.value = 0;
      if (_isUploading) setState(() => _isUploading = false);
      return;
    }

    job.progress.addListener(_onUploadProgress);
    _onUploadProgress();
    if (!_isUploading) setState(() => _isUploading = true);
  }

  void _onUploadProgress() {
    final values = _uploadJob?.progress.value;
    if (values == null || values.isEmpty) return;
    _uploadProgress.value = values.first.fraction;
  }

  Future<void> _onUploadEvent(UploadJobEvent event) async {
    final chatId = _envGroupId;
    final accountId = _accountId;
    if (!mounted || chatId == null || accountId == null) return;
    if (event.chatId != chatId || event.kind != UploadKind.file) return;

    _syncUploadJob();

    if (event is UploadJobFailed) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.devicesGenericError(event.reason),
      );
      return;
    }
    if (event is! UploadJobDone) return;
    await _showUploaded(accountId, chatId, event.fileId);
  }

  Future<void> _showUploaded(int accountId, int chatId, int? fileId) async {
    final newest = await CloudStorageModule.fetchLatestFile(
      messagesModule,
      accountId,
      chatId,
      expectedFileId: fileId,
    );
    if (!mounted) return;
    if (newest == null) {
      await _loadFiles(accountId, chatId);
      return;
    }
    _prependFile(newest);
  }

  @override
  void dispose() {
    _uploadEventSub?.cancel();
    _uploadJob?.progress.removeListener(_onUploadProgress);
    _uploadProgress.dispose();
    _gridController.dispose();
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

  @override
  void reloadAfterReconnect() {
    final accountId = _accountId;
    final groupId = _envGroupId;
    if (accountId == null || groupId == null) {
      _checkEnv();
      return;
    }
    unawaited(_loadFiles(accountId, groupId));
  }

  Future<void> _reload() async {
    final accountId = _accountId;
    final groupId = _envGroupId;
    if (accountId == null || groupId == null) return;
    try {
      await _loadFiles(accountId, groupId);
    } catch (e) {
      logger.w('Облако: не удалось обновить список файлов: $e');
    }
  }

  Future<void> _loadFiles(int accountId, int chatId) async {
    final page = await CloudStorageModule.fetchPage(
      messagesModule,
      accountId,
      chatId,
    );
    if (!mounted) return;
    final boundary = page.oldestTime;
    setState(() {
      final older = boundary == null
          ? const <CloudFile>[]
          : [
              for (final f in _files)
                if (f.time < boundary) f,
            ];
      _files = [...page.files, ...older];
      _filesLoaded = true;
      if (older.isEmpty) {
        _oldestTime = boundary;
        _hasMore = boundary != null;
      }
    });
    _syncUploadJob();
    _scheduleLoadMoreCheck();
  }

  void _scheduleLoadMoreCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadMore();
    });
  }

  void _maybeLoadMore() {
    if (!_hasMore || _loadingMore) return;
    if (_gridController.hasClients &&
        _gridController.position.extentAfter > _loadMoreExtent) {
      return;
    }
    unawaited(_loadMore());
  }

  static String _fileKey(CloudFile file) => '${file.messageId}_${file.fileId}';

  Future<void> _loadMore() async {
    final accountId = _accountId;
    final chatId = _envGroupId;
    var cursor = _oldestTime;
    if (accountId == null || chatId == null || cursor == null) return;
    setState(() => _loadingMore = true);
    var grew = false;
    try {
      for (var page = 0; page < _emptyPagesPerLoad || _files.isEmpty; page++) {
        final result = await CloudStorageModule.fetchPage(
          messagesModule,
          accountId,
          chatId,
          before: cursor,
        );
        if (!mounted) return;
        final known = {for (final f in _files) _fileKey(f)};
        final fresh = [
          for (final f in result.files)
            if (known.add(_fileKey(f))) f,
        ];
        final next = result.oldestTime;
        setState(() {
          _files = [..._files, ...fresh];
          _oldestTime = next ?? cursor;
          _hasMore = next != null;
        });
        if (next == null || fresh.isNotEmpty) {
          grew = fresh.isNotEmpty;
          break;
        }
        cursor = next;
      }
    } catch (e) {
      logger.w('Облако: не удалось подгрузить старые файлы: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
    if (grew) _scheduleLoadMoreCheck();
  }

  void _prependFile(CloudFile file) {
    setState(() {
      _files = [
        file,
        for (final f in _files)
          if (f.messageId != file.messageId || f.fileId != file.fileId) f,
      ];
      _animateNewCard = true;
    });
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
    if (!mounted) return;
    setState(() {
      _isCreatingEnv = false;
      _envState = _EnvState.ready;
      _envGroupId = result.id;
      _accountId = profile.id;
    });
    _loadFiles(profile.id, result.id);
    unawaited(_showHowItWorks());
  }

  Future<void> _showHowItWorks() async {
    final l10n = AppLocalizations.of(context)!;
    final groupId = _envGroupId;
    await showInfoActionSheet(
      context,
      headerIcon: Symbols.cloud,
      title: l10n.cloudStorageAboutTitle,
      subtitle: l10n.cloudStorageAboutSubtitle,
      items: [
        InfoActionSheetItem(
          icon: Symbols.visibility_off,
          title: l10n.cloudStorageAboutGroupTitle,
          body: l10n.cloudStorageAboutGroupBody,
        ),
        InfoActionSheetItem(
          icon: Symbols.badge,
          title: groupId == null
              ? l10n.cloudStorageAboutSampleNameTitle(
                  CloudStorageModule.sampleTitle,
                )
              : l10n.cloudStorageAboutNameTitle(
                  CloudStorageModule.titleFor(groupId),
                ),
          body: l10n.cloudStorageAboutNameBody,
        ),
        InfoActionSheetItem(
          icon: Symbols.devices,
          title: l10n.cloudStorageAboutOtherAppsTitle,
          body: l10n.cloudStorageAboutOtherAppsBody,
        ),
        InfoActionSheetItem(
          icon: Symbols.link,
          title: l10n.cloudStorageAboutLinksTitle,
          body: l10n.cloudStorageAboutLinksBody,
        ),
      ],
    );
  }

  Future<void> _pickAndUploadFile() async {
    final chatId = _envGroupId;
    final accountId = _accountId;
    if (chatId == null || accountId == null) return;

    final result = await AppLock.instance.external(
      () => FilePicker.platform.pickFiles(),
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    if (picked.path == null) return;

    _uploadProgress.value = 0;
    setState(() => _isUploading = true);

    final service = UploadService.instance;
    final sending = service.sendFile(
      accountId: accountId,
      chatId: chatId,
      tempId: service.newTempId(),
      source: File(picked.path!),
      filename: picked.name,
      size: picked.size,
    );
    _syncUploadJob();
    await sending;
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
          final sentId = await messagesModule.sendFileMessage(chatId, id);
          if (sentId == null) return false;
          if (mounted) await _showUploaded(accountId, chatId, id);
          return true;
        },
      ),
    );
  }

  Future<void> _onCardTap(CloudFile file) async {
    final delete = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FileDetailsSheet(file: file),
    );
    if (delete == true && mounted) _deleteFile(file);
  }

  void _deleteFile(CloudFile file) {
    final l10n = AppLocalizations.of(context)!;
    final removed = [
      for (final f in _files)
        if (f.messageId == file.messageId) f,
    ];
    setState(() {
      _files = [
        for (final f in _files)
          if (f.messageId != file.messageId) f,
      ];
    });
    void restore() {
      if (!mounted) return;
      final present = {for (final f in _files) _fileKey(f)};
      setState(() {
        _files = [
          ..._files,
          for (final f in removed)
            if (!present.contains(_fileKey(f))) f,
        ]..sort((a, b) => b.time.compareTo(a.time));
      });
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    showUndoNotification(
      context,
      l10n.cloudStorageFileDeleted,
      onUndo: restore,
      onCommit: () async {
        final ok = await messagesModule.deleteMessages(file.chatId, [
          file.messageId,
        ], forEveryone: true);
        if (!ok) {
          restore();
          if (overlay.mounted) {
            showCustomNotificationOnOverlay(
              overlay,
              l10n.cloudStorageDeleteFailed,
            );
          }
          return;
        }
        try {
          await AppDatabase.deleteMessage(
            file.accountId,
            file.chatId,
            file.messageId,
          );
        } catch (_) {}
      },
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: ConnectionTitleText(
          l10n.cloudStorageTitle,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Symbols.info, color: cs.onSurface),
            tooltip: l10n.cloudStorageAboutTooltip,
            onPressed: _showHowItWorks,
          ),
        ],
      ),
      body: switch (_envState) {
        _EnvState.loading => const Center(child: SmallSpinner(size: 36)),
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
                shape: AppShape.buttonBorder,
              ),
              child: _isCreatingEnv
                  ? SmallSpinner(size: 18, color: cs.onPrimary)
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
    return Column(
      children: [
        if (_isUploading) _buildUploadProgress(cs),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: _files.isNotEmpty
                ? _buildGrid()
                : !_filesLoaded || _hasMore
                ? const Center(child: SmallSpinner(size: 36))
                : _buildEmptyState(cs),
          ),
        ),
        _buildActions(),
      ],
    );
  }

  Widget _buildUploadProgress(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gridPadding, 4, _gridPadding, 8),
      child: ValueListenableBuilder<double>(
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
            const SizedBox(height: 6),
            Text(
              l10n.cloudStorageUploadingPercent(
                (progress * 100).toStringAsFixed(0),
              ),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return CustomScrollView(
      controller: _gridController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            _gridPadding,
            8,
            _gridPadding,
            _gridPadding,
          ),
          sliver: _buildGridItems(),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: _gridPadding),
              child: Center(child: SmallSpinner()),
            ),
          ),
      ],
    );
  }

  Widget _buildGridItems() {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxCardExtent,
        mainAxisSpacing: _gridSpacing,
        crossAxisSpacing: _gridSpacing,
      ),
      itemCount: _files.length,
      itemBuilder: (_, i) {
        final file = _files[i];
        final card = _CloudFileCard(
          key: ValueKey('${file.messageId}_${file.fileId}'),
          file: file,
          onTap: () => _onCardTap(file),
        );
        if (i == 0 && _animateNewCard) {
          return _FadeScaleEntry(
            key: ValueKey('new_${file.messageId}_${file.fileId}'),
            child: card,
          );
        }
        return card;
      },
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _horizontalPadding,
              ),
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
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _actionsPadding,
          8,
          _actionsPadding,
          _actionsPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: _CornerAction(
                icon: Symbols.upload_file,
                label: l10n.cloudStorageFromFile,
                onTap: _pickAndUploadFile,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CornerAction(
                icon: Symbols.tag,
                label: l10n.cloudStorageById,
                onTap: _showSendByIdSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    return GlossyPill(
      onTap: onTap,
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      depth: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: cs.onSurface, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

  const _CloudFileCard({super.key, required this.file, required this.onTap});

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

  static String _formatTime(AppLocalizations l10n, int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return formatClock(d);
    }
    if (d.year == now.year) return formatDayMonth(l10n, d);
    return formatDateNumeric(d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final size = file.size;
    final details = [
      if (size != null) formatBytes(l10n, size),
      _formatTime(l10n, file.time),
    ].join(' · ');
    return GlossyPill(
      onTap: onTap,
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      depth: 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Icon(_icon(file.name), color: cs.primary, size: 40),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
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

  static String _formatSize(AppLocalizations l10n, int? bytes) {
    if (bytes == null) return '—';
    return formatBytes(l10n, bytes);
  }

  static String _formatExpiry(AppLocalizations l10n, int expiresMs) {
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      expiresMs,
    ).difference(DateTime.now());
    if (remaining.isNegative) return l10n.cloudStorageScreenExpired;
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h >= 24) return l10n.cloudStorageScreenExpiresInDays(remaining.inDays);
    if (h > 0) return l10n.cloudStorageScreenExpiresInHours(h, m);
    return l10n.cloudStorageScreenExpiresInMinutes(m);
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShape.sheet),
        ),
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
            value: _formatSize(l10n, f.size),
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
                          _formatExpiry(l10n, _link!.expires),
                        ),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              _loading
                  ? SmallSpinner(size: 20, color: cs.primary)
                  : Builder(
                      builder: (buttonContext) => IconButton(
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
                                showHintBubble(
                                  buttonContext,
                                  l10n.cloudStorageLinkCopied,
                                );
                              },
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: cs.outlineVariant),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: cs.error,
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Symbols.delete, size: 20),
            label: Text(
              l10n.cloudStorageDeleteFile,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShape.sheet),
        ),
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
              shape: AppShape.buttonBorder,
            ),
            child: _sending
                ? SmallSpinner(size: 18, color: cs.onPrimary)
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
