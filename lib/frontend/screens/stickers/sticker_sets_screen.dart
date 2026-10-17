import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../l10n/app_localizations.dart';
import '../../../backend/modules/stickers.dart';
import '../../../main.dart' show stickersModule;
import '../../../models/sticker.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/lottie_image.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/sticker_pack_sheet.dart';
import '../../widgets/sticker_pin.dart';
import '../../widgets/swipe_route.dart';
import 'sticker_screen_bar.dart';
import 'sticker_settings_screen.dart';

class StickerSetsScreen extends StatefulWidget {
  const StickerSetsScreen({super.key, this.module});

  final StickersModule? module;

  @override
  State<StickerSetsScreen> createState() => _StickerSetsScreenState();
}

class _StickerSetsScreenState extends State<StickerSetsScreen> {
  StickersModule get _stickers => widget.module ?? stickersModule;

  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Set<int> _busy = {};
  bool _loading = true;
  bool _failed = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _stickers.setsChanged.addListener(_onSetsChanged);
    _search.addListener(_onSetsChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _stickers.setsChanged.removeListener(_onSetsChanged);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var failed = false;
    try {
      await _stickers.ensureLoaded();
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = failed;
    });
  }

  void _onSetsChanged() {
    if (mounted) setState(() {});
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _searchFocus.requestFocus();
    } else {
      _search.clear();
      _searchFocus.unfocus();
    }
  }

  List<StickerSet> get _visibleSets {
    final query = _search.text.trim().toLowerCase();
    final sets = _stickers.sets.where((s) => s.stickerIds.isNotEmpty);
    if (query.isEmpty) return sets.toList();
    return sets.where((s) => s.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _toggleSet(StickerSet set) async {
    if (!_busy.add(set.id)) return;
    setState(() {});
    final l10n = AppLocalizations.of(context)!;
    final adding = !_stickers.isFavorite(set.id);
    String? failure;
    try {
      final ok = adding
          ? await _stickers.favoriteSet(set.id)
          : await _stickers.unfavoriteSet(set.id);
      if (!ok) failure = l10n.stickerPackSheetActionFailed;
    } catch (e) {
      failure = stickerActionError(e) ?? l10n.stickerPackSheetActionFailed;
    }
    if (!mounted) return;
    setState(() => _busy.remove(set.id));
    showCustomNotification(
      context,
      failure ??
          (adding ? l10n.stickerPackSheetAdded : l10n.stickerPackSheetRemoved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: stickerScreenBar(
        context,
        title: _searching
            ? TextField(
                key: const ValueKey('sticker-sets-search-field'),
                controller: _search,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: cs.onSurface, fontSize: 17),
                decoration: InputDecoration(
                  hintText: l10n.stickerSetsSearchHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
              )
            : Text(l10n.stickerSetsTitle),
        actions: [
          IconButton(
            key: const ValueKey('sticker-sets-search'),
            icon: Icon(
              _searching ? Symbols.close : Symbols.search,
              color: cs.onSurface,
              size: 24,
            ),
            tooltip: l10n.stickerSetsSearchHint,
            onPressed: _toggleSearch,
          ),
          IconButton(
            key: const ValueKey('sticker-sets-settings'),
            icon: Icon(Symbols.settings, color: cs.onSurface, size: 24),
            tooltip: l10n.stickerSettingsTitle,
            onPressed: () => pushSwipeable(
              context,
              (_) => StickerSettingsScreen(module: widget.module),
            ),
          ),
        ],
      ),
      body: _body(cs, l10n),
    );
  }

  Widget _body(ColorScheme cs, AppLocalizations l10n) {
    final sets = _visibleSets;
    if (_loading && sets.isEmpty) {
      return Center(child: SmallSpinner(size: 28, color: cs.primary));
    }
    if (sets.isEmpty) {
      return Center(
        child: Text(
          _failed
              ? l10n.stickerPanelLoadFailed
              : _search.text.trim().isEmpty
              ? l10n.stickerPanelEmpty
              : l10n.contactsSearchEmpty,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: sets.length,
      itemBuilder: (context, index) {
        final set = sets[index];
        return _StickerSetTile(
          key: ValueKey(set.id),
          module: _stickers,
          set: set,
          added: _stickers.isFavorite(set.id),
          busy: _busy.contains(set.id),
          onToggle: () => _toggleSet(set),
          onOpen: () => showStickerPackSheet(context, knownSetId: set.id),
        );
      },
    );
  }
}

class _StickerSetTile extends StatefulWidget {
  const _StickerSetTile({
    super.key,
    required this.module,
    required this.set,
    required this.added,
    required this.busy,
    required this.onToggle,
    required this.onOpen,
  });

  static const int previewCount = 5;

  final StickersModule module;
  final StickerSet set;
  final bool added;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  State<_StickerSetTile> createState() => _StickerSetTileState();
}

class _StickerSetTileState extends State<_StickerSetTile> {
  late Future<List<StickerItem>> _preview = _loadPreview();

  @override
  void didUpdateWidget(_StickerSetTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.id != widget.set.id) _preview = _loadPreview();
  }

  Future<List<StickerItem>> _loadPreview() => widget.module.ensureStickers(
    widget.set.stickerIds.take(_StickerSetTile.previewCount).toList(),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: widget.onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.set.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.stickerPackSheetStickerCount(
                          widget.set.stickerIds.length,
                        ),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _toggleButton(cs, l10n),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cell =
                    constraints.maxWidth / _StickerSetTile.previewCount;
                return SizedBox(
                  height: cell,
                  child: FutureBuilder<List<StickerItem>>(
                    future: _preview,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <StickerItem>[];
                      return Row(
                        children: [
                          for (final item in items)
                            SizedBox(
                              width: cell,
                              height: cell,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: LottieImage(
                                  url: item.url,
                                  memCacheWidth: 220,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(ColorScheme cs, AppLocalizations l10n) {
    final label = widget.added
        ? l10n.stickerPackSheetRemove
        : l10n.stickerSetsAdd;
    final child = widget.busy
        ? SmallSpinner(
            size: 18,
            color: widget.added ? cs.onSecondaryContainer : cs.onPrimary,
          )
        : Text(label);
    final onPressed = widget.busy ? null : widget.onToggle;
    return widget.added
        ? FilledButton.tonal(
            key: ValueKey('sticker-set-remove-${widget.set.id}'),
            onPressed: onPressed,
            child: child,
          )
        : FilledButton(
            key: ValueKey('sticker-set-add-${widget.set.id}'),
            onPressed: onPressed,
            child: child,
          );
  }
}
