import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import 'lock_glyph.dart';
import 'passcode_pad.dart';

class AppLockLayer extends StatefulWidget {
  final Widget child;

  const AppLockLayer({super.key, required this.child});

  @override
  State<AppLockLayer> createState() => _AppLockLayerState();
}

class _AppLockLayerState extends State<AppLockLayer>
    with TickerProviderStateMixin {
  static const Duration _enterDuration = Duration(milliseconds: 620);
  static const Duration _exitDuration = Duration(milliseconds: 300);
  static const Duration _openDuration = Duration(milliseconds: 240);

  final AppLock _lock = AppLock.instance;
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: _enterDuration,
    reverseDuration: _exitDuration,
  );
  late final AnimationController _opening = AnimationController(
    vsync: this,
    duration: _openDuration,
  );
  bool _shown = false;
  bool _covered = false;
  Rect? _origin;

  @override
  void initState() {
    super.initState();
    _lock.locked.addListener(_onLockedChanged);
    _presence.addStatusListener(_onPresenceStatus);
    if (_lock.locked.value) {
      _shown = true;
      _presence.value = 1;
      _covered = true;
    }
  }

  void _onPresenceStatus(AnimationStatus status) {
    final covered = status == AnimationStatus.completed && _lock.locked.value;
    if (covered != _covered && mounted) setState(() => _covered = covered);
  }

  @override
  void dispose() {
    _lock.locked.removeListener(_onLockedChanged);
    _presence.removeStatusListener(_onPresenceStatus);
    _presence.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _onLockedChanged() {
    if (_lock.locked.value) {
      _opening.value = 0;
      final origin = _lock.takeOrigin();
      setState(() {
        _shown = true;
        _origin = origin;
      });
      if (origin == null) {
        _presence.value = 1;
        _onPresenceStatus(_presence.status);
      } else {
        _presence.forward(from: 0);
      }
      return;
    }
    setState(() => _covered = false);
    unawaited(_playUnlock());
  }

  Future<void> _playUnlock() async {
    await _opening.forward(from: 0);
    if (!mounted || _lock.locked.value) return;
    await _presence.reverse();
    if (!mounted || _lock.locked.value) return;
    setState(() {
      _shown = false;
      _origin = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: !_covered,
          child: Offstage(
            offstage: _covered,
            child: ExcludeFocus(
              excluding: _shown,
              child: IgnorePointer(ignoring: _shown, child: widget.child),
            ),
          ),
        ),
        if (_shown)
          Positioned.fill(
            child: _LockScreen(
              presence: _presence,
              opening: _opening,
              origin: _origin,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatefulWidget {
  final AnimationController presence;
  final AnimationController opening;
  final Rect? origin;

  const _LockScreen({
    required this.presence,
    required this.opening,
    required this.origin,
  });

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> with WidgetsBindingObserver {
  static const double _glyphSize = 72;
  static const double _chromeHeight = 300;

  final AppLock _lock = AppLock.instance;
  final GlobalKey _slotKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  final FocusNode _focus = FocusNode();
  String _pin = '';
  int _errorTick = 0;
  bool _checking = false;
  bool _wrong = false;
  bool _biometricReady = false;
  bool _wasBackground = false;
  Timer? _countdown;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lock.blockedUntil.addListener(_onBlockedChanged);
    _onBlockedChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
    unawaited(_prepareBiometric());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock.blockedUntil.removeListener(_onBlockedChanged);
    _countdown?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackground = true;
    }
    if (state == AppLifecycleState.resumed && _wasBackground) {
      _wasBackground = false;
      _lock.refreshLockout();
      unawaited(_promptBiometric());
    }
  }

  void _measureTarget() {
    if (!mounted) return;
    final slot = _slotKey.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (slot is! RenderBox || stack is! RenderBox) return;
    final topLeft = slot.localToGlobal(Offset.zero, ancestor: stack);
    setState(() => _target = topLeft & slot.size);
  }

  Future<void> _prepareBiometric() async {
    final ready = _lock.biometric.value && await _lock.biometricAvailable();
    if (!mounted) return;
    setState(() => _biometricReady = ready);
    if (ready) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await _promptBiometric();
    }
  }

  Future<void> _promptBiometric() async {
    if (!_biometricReady || !mounted || !_lock.locked.value) return;
    final reason = AppLocalizations.of(context)!.lockBiometricReason;
    final ok = await _lock.unlockWithBiometric(reason);
    if (ok) Haptics.success();
  }

  void _onBlockedChanged() {
    _countdown?.cancel();
    if (_lock.blockedUntil.value == null) {
      if (mounted) setState(() {});
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      _lock.refreshLockout();
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _pin = '');
  }

  bool get _blocked => _lock.blockedUntil.value != null;

  void _onDigit(int digit) {
    if (_checking || _blocked || _pin.length >= AppLock.pinLength) return;
    setState(() {
      _pin += '$digit';
      _wrong = false;
    });
    if (_pin.length == AppLock.pinLength) unawaited(_submit());
  }

  void _onBackspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    final ok = await _lock.unlockWithPin(_pin);
    if (!mounted) return;
    if (ok) {
      Haptics.success();
      setState(() => _checking = false);
      return;
    }
    Haptics.error();
    setState(() {
      _checking = false;
      _pin = '';
      _wrong = true;
      _errorTick++;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final digit = PasscodeKeypad.digitOf(event);
    if (digit != null) {
      _onDigit(digit);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _status(AppLocalizations l10n) {
    final until = _lock.blockedUntil.value;
    if (until != null) {
      final left = until.difference(DateTime.now());
      final seconds = left.inSeconds.clamp(0, 3600);
      final text =
          '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      return l10n.lockBlocked(text);
    }
    if (_wrong) return l10n.lockAttemptsLeft(_lock.attemptsLeft);
    return '';
  }

  Animation<double> _interval(double begin, double end, {Curve? curve}) =>
      CurvedAnimation(
        parent: widget.presence,
        curve: Interval(begin, end, curve: curve ?? Curves.easeOutCubic),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final animated = widget.origin != null;
    final background = animated
        ? _interval(0, 0.45)
        : const AlwaysStoppedAnimation<double>(1);
    final content = animated
        ? _interval(0.3, 1)
        : const AlwaysStoppedAnimation<double>(1);
    final status = _status(l10n);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          key: _stackKey,
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: background,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.alphaBlend(
                        cs.primary.withValues(alpha: 0.08),
                        cs.surface,
                      ),
                      cs.surface,
                      cs.surfaceContainerLow,
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([widget.presence, widget.opening]),
              builder: (context, child) {
                final out = widget.opening.value;
                return Opacity(
                  opacity: widget.presence.status == AnimationStatus.reverse
                      ? widget.presence.value
                      : 1,
                  child: Transform.scale(scale: 1 + out * 0.03, child: child),
                );
              },
              child: SafeArea(
                child: FadeTransition(
                  opacity: content,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(content),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                const Spacer(flex: 5),
                                SizedBox.square(
                                  key: _slotKey,
                                  dimension: _glyphSize,
                                  child: _restingGlyph(cs),
                                ),
                                const SizedBox(height: 30),
                                Text(
                                  l10n.lockTitle,
                                  style: TextStyle(
                                    fontFamily: displayFontOf(context),
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                PasscodeDots(
                                  length: AppLock.pinLength,
                                  filled: _pin.length,
                                  errorTick: _errorTick,
                                  color: cs.primary,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 40,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      status,
                                      key: ValueKey(status),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.35,
                                        color: _blocked || _wrong
                                            ? cs.error
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(flex: 3),
                                PasscodeKeypad(
                                  onDigit: _onDigit,
                                  onBackspace: _onBackspace,
                                  enabled: !_blocked && !_checking,
                                  canErase: _pin.isNotEmpty,
                                  onBiometric: _biometricReady
                                      ? () => unawaited(_promptBiometric())
                                      : null,
                                  biometricIcon: Symbols.fingerprint,
                                  keySize: PasscodeKeypad.keySizeFor(
                                    constraints.maxHeight - _chromeHeight,
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _flyingGlyph(cs),
          ],
        ),
      ),
    );
  }

  bool get _flying =>
      widget.origin != null &&
      widget.presence.status == AnimationStatus.forward;

  Rect? _slotRect() {
    final slot = _slotKey.currentContext?.findRenderObject();
    final stack = _stackKey.currentContext?.findRenderObject();
    if (slot is! RenderBox || stack is! RenderBox || !slot.hasSize) {
      return null;
    }
    return slot.localToGlobal(Offset.zero, ancestor: stack) & slot.size;
  }

  Widget _restingGlyph(ColorScheme cs) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.presence, widget.opening]),
      builder: (context, _) {
        if (_flying) return const SizedBox.shrink();
        return LockGlyph(
          closed: 1 - widget.opening.value,
          size: _glyphSize,
          color: cs.primary,
          holeColor: cs.surface,
        );
      },
    );
  }

  Widget _flyingGlyph(ColorScheme cs) {
    return AnimatedBuilder(
      animation: widget.presence,
      builder: (context, _) {
        final origin = widget.origin;
        final target = _slotRect() ?? _target;
        if (!_flying || origin == null || target == null) {
          return const SizedBox.shrink();
        }
        final value = widget.presence.value;
        final t = Curves.easeInOutCubic.transform(
          const Interval(0, 0.75).transform(value),
        );
        final closed = Curves.easeOutBack.transform(
          const Interval(0.55, 1).transform(value),
        );
        final rect = Rect.lerp(origin, target, t)!;
        return Positioned.fromRect(
          rect: rect,
          child: LockGlyph(
            closed: closed,
            size: rect.width,
            color: Color.lerp(cs.outline, cs.primary, t)!,
            holeColor: cs.surface,
          ),
        );
      },
    );
  }
}
