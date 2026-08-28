import 'dart:async';

import 'package:flutter/material.dart';

class PasteMediaScope extends StatefulWidget {
  const PasteMediaScope({
    super.key,
    required this.onPaste,
    required this.child,
  });

  final Future<bool> Function()? onPaste;
  final Widget child;

  @override
  State<PasteMediaScope> createState() => _PasteMediaScopeState();
}

class _PasteMediaScopeState extends State<PasteMediaScope> {
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    PasteTextIntent: _PasteMediaAction(_paste),
  };

  Future<bool> _paste() async {
    final handler = widget.onPaste;
    if (handler == null) return false;
    final handled = await handler();
    return handled || !mounted;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onPaste == null) return widget.child;
    return Actions(actions: _actions, child: widget.child);
  }
}

class _PasteMediaAction extends Action<PasteTextIntent> {
  _PasteMediaAction(this.onPaste);

  final Future<bool> Function() onPaste;

  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? true;

  @override
  bool consumesKey(PasteTextIntent intent) =>
      callingAction?.consumesKey(intent) ?? true;

  @override
  Object? invoke(PasteTextIntent intent) {
    unawaited(_resolve(intent, callingAction));
    return null;
  }

  Future<void> _resolve(
    PasteTextIntent intent,
    Action<PasteTextIntent>? fallback,
  ) async {
    if (await onPaste()) return;
    fallback?.invoke(intent);
  }
}
