import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/format.dart';
import '../../main.dart' show stickersModule, messagesModule;
import '../../models/sticker.dart';
import '../screens/chats/chat_list_screen.dart';
import 'custom_notification.dart';
import 'small_spinner.dart';
import 'lottie_image.dart';
import 'sticker_peek.dart';

enum _PackAction { forward, copyLink }

Future<void> showStickerPackSheet(
  BuildContext context, {
  int? stickerId,
  int? knownSetId,
}) {
  assert(stickerId != null || knownSetId != null);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _StickerPackSheet(stickerId: stickerId, knownSetId: knownSetId),
  );
}

class _StickerPackSheet extends StatefulWidget {
  final int? stickerId;
  final int? knownSetId;

  const _StickerPackSheet({this.stickerId, this.knownSetId});

  @override
  State<_StickerPackSheet> createState() => _StickerPackSheetState();
}

class _StickerPackSheetState extends State<_StickerPackSheet> {
  bool _loading = true;
  bool _busy = false;
  bool _isFavorite = false;
  Object? _error;
  StickerSet? _set;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final setId =
          widget.knownSetId ??
          (widget.stickerId != null
              ? await stickersModule.resolveSetId(widget.stickerId!)
              : null);
      if (setId == null) throw Exception('no set');
      final setFuture = stickersModule.ensureSet(setId);
      final favoritesFuture = stickersModule.ensureFavoritesLoaded();
      final set = await setFuture;
      await favoritesFuture;
      if (set == null) throw Exception('no meta');
      await stickersModule.ensureStickers(set.stickerIds);
      if (!mounted) return;
      setState(() {
        _set = set;
        _isFavorite = stickersModule.isFavorite(set.id);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final set = _set;
    if (set == null || _busy) return;
    setState(() => _busy = true);
    final wasFavorite = _isFavorite;
    try {
      final ok = wasFavorite
          ? await stickersModule.unfavoriteSet(set.id)
          : await stickersModule.favoriteSet(set.id);
      if (!mounted) return;
      if (ok) {
        setState(() => _isFavorite = !wasFavorite);
        showCustomNotification(
          context,
          wasFavorite ? 'Стикерпак удалён' : 'Стикерпак добавлен',
        );
      } else {
        showCustomNotification(context, 'Не удалось выполнить действие');
      }
    } catch (e) {
      if (!mounted) return;
      showCustomNotification(context, 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copyLink(StickerSet set) {
    final link = set.link;
    if (link == null || link.isEmpty) {
      showCustomNotification(context, 'Ссылка недоступна');
      return;
    }
    Clipboard.setData(ClipboardData(text: link));
    showCustomNotification(context, 'Ссылка скопирована');
  }

  Future<void> _forward(StickerSet set) async {
    final link = set.link;
    if (link == null || link.isEmpty) {
      showCustomNotification(context, 'Ссылка недоступна');
      return;
    }
    final target = await openForwardScreen(context: context);
    if (target == null || !mounted) return;
    final ok = await messagesModule.sendLinkMessage(target.chatId, link);
    if (!mounted) return;
    showCustomNotification(
      context,
      ok ? 'Переслано в «${target.name}»' : 'Не удалось переслать',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(child: _buildBody(cs)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_loading) {
      return Center(child: SmallSpinner());
    }
    final set = _set;
    if (_error != null || set == null) {
      return Center(
        child: Text(
          'Стикерпак недоступен',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return Column(
      children: [
        _buildHeader(cs, set),
        Expanded(child: _buildGrid(set)),
        _buildActionButton(cs),
      ],
    );
  }

  Widget _buildHeader(ColorScheme cs, StickerSet set) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  set.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${set.stickerIds.length} '
                  '${pluralRu(set.stickerIds.length, 'стикер', 'стикера', 'стикеров')}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
          _buildMenu(cs, set),
        ],
      ),
    );
  }

  Widget _buildMenu(ColorScheme cs, StickerSet set) {
    return PopupMenuButton<_PackAction>(
      icon: Icon(Symbols.more_horiz, color: cs.onSurfaceVariant),
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        switch (action) {
          case _PackAction.forward:
            _forward(set);
          case _PackAction.copyLink:
            _copyLink(set);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PackAction.forward,
          child: Row(
            children: [
              Icon(Symbols.forward, size: 20, color: cs.onSurface),
              const SizedBox(width: 12),
              const Text('Переслать'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _PackAction.copyLink,
          child: Row(
            children: [
              Icon(Symbols.link, size: 20, color: cs.onSurface),
              const SizedBox(width: 12),
              const Text('Скопировать ссылку'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(StickerSet set) {
    return StickerPeekScope(
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: set.stickerIds.length,
        itemBuilder: (context, i) {
          final item = stickersModule.cachedSticker(set.stickerIds[i]);
          if (item == null || item.url.isEmpty) {
            return const SizedBox.shrink();
          }
          return StickerPeekable(
            peekId: item.id,
            url: item.url,
            lottieUrl: item.lottieUrl,
            tags: item.tags,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: LottieImage(
                url: item.url,
                lottieUrl: item.lottieUrl,
                memCacheWidth: 220,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isFavorite
                  ? cs.surfaceContainerHighest
                  : cs.primary,
              foregroundColor: _isFavorite ? cs.onSurface : cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _busy ? null : _toggle,
            child: _busy
                ? SmallSpinner(
                    size: 22,
                    color: _isFavorite ? cs.onSurface : cs.onPrimary,
                  )
                : Text(
                    _isFavorite ? 'Убрать' : 'Добавить',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
