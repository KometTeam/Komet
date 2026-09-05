import 'dart:async';

import 'package:flutter/material.dart';
import 'package:komet/backend/modules/chats.dart' show CachedChat;
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_visual_style.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart' show ChatWallpaper;
import 'package:komet/frontend/screens/chats/chat/command_panel_controller.dart';
import 'package:komet/frontend/screens/chats/chat/chat_search_controller.dart';
import 'package:komet/frontend/screens/chats/chat/mention_panel_controller.dart';
import 'package:komet/frontend/screens/chats/chat/video_note_controller.dart';
import 'package:komet/frontend/screens/chats/chat/message_search_result.dart';
import 'package:komet/frontend/widgets/chat_wallpaper_view.dart';

import 'command_panel_view.dart';
import 'measure_size.dart';
import 'mention_panel_view.dart';
import 'message_list_decorations.dart';
import 'pinned_banner_pill.dart';
import 'search_view.dart';

class ChatBodyLayout extends StatelessWidget {
  final bool underlap;
  final ColorScheme cs;
  final CachedChat? chat;
  final ChatChromeStyle effectiveChrome;
  final bool liquidChrome;
  final BackdropKey? pillBackdrop;
  final int myId;
  final VoidCallback onJumpToPinnedMessage;
  final Future<void> Function() onUnpinCurrentMessage;
  final bool composerFrosted;
  final ValueNotifier<double> composerHeight;
  final ValueNotifier<double> pinnedBannerHeight;
  final Widget Function(BuildContext) composerAreaBuilder;
  final Widget messagesArea;
  final MentionPanelController mentionPanel;
  final CommandPanelController commandPanel;
  final VideoNoteController note;
  final Animation<double> searchAnim;
  final ChatSearchController search;
  final void Function(MessageSearchResult) onOpenSearchResult;
  final String Function(int senderId) searchSenderName;
  final String? Function(int senderId) searchSenderAvatar;
  final bool chromeVignette;
  final bool composerPaintsSurface;
  final double pinnedBannerTop;
  final double defaultEdgeVignetteHeight;
  final ChatWallpaper? wallpaper;

  const ChatBodyLayout({
    super.key,
    required this.underlap,
    required this.cs,
    required this.chat,
    required this.effectiveChrome,
    required this.liquidChrome,
    required this.pillBackdrop,
    required this.myId,
    required this.onJumpToPinnedMessage,
    required this.onUnpinCurrentMessage,
    required this.composerFrosted,
    required this.composerHeight,
    required this.pinnedBannerHeight,
    required this.composerAreaBuilder,
    required this.messagesArea,
    required this.mentionPanel,
    required this.commandPanel,
    required this.note,
    required this.searchAnim,
    required this.search,
    required this.onOpenSearchResult,
    required this.searchSenderName,
    required this.searchSenderAvatar,
    required this.chromeVignette,
    required this.composerPaintsSurface,
    required this.pinnedBannerTop,
    required this.defaultEdgeVignetteHeight,
    required this.wallpaper,
  });

  Widget? _pinnedBanner({required bool floating, BorderRadius? borderRadius}) {
    return buildPinnedMessageBanner(
      chat: chat,
      floating: floating,
      borderRadius: borderRadius,
      frosted: effectiveChrome == ChatChromeStyle.transparent,
      liquidChrome: liquidChrome,
      backdropKey: pillBackdrop,
      onTap: onJumpToPinnedMessage,
      myId: myId,
      onUnpinRequested: () => unawaited(onUnpinCurrentMessage()),
    );
  }

  Widget _panelsColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MentionPanelView(mentionPanel: mentionPanel),
        CommandPanelView(commandPanel: commandPanel),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final composer = MeasureSize(
      onHeight: (value) => composerHeight.value = value,
      child: Builder(builder: composerAreaBuilder),
    );

    if (!underlap) {
      final banner = _pinnedBanner(floating: false);
      final frosted = composerFrosted;
      return Column(
        children: [
          ?banner,
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (wallpaper != null)
                  Positioned.fill(child: ChatWallpaperView(wallpaper: wallpaper!)),
                Positioned.fill(child: messagesArea),
                ValueListenableBuilder<double>(
                  valueListenable: composerHeight,
                  builder: (context, height, _) => Positioned(
                    left: 0,
                    right: 0,
                    bottom: frosted ? height : 0,
                    child: _panelsColumn(),
                  ),
                ),
                VideoNoteRecordingLayer(controller: note),
                if (frosted)
                  Positioned(left: 0, right: 0, bottom: 0, child: composer),
                SearchOverlay(
                  cs: cs,
                  searchAnim: searchAnim,
                  search: search,
                  onOpenResult: onOpenSearchResult,
                  senderName: searchSenderName,
                  senderAvatar: searchSenderAvatar,
                ),
              ],
            ),
          ),
          if (!frosted) composer,
        ],
      );
    }

    final vignette = chromeVignette;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (wallpaper != null)
          Positioned.fill(child: ChatWallpaperView(wallpaper: wallpaper!)),
        Positioned.fill(child: messagesArea),
        SearchOverlay(
          cs: cs,
          searchAnim: searchAnim,
          search: search,
          onOpenResult: onOpenSearchResult,
          senderName: searchSenderName,
          senderAvatar: searchSenderAvatar,
        ),
        if (vignette) ...[
          if (AppVisualStyle.current.value.glossyChrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MessageListEdgeVignette(
                top: true,
                height: defaultEdgeVignetteHeight,
              ),
            ),
          ValueListenableBuilder<double>(
            valueListenable: composerHeight,
            builder: (context, height, _) => composerPaintsSurface
                ? Positioned(
                    left: 0,
                    right: 0,
                    bottom: height,
                    child: const MessageListEdgeFade(height: 24.0),
                  )
                : Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: MessageListEdgeVignette(top: false, height: height),
                  ),
          ),
        ],
        Positioned(
          top: pinnedBannerTop,
          left: 8,
          right: 8,
          child: MeasureSize(
            onHeight: (value) => pinnedBannerHeight.value = value,
            child: buildPinnedAndPill(
              chat: chat,
              frosted: effectiveChrome == ChatChromeStyle.transparent,
              liquidChrome: liquidChrome,
              backdropKey: pillBackdrop,
              onTap: onJumpToPinnedMessage,
              myId: myId,
              onUnpinRequested: () => unawaited(onUnpinCurrentMessage()),
            ),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: composerHeight,
          builder: (context, height, _) => Positioned(
            left: 0,
            right: 0,
            bottom: height,
            child: _panelsColumn(),
          ),
        ),
        VideoNoteRecordingLayer(controller: note),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Builder(
            builder: (context) => MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: composer,
            ),
          ),
        ),
      ],
    );
  }
}
