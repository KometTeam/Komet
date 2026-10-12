import 'package:flutter/material.dart';

import '../../../../backend/modules/chats.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_admin_widgets.dart';
import 'members_pager.dart';

class MembersList extends StatefulWidget {
  final MembersPager controller;
  final List<Widget> header;
  final bool Function(ChatMemberEntry member) include;
  final Widget Function(BuildContext context, ChatMemberEntry member)
  itemBuilder;
  final String emptyLabel;

  const MembersList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.emptyLabel,
    this.header = const [],
    this.include = _everyone,
  });

  static bool _everyone(ChatMemberEntry member) => true;

  @override
  State<MembersList> createState() => _MembersListState();
}

class _MembersListState extends State<MembersList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.controller.addListener(_scheduleFill);
  }

  @override
  void didUpdateWidget(MembersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_scheduleFill);
    widget.controller.addListener(_scheduleFill);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleFill);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scroll.position;
    if (widget.controller.failed) return;
    if (position.pixels >= position.maxScrollExtent - 400) {
      widget.controller.loadMore();
    }
  }

  void _scheduleFill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final controller = widget.controller;
      if (controller.failed || controller.searching) return;
      if (_scroll.position.maxScrollExtent <= 0) controller.loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final members = controller.members.where(widget.include).toList();
        final header = widget.header;
        return ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.only(
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: header.length + members.length + 1,
          itemBuilder: (context, index) {
            if (index < header.length) return header[index];
            final memberIndex = index - header.length;
            if (memberIndex < members.length) {
              final member = members[memberIndex];
              return KeyedSubtree(
                key: ValueKey(member.id),
                child: widget.itemBuilder(context, member),
              );
            }
            final searchMore = controller.searching && !controller.end;
            return MembersListFooter(
              loading: controller.loading,
              onRetry: controller.failed || searchMore
                  ? controller.loadMore
                  : null,
              message: controller.failed
                  ? l10n.membersLoadFailed
                  : searchMore
                  ? l10n.membersSearchMore
                  : members.isEmpty && controller.end
                  ? widget.emptyLabel
                  : null,
            );
          },
        );
      },
    );
  }
}
