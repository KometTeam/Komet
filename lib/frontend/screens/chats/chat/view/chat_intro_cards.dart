import 'package:flutter/material.dart';

import '../../../../../core/cache/info_cache.dart';
import '../../../../../core/config/app_fonts.dart';
import '../../../../../core/utils/text_format.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../models/bot_info.dart';
import '../../../../widgets/formatted_message_text.dart';
import '../../../../widgets/komet_avatar.dart';

class BotIntroCard extends StatefulWidget {
  final int botId;
  final String name;
  final String avatarUrl;

  const BotIntroCard({
    super.key,
    required this.botId,
    required this.name,
    required this.avatarUrl,
  });

  @override
  State<BotIntroCard> createState() => _BotIntroCardState();
}

class _BotIntroCardState extends State<BotIntroCard> {
  late final Future<BotInfo?> _info = BotInfoFetch.get(widget.botId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BotInfo?>(
      future: _info,
      initialData: BotInfoFetch.peek(widget.botId),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final cs = Theme.of(context).colorScheme;
        return _IntroCard(
          children: [
            KometAvatar(
              name: widget.name,
              imageUrl: widget.avatarUrl,
              size: 72,
            ),
            const SizedBox(height: 14),
            ..._text(context, cs, info),
          ],
        );
      },
    );
  }

  List<Widget> _text(BuildContext context, ColorScheme cs, BotInfo? info) {
    final start = info?.startMessage;
    if (start == null) {
      final description = info?.description?.trim();
      return [
        _title(context, cs, widget.name),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 8),
          _body(cs, description, const []),
        ],
      ];
    }
    final sections = start.sections;
    final heading = sections.heading;
    final body = sections.body;
    return [
      if (heading.isNotEmpty) _title(context, cs, heading),
      if (heading.isNotEmpty && body.isNotEmpty) const SizedBox(height: 10),
      if (body.isNotEmpty) _body(cs, body, sections.bodyRanges),
    ];
  }

  Widget _title(BuildContext context, ColorScheme cs, String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: cs.onSurface,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      height: 1.3,
      fontFamily: displayFontOf(context),
    ),
  );

  Widget _body(ColorScheme cs, String text, List<FormatRange> ranges) =>
      FormattedMessageText(
        text: text,
        ranges: ranges,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
          height: 1.35,
        ),
      );
}

class ChatReadyCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final bool isChannel;

  const ChatReadyCard({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.isChannel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return _IntroCard(
      children: [
        KometAvatar(name: name, imageUrl: avatarUrl, size: 72),
        const SizedBox(height: 14),
        Text(
          isChannel ? l10n.channelReadyTitle : l10n.groupReadyTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: displayFontOf(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isChannel ? l10n.channelReadyHint : l10n.groupReadyHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  final List<Widget> children;

  const _IntroCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
