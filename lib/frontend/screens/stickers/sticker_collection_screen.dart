import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../backend/modules/stickers.dart';
import '../../../main.dart' show stickersModule;
import '../../../models/sticker.dart';
import '../../widgets/chat_menu_overlay.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/lottie_image.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/sticker_pin.dart';
import 'sticker_screen_bar.dart';

enum StickerCollection { recent, favorites }

class StickerCollectionScreen extends StatefulWidget {
  const StickerCollectionScreen({
    super.key,
    this.module,
    required this.collection,
  });

  final StickerCollection collection;

  final StickersModule? module;

  @override
  State<StickerCollectionScreen> createState() =>
      _StickerCollectionScreenState();
}

class _StickerCollectionScreenState extends State<StickerCollectionScreen> {
  StickersModule get _stickers => widget.module ?? stickersModule;

  final Set<int> _selected = {};
  bool _loading = true;
  bool _editing = false;
  bool _deleting = false;

  bool get _recent => widget.collection == StickerCollection.recent;

  ValueListenable<List<int>> get _ids =>
      _recent ? _stickers.recentStickerIds : _stickers.favoriteStickerIds;

  @override
  void initState() {
    super.initState();
    _ids.addListener(_onIdsChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _ids.removeListener(_onIdsChanged);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await (_recent
          ? _stickers.ensureLoaded()
          : _stickers.ensureFavoritesLoaded());
      await _stickers.ensureStickers(_ids.value);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _onIdsChanged() {
    if (!mounted) return;
    final ids = _ids.value.toSet();
    setState(() {
      _selected.retainAll(ids);
      if (ids.isEmpty) _editing = false;
    });
    unawaited(
      _stickers
          .ensureStickers(_ids.value)
          .then((_) => mounted ? setState(() {}) : null, onError: (_) {}),
    );
  }

  void _startEditing([int? first]) {
    Haptics.tap();
    setState(() {
      _editing = true;
      if (first != null) _selected.add(first);
    });
  }

  void _stopEditing() {
    setState(() {
      _editing = false;
      _selected.clear();
    });
  }

  void _toggle(int id) {
    Haptics.tap();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _openMenu(BuildContext anchor) {
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    showChatMenu(
      context: anchor,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      items: [
        ChatMenuItem(
          icon: Symbols.edit,
          label: AppLocalizations.of(context)!.stickerListEdit,
          onTap: _startEditing,
        ),
      ],
    );
  }

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context)!;
    final count = _selected.length;
    if (count == 0 || _deleting) return;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.stickerListDeleteTitle(count),
      message: l10n.stickerListDeleteBody,
      confirmLabel: l10n.stickerListDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final selected = {..._selected};
    final remaining = [
      for (final id in _ids.value)
        if (!selected.contains(id)) id,
    ];
    setState(() => _deleting = true);
    String? failure;
    try {
      final ok = _recent
          ? await _stickers.removeRecentStickers(selected)
          : await _stickers.setFavoriteStickers(remaining);
      if (!ok) failure = l10n.stickerListDeleteFailed;
    } catch (e) {
      failure = stickerActionError(e) ?? l10n.stickerListDeleteFailed;
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    if (failure != null) {
      showCustomNotification(context, failure);
      return;
    }
    _stopEditing();
  }

  PreferredSizeWidget _bar(BuildContext context, List<int> ids) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (_editing) {
      return stickerScreenBar(
        context,
        leading: IconButton(
          key: const ValueKey('sticker-list-stop-editing'),
          icon: Icon(Symbols.close, color: cs.onSurface, size: 24),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: _stopEditing,
        ),
        title: Text(l10n.stickerListSelected(_selected.length)),
        actions: [
          _deleting
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SmallSpinner(size: 24, color: cs.error),
                )
              : IconButton(
                  key: const ValueKey('sticker-list-delete'),
                  icon: Icon(
                    Symbols.delete,
                    color: _selected.isEmpty
                        ? cs.onSurface.withValues(alpha: 0.38)
                        : cs.error,
                    size: 24,
                  ),
                  tooltip: l10n.stickerListDelete,
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
        ],
      );
    }
    return stickerScreenBar(
      context,
      title: Text(
        _recent ? l10n.stickerRecentTitle : l10n.stickerFavoritesTitle,
      ),
      actions: [
        if (ids.isNotEmpty)
          Builder(
            builder: (anchor) => IconButton(
              key: const ValueKey('sticker-list-menu'),
              icon: Icon(Symbols.more_vert, color: cs.onSurface, size: 24),
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              onPressed: () => _openMenu(anchor),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ids = _ids.value;
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _stopEditing();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: _bar(context, ids),
        body: _body(cs, ids),
      ),
    );
  }

  Widget _body(ColorScheme cs, List<int> ids) {
    if (_loading && ids.isEmpty) {
      return Center(child: SmallSpinner(size: 28, color: cs.primary));
    }
    if (ids.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.stickerPanelEmpty,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 8.0;
        final columns = ((constraints.maxWidth - padding * 2) / 84)
            .floor()
            .clamp(4, 8);
        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(padding, 4, padding, 32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
          ),
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final id = ids[index];
            return _StickerCell(
              key: ValueKey(id),
              item: _stickers.cachedSticker(id),
              editing: _editing,
              selected: _selected.contains(id),
              onTap: _editing ? () => _toggle(id) : null,
              onLongPress: _editing ? null : () => _startEditing(id),
            );
          },
        );
      },
    );
  }
}

class _StickerCell extends StatelessWidget {
  const _StickerCell({
    super.key,
    required this.item,
    required this.editing,
    required this.selected,
    this.onTap,
    this.onLongPress,
  });

  final StickerItem? item;
  final bool editing;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = this.item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedScale(
              scale: editing && selected ? 0.82 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: item == null
                    ? const SizedBox.expand()
                    : LottieImage(
                        url: item.url,
                        lottieUrl: item.lottieUrl,
                        memCacheWidth: 220,
                      ),
              ),
            ),
          ),
          if (editing)
            Positioned(
              top: 4,
              right: 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? cs.primary
                      : cs.surface.withValues(alpha: 0.6),
                  border: Border.all(
                    color: selected ? cs.primary : cs.outline,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(
                        Symbols.check,
                        size: 16,
                        color: cs.onPrimary,
                        weight: 600,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
