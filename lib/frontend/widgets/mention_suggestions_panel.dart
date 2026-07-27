import 'package:flutter/material.dart';

import '../screens/chats/chat/mention_panel_controller.dart';
import 'komet_avatar.dart';
import 'small_spinner.dart';

class MentionSuggestionsPanel extends StatefulWidget {
  final List<MentionCandidate> candidates;
  final double maxHeight;
  final bool loadingMore;
  final ValueChanged<MentionCandidate> onSelected;
  final VoidCallback onLoadMore;

  const MentionSuggestionsPanel({
    super.key,
    required this.candidates,
    required this.onSelected,
    required this.onLoadMore,
    this.loadingMore = false,
    this.maxHeight = 220,
  });

  @override
  State<MentionSuggestionsPanel> createState() =>
      _MentionSuggestionsPanelState();
}

class _MentionSuggestionsPanelState extends State<MentionSuggestionsPanel> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final candidates = widget.candidates;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: candidates.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SmallSpinner(size: 20, color: cs.onSurfaceVariant),
                ),
              )
            : ListView.separated(
                controller: _controller,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: candidates.length + (widget.loadingMore ? 1 : 0),
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 14,
                  endIndent: 14,
                  color: cs.outlineVariant.withValues(alpha: 0.18),
                ),
                itemBuilder: (context, i) {
                  if (i >= candidates.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: SmallSpinner(
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final candidate = candidates[i];
                  return InkWell(
                    onTap: () => widget.onSelected(candidate),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          KometAvatar(
                            name: candidate.name,
                            imageUrl: candidate.avatarUrl,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              candidate.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
