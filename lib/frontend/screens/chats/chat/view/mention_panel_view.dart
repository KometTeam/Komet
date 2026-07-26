import 'package:flutter/material.dart';

import 'package:komet/frontend/screens/chats/chat/mention_panel_controller.dart';
import 'package:komet/frontend/widgets/mention_suggestions_panel.dart';

class MentionPanelView extends StatelessWidget {
  const MentionPanelView({super.key, required this.mentionPanel});

  final MentionPanelController mentionPanel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: mentionPanel.anim,
      child: ValueListenableBuilder<List<MentionCandidate>>(
        valueListenable: mentionPanel.matches,
        builder: (context, matches, _) => ValueListenableBuilder<bool>(
          valueListenable: mentionPanel.loadingMore,
          builder: (context, loading, _) => MentionSuggestionsPanel(
            candidates: matches,
            loadingMore: loading && mentionPanel.hasMore,
            onSelected: mentionPanel.select,
            onLoadMore: mentionPanel.loadMore,
          ),
        ),
      ),
      builder: (context, child) {
        final t = mentionPanel.anim.value;
        if (t == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: IgnorePointer(
            ignoring: t < 1,
            child: Opacity(opacity: t, child: child),
          ),
        );
      },
    );
  }
}
