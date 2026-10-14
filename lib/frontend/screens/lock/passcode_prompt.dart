import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/security/pin_credential.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/logger.dart';
import '../../../l10n/app_localizations.dart';
import 'passcode_pad.dart';

class PasscodePrompt extends StatefulWidget {
  final PinCredential credential;
  final Future<bool> Function(String pin) onSubmit;
  final Widget header;
  final VoidCallback? onBiometric;

  const PasscodePrompt({
    super.key,
    required this.credential,
    required this.onSubmit,
    required this.header,
    this.onBiometric,
  });

  @override
  State<PasscodePrompt> createState() => _PasscodePromptState();
}

class _PasscodePromptState extends State<PasscodePrompt> {
  static const double _chromeHeight = 300;

  final FocusNode _focus = FocusNode();
  String _pin = '';
  int _errorTick = 0;
  bool _checking = false;
  bool _wrong = false;
  Timer? _countdown;

  PinCredential get _credential => widget.credential;

  bool get _blocked => _credential.blockedUntil.value != null;

  @override
  void initState() {
    super.initState();
    _credential.blockedUntil.addListener(_onBlockedChanged);
    _onBlockedChanged();
  }

  @override
  void didUpdateWidget(PasscodePrompt old) {
    super.didUpdateWidget(old);
    if (old.credential == widget.credential) return;
    old.credential.blockedUntil.removeListener(_onBlockedChanged);
    widget.credential.blockedUntil.addListener(_onBlockedChanged);
    _onBlockedChanged();
  }

  @override
  void dispose() {
    _credential.blockedUntil.removeListener(_onBlockedChanged);
    _countdown?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onBlockedChanged() {
    _countdown?.cancel();
    _countdown = null;
    if (!_blocked) {
      if (mounted) setState(() {});
      return;
    }
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      _credential.refreshLockout();
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _pin = '');
  }

  void _onDigit(int digit) {
    if (_checking || _blocked || _pin.length >= PinCredential.length) return;
    setState(() {
      _pin += '$digit';
      _wrong = false;
    });
    if (_pin.length == PinCredential.length) unawaited(_submit());
  }

  void _onBackspace() {
    if (_checking || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _checking = true);
    var ok = false;
    try {
      ok = await widget.onSubmit(_pin);
    } catch (e) {
      logger.w('PasscodePrompt: проверка кода упала: $e');
    }
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
    final until = _credential.blockedUntil.value;
    if (until != null) {
      final left = until.difference(DateTime.now());
      final seconds = left.inSeconds.clamp(0, 3600);
      final text =
          '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      return l10n.lockBlocked(text);
    }
    if (_wrong) return l10n.lockAttemptsLeft(_credential.attemptsLeft);
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _status(AppLocalizations.of(context)!);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
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
                  widget.header,
                  const SizedBox(height: 30),
                  PasscodeDots(
                    length: PinCredential.length,
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
                    onBiometric: widget.onBiometric,
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
    );
  }
}
