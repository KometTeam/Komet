import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/animoji.dart' show AnimojiModule;
import '../../core/utils/emoji_keyword_index.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show animojiModule;
import '../../models/animoji.dart';
import 'lottie_image.dart';
import 'small_spinner.dart';

class ReactionEmoji {
  final String emoji;
  final String? animationUrl;
  final String? staticUrl;

  const ReactionEmoji({required this.emoji, this.animationUrl, this.staticUrl});

  factory ReactionEmoji.fromAnimoji(Animoji animoji) => ReactionEmoji(
    emoji: animoji.emoji,
    animationUrl: animoji.lottieUrl,
    staticUrl: animoji.iconUrl,
  );
}

List<ReactionEmoji> availableReactions() {
  final catalog = animojiModule.animojis;
  if (catalog.isEmpty) {
    return AnimojiModule.fallbackReactions
        .map((emoji) => ReactionEmoji(emoji: emoji))
        .toList();
  }
  return catalog.map(ReactionEmoji.fromAnimoji).toList();
}

class ReactionEmojiPicker extends StatefulWidget {
  final ValueChanged<String> onPick;
  final Future<List<ReactionEmoji>> Function()? loadEmojis;
  final String? selected;

  const ReactionEmojiPicker({
    super.key,
    required this.onPick,
    this.loadEmojis,
    this.selected,
  });

  @override
  State<ReactionEmojiPicker> createState() => ReactionEmojiPickerState();
}

class ReactionEmojiPickerState extends State<ReactionEmojiPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ValueNotifier<bool> _scrolling = ValueNotifier(false);
  List<ReactionEmoji> _all = const [];
  List<ReactionEmoji> _results = const [];
  String _query = '';
  bool _loaded = false;

  bool _onScrollNotification(ScrollNotification n) {
    if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
      if (!_scrolling.value) _scrolling.value = true;
    } else if (n is ScrollEndNotification) {
      if (_scrolling.value) _scrolling.value = false;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await EmojiKeywordIndex.instance.ensureLoaded();
    final loader = widget.loadEmojis;
    final emojis = loader != null
        ? await loader()
        : EmojiKeywordIndex.instance.all
              .map((e) => ReactionEmoji(emoji: e))
              .toList();
    if (!mounted) return;
    setState(() {
      _all = emojis;
      _results = _all;
      _loaded = true;
    });
  }

  void _onQueryChanged(String value) {
    final q = value.trim();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _results = _all;
      } else {
        final matches = EmojiKeywordIndex.instance
            .search(q)
            .map(EmojiKeywordIndex.normalize)
            .toSet();
        _results = _all
            .where(
              (e) => matches.contains(EmojiKeywordIndex.normalize(e.emoji)),
            )
            .toList();
      }
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _onQueryChanged('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrolling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = widget.selected;
    final selected = current == null
        ? null
        : EmojiKeywordIndex.normalize(current);
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          _buildSearchField(cs),
          Expanded(
            child: !_loaded
                ? const Center(child: SmallSpinner(size: 26))
                : _results.isEmpty
                ? const SizedBox.shrink()
                : LottieScrollScope(
                    isScrolling: _scrolling,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        addAutomaticKeepAlives: false,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 48,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final reaction = _results[i];
                          return _EmojiCell(
                            reaction: reaction,
                            selected:
                                selected != null &&
                                EmojiKeywordIndex.normalize(reaction.emoji) ==
                                    selected,
                            onTap: () => widget.onPick(reaction.emoji),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Symbols.search, size: 22, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                cursorColor: cs.primary,
                style: TextStyle(color: cs.onSurface, fontSize: 15),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: AppLocalizations.of(context)!.emojiSearchHint,
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (_query.isEmpty)
              const SizedBox(width: 12)
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clearSearch,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Symbols.close,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  final ReactionEmoji reaction;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiCell({
    required this.reaction,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final glyph = Center(child: ReactionGlyph(reaction: reaction, size: 34));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.22),
              ),
              child: glyph,
            )
          : glyph,
    );
  }
}

class ReactionGlyph extends StatelessWidget {
  final ReactionEmoji reaction;
  final double size;

  const ReactionGlyph({super.key, required this.reaction, required this.size});

  @override
  Widget build(BuildContext context) {
    final anim = reaction.animationUrl;
    final still = reaction.staticUrl;
    final hasAsset =
        (anim != null && anim.isNotEmpty) ||
        (still != null && still.isNotEmpty);
    if (!hasAsset) {
      return Center(
        child: Text(reaction.emoji, style: TextStyle(fontSize: size * 0.9)),
      );
    }
    return LottieImage(
      lottieUrl: anim,
      url: still,
      size: size,
      memCacheWidth: (size * 3).round(),
    );
  }
}
