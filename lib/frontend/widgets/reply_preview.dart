import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/media/preview_image.dart';
import '../../models/attachment.dart';

class ReplyPreview {
  const ReplyPreview._({this.icon, this.media, this.round = false});

  final IconData? icon;
  final MessageAttachment? media;
  final bool round;

  bool get hasMedia => media != null;

  static ReplyPreview of({
    String? text,
    List<MessageAttachment>? attachments,
  }) {
    final list = attachments;
    if (list == null || list.isEmpty) return const ReplyPreview._();
    final attachment = list.first;
    final icon = _iconFor(attachment.type);
    final captioned = text != null && text.trim().isNotEmpty;
    if (captioned || !_hasThumbnail(attachment)) {
      return ReplyPreview._(icon: icon);
    }
    return ReplyPreview._(
      icon: icon,
      media: attachment,
      round: attachment is VideoAttachment && attachment.isNote,
    );
  }

  Size box({required double maxSide, double minSide = 72}) {
    final attachment = media;
    if (round) return Size(maxSide, maxSide);
    final width = _sizeOf(attachment, horizontal: true);
    final height = _sizeOf(attachment, horizontal: false);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return Size(maxSide, maxSide);
    }
    final ratio = width / height;
    if (ratio >= 1) {
      return Size(maxSide, (maxSide / ratio).clamp(minSide, maxSide));
    }
    return Size((maxSide * ratio).clamp(minSide, maxSide), maxSide);
  }

  Widget thumbnail({
    required Size size,
    required ColorScheme cs,
    double radius = 8,
  }) {
    final attachment = media;
    if (attachment == null) return const SizedBox.shrink();
    final url = _networkThumbnail(attachment);
    final local = dataUriImage(attachment, attachment.previewData);

    Widget fallback() => Container(
      width: size.width,
      height: size.height,
      color: cs.surfaceContainerHighest,
      child: Icon(
        icon ?? Symbols.image,
        size: size.shortestSide * 0.4,
        color: cs.onSurfaceVariant,
      ),
    );

    Widget localImage() => Image(
      image: local!,
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback(),
    );

    final Widget image;
    if (url != null) {
      image = CachedNetworkImage(
        imageUrl: url,
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, _) => local == null ? fallback() : localImage(),
        errorWidget: (_, _, _) => local == null ? fallback() : localImage(),
      );
    } else if (local != null) {
      image = localImage();
    } else {
      image = fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        round ? size.shortestSide / 2 : radius,
      ),
      child: image,
    );
  }

  static bool _hasThumbnail(MessageAttachment attachment) {
    if (attachment is! PhotoAttachment && attachment is! VideoAttachment) {
      return false;
    }
    return _networkThumbnail(attachment) != null ||
        dataUriImage(attachment, attachment.previewData) != null;
  }

  static String? _networkThumbnail(MessageAttachment attachment) {
    final candidates = <String?>[
      if (attachment is VideoAttachment) attachment.thumbnail,
      attachment.baseUrl,
    ];
    for (final url in candidates) {
      if (url == null || url.isEmpty || url.startsWith('data:')) continue;
      return url;
    }
    return null;
  }

  static int? _sizeOf(MessageAttachment? attachment, {required bool horizontal}) {
    if (attachment is PhotoAttachment) {
      return horizontal ? attachment.width : attachment.height;
    }
    if (attachment is VideoAttachment) {
      return horizontal ? attachment.width : attachment.height;
    }
    return null;
  }

  static IconData? _iconFor(AttachmentType type) => switch (type) {
    AttachmentType.photo => Symbols.image,
    AttachmentType.video => Symbols.videocam,
    AttachmentType.audio => Symbols.mic,
    AttachmentType.file => Symbols.description,
    AttachmentType.sticker => Symbols.emoji_emotions,
    AttachmentType.contact => Symbols.person,
    AttachmentType.location => Symbols.location_on,
    AttachmentType.poll => Symbols.bar_chart,
    AttachmentType.call => Symbols.call,
    AttachmentType.share => Symbols.link,
    AttachmentType.forward => Symbols.forward,
    AttachmentType.unknown => Symbols.attach_file,
    AttachmentType.control || AttachmentType.inlineKeyboard => null,
  };
}
