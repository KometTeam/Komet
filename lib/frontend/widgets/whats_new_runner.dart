import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/link_opener.dart';
import '../../core/utils/logger.dart';
import '../../core/whats_new/whats_new_document.dart';
import '../../main.dart' show KometApp;
import 'custom_notification.dart';
import 'hint_bubble.dart';
import 'max_link_nav.dart';
import 'spotlight.dart';

class WhatsNewRunner {
  WhatsNewRunner(this.document, {Future<void> Function()? closeSheet})
    : _closeSheet = closeSheet;

  static const int _maxDepth = 6;
  static const Duration _scroll = Duration(milliseconds: 420);

  final WhatsNewDocument document;
  Future<void> Function()? _closeSheet;

  BuildContext? get _context => KometApp.overlayContext;

  Future<void> run(WhatsNewTarget target) async {
    final scenario = target.scenario;
    if (scenario != null) return _scenario(scenario, 0);
    await _leaveSheet();
    await _open(target.link!);
  }

  Future<void> _scenario(String name, int depth) async {
    final steps = document.scenarios[name];
    if (steps == null || depth > _maxDepth) return;
    for (final step in steps) {
      try {
        await _step(step, depth);
      } catch (e) {
        logger.w('[whats-new] #$name, ${step.command.name}: $e');
        return;
      }
    }
  }

  Future<void> _step(WhatsNewStep step, int depth) async {
    final args = step.args;
    switch (step.command) {
      case WhatsNewCommand.close:
        await _leaveSheet();
      case WhatsNewCommand.tab:
        await _leaveSheet();
        final context = _context;
        if (context == null || !context.mounted) return;
        await openRootTab(context, WhatsNewTab.values.byName(args.first).index);
        await Spotlight.settle();
      case WhatsNewCommand.open:
        await _leaveSheet();
        await _open(args.first);
      case WhatsNewCommand.back:
        await _leaveSheet();
        final context = _context;
        if (context != null && context.mounted) {
          await Navigator.of(context).maybePop();
          await Spotlight.settle();
        }
      case WhatsNewCommand.scroll:
        await _leaveSheet();
        await _scrollTo(args.first);
      case WhatsNewCommand.tap:
        await _leaveSheet();
        if (await Spotlight.tap(args.first)) {
          await Spotlight.settle();
        } else {
          _missing(args.first);
        }
      case WhatsNewCommand.highlight:
        await _leaveSheet();
        if (!await Spotlight.highlight(args.first)) _missing(args.first);
      case WhatsNewCommand.hint:
        await _leaveSheet();
        final anchor = await Spotlight.reveal(args.first);
        if (anchor == null) {
          _missing(args.first);
          _notify(args[1]);
        } else if (anchor.mounted) {
          showHintBubble(anchor, args[1]);
        }
      case WhatsNewCommand.notify:
        final target = args.length == 3 ? WhatsNewTarget.parse(args[2]) : null;
        _notify(
          args.first,
          action: target == null
              ? null
              : (label: args[1], onTap: () => unawaited(run(target))),
        );
      case WhatsNewCommand.wait:
        await Future<void>.delayed(
          Duration(milliseconds: int.parse(args.first)),
        );
      case WhatsNewCommand.run:
        await _scenario(args.first.substring(1), depth + 1);
    }
  }

  Future<void> _leaveSheet() async {
    final close = _closeSheet;
    if (close == null) return;
    _closeSheet = null;
    await close();
  }

  Future<void> _open(String link) async {
    final context = _context;
    if (context == null) return;
    unawaited(
      openExternalUrl(context, link).catchError((Object error) {
        logger.w('[whats-new] не открылось $link: $error');
      }),
    );
    await WidgetsBinding.instance.endOfFrame;
    await Spotlight.settle();
  }

  Future<void> _scrollTo(String where) async {
    if (where != 'top' && where != 'bottom') {
      if (await Spotlight.reveal(where) == null) _missing(where);
      return;
    }
    final position = Spotlight.mainScrollPosition();
    if (position == null) return;
    await position.animateTo(
      where == 'top' ? position.minScrollExtent : position.maxScrollExtent,
      duration: _scroll,
      curve: Curves.easeOutCubic,
    );
  }

  void _notify(String text, {NotificationAction? action}) {
    final context = _context;
    if (context != null) showCustomNotification(context, text, action: action);
  }

  void _missing(String id) =>
      logger.w('[whats-new] элемент «$id» не нашёлся на экране');
}
