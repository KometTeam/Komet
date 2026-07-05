import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/frontend/widgets/glossy_pill.dart';
import 'package:komet/frontend/widgets/online_dot.dart';

class ChatHeaderRow extends StatelessWidget {
  final bool glossy;
  final ColorScheme cs;
  final bool embedded;
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool isOfficial;
  final int myId;
  final ValueListenable<String> headerStatus;
  final ValueListenable<int> scheduledCount;
  final ValueListenable<int> otherUnread;
  final bool showCall;
  final VoidCallback? onClose;
  final VoidCallback onOpenInfo;
  final VoidCallback onOpenScheduled;
  final VoidCallback onCall;
  final void Function(BuildContext) onMenu;

  const ChatHeaderRow({
    super.key,
    required this.glossy,
    required this.cs,
    required this.embedded,
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    required this.isOfficial,
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
  });

  @override
  Widget build(BuildContext context) =>
      glossy ? _glossyRow(context) : _materialRow(context);

  Widget _glossyRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          _backWithBadge(
            cs,
            SizedBox(
              width: 56,
              height: 56,
              child: GlossyPill(
                onTap: () {
                  if (embedded) {
                    onClose?.call();
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Center(
                  child: Icon(
                    embedded ? Symbols.close : Symbols.arrow_back,
                    color: cs.onSurface,
                    weight: 500,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlossyPill(
              onTap: onOpenInfo,
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              child: Row(
                children: [
                  _withOnlineDot(
                    cs,
                    imageUrl.isNotEmpty
                        ? CircleAvatar(
                            radius: 22,
                            backgroundImage: CachedNetworkImageProvider(
                              imageUrl,
                              maxWidth: 144,
                              maxHeight: 144,
                            ),
                          )
                        : CircleAvatar(
                            radius: 22,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOfficial) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Symbols.verified,
                                color: cs.primary,
                                size: 16,
                                weight: 600,
                                fill: 1,
                              ),
                            ],
                          ],
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: headerStatus,
                          builder: (context, status, _) => Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlossyPill(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: scheduledCount,
                    builder: (_, count, _) => count > 0
                        ? IconButton(
                            icon: Icon(
                              Symbols.schedule,
                              weight: 500,
                              color: cs.onSurface,
                            ),
                            onPressed: onOpenScheduled,
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (showCall)
                    IconButton(
                      icon: Icon(
                        Symbols.call,
                        weight: 500,
                        color: cs.onSurface,
                      ),
                      onPressed: onCall,
                    ),
                  Builder(
                    builder: (btnContext) => IconButton(
                      icon: Icon(
                        Symbols.more_vert,
                        weight: 500,
                        color: cs.onSurface,
                      ),
                      onPressed: () => onMenu(btnContext),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialRow(BuildContext context) {
    return Row(
      children: [
        _backWithBadge(
          cs,
          IconButton(
            icon: Icon(
              embedded ? Symbols.close : Symbols.arrow_back,
              weight: 400,
              color: cs.onSurface,
            ),
            onPressed: () {
              if (embedded) {
                onClose?.call();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onOpenInfo,
            child: Row(
              children: [
                _withOnlineDot(
                  cs,
                  imageUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 18,
                          backgroundImage: CachedNetworkImageProvider(
                            imageUrl,
                            maxWidth: 144,
                            maxHeight: 144,
                          ),
                        )
                      : CircleAvatar(
                          radius: 18,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                  dotSize: 11,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOfficial) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Symbols.verified,
                              color: cs.primary,
                              size: 16,
                              weight: 600,
                              fill: 1,
                            ),
                          ],
                        ],
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: headerStatus,
                        builder: (context, status, _) => Text(
                          status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: scheduledCount,
          builder: (_, count, _) => count > 0
              ? IconButton(
                  icon: Icon(
                    Symbols.schedule,
                    weight: 400,
                    color: cs.onSurface,
                  ),
                  onPressed: onOpenScheduled,
                )
              : const SizedBox.shrink(),
        ),
        if (showCall)
          IconButton(
            icon: Icon(Symbols.call, weight: 400, color: cs.onSurface),
            onPressed: onCall,
          ),
        Builder(
          builder: (btnContext) => IconButton(
            icon: Icon(Symbols.more_vert, weight: 400, color: cs.onSurface),
            onPressed: () => onMenu(btnContext),
          ),
        ),
      ],
    );
  }

  Widget _withOnlineDot(ColorScheme cs, Widget avatar, {double dotSize = 12}) {
    final otherId = chatId ^ myId;
    final showDot = chatType == 'DIALOG' && myId != 0 && otherId > 0;
    return Stack(
      children: [
        avatar,
        if (showDot)
          Positioned(
            right: 0,
            bottom: 0,
            child: OnlineDot(
              userId: otherId,
              borderColor: cs.surface,
              size: dotSize,
            ),
          ),
      ],
    );
  }

  Widget _backWithBadge(ColorScheme cs, Widget button) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        button,
        Positioned(
          right: -2,
          bottom: 0,
          child: IgnorePointer(child: _backUnreadBadge(cs)),
        ),
      ],
    );
  }

  Widget _backUnreadBadge(ColorScheme cs) {
    return ValueListenableBuilder<int>(
      valueListenable: otherUnread,
      builder: (context, count, _) {
        return AnimatedScale(
          scale: count > 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: cs.surface, width: 1.5),
            ),
            alignment: Alignment.center,
            child: _RollingCount(
              count: count > 99 ? 99 : count,
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RollingCount extends StatefulWidget {
  final int count;
  final TextStyle style;

  const _RollingCount({required this.count, required this.style});

  @override
  State<_RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<_RollingCount> {
  late int _count = widget.count;
  bool _increasing = true;

  @override
  void didUpdateWidget(_RollingCount old) {
    super.didUpdateWidget(old);
    if (widget.count != _count) {
      _increasing = widget.count > _count;
      _count = widget.count;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        final incoming = (child.key as ValueKey<int>).value == _count;
        final Offset begin;
        if (incoming) {
          begin = _increasing ? const Offset(0, -1) : const Offset(0, 1);
        } else {
          begin = _increasing ? const Offset(0, 1) : const Offset(0, -1);
        }
        return ClipRect(
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: begin, end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
        );
      },
      child: Text(
        '${widget.count}',
        key: ValueKey<int>(widget.count),
        style: widget.style,
      ),
    );
  }
}
