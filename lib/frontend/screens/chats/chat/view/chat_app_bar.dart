import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:komet/backend/modules/messages.dart' show CachedMessage;
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_frost.dart';

import 'chat_header.dart';
import 'frosted_panel.dart';
import 'search_view.dart';
import 'selection_bar.dart';
import '../chat_search_controller.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  static const double _glossyHeaderHeight = 76.0;
  static const double _glossySearchHeight = 58.0;
  static const double _edgeFadeHeight = 24.0;

  final ColorScheme cs;
  final Animation<double> searchAnim;
  final Animation<double> selectionAnim;
  final ChatChromeStyle chrome;
  final bool chromeVignette;
  final bool liquidChrome;
  final BackdropKey? barBackdrop;
  final BackdropKey? pillBackdrop;

  final bool glossyChrome;

  final bool embedded;
  final int chatId;
  final Object heroTag;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool isOfficial;
  final bool encrypted;
  final int myId;
  final ValueNotifier<String> headerStatus;
  final ValueListenable<int> scheduledCount;
  final ValueListenable<int> otherUnread;
  final bool showCall;
  final VoidCallback? onClose;
  final VoidCallback onOpenInfo;
  final VoidCallback onOpenScheduled;
  final VoidCallback onCall;
  final void Function(BuildContext) onMenu;

  final ValueListenable<Set<String>> selectedIds;
  final List<CachedMessage> Function(Set<String> ids) copyableSelection;
  final CachedMessage? Function(Set<String> ids) singleEditable;
  final VoidCallback onClearSelection;
  final void Function(List<CachedMessage>) onCopySelected;
  final void Function(CachedMessage) onEditSelected;
  final VoidCallback onDeleteSelected;

  final ChatSearchController search;
  final FocusNode searchFocusNode;
  final VoidCallback onCloseSearch;

  const ChatAppBar({
    super.key,
    required this.cs,
    required this.searchAnim,
    required this.selectionAnim,
    required this.chrome,
    required this.chromeVignette,
    required this.liquidChrome,
    required this.barBackdrop,
    required this.pillBackdrop,
    required this.glossyChrome,
    required this.embedded,
    required this.chatId,
    required this.heroTag,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    required this.isOfficial,
    required this.encrypted,
    required this.myId,
    required this.headerStatus,
    required this.scheduledCount,
    required this.otherUnread,
    required this.showCall,
    required this.onClose,
    required this.onOpenInfo,
    required this.onOpenScheduled,
    required this.onCall,
    required this.onMenu,
    required this.selectedIds,
    required this.copyableSelection,
    required this.singleEditable,
    required this.onClearSelection,
    required this.onCopySelected,
    required this.onEditSelected,
    required this.onDeleteSelected,
    required this.search,
    required this.searchFocusNode,
    required this.onCloseSearch,
  });

  double get _height {
    final searchT = Curves.easeOut.transform(searchAnim.value.clamp(0.0, 1.0));
    return glossyChrome
        ? ui.lerpDouble(_glossyHeaderHeight, _glossySearchHeight, searchT)!
        : kToolbarHeight;
  }

  @override
  Size get preferredSize => Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final height = _height;
    final barExtent = MediaQuery.paddingOf(context).top + height;
    final fadeStop = ((barExtent - _edgeFadeHeight) / barExtent).clamp(
      0.0,
      1.0,
    );
    return AppBar(
      backgroundColor: chrome == ChatChromeStyle.color
          ? (glossyChrome ? Colors.transparent : cs.surfaceContainerHigh)
          : Colors.transparent,
      flexibleSpace: chrome == ChatChromeStyle.blur
          ? FrostedPanel(
              tint: AppFrost.blurPanelTint(cs),
              border: Border(bottom: AppFrost.hairline(cs)),
              backdropKey: barBackdrop,
              child: const SizedBox.expand(),
            )
          : (chromeVignette && !glossyChrome)
          ? IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface,
                      cs.surface,
                      cs.surface.withValues(alpha: 0.0),
                    ],
                    stops: [0.0, fadeStop, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            )
          : (chrome == ChatChromeStyle.transparent && !glossyChrome)
          ? FrostedPanel(
              sigma: AppFrost.sigma,
              tint: AppFrost.glassTint(cs),
              border: Border(bottom: AppFrost.hairline(cs)),
              backdropKey: barBackdrop,
              child: const SizedBox.expand(),
            )
          : null,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: cs.onSurface),
      elevation: 0,
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      centerTitle: false,
      title: SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: Listenable.merge([selectionAnim, searchAnim]),
          builder: (context, _) {
            final t = Curves.easeOut.transform(
              selectionAnim.value.clamp(0.0, 1.0),
            );
            final s = Curves.easeOut.transform(
              searchAnim.value.clamp(0.0, 1.0),
            );
            return ValueListenableBuilder<Set<String>>(
              valueListenable: selectedIds,
              builder: (context, selected, _) => Stack(
                fit: StackFit.expand,
                children: [
                  if (t < 1 && s < 1)
                    IgnorePointer(
                      ignoring: t > 0.5 || s > 0.5,
                      child: Opacity(
                        opacity: (1 - t) * (1 - s),
                        child: Transform.translate(
                          offset: Offset(0, -height * 0.4 * t),
                          child: ChatHeaderRow(
                            glossy: glossyChrome,
                            frosted:
                                glossyChrome &&
                                chrome == ChatChromeStyle.transparent,
                            backdropVisible: t == 0 && s == 0,
                            liquid: liquidChrome,
                            backdropKey: pillBackdrop,
                            cs: cs,
                            embedded: embedded,
                            chatId: chatId,
                            heroTag: heroTag,
                            name: name,
                            imageUrl: imageUrl,
                            chatType: chatType,
                            isOfficial: isOfficial,
                            encrypted: encrypted,
                            myId: myId,
                            headerStatus: headerStatus,
                            scheduledCount: scheduledCount,
                            otherUnread: otherUnread,
                            showCall: showCall,
                            onClose: onClose,
                            onOpenInfo: onOpenInfo,
                            onOpenScheduled: onOpenScheduled,
                            onCall: onCall,
                            onMenu: onMenu,
                          ),
                        ),
                      ),
                    ),
                  if (t > 0)
                    IgnorePointer(
                      ignoring: t < 0.5,
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, height * 0.4 * (1 - t)),
                          child: SelectionTopBar(
                            cs: cs,
                            selected: selected,
                            glossy: glossyChrome,
                            copyMsgs: copyableSelection(selected),
                            editMsg: singleEditable(selected),
                            onClear: onClearSelection,
                            onCopy: onCopySelected,
                            onEdit: onEditSelected,
                            onDelete: onDeleteSelected,
                          ),
                        ),
                      ),
                    ),
                  if (s > 0)
                    IgnorePointer(
                      ignoring: s < 0.5,
                      child: Opacity(
                        opacity: s,
                        child: SearchTopBar(
                          cs: cs,
                          glossy: glossyChrome,
                          search: search,
                          focusNode: searchFocusNode,
                          onClose: onCloseSearch,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
