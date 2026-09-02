import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/models/chat_preview_media.dart';

const String _forwardMark = '↪ ';

IconData? chatKindIcon(String chatType, {required bool isBot}) {
  switch (chatType) {
    case 'CHANNEL':
      return Symbols.campaign;
    case 'CHAT':
    case 'GROUP':
      return Symbols.group;
    default:
      return isBot ? Symbols.smart_toy : null;
  }
}

IconData previewKindIcon(ChatPreviewKind kind) {
  switch (kind) {
    case ChatPreviewKind.photo:
      return Symbols.image;
    case ChatPreviewKind.video:
      return Symbols.movie;
    case ChatPreviewKind.videoNote:
      return Symbols.videocam;
    case ChatPreviewKind.audio:
      return Symbols.mic;
    case ChatPreviewKind.file:
      return Symbols.description;
    case ChatPreviewKind.sticker:
      return Symbols.emoji_emotions;
    case ChatPreviewKind.contact:
      return Symbols.person;
    case ChatPreviewKind.location:
      return Symbols.location_on;
    case ChatPreviewKind.poll:
      return Symbols.bar_chart;
    case ChatPreviewKind.share:
      return Symbols.link;
    case ChatPreviewKind.call:
      return Symbols.call;
    case ChatPreviewKind.missedCall:
      return Symbols.call_missed;
    case ChatPreviewKind.videoCall:
      return Symbols.videocam;
    case ChatPreviewKind.missedVideoCall:
      return Symbols.missed_video_call;
    case ChatPreviewKind.control:
      return Symbols.info;
    case ChatPreviewKind.other:
      return Symbols.attach_file;
  }
}

const Set<ChatPreviewKind> _iconWithCaption = {
  ChatPreviewKind.photo,
  ChatPreviewKind.video,
  ChatPreviewKind.videoNote,
  ChatPreviewKind.audio,
  ChatPreviewKind.file,
  ChatPreviewKind.sticker,
  ChatPreviewKind.contact,
  ChatPreviewKind.location,
  ChatPreviewKind.poll,
  ChatPreviewKind.call,
  ChatPreviewKind.missedCall,
  ChatPreviewKind.videoCall,
  ChatPreviewKind.missedVideoCall,
};

class ChatPreviewLine extends StatelessWidget {
  final String prefix;
  final String text;
  final List<FormatRange> ranges;
  final ChatPreviewMedia? media;
  final TextStyle style;
  final bool italic;

  const ChatPreviewLine({
    super.key,
    required this.text,
    required this.style,
    this.prefix = '',
    this.ranges = const [],
    this.media,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preview = media;
    final label = preview?.label;
    final detail = preview?.detail;
    final labelled = label != null || detail != null;
    final forwarded = label != null && label.startsWith(_forwardMark);

    final bodyStyle = style.copyWith(
      fontStyle: italic ? FontStyle.italic : style.fontStyle,
    );

    final spans = <InlineSpan>[];
    if (prefix.isNotEmpty) spans.add(TextSpan(text: prefix, style: style));
    if (forwarded) spans.add(TextSpan(text: _forwardMark, style: bodyStyle));

    final leading = _leading(
      cs,
      preview,
      labelled: labelled,
      gap: detail == null ? 4 : 0,
    );
    if (leading != null) {
      spans.add(
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: leading),
      );
    }

    if (labelled) {
      final body = detail != null
          ? ': $detail'
          : label!.substring(forwarded ? _forwardMark.length : 0);
      spans.add(TextSpan(text: body, style: bodyStyle));
    } else {
      spans.addAll(
        FormattedMessageText.buildInlineChildren(text, ranges, bodyStyle),
      );
    }

    return Text.rich(
      TextSpan(style: bodyStyle, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _leading(
    ColorScheme cs,
    ChatPreviewMedia? preview, {
    required bool labelled,
    required double gap,
  }) {
    if (preview == null) return null;
    final size = (style.fontSize ?? 14) + 2;
    if (preview.thumbs.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(right: gap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final thumb in preview.thumbs)
              _PreviewThumb(thumb: thumb, size: size),
          ],
        ),
      );
    }
    if (!labelled && !_iconWithCaption.contains(preview.kind)) return null;
    return Padding(
      padding: EdgeInsets.only(right: gap),
      child: Icon(
        previewKindIcon(preview.kind),
        size: size,
        color: cs.outline,
        weight: 500,
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  final ChatPreviewThumb thumb;
  final double size;

  const _PreviewThumb({required this.thumb, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = _provider();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: cs.surfaceContainerHighest),
            if (provider != null)
              Image(image: provider, fit: BoxFit.cover, gaplessPlayback: true),
            if (thumb.video)
              Center(
                child: Icon(
                  Symbols.play_arrow,
                  size: size * 0.7,
                  fill: 1,
                  color: Colors.white,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _provider() => _thumbProvider(thumb.source);
}

const int _thumbCacheLimit = 128;
final Map<String, ImageProvider> _thumbCache = {};

ImageProvider? _thumbProvider(String source) {
  final cached = _thumbCache[source];
  if (cached != null) return cached;
  final ImageProvider? provider;
  if (source.startsWith('data:')) {
    provider = _decodeDataUri(source);
  } else if (source.startsWith('http')) {
    provider = CachedNetworkImageProvider(source, maxWidth: 64, maxHeight: 64);
  } else {
    provider = null;
  }
  if (provider == null) return null;
  if (_thumbCache.length >= _thumbCacheLimit) {
    _thumbCache.remove(_thumbCache.keys.first);
  }
  _thumbCache[source] = provider;
  return provider;
}

ImageProvider? _decodeDataUri(String source) {
  final comma = source.indexOf(',');
  if (comma < 0) return null;
  try {
    return MemoryImage(base64Decode(source.substring(comma + 1)));
  } catch (_) {
    return null;
  }
}
