import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_message_actions_style.dart';
import '../../core/utils/format.dart';
import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';

enum MessageActionsInteraction { dragAndRelease, click, tap }

enum _RadialSide { below, above, left, right }

class MessageActionsController extends ChangeNotifier {
  Offset? pointer;
  Offset? initialPointer;
  bool committed = false;
  bool movedSignificantly = false;
  bool _attached = false;

  void attach(Offset initial) {
    if (_attached) return;
    _attached = true;
    initialPointer = initial;
    pointer = initial;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointerEvent);
  }

  void updatePointer(Offset p) {
    if (committed) return;
    pointer = p;
    if (initialPointer != null &&
        !movedSignificantly &&
        (p - initialPointer!).distance > 18) {
      movedSignificantly = true;
    }
    notifyListeners();
  }

  void _onPointerEvent(PointerEvent event) {
    if (committed) return;
    if (event is PointerMoveEvent) {
      updatePointer(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      commit();
    }
  }

  void commit() {
    if (committed) return;
    committed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_attached) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointerEvent);
      _attached = false;
    }
    super.dispose();
  }
}

void showMessageActions({
  required BuildContext context,
  ui.Image? snapshot,
  required Rect originRect,
  required Offset tapPoint,
  required bool isMe,
  required String? messageText,
  required MessageActionsController controller,
  required MessageActionsStyle style,
  required VoidCallback onDispose,
  List<Map<String, dynamic>>? editHistory,
  Future<List<({int id, String title})>> Function()? loadReportReasons,
  Future<bool> Function(int reasonId)? onReport,
  VoidCallback? onDelete,
  VoidCallback? onEdit,
  VoidCallback? onReply,
  VoidCallback? onForward,
  VoidCallback? onMarkUnread,
  MessageActionsInteraction interaction =
      MessageActionsInteraction.dragAndRelease,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _MessageActionsLayer(
      snapshot: snapshot,
      originRect: originRect,
      tapPoint: tapPoint,
      isMe: isMe,
      messageText: messageText,
      controller: controller,
      style: style,
      interaction: interaction,
      editHistory: editHistory,
      loadReportReasons: loadReportReasons,
      onReport: onReport,
      onDelete: onDelete,
      onEdit: onEdit,
      onReply: onReply,
      onForward: onForward,
      onMarkUnread: onMarkUnread,
      onDismiss: () {
        if (entry.mounted) entry.remove();
        onDispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _MessageActionsLayer extends StatefulWidget {
  final ui.Image? snapshot;
  final Rect originRect;
  final Offset tapPoint;
  final bool isMe;
  final String? messageText;
  final MessageActionsController controller;
  final MessageActionsStyle style;
  final MessageActionsInteraction interaction;
  final VoidCallback onDismiss;
  final List<Map<String, dynamic>>? editHistory;
  final Future<List<({int id, String title})>> Function()? loadReportReasons;
  final Future<bool> Function(int reasonId)? onReport;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onMarkUnread;

  const _MessageActionsLayer({
    required this.snapshot,
    required this.originRect,
    required this.tapPoint,
    required this.isMe,
    required this.messageText,
    required this.controller,
    required this.style,
    required this.interaction,
    required this.onDismiss,
    this.editHistory,
    this.loadReportReasons,
    this.onReport,
    this.onDelete,
    this.onEdit,
    this.onReply,
    this.onForward,
    this.onMarkUnread,
  });

  @override
  State<_MessageActionsLayer> createState() => _MessageActionsLayerState();
}

class _MessageActionsLayerState extends State<_MessageActionsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _animation;
  bool _closing = false;
  static const double _radius = 92.0;
  static const double _arcSpan = math.pi * 0.62;
  static const double _btnSize = 52.0;
  static const double _hitRadius = 40.0;
  static const double _hMargin = 8.0;

  late List<_Action> _actions;
  late MessageActionsStyle _effectiveStyle;
  bool _showBelow = true;
  Offset _anchor = Offset.zero;
  List<Offset> _buttonCenters = const [];
  List<Rect> _buttonHitRects = const [];
  Rect _menuRect = Rect.zero;
  bool _initialized = false;

  int _hoveredIndex = -1;
  bool _committedFired = false;
  bool _showHistory = false;
  bool _showReport = false;
  bool _reportLoading = false;
  bool _reportSending = false;
  List<({int id, String title})>? _reasons;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _actions = _buildActions();
    _effectiveStyle = widget.interaction == MessageActionsInteraction.click
        ? MessageActionsStyle.list
        : widget.style;
    final screenSize = MediaQuery.sizeOf(context);
    if (_effectiveStyle == MessageActionsStyle.radial) {
      _computeRadialGeometry(screenSize);
    } else {
      _computeListGeometry(screenSize);
    }
    if (widget.interaction == MessageActionsInteraction.dragAndRelease) {
      widget.controller.addListener(_onControllerUpdate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onControllerUpdate();
      });
    }
  }

  void _computeRadialGeometry(Size screenSize) {
    final n = _actions.length;
    const reach = _radius + _btnSize / 2;
    final padding = MediaQuery.paddingOf(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final topMargin = padding.top + _hMargin;
    final bottomMargin = math.max(padding.bottom, keyboardInset) + _hMargin;
    final rect = widget.originRect;

    final spaceBelow = screenSize.height - bottomMargin - (rect.bottom + 16);
    final spaceAbove = (rect.top - 16) - topMargin;
    final belowFits = spaceBelow >= reach;
    final aboveFits = spaceAbove >= reach;
    final preferBelow = widget.tapPoint.dy < screenSize.height * 0.55;

    final _RadialSide side;
    if (belowFits && aboveFits) {
      side = preferBelow ? _RadialSide.below : _RadialSide.above;
    } else if (belowFits) {
      side = _RadialSide.below;
    } else if (aboveFits) {
      side = _RadialSide.above;
    } else {
      final spaceRight = screenSize.width - _hMargin - (rect.right + 16);
      final spaceLeft = (rect.left - 16) - _hMargin;
      final rightFits = spaceRight >= reach;
      final leftFits = spaceLeft >= reach;
      if (widget.isMe) {
        side = (leftFits || !rightFits) ? _RadialSide.left : _RadialSide.right;
      } else {
        side = (rightFits || !leftFits) ? _RadialSide.right : _RadialSide.left;
      }
    }

    final double base;
    double anchorX;
    double anchorY;
    switch (side) {
      case _RadialSide.below:
        base = math.pi * 0.5;
        anchorX = widget.tapPoint.dx;
        anchorY = rect.bottom + 16;
      case _RadialSide.above:
        base = -math.pi * 0.5;
        anchorX = widget.tapPoint.dx;
        anchorY = rect.top - 16;
      case _RadialSide.right:
        base = 0;
        anchorX = rect.right + 16;
        anchorY = widget.tapPoint.dy.clamp(rect.top, rect.bottom).toDouble();
      case _RadialSide.left:
        base = math.pi;
        anchorX = rect.left - 16;
        anchorY = widget.tapPoint.dy.clamp(rect.top, rect.bottom).toDouble();
    }

    _showBelow =
        side == _RadialSide.below ||
        (side != _RadialSide.above && spaceBelow >= spaceAbove);

    final start = base - _arcSpan / 2;
    final step = n <= 1 ? 0.0 : _arcSpan / (n - 1);

    final offsets = <Offset>[];
    double minDx = 0;
    double maxDx = 0;
    double minDy = 0;
    double maxDy = 0;
    for (int i = 0; i < n; i++) {
      final angle = start + step * i;
      final dx = math.cos(angle) * _radius;
      final dy = math.sin(angle) * _radius;
      offsets.add(Offset(dx, dy));
      if (dx < minDx) minDx = dx;
      if (dx > maxDx) maxDx = dx;
      if (dy < minDy) minDy = dy;
      if (dy > maxDy) maxDy = dy;
    }

    final minX = _hMargin + _btnSize / 2;
    final maxX = screenSize.width - _hMargin - _btnSize / 2;
    final minY = topMargin + _btnSize / 2;
    final maxY = screenSize.height - bottomMargin - _btnSize / 2;

    if (anchorX + maxDx > maxX) anchorX = maxX - maxDx;
    if (anchorX + minDx < minX) anchorX = minX - minDx;
    if (anchorY + maxDy > maxY) anchorY = maxY - maxDy;
    if (anchorY + minDy < minY) anchorY = minY - minDy;

    _anchor = Offset(anchorX, anchorY);
    _buttonCenters = [for (final o in offsets) _anchor + o];
    _buttonHitRects = [
      for (final c in _buttonCenters)
        Rect.fromCenter(
          center: c,
          width: _hitRadius * 2,
          height: _hitRadius * 2,
        ),
    ];
  }

  void _computeListGeometry(Size screenSize) {
    final n = _actions.length;
    const menuWidth = 220.0;
    const itemHeight = 42.0;
    const vPad = 6.0;
    final menuHeight = n * itemHeight + vPad * 2;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomLimit = screenSize.height - keyboardInset;
    final maxMenuY = math.max(8.0, bottomLimit - menuHeight - 8.0);
    late double menuX;
    late double menuY;
    if (widget.interaction != MessageActionsInteraction.dragAndRelease) {
      final spaceBelow = bottomLimit - widget.tapPoint.dy - 8;
      _showBelow = spaceBelow >= menuHeight || widget.tapPoint.dy < menuHeight;
      final rawY = _showBelow
          ? widget.tapPoint.dy
          : widget.tapPoint.dy - menuHeight;
      menuY = rawY.clamp(8.0, maxMenuY).toDouble();
      menuX = widget.tapPoint.dx
          .clamp(8.0, screenSize.width - menuWidth - 8.0)
          .toDouble();
    } else {
      final spaceBelow = bottomLimit - widget.originRect.bottom - 24;
      final spaceAbove = widget.originRect.top - 24;
      _showBelow = spaceBelow >= menuHeight || spaceBelow >= spaceAbove;
      final rawY = _showBelow
          ? widget.originRect.bottom + 10
          : widget.originRect.top - 10 - menuHeight;
      menuY = rawY.clamp(8.0, maxMenuY).toDouble();
      final rawX = widget.isMe
          ? widget.originRect.right - menuWidth
          : widget.originRect.left;
      menuX = rawX.clamp(8.0, screenSize.width - menuWidth - 8.0).toDouble();
    }
    _menuRect = Rect.fromLTWH(menuX, menuY, menuWidth, menuHeight);
    _buttonHitRects = [
      for (int i = 0; i < n; i++)
        Rect.fromLTWH(
          menuX,
          menuY + vPad + i * itemHeight,
          menuWidth,
          itemHeight,
        ),
    ];
  }

  @override
  void dispose() {
    _animController.dispose();
    widget.controller.removeListener(_onControllerUpdate);
    widget.snapshot?.dispose();
    super.dispose();
  }

  List<_Action> _buildActions() {
    final l10n = AppLocalizations.of(context)!;
    final hasText =
        widget.messageText != null && widget.messageText!.isNotEmpty;
    return <_Action>[
      if (hasText) _Action(Symbols.content_copy, l10n.msgActionsCopy, _copy),
      if (widget.isMe && widget.onEdit != null)
        _Action(Symbols.edit, l10n.msgActionsEdit, _edit),
      if (widget.onReply != null)
        _Action(Symbols.reply, l10n.msgActionsReply, _reply),
      if (widget.onForward != null)
        _Action(Symbols.forward, l10n.msgActionsForward, _forward),
      if (widget.onMarkUnread != null)
        _Action(
          Symbols.mark_chat_unread,
          l10n.msgActionsMarkUnread,
          _markUnread,
        ),
      if (widget.editHistory != null && widget.editHistory!.isNotEmpty)
        _Action(Symbols.history, l10n.msgActionsEditHistory, _showHistoryView),
      if (widget.onReport != null && widget.loadReportReasons != null)
        _Action(
          Symbols.flag,
          l10n.msgActionsReport,
          _showReportView,
          destructive: true,
        ),
      _Action(Symbols.delete, l10n.msgActionsDelete, _delete, destructive: true),
    ];
  }

  void _showHistoryView() {
    if (!mounted) return;
    setState(() => _showHistory = true);
  }

  Future<void> _showReportView() async {
    if (!mounted) return;
    setState(() {
      _showReport = true;
      _reportLoading = _reasons == null;
    });
    if (_reasons != null) return;
    final loaded = await widget.loadReportReasons?.call();
    if (!mounted) return;
    setState(() {
      _reasons = loaded ?? const [];
      _reportLoading = false;
    });
  }

  Future<void> _submitReport(int reasonId) async {
    if (_reportSending) return;
    setState(() => _reportSending = true);
    final report = widget.onReport;
    final ok = report == null ? false : await report(reasonId);
    if (!mounted) return;
    if (ok) {
      await _close();
    } else {
      setState(() => _reportSending = false);
    }
  }

  void _backToMenu() {
    if (!mounted) return;
    setState(() {
      _showHistory = false;
      _showReport = false;
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final p = widget.controller.pointer;
    if (p != null) {
      final newHovered = _findButtonAt(p);
      if (newHovered != _hoveredIndex) {
        if (newHovered != -1) Haptics.selection();
        setState(() => _hoveredIndex = newHovered);
      }
    }

    if (widget.controller.committed && !_committedFired) {
      _committedFired = true;
      _onCommit();
    }
  }

  int _findButtonAt(Offset p) {
    for (int i = 0; i < _buttonHitRects.length; i++) {
      if (_buttonHitRects[i].contains(p)) return i;
    }
    return -1;
  }

  void _onCommit() {
    if (_hoveredIndex != -1 && widget.controller.movedSignificantly) {
      Haptics.medium();
      _actions[_hoveredIndex].onTap();
    } else if (widget.controller.movedSignificantly) {
      _close();
    }
  }

  Future<void> _close() async {
    if (!mounted || _closing) return;
    _closing = true;
    try {
      await _animController.reverse();
    } catch (_) {}
    if (!mounted) return;
    widget.onDismiss();
  }

  Future<void> _copy() async {
    final text = widget.messageText;
    if (text != null && text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      showCustomNotification(context, AppLocalizations.of(context)!.msgActionsCopied);
    }
    await _close();
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    await _close();
    onDelete?.call();
  }

  Future<void> _edit() async {
    final onEdit = widget.onEdit;
    await _close();
    onEdit?.call();
  }

  Future<void> _reply() async {
    final onReply = widget.onReply;
    await _close();
    onReply?.call();
  }

  Future<void> _forward() async {
    final onForward = widget.onForward;
    await _close();
    onForward?.call();
  }

  Future<void> _markUnread() async {
    final onMarkUnread = widget.onMarkUnread;
    await _close();
    onMarkUnread?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isClick = widget.interaction == MessageActionsInteraction.click;
    return AnimatedBuilder(
      animation: _animation,
      builder: (ctx, _) {
        final t = _animation.value.clamp(0.0, 1.0);
        final blurSigma = 14.0 * t;
        final bubbleScale = 1.0 + 0.05 * t;

        return GestureDetector(
          onTap: _close,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              if (!isClick) ...[
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.22 * t),
                    ),
                  ),
                ),
                if (widget.snapshot != null)
                  Positioned(
                    left: widget.originRect.left,
                    top: widget.originRect.top,
                    width: widget.originRect.width,
                    height: widget.originRect.height,
                    child: Transform.scale(
                      scale: bubbleScale,
                      child: RawImage(
                        image: widget.snapshot,
                        width: widget.originRect.width,
                        height: widget.originRect.height,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
              ],
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _showHistory || _showReport,
                  child: AnimatedOpacity(
                    opacity: (_showHistory || _showReport) ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: Stack(
                      children: [
                        if (_effectiveStyle == MessageActionsStyle.radial) ...[
                          ..._buildButtons(t),
                          _buildLabelBanner(size, t),
                        ] else
                          _buildListMenu(t),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !(_showHistory || _showReport),
                  child: AnimatedOpacity(
                    opacity: (_showHistory || _showReport) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Stack(
                      children: [
                        if (_showReport)
                          _buildReportMenu()
                        else if (_showHistory)
                          _buildHistoryMenu(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnchoredPanel({required String title, required Widget body}) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    const menuWidth = 220.0;

    double left;
    double top;
    if (_menuRect != Rect.zero) {
      left = _menuRect.left;
      top = _menuRect.top;
    } else {
      left = widget.isMe
          ? widget.originRect.right - menuWidth
          : widget.originRect.left;
      top = _showBelow
          ? widget.originRect.bottom + 10
          : widget.originRect.top - 10;
    }
    final bottomLimit = size.height - MediaQuery.viewInsetsOf(context).bottom;
    left = left.clamp(8.0, size.width - menuWidth - 8.0);
    top = top.clamp(8.0, math.max(8.0, bottomLimit - 160.0));
    final maxHeight = math.min(size.height * 0.6, bottomLimit - top - 8.0);

    return Positioned(
      left: left,
      top: top,
      width: menuWidth,
      child: GestureDetector(
        onTap: () {},
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.4),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      _panelBackButton(cs),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
                Flexible(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelBackButton(ColorScheme cs) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: () {
        Haptics.tap();
        _backToMenu();
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(Symbols.arrow_back, color: cs.onSurface, size: 20),
      ),
    ),
  );

  Widget _buildHistoryMenu() {
    final cs = Theme.of(context).colorScheme;
    final history = widget.editHistory ?? const <Map<String, dynamic>>[];

    final rows = <Widget>[];
    for (var i = 0; i < history.length; i++) {
      if (i > 0) rows.add(_historyDivider(cs));
      rows.add(
        _historyRow(
          cs,
          history[i]['text'] as String?,
          history[i]['time'],
          current: false,
        ),
      );
    }
    final currentTime = history.isNotEmpty ? history.last['time'] : null;
    if (rows.isNotEmpty) rows.add(_historyDivider(cs));
    rows.add(_historyRow(cs, widget.messageText, currentTime, current: true));

    return _buildAnchoredPanel(
      title: AppLocalizations.of(context)!.msgActionsEditHistory,
      body: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }

  Widget _buildReportMenu() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final Widget body;
    if (_reportLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    } else {
      final reasons = _reasons ?? const <({int id, String title})>[];
      if (reasons.isEmpty) {
        body = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Text(
            l10n.msgActionsLoadReasonsFailed,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        );
      } else {
        final rows = <Widget>[];
        for (var i = 0; i < reasons.length; i++) {
          if (i > 0) rows.add(_historyDivider(cs));
          rows.add(_reasonRow(cs, reasons[i]));
        }
        body = SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        );
      }
    }
    return _buildAnchoredPanel(title: l10n.msgActionsReport, body: body);
  }

  Widget _reasonRow(ColorScheme cs, ({int id, String title}) reason) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _reportSending ? null : () => _submitReport(reason.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Text(
              reason.title,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
            ),
          ),
        ),
      );

  Widget _historyDivider(ColorScheme cs) =>
      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.25));

  Widget _historyRow(
    ColorScheme cs,
    String? text,
    dynamic time, {
    required bool current,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final ms = time is int ? time : int.tryParse(time?.toString() ?? '');
    final dateStr = ms != null
        ? formatDateTimeWords(DateTime.fromMillisecondsSinceEpoch(ms))
        : '';
    final label = current
        ? (dateStr.isEmpty
              ? l10n.msgActionsCurrentVersion
              : l10n.msgActionsCurrentVersionWithDate(dateStr))
        : dateStr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text == null || text.isEmpty ? l10n.msgActionsNoText : text,
            style: TextStyle(
              color: current ? cs.primary : cs.onSurface,
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildListMenu(double t) {
    final cs = Theme.of(context).colorScheme;
    final eased = Curves.easeOutCubic.transform(t);
    final scale = 0.88 + 0.12 * eased;
    final tapAnchored =
        widget.interaction != MessageActionsInteraction.dragAndRelease;
    return Positioned(
      left: _menuRect.left,
      top: _menuRect.top,
      width: _menuRect.width,
      height: _menuRect.height,
      child: Opacity(
        opacity: eased,
        child: Transform.scale(
          scale: scale,
          alignment: tapAnchored
              ? Alignment(-1.0, _showBelow ? -1.0 : 1.0)
              : Alignment(widget.isMe ? 1.0 : -1.0, _showBelow ? -1.0 : 1.0),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                for (int i = 0; i < _actions.length; i++)
                  _ListMenuItem(
                    action: _actions[i],
                    highlighted: _hoveredIndex == i,
                    onHoverChanged: tapAnchored
                        ? (hovered) {
                            if (hovered) {
                              if (_hoveredIndex != i) {
                                setState(() => _hoveredIndex = i);
                              }
                            } else if (_hoveredIndex == i) {
                              setState(() => _hoveredIndex = -1);
                            }
                          }
                        : null,
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildButtons(double t) {
    final n = _actions.length;
    return [
      for (int i = 0; i < n; i++)
        Builder(
          builder: (_) {
            final delay = (i / n) * 0.25;
            final localT = ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
            final eased = Curves.easeOutBack.transform(localT);
            final isHovered = _hoveredIndex == i;
            final hoverScale = isHovered ? 1.18 : 1.0;
            final entryScale = 0.4 + 0.6 * eased;
            final centerAtFull = _buttonCenters[i];
            final centerAtT = _anchor + (centerAtFull - _anchor) * eased;

            return Positioned(
              left: centerAtT.dx - _btnSize / 2,
              top: centerAtT.dy - _btnSize / 2,
              width: _btnSize,
              height: _btnSize,
              child: Opacity(
                opacity: localT,
                child: Transform.scale(
                  scale: entryScale,
                  child: AnimatedScale(
                    scale: hoverScale,
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    child: _ActionButton(
                      action: _actions[i],
                      highlighted: isHovered,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  Widget _buildLabelBanner(Size size, double t) {
    final label = _hoveredIndex == -1 ? null : _actions[_hoveredIndex].label;
    final bottomInset = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewInsetsOf(context).bottom,
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + 36,
      child: IgnorePointer(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                child: child,
              ),
            ),
            child: label == null
                ? const SizedBox(key: ValueKey('empty'), height: 0)
                : Container(
                    key: ValueKey('label_$label'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72 * t),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const _Action(this.icon, this.label, this.onTap, {this.destructive = false});
}

class _ListMenuItem extends StatelessWidget {
  final _Action action;
  final bool highlighted;
  final ValueChanged<bool>? onHoverChanged;
  const _ListMenuItem({
    required this.action,
    required this.highlighted,
    this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pillBg = action.destructive ? cs.error : cs.primary;
    final onPill = action.destructive ? cs.onError : cs.onPrimary;
    final restFg = action.destructive ? cs.error : cs.onSurface;
    final fg = highlighted ? onPill : restFg;
    final inner = SizedBox(
      height: 42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.tap();
            action.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: highlighted ? pillBg : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(action.icon, color: fg, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: highlighted
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (onHoverChanged == null) return inner;
    return MouseRegion(
      onEnter: (_) => onHoverChanged!(true),
      onExit: (_) => onHoverChanged!(false),
      child: inner,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final _Action action;
  final bool highlighted;
  const _ActionButton({required this.action, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = highlighted ? cs.primary : cs.surfaceContainerHighest;
    final iconColor = highlighted ? cs.onPrimary : cs.onSurface;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: highlighted ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Haptics.tap();
            action.onTap();
          },
          child: Center(child: Icon(action.icon, color: iconColor, size: 24)),
        ),
      ),
    );
  }
}
