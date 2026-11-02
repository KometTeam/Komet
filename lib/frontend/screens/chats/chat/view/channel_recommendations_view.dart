import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/app_motion.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/hint_bubble.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';
import 'package:komet/frontend/widgets/max_link_handler.dart';
import 'package:komet/frontend/widgets/small_spinner.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/suggested_channel.dart';

import '../channel_recommendations.dart';

class ChannelRecommendationsView extends StatefulWidget {
  const ChannelRecommendationsView({super.key, required this.recommendations});

  final ChannelRecommendations recommendations;

  @override
  State<ChannelRecommendationsView> createState() =>
      _ChannelRecommendationsViewState();
}

class _ChannelRecommendationsViewState extends State<ChannelRecommendationsView>
    with SingleTickerProviderStateMixin {
  static const Duration _showDuration = Duration(milliseconds: 320);
  static const Duration _hideDuration = Duration(milliseconds: 260);
  static const double _cardsHeight = 178;

  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: AppMotion.of(_showDuration),
    reverseDuration: AppMotion.of(_hideDuration),
    value: widget.recommendations.visible ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _presence,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    widget.recommendations.addListener(_syncPresence);
  }

  @override
  void didUpdateWidget(ChannelRecommendationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recommendations == widget.recommendations) return;
    oldWidget.recommendations.removeListener(_syncPresence);
    widget.recommendations.addListener(_syncPresence);
    _syncPresence();
  }

  @override
  void dispose() {
    widget.recommendations.removeListener(_syncPresence);
    _curve.dispose();
    _presence.dispose();
    super.dispose();
  }

  void _syncPresence() {
    if (widget.recommendations.visible) {
      _presence.forward();
    } else {
      _presence.reverse();
    }
  }

  void _hide() {
    Haptics.tap();
    final l10n = AppLocalizations.of(context)!;
    unawaited(widget.recommendations.hide());
    showCustomNotification(
      context,
      l10n.channelRecommendationsHidden,
      action: (
        label: l10n.channelRecommendationsHideEverywhere,
        onTap: () =>
            unawaited(KometSettings.setHideChannelRecommendations(true)),
      ),
    );
  }

  void _open(SuggestedChannel channel) {
    unawaited(tryHandleMaxLink(context, channel.link));
  }

  Future<void> _join(BuildContext button, SuggestedChannel channel) async {
    Haptics.tap();
    try {
      await widget.recommendations.join(channel);
    } catch (_) {
      if (!button.mounted) return;
      showHintBubble(
        button,
        AppLocalizations.of(button)!.chatScreenSubscribeFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _presence,
      builder: (context, child) => _presence.isDismissed
          ? const SizedBox.shrink()
          : SizeTransition(
              sizeFactor: _curve,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: _curve, child: child),
            ),
      child: ListenableBuilder(
        listenable: widget.recommendations,
        builder: (context, _) => _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final recommendations = widget.recommendations;
    final channels = recommendations.channels;
    if (channels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecommendationsHeader(onHide: _hide),
          SizedBox(
            height: _cardsHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: channels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _SuggestedChannelCard(
                  key: ValueKey(channel.id),
                  channel: channel,
                  state: recommendations.stateOf(channel),
                  onOpen: () => _open(channel),
                  onJoin: (button) => unawaited(_join(button, channel)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationsHeader extends StatelessWidget {
  const _RecommendationsHeader({required this.onHide});

  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.channelRecommendationsTitle,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              Tooltip(
                message: l10n.channelRecommendationsHide,
                child: InkResponse(
                  onTap: onHide,
                  radius: 14,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
                    child: Icon(
                      Symbols.close,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedChannelCard extends StatelessWidget {
  const _SuggestedChannelCard({
    super.key,
    required this.channel,
    required this.state,
    required this.onOpen,
    required this.onJoin,
  });

  static const double width = 136;

  final SuggestedChannel channel;
  final SuggestedChannelState state;
  final VoidCallback onOpen;
  final void Function(BuildContext button) onJoin;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = cs.onSurfaceVariant;
    final subscribers = channel.subscribers;
    return SizedBox(
      width: width,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(
              children: [
                KometAvatar(
                  name: channel.title,
                  imageUrl: channel.iconUrl,
                  size: 60,
                ),
                const SizedBox(height: 10),
                Text(
                  channel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subscribers != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Symbols.person, size: 13, fill: 1, color: dim),
                      const SizedBox(width: 2),
                      Text(
                        formatCompactCount(subscribers),
                        style: TextStyle(color: dim, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Builder(
                  builder: (button) => _JoinButton(
                    state: state,
                    onJoin: () => onJoin(button),
                    onOpen: onOpen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.state,
    required this.onJoin,
    required this.onOpen,
  });

  final SuggestedChannelState state;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(
      color: cs.onSurface,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    return SizedBox(
      height: 34,
      width: double.infinity,
      child: Material(
        color: cs.onSurface.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: switch (state) {
            SuggestedChannelState.idle => onJoin,
            SuggestedChannelState.joining => null,
            SuggestedChannelState.joined => onOpen,
          },
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.of(const Duration(milliseconds: 180)),
              child: switch (state) {
                SuggestedChannelState.idle => Text(
                  l10n.chatInfoActionSubscribe,
                  key: const ValueKey('join'),
                  style: style,
                ),
                SuggestedChannelState.joining => SmallSpinner(
                  key: const ValueKey('joining'),
                  size: 18,
                  color: cs.onSurface,
                ),
                SuggestedChannelState.joined => Text(
                  l10n.chatPreviewOpen,
                  key: const ValueKey('open'),
                  style: style,
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
