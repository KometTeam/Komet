import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:komet/backend/modules/messages.dart' show ContactCache;
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show messagesModule;
import 'package:komet/models/chat_call.dart';
import 'package:material_symbols_icons/symbols.dart';

class ChatCallBanner extends StatelessWidget {
  final ChatCall call;
  final VoidCallback onJoin;
  final bool floating;
  final bool frosted;
  final bool liquid;
  final BackdropKey? backdropKey;

  const ChatCallBanner({
    super.key,
    required this.call,
    required this.onJoin,
    this.floating = false,
    this.frosted = false,
    this.liquid = false,
    this.backdropKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final content = Material(
      color: frosted
          ? AppFrost.glassTint(cs)
          : floating
          ? cs.surfaceContainerHigh.withValues(alpha: 0.92)
          : cs.surfaceContainerHigh,
      borderRadius: floating ? BorderRadius.circular(16) : null,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        child: Row(
          children: [
            _CallParticipantAvatars(
              participantIds: call.participantIds,
              isVideo: call.isVideo,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    call.isVideo
                        ? l10n.chatVideoCallBannerTitle
                        : l10n.chatCallBannerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.chatCallParticipants(call.participantsCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onJoin,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.chatCallJoin),
            ),
          ],
        ),
      ),
    );

    final bottomBorder = Border(bottom: AppFrost.hairline(cs));

    if (frosted) {
      return GlassSurface(
        liquid: liquid,
        borderRadius: floating ? BorderRadius.circular(16) : BorderRadius.zero,
        frostTint: Colors.transparent,
        border: floating ? null : bottomBorder,
        backdropKey: backdropKey,
        child: content,
      );
    }

    if (!floating) {
      return DecoratedBox(
        decoration: BoxDecoration(border: bottomBorder),
        child: content,
      );
    }
    return content;
  }
}

class _CallParticipantAvatars extends StatefulWidget {
  final List<int> participantIds;
  final bool isVideo;

  const _CallParticipantAvatars({
    required this.participantIds,
    required this.isVideo,
  });

  @override
  State<_CallParticipantAvatars> createState() =>
      _CallParticipantAvatarsState();
}

class _CallParticipantAvatarsState extends State<_CallParticipantAvatars> {
  static const double _size = 32;
  static const double _overlap = 12;
  static const int _maxShown = 3;

  @override
  void initState() {
    super.initState();
    _resolveNames();
  }

  @override
  void didUpdateWidget(_CallParticipantAvatars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.participantIds, widget.participantIds)) {
      _resolveNames();
    }
  }

  Future<void> _resolveNames() async {
    final resolved = await messagesModule.ensureContactNames(
      widget.participantIds.take(_maxShown),
    );
    if (resolved && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shown = widget.participantIds.take(_maxShown).toList();
    if (shown.isEmpty) {
      return CircleAvatar(
        radius: _size / 2,
        backgroundColor: cs.primaryContainer,
        child: Icon(
          widget.isVideo ? Symbols.videocam : Symbols.call,
          fill: 1,
          size: 18,
          color: cs.onPrimaryContainer,
        ),
      );
    }
    return SizedBox(
      width: _size + (shown.length - 1) * (_size - _overlap),
      height: _size,
      child: Stack(
        children: [
          for (var i = shown.length - 1; i >= 0; i--)
            Positioned(
              left: i * (_size - _overlap),
              child: _avatar(cs, shown[i]),
            ),
        ],
      ),
    );
  }

  Widget _avatar(ColorScheme cs, int userId) {
    final url = ContactCache.getAvatar(userId);
    final name = ContactCache.get(userId) ?? '';
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: _size / 2 - 1.5,
        backgroundColor: cs.surfaceContainerHighest,
        backgroundImage: url != null && url.isNotEmpty
            ? CachedNetworkImageProvider(url, maxWidth: 96, maxHeight: 96)
            : null,
        child: url != null && url.isNotEmpty
            ? null
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
      ),
    );
  }
}
