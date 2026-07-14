import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ogg_opus_player/ogg_opus_player.dart';

import '../../../backend/modules/messages.dart' show CachedMessage, ContactCache;
import '../../../backend/modules/shared_content.dart';
import '../../../core/cache/info_cache.dart';
import '../../../core/utils/download_progress.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_cache.dart';
import '../../../core/utils/media_saver.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/attachment.dart';
import '../../screens/chats/chat_screen.dart';
import '../custom_notification.dart';
import '../komet_avatar.dart';
import '../photo_viewer.dart';
import '../small_spinner.dart';
import '../swipe_route.dart';
import '../video_player_screen.dart';

enum SharedContentKind { media, files, voice, links }

extension on SharedContentKind {
  List<String> get attachTypes {
    switch (this) {
      case SharedContentKind.media:
        return const ['PHOTO', 'VIDEO'];
      case SharedContentKind.files:
        return const ['FILE'];
      case SharedContentKind.voice:
        return const ['AUDIO'];
      case SharedContentKind.links:
        return const ['SHARE'];
    }
  }
}

const List<String> _ruMonthsFull = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const List<String> _enMonthsFull = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthHeader(String locale, DateTime date) {
  final months = locale.startsWith('ru') ? _ruMonthsFull : _enMonthsFull;
  final now = DateTime.now();
  final name = months[date.month - 1];
  final label = date.year == now.year ? name : '$name ${date.year}';
  return label.toUpperCase();
}

Widget _emptyState(ColorScheme cs, String label, IconData icon) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      ],
    ),
  );
}

Widget _loadingState(ColorScheme cs) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Center(
      child: SmallSpinner(size: 26, color: cs.primary),
    ),
  );
}

Widget _sectionHeader(ColorScheme cs, String label) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
    child: Text(
      label,
      style: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
  );
}

List<({DateTime month, List<SharedMediaItem> items})> _groupByMonth(
  List<SharedMediaItem> items,
) {
  final groups = <({DateTime month, List<SharedMediaItem> items})>[];
  DateTime? current;
  for (final item in items) {
    final dt = DateTime.fromMillisecondsSinceEpoch(item.time);
    final monthStart = DateTime(dt.year, dt.month);
    if (current == null || current != monthStart) {
      current = monthStart;
      groups.add((month: monthStart, items: [item]));
    } else {
      groups.last.items.add(item);
    }
  }
  return groups;
}

class _MenuAction {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  const _MenuAction(this.icon, this.label, this.onTap);
}

Future<void> _showItemMenu(BuildContext context, List<_MenuAction> actions) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          for (final action in actions)
            ListTile(
              leading: Icon(action.icon, color: cs.onSurface),
              title: Text(
                action.label,
                style: TextStyle(color: cs.onSurface, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                action.onTap();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _moreButton(ColorScheme cs, VoidCallback onTap, {bool overlay = false}) {
  if (overlay) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Symbols.more_horiz, color: Colors.white, size: 18),
      ),
    );
  }
  return IconButton(
    onPressed: onTap,
    icon: Icon(Symbols.more_vert, color: cs.onSurfaceVariant, size: 22),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
  );
}

