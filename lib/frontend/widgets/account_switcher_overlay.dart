import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/haptics.dart';
import 'animated_overlay_popup.dart';
import 'komet_avatar.dart';

class AccountSwitcherController extends ChangeNotifier {
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

  void _onPointerEvent(PointerEvent event) {
    if (committed) return;
    if (event is PointerMoveEvent) {
      pointer = event.position;
      if (initialPointer != null &&
          !movedSignificantly &&
          (event.position - initialPointer!).distance > 12) {
        movedSignificantly = true;
      }
      notifyListeners();
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

typedef AccountSwitcherCallback = void Function(int? accountId);

void showAccountSwitcher({
  required BuildContext context,
  required Offset tapPoint,
  required AccountSwitcherController controller,
  required AccountSwitcherCallback onSelected,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _AccountSwitcherLayer(
      tapPoint: tapPoint,
      controller: controller,
      onSelected: onSelected,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _AccountSwitcherLayer extends StatefulWidget {
  final Offset tapPoint;
  final AccountSwitcherController controller;
  final AccountSwitcherCallback onSelected;
  final VoidCallback onDismiss;

  const _AccountSwitcherLayer({
    required this.tapPoint,
    required this.controller,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<_AccountSwitcherLayer> createState() => _AccountSwitcherLayerState();
}

class _AccountSwitcherLayerState extends State<_AccountSwitcherLayer>
    with
        SingleTickerProviderStateMixin,
        AnimatedOverlayPopup<_AccountSwitcherLayer> {
  static const double _menuWidth = 280.0;
  static const double _itemHeight = 60.0;
  static const double _addItemHeight = 54.0;
  static const double _vPad = 8.0;
  static const double _hMargin = 12.0;

  List<ProfileData> _accounts = const [];
  int? _activeId;
  bool _loaded = false;

  int _hoveredIndex = -1;
  Rect _menuRect = Rect.zero;
  List<Rect> _itemHitRects = const [];
  bool _committedFired = false;

  @override
  Duration get overlayForwardDuration => const Duration(milliseconds: 240);

  @override
  Duration get overlayReverseDuration => const Duration(milliseconds: 180);

  @override
  VoidCallback get onOverlayDismiss => widget.onDismiss;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AppDatabase.loadAllProfiles();
    final activeId = await TokenStorage.getActiveAccountId();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _activeId = activeId;
      _loaded = true;
      _computeGeometry();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onControllerUpdate();
    });
  }

  void _computeGeometry() {
    final screen = MediaQuery.sizeOf(context);
    final totalItems = _accounts.length;
    final height = _vPad * 2 + totalItems * _itemHeight + _addItemHeight;

    final maxWidth = screen.width - 2 * _hMargin;
    final menuWidth = maxWidth <= 0
        ? screen.width
        : (_menuWidth > maxWidth ? maxWidth : _menuWidth);

    double menuX = widget.tapPoint.dx - menuWidth / 2;
    final maxX = screen.width - menuWidth - _hMargin;
    if (menuX > maxX) menuX = maxX;
    if (menuX < _hMargin) menuX = _hMargin;

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxBottom = screen.height - bottomInset - 88;
    double menuBottom = maxBottom;
    if (widget.tapPoint.dy - 20 < menuBottom) {
      menuBottom = widget.tapPoint.dy - 20;
    }
    double menuY = menuBottom - height;
    if (menuY < 24) menuY = 24;

    _menuRect = Rect.fromLTWH(menuX, menuY, menuWidth, height);
    _itemHitRects = [
      for (int i = 0; i < totalItems; i++)
        Rect.fromLTWH(
          menuX,
          menuY + _vPad + i * _itemHeight,
          menuWidth,
          _itemHeight,
        ),
      Rect.fromLTWH(
        menuX,
        menuY + _vPad + totalItems * _itemHeight,
        menuWidth,
        _addItemHeight,
      ),
    ];
  }

  void _onControllerUpdate() {
    if (!mounted || !_loaded) return;
    final p = widget.controller.pointer;
    if (p != null) {
      final newHovered = _findItemAt(p);
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

  int _findItemAt(Offset p) {
    for (int i = 0; i < _itemHitRects.length; i++) {
      if (_itemHitRects[i].contains(p)) return i;
    }
    return -1;
  }

  void _onCommit() {
    if (_hoveredIndex == -1) {
      closeOverlay();
      return;
    }
    Haptics.medium();
    final isAddItem = _hoveredIndex == _accounts.length;
    final id = isAddItem ? null : _accounts[_hoveredIndex].id;
    if (!isAddItem && id == _activeId) {
      closeOverlay();
      return;
    }
    final selected = id;
    closeOverlay().then((_) => widget.onSelected(selected));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: overlayAnimation,
      builder: (ctx, _) {
        final t = overlayAnimation.value.clamp(0.0, 1.0);
        final blurSigma = 14.0 * t;
        return GestureDetector(
          onTap: closeOverlay,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
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
              if (_loaded) _buildMenu(t),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenu(double t) {
    final cs = Theme.of(context).colorScheme;
    final eased = Curves.easeOutCubic.transform(t);
    final scale = 0.88 + 0.12 * eased;
    return Positioned(
      left: _menuRect.left,
      top: _menuRect.top,
      width: _menuRect.width,
      height: _menuRect.height,
      child: Opacity(
        opacity: eased,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: _vPad),
                for (int i = 0; i < _accounts.length; i++)
                  _AccountRow(
                    profile: _accounts[i],
                    highlighted: _hoveredIndex == i,
                    active: _accounts[i].id == _activeId,
                  ),
                _AddAccountRow(highlighted: _hoveredIndex == _accounts.length),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final ProfileData profile;
  final bool highlighted;
  final bool active;

  const _AccountRow({
    required this.profile,
    required this.highlighted,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pillBg = cs.primary;
    final onPill = cs.onPrimary;
    final fg = highlighted ? onPill : cs.onSurface;
    final subFg = highlighted
        ? onPill.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;
    final fullName = (profile.lastName != null && profile.lastName!.isNotEmpty)
        ? '${profile.firstName} ${profile.lastName}'
        : profile.firstName;
    final phone = profile.phone == 0 ? '' : '+${profile.phone}';
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: highlighted ? pillBg : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(
                          color: highlighted ? onPill : cs.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: KometAvatar(
                  name: fullName,
                  imageUrl: profile.baseUrl,
                  size: 36,
                  backgroundColor: highlighted
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  foregroundColor: cs.onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'Без имени',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: subFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              if (active)
                Icon(
                  Symbols.check_circle,
                  color: highlighted ? onPill : cs.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAccountRow extends StatelessWidget {
  final bool highlighted;

  const _AddAccountRow({required this.highlighted});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pillBg = cs.primary;
    final onPill = cs.onPrimary;
    final fg = highlighted ? onPill : cs.primary;
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: highlighted ? pillBg : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlighted
                      ? onPill.withValues(alpha: 0.18)
                      : cs.primary.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(Symbols.add, color: fg, size: 20, weight: 500),
              ),
              const SizedBox(width: 14),
              Text(
                'Добавить аккаунт',
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
