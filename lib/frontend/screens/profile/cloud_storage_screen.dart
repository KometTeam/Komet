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
import '../../../main.dart';
import '../../widgets/custom_notification.dart';

enum _EnvState { loading, notConfigured, ready }

class CloudStorageScreen extends StatefulWidget {
  const CloudStorageScreen({super.key});

  @override
  State<CloudStorageScreen> createState() => _CloudStorageScreenState();
}

class _CloudStorageScreenState extends State<CloudStorageScreen> {
  static const _horizontalPadding = 32.0;
  static const _cardViewportFraction = 0.38;

  late final PageController _pageController;
  final _currentFilePage = ValueNotifier<int>(0);

  _EnvState _envState = _EnvState.loading;
  bool _isCreatingEnv = false;
  int? _envGroupId;
  int? _accountId;
  List<CloudFile> _files = [];
  bool _filesLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _animateNewCard = false;
  bool _showUploadCard = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _cardViewportFraction);
    _pageController.addListener(_onPageScroll);
    _checkEnv();
    _bindUploadManager();
  }

  void _bindUploadManager() {
    final mgr = UploadManager.instance;
    if (mgr.isActive) {
      // Upload was already running (e.g. user left and came back)
      setState(() { _isUploading = true; _showUploadCard = true; });
    }
    mgr.onProgress = (progress, speedBps) {
      if (!mounted) return;
      setState(() { _isUploading = true; _uploadProgress = progress; });
    };
    mgr.onDone = (file) {
      if (!mounted) return;
      setState(() { _isUploading = false; _uploadProgress = 0; });
      _prependFile(file);
    };
    mgr.onError = (msg) {
      if (!mounted) return;
      setState(() { _isUploading = false; _uploadProgress = 0; });
      showCustomNotification(context, 'Ошибка: $msg');
    };
  }

  void _onPageScroll() {
    _currentFilePage.value = _pageController.page?.round() ?? 0;
  }

  @override
  void dispose() {
    // Unregister UI callbacks — upload continues in background via UploadManager
    final mgr = UploadManager.instance;
    mgr.onProgress = null;
    mgr.onDone = null;
    mgr.onError = null;
    _pageController.dispose();
    _currentFilePage.dispose();
    super.dispose();
  }

  Future<void> _checkEnv() async {
    final profile = await AppDatabase.loadActiveProfile();
    if (profile == null) {
      if (mounted) setState(() => _envState = _EnvState.notConfigured);
      return;
    }

    // Fast path: validate cached env group ID with a single DB row query
    final cachedId = await CloudStorageModule.getCachedEnvGroupId(profile.id);
    if (cachedId != null) {
      final rows = await ChatsModule.getChat(profile.id, cachedId);
      if (rows.isNotEmpty && CloudStorageModule.isCloudStorageGroup(rows.first)) {
        if (!mounted) return;
        setState(() {
          _envState = _EnvState.ready;
          _envGroupId = cachedId;
          _accountId = profile.id;
        });
        _loadFiles(profile.id, cachedId);
        _handleOrphansBackground(profile.id, cachedId);
        return;
      }
      await CloudStorageModule.clearEnvGroupCache(profile.id);
    }

    // Full scan
    final chats = await ChatsModule.getChats(profile.id);
    CachedChat? envGroup = CloudStorageModule.findEnvGroup(chats);
    final orphans = CloudStorageModule.findOrphanGroups(chats);

    if (envGroup == null && orphans.isNotEmpty) {
      // Repair first orphan into a valid env group
      final repaired = await CloudStorageModule.repairOrphan(api, orphans.first);
      if (repaired != null) {
        envGroup = repaired;
        await CloudStorageModule.cacheEnvGroupId(profile.id, repaired.id);
      }
      // If there were multiple orphans, clean up the rest
      for (final orphan in orphans.skip(1)) {
        _deleteOrLeave(profile.id, orphan);
      }
    } else if (envGroup != null) {
      await CloudStorageModule.cacheEnvGroupId(profile.id, envGroup.id);
      // Env already exists — delete or leave any orphan groups
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

  // Runs in background after the fast-cache path — loads all chats to find and remove orphans
  void _handleOrphansBackground(int accountId, int envGroupId) async {
    final chats = await ChatsModule.getChats(accountId);
    final orphans = CloudStorageModule.findOrphanGroups(chats);
    for (final orphan in orphans) {
      _deleteOrLeave(accountId, orphan);
    }
  }

  void _deleteOrLeave(int accountId, CachedChat chat) async {
    final isAdmin = chat.owner == accountId || chat.admins.contains(accountId);
    if (isAdmin) {
      await ChatsModule.deleteChat(api, chatId: chat.id, lastEventTime: chat.lastEventTime, forAll: true);
    } else {
      await ChatsModule.leaveChat(api, chatId: chat.id);
    }
  }

  Future<void> _loadFiles(int accountId, int chatId) async {
    if (mounted) setState(() => _filesLoading = true);
    final files = await CloudStorageModule.fetchFiles(messagesModule, accountId, chatId);
    if (!mounted) return;
    setState(() {
      _files = files.reversed.toList();
      _filesLoading = false;
    });
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
      showCustomNotification(context, 'Нет активного профиля');
      return;
    }
    setState(() => _isCreatingEnv = true);
    final result = await CloudStorageModule.setupEnv(api);
    if (!mounted) return;
    if (result == null) {
      setState(() => _isCreatingEnv = false);
      showCustomNotification(context, 'Не удалось создать среду');
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

    setState(() { _isUploading = true; _uploadProgress = 0; });

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
          // Fetch just the new file — avoids full 200-msg reload
          final newest = await CloudStorageModule.fetchLatestFile(
            messagesModule, accountId, chatId, expectedFileId: id,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: cs.onSurface),
          onPressed: () {
            if (_showUploadCard) {
              setState(() => _showUploadCard = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Облачное хранилище',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Среда для облачного хранилища не настроена',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface, fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Начнем? Это быстро.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isCreatingEnv ? null : _setupEnv,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isCreatingEnv
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                    )
                  : const Text('Начать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReady(ColorScheme cs) {
    return LayoutBuilder(builder: (context, constraints) {
      final cardSide = constraints.maxWidth * _cardViewportFraction;
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showUploadCard
                ? () => setState(() => _showUploadCard = false)
                : null,
            child: _buildMainContent(cs),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            reverseDuration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _showUploadCard
                ? _buildUploadCard(cs, cardSide)
                : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  Widget _buildMainContent(ColorScheme cs) {
    if (_filesLoading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _files.isEmpty ? 'Облачных файлов пока нет...' : '${_files.length} ${_pluralFiles(_files.length)} в облаке',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _files.isEmpty ? 'Добавите?' : 'Добавить ещё?',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _showUploadCard ? null : () => setState(() => _showUploadCard = true),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Загрузить', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard(ColorScheme cs, double cardSide) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          key: const ValueKey('upload_card'),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_files.isNotEmpty) ...[
                SizedBox(
                  height: cardSide,
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
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: card,
                        );
                        if (i == 0 && _animateNewCard) {
                          return _FadeScaleEntry(
                            key: ValueKey('${_files[0].messageId}_${_files[0].time}'),
                            child: padded,
                          );
                        }
                        return padded;
                      },
                    ),
                  ),
                ),
                // Page indicator
                const SizedBox(height: 8),
                Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _currentFilePage,
                    builder: (context, page, child) => Text(
                      '${page + 1} / ${_files.length}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isUploading) ...[
                LinearProgressIndicator(
                  value: _uploadProgress,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 5,
                  color: cs.primary,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
                const SizedBox(height: 6),
                Text(
                  'Загрузка ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Начните загрузку для прогресс-бара',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ],
              Row(
                children: [
                  Expanded(
                    child: _CardActionButton(
                      icon: Symbols.upload_file,
                      label: 'С файла',
                      onTap: _isUploading ? null : _pickAndUploadFile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CardActionButton(
                      icon: Symbols.tag,
                      label: 'По ID',
                      onTap: _showSendByIdSheet,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _pluralFiles(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'файл';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'файла';
    return 'файлов';
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    _opacity = CurvedAnimation(parent: _c, curve: const Interval(0, 0.4, curve: Curves.easeIn));
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
      builder: (_, child) => Opacity(
        opacity: _opacity.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: widget.child,
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _CardActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
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
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
          ),
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
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
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
    // Refresh the expiry countdown every minute
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
    if (mounted) setState(() { _link = result; _loading = false; });
  }

  static String _formatSize(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  static String _formatExpiry(int expiresMs) {
    final remaining = DateTime.fromMillisecondsSinceEpoch(expiresMs).difference(DateTime.now());
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
    final f = widget.file;
    final isExpired = _link == null ||
        _link!.expires <= DateTime.now().millisecondsSinceEpoch;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            f.name,
            style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'ID файла', value: f.fileId?.toString() ?? '—'),
          const SizedBox(height: 6),
          _InfoRow(label: 'Размер', value: _formatSize(f.size)),
          const SizedBox(height: 20),
          Container(height: 0.5, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: isExpired
                    ? Text(
                        'Ссылки пока нет. Создайте.',
                        style: TextStyle(color: cs.error, fontSize: 13),
                      )
                    : Text(
                        'Ссылка истечет ${_formatExpiry(_link!.expires)}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
              ),
              const SizedBox(width: 8),
              _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
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
                              Clipboard.setData(ClipboardData(text: _link!.url));
                              showCustomNotification(context, 'Ссылка скопирована');
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
        Text('$label: ', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
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
      showCustomNotification(context, 'Неверный ID');
      return;
    }
    setState(() => _sending = true);
    final ok = await widget.onSend(id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _sending = false);
      showCustomNotification(context, 'Ошибка отправки');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Отправить по ID',
            style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Text('Отправить', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