void _notifySave(BuildContext context, MediaSaveResult result) {
  if (!context.mounted) return;
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

Future<void> _downloadAttachment(
  BuildContext context,
  SharedMediaItem item,
) async {
  final att = item.attachment;
  final now = DateTime.now().millisecondsSinceEpoch;

  if (att is PhotoAttachment) {
    final url = att.baseUrl ?? '';
    if (url.isEmpty) return;
    final result = await saveMediaFile(
      cacheName: 'photo_${att.photoId ?? url.hashCode}.jpg',
      resolveUrl: () async => url,
      saveName: 'IMG_$now.jpg',
      kind: SaveMediaKind.image,
    );
    if (context.mounted) _notifySave(context, result);
    return;
  }

  if (att is VideoAttachment) {
    final result = await saveMediaFile(
      cacheName: 'video_${att.videoId ?? item.messageId}.mp4',
      resolveUrl: () async {
        final sources = await messagesModule.getVideoSources(
          messageId: item.messageId,
          chatId: item.chatId,
          token: att.videoToken ?? '',
          videoId: att.videoId ?? 0,
        );
        return sources.values.isEmpty ? null : sources.values.first;
      },
      saveName: 'VID_$now.mp4',
      kind: SaveMediaKind.video,
    );
    if (context.mounted) _notifySave(context, result);
    return;
  }

  if (att is FileAttachment) {
    final fileId = att.fileId;
    if (fileId == null) return;
    final name = att.name ?? 'file_$now';
    final result = await saveMediaFile(
      cacheName: '${fileId}_$name',
      resolveUrl: () => messagesModule.getFileUrl(
        messageId: item.messageId,
        chatId: item.chatId,
        fileId: fileId,
      ),
      saveName: name,
      kind: SaveMediaKind.file,
    );
    if (context.mounted) _notifySave(context, result);
    return;
  }

  if (att is AudioAttachment) {
    final url = att.fileUrl ?? att.baseUrl ?? '';
    if (url.isEmpty) return;
    final result = await saveMediaFile(
      cacheName: '${att.audioId ?? item.messageId}.ogg',
      resolveUrl: () async => url,
      saveName: 'AUD_$now.ogg',
      kind: SaveMediaKind.file,
    );
    if (context.mounted) _notifySave(context, result);
  }
}

class CommonChatsTab extends StatefulWidget {
  final int userId;
  final String emptyLabel;

  const CommonChatsTab({
    super.key,
    required this.userId,
    required this.emptyLabel,
  });

  @override
  State<CommonChatsTab> createState() => _CommonChatsTabState();
}

class _CommonChatsTabState extends State<CommonChatsTab> {
  bool _loading = true;
  List<CommonChatEntry> _chats = const [];
  Map<int, int> _onlineByChat = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chats = await sharedContentModule.fetchCommonChats(widget.userId);

    final allIds = <int>{};
    for (final c in chats) {
      allIds.addAll(c.participantIds);
    }

    final onlineByChat = <int, int>{};
    if (allIds.isNotEmpty) {
      try {
        final presence = await PresenceFetch.getMany(allIds.toList());
        for (final c in chats) {
          var online = 0;
          for (final id in c.participantIds) {
            if ((presence[id]?['status'] as int?) == 1) online++;
          }
          onlineByChat[c.id] = online;
        }
      } catch (e) {
        logger.w('CommonChatsTab presence failed: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _chats = chats;
      _onlineByChat = onlineByChat;
      _loading = false;
    });
  }

  void _openChat(CommonChatEntry chat) {
    final type = chat.type == 'CHANNEL' ? 'CHANNEL' : 'CHAT';
    pushSwipeable(
      context,
      (_) => ChatScreen(
        chatId: chat.id,
        name: chat.title,
        imageUrl: chat.iconUrl ?? '',
        chatType: type,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return _loadingState(cs);
    if (_chats.isEmpty) {
      return _emptyState(cs, widget.emptyLabel, Icons.group);
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _chats.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 68,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            _tile(cs, _chats[i]),
          ],
        ],
      ),
    );
  }

  Widget _tile(ColorScheme cs, CommonChatEntry chat) {
    final l10n = AppLocalizations.of(context)!;
    final online = _onlineByChat[chat.id] ?? 0;
    final total = chat.participantsCount;
    final subtitle = online > 0
        ? l10n.chatInfoOnlineOfTotal('$online', '$total')
        : l10n.sharedMembersCount(total);

    return InkWell(
      onTap: () => _openChat(chat),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            KometAvatar(
              name: chat.title,
              imageUrl: chat.iconUrl,
              size: 46,
              fontSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SharedMediaTab extends StatefulWidget {
  final int chatId;
  final String anchorMessageId;
  final int myId;
  final SharedContentKind kind;
  final String emptyLabel;
  final IconData emptyIcon;
  final void Function(String messageId, int time) onGoToMessage;
  final ScrollController? scrollController;

  const SharedMediaTab({
    super.key,
    required this.chatId,
    required this.anchorMessageId,
    required this.myId,
    required this.kind,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.onGoToMessage,
    this.scrollController,
  });

  @override
  State<SharedMediaTab> createState() => _SharedMediaTabState();
}

class _SharedMediaTabState extends State<SharedMediaTab> {
  static const int _pageSize = 60;

  bool _loading = true;
  bool _loadingMore = false;
  bool _canLoadMore = false;
  int _total = 0;
  final List<SharedMediaItem> _items = [];
  final Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
    _load(widget.anchorMessageId, initial: true);
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 800) {
      _loadMore();
    }
  }

  Future<void> _load(String anchor, {required bool initial}) async {
    final page = await sharedContentModule.fetchMedia(
      chatId: widget.chatId,
      anchorMessageId: anchor,
      attachTypes: widget.kind.attachTypes,
      forward: initial ? _pageSize : 0,
      backward: _pageSize,
    );
    if (!mounted) return;

    var added = 0;
    for (final item in page.items) {
      if (_seen.add(item.dedupKey)) {
        _items.add(item);
        added++;
      }
    }
    _items.sort((a, b) => b.time.compareTo(a.time));
    _total = page.total > _total ? page.total : _total;

    setState(() {
      _canLoadMore = added > 0 && _items.length < _total;
      _loading = false;
      _loadingMore = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoLoad());
  }

  void _maybeAutoLoad() {
    if (!mounted || !_hasMore || _loadingMore) return;
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.maxScrollExtent - position.pixels <= 800) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    await _load(_items.last.messageId, initial: false);
  }

  bool get _hasMore => _canLoadMore;

  String _resolveName(int senderId) {
    final l10n = AppLocalizations.of(context)!;
    if (senderId == widget.myId) return l10n.callParticipantYou;
    return ContactCache.get(senderId) ?? '#$senderId';
  }

  void _goTo(SharedMediaItem item) =>
      widget.onGoToMessage(item.messageId, item.time);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return _loadingState(cs);
    if (_items.isEmpty) {
      return _emptyState(cs, widget.emptyLabel, widget.emptyIcon);
    }

    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;
    final groups = _groupByMonth(_items);
    final children = <Widget>[];

    for (final group in groups) {
      children.add(_sectionHeader(cs, _monthHeader(locale, group.month)));
      switch (widget.kind) {
        case SharedContentKind.media:
          children.add(_mediaGrid(cs, group.items));
        case SharedContentKind.files:
          children.addAll(
            group.items.map((i) => _FileRow(item: i, onGoTo: () => _goTo(i))),
          );
        case SharedContentKind.voice:
          children.addAll(
            group.items.map(
              (i) => _ProfileVoiceTile(
                item: i,
                senderName: _resolveName(i.senderId),
                onGoTo: () => _goTo(i),
              ),
            ),
          );
        case SharedContentKind.links:
          children.addAll(
            group.items.map((i) => _LinkRow(item: i, onGoTo: () => _goTo(i))),
          );
      }
    }

    if (_hasMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _loadingMore
                ? SmallSpinner(size: 22, color: cs.primary)
                : TextButton(
                    onPressed: _loadMore,
                    child: Text(l10n.sharedLoadMore),
                  ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _mediaGrid(ColorScheme cs, List<SharedMediaItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _MediaTile(
            item: items[index],
            onGoTo: () => _goTo(items[index]),
            onGoToMessage: widget.onGoToMessage,
          ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final SharedMediaItem item;
  final VoidCallback onGoTo;
  final void Function(String messageId, int time) onGoToMessage;

  const _MediaTile({
    required this.item,
    required this.onGoTo,
    required this.onGoToMessage,
  });

  void _menu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showItemMenu(context, [
      _MenuAction(Symbols.arrow_forward, l10n.sharedGoToMessage, () async {
        onGoTo();
      }),
      _MenuAction(Symbols.download, l10n.sharedDownload, () async {
        await _downloadAttachment(context, item);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final att = item.attachment;
    final video = att is VideoAttachment ? att : null;
    final duration = video?.duration ?? 0;
    final thumb = att.baseUrl?.isNotEmpty == true
        ? att.baseUrl
        : att.previewData;

    return GestureDetector(
      onTap: () => _open(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: cs.surfaceContainerHighest),
            if (thumb != null && thumb.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                fadeInDuration: const Duration(milliseconds: 120),
                errorWidget: (_, _, _) => Icon(
                  video != null ? Symbols.movie : Symbols.image,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            if (video != null) ...[
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              const Center(
                child: Icon(Symbols.play_arrow, color: Colors.white, size: 34),
              ),
              if (duration > 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Text(
                    formatSecondsMmSs((duration / 1000).round()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            Positioned(
              top: 4,
              right: 4,
              child: _moreButton(cs, () => _menu(context), overlay: true),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final att = item.attachment;
    if (att is VideoAttachment) {
      final sources = await messagesModule.getVideoSources(
        messageId: item.messageId,
        chatId: item.chatId,
        token: att.videoToken ?? '',
        videoId: att.videoId ?? 0,
      );
      if (!context.mounted) return;
      if (sources.isEmpty) {
        showCustomNotification(context, 'Не удалось загрузить видео');
        return;
      }
      pushSwipeable(context, (_) => VideoPlayerScreen(sources: sources));
      return;
    }
    final url = att.baseUrl ?? att.previewData ?? '';
    if (url.isEmpty) return;

    final photo = att is PhotoAttachment && (att.baseUrl ?? '').isNotEmpty
        ? att
        : PhotoAttachment(baseUrl: url);
    pushSwipeable(
      context,
      (_) => PhotoViewerScreen(
        photos: [photo],
        chatId: item.chatId,
        message: CachedMessage(
          id: item.messageId,
          accountId: 0,
          chatId: item.chatId,
          senderId: item.senderId,
          time: item.time,
        ),
        actions: PhotoViewerActions(goToMessage: onGoToMessage),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final SharedMediaItem item;
  final VoidCallback onGoTo;

  const _FileRow({required this.item, required this.onGoTo});

  void _menu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showItemMenu(context, [
      _MenuAction(Symbols.arrow_forward, l10n.sharedGoToMessage, () async {
        onGoTo();
      }),
      _MenuAction(Symbols.download, l10n.sharedDownload, () async {
        await _downloadAttachment(context, item);
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final att = item.attachment as FileAttachment;
    final fullName = att.name ?? 'file';
    final dot = fullName.lastIndexOf('.');
    final ext = dot > 0 && dot < fullName.length - 1
        ? fullName.substring(dot + 1).toUpperCase()
        : '';
    final displayName = dot > 0 ? fullName.substring(0, dot) : fullName;
    final size = att.size ?? 0;
    final cacheName = '${att.fileId}_$fullName';

    return InkWell(
      onTap: () => _open(context, cacheName),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            _badge(cs, ext, cacheName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ext.isEmpty
                        ? formatBytes(size)
                        : '$ext • ${formatBytes(size)}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            _moreButton(cs, () => _menu(context)),
          ],
        ),
      ),
    );
  }

  Widget _badge(ColorScheme cs, String ext, String cacheName) {
    return SizedBox(
      width: 46,
      height: 46,
      child: ValueListenableBuilder<double?>(
        valueListenable: MediaDownloadProgress.notifier(cacheName),
        builder: (context, progress, _) {
          return Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: progress != null
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      value: progress > 0 ? progress : null,
                      color: cs.primary,
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Symbols.download,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        size: 26,
                      ),
                      if (ext.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          child: Text(
                            ext,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, String cacheName) async {
    final att = item.attachment as FileAttachment;
    final fileId = att.fileId;
    if (fileId == null) return;
    if (MediaDownloadProgress.notifier(cacheName).value != null) return;

    MediaDownloadProgress.set(cacheName, 0);
    final result = await openCachedFile(
      cacheName,
      () => messagesModule.getFileUrl(
        messageId: item.messageId,
        chatId: item.chatId,
        fileId: fileId,
      ),
      onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
    );
    MediaDownloadProgress.set(cacheName, null);

    if (!context.mounted) return;
    if (!result.ok) {
      showCustomNotification(context, 'Не удалось открыть файл');
    }
  }
}

class _LinkRow extends StatelessWidget {
  final SharedMediaItem item;
  final VoidCallback onGoTo;

  const _LinkRow({required this.item, required this.onGoTo});

  void _menu(BuildContext context, String url) {
    final l10n = AppLocalizations.of(context)!;
    _showItemMenu(context, [
      _MenuAction(Symbols.arrow_forward, l10n.sharedGoToMessage, () async {
        onGoTo();
      }),
      if (url.isNotEmpty)
        _MenuAction(Symbols.content_copy, l10n.sharedCopyLink, () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (context.mounted) {
            showCustomNotification(context, l10n.sharedLinkCopied);
          }
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final att = item.attachment as ShareAttachment;
    final url = att.url ?? '';
    final host =
        att.host ?? (url.isNotEmpty ? Uri.tryParse(url)?.host ?? '' : '');
    final title = att.title ?? url;
    final image = att.image;
    final thumb = image?.baseUrl?.isNotEmpty == true
        ? image!.baseUrl
        : image?.previewData;

    return InkWell(
      onTap: url.isEmpty ? null : () => openExternalUrl(context, url),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 46,
                height: 46,
                color: cs.surfaceContainerHighest,
                child: (thumb != null && thumb.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        errorWidget: (_, _, _) => Icon(
                          Symbols.link,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      )
                    : Icon(
                        Symbols.link,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (host.isNotEmpty)
                    Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  if (title.isNotEmpty)
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (att.description != null &&
                      att.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      att.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                  if (url.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.primary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            _moreButton(cs, () => _menu(context, url)),
          ],
        ),
      ),
    );
  }
}

class _ProfileVoiceTile extends StatefulWidget {
  final SharedMediaItem item;
  final String senderName;
  final VoidCallback onGoTo;

  const _ProfileVoiceTile({
    required this.item,
    required this.senderName,
    required this.onGoTo,
  });

  @override
  State<_ProfileVoiceTile> createState() => _ProfileVoiceTileState();
}

class _ProfileVoiceTileState extends State<_ProfileVoiceTile> {
  OggOpusPlayer? _player;
  bool _isPlaying = false;
  bool _loadingAudio = false;
  Timer? _ticker;
  final ValueNotifier<double> _progress = ValueNotifier(0.0);

  AudioAttachment get _audio => widget.item.attachment as AudioAttachment;
  int get _durationSec => ((_audio.duration ?? 0) / 1000).round();

  @override
  void dispose() {
    _ticker?.cancel();
    _player?.state.removeListener(_onPlayerState);
    _player?.dispose();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_loadingAudio) return;

    if (_player != null) {
      if (_isPlaying) {
        _player!.pause();
      } else {
        final dur = _audio.duration ?? 0;
        if (dur > 0 && _player!.currentPosition * 1000 >= dur - 50) {
          _progress.value = 0;
        }
        _player!.play();
      }
      return;
    }

    final url = _audio.fileUrl ?? _audio.baseUrl ?? '';
    if (url.isEmpty) return;

    setState(() => _loadingAudio = true);
    try {
      final name = '${_audio.audioId ?? widget.item.messageId}.ogg';
      final file = await MediaCache.getOrDownload(name, url);
      if (!mounted) return;
      if (file == null) {
        showCustomNotification(context, 'Не удалось загрузить аудио');
        return;
      }
      final player = OggOpusPlayer(file.path);
      _player = player;
      player.state.addListener(_onPlayerState);
      _ticker = Timer.periodic(
        const Duration(milliseconds: 60),
        (_) => _onTick(),
      );
      player.play();
    } catch (e) {
      logger.w('ProfileVoiceTile._togglePlay: $e');
      if (mounted) showCustomNotification(context, 'Ошибка воспроизведения');
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  void _onTick() {
    final player = _player;
    final dur = _audio.duration ?? 0;
    if (player == null || dur <= 0) return;
    _progress.value = (player.currentPosition * 1000 / dur).clamp(0.0, 1.0);
  }

  void _onPlayerState() {
    if (!mounted) return;
    final state = _player?.state.value;
    final playing = state == PlayerState.playing;
    if (playing != _isPlaying) setState(() => _isPlaying = playing);
    if (state == PlayerState.ended) _progress.value = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateTime.fromMillisecondsSinceEpoch(widget.item.time);
    final subtitle =
        '${formatSecondsMmSs(_durationSec)} • ${formatDateTimeWords(date)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: _loadingAudio
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SmallSpinner(size: 36, color: Colors.white),
                    )
                  : ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, progress, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          if (progress > 0 && progress < 1)
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: progress,
                                color: cs.onPrimary.withValues(alpha: 0.5),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          child!,
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Symbols.pause : Symbols.play_arrow,
                        color: cs.onPrimary,
                        size: 24,
                        fill: 1,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
          _moreButton(cs, () => _menu(context)),
        ],
      ),
    );
  }

  void _menu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _showItemMenu(context, [
      _MenuAction(Symbols.arrow_forward, l10n.sharedGoToMessage, () async {
        widget.onGoTo();
      }),
      _MenuAction(Symbols.download, l10n.sharedDownload, () async {
        await _downloadAttachment(context, widget.item);
      }),
    ]);
  }
}
