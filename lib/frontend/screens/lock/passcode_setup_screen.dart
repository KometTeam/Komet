import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_fonts.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/connection_status.dart';
import 'lock_glyph.dart';
import 'passcode_pad.dart';

class PasscodeSetupScreen extends StatefulWidget {
  const PasscodeSetupScreen({super.key});

  @override
  State<PasscodeSetupScreen> createState() => _PasscodeSetupScreenState();
}

class _PasscodeSetupScreenState extends State<PasscodeSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  bool _mismatch = false;
  bool _saving = false;
  int _errorTick = 0;

  void _onDigit(int digit) {
    if (_saving || _pin.length >= AppLock.pinLength) return;
    setState(() {
      _pin += '$digit';
      _mismatch = false;
    });
    if (_pin.length == AppLock.pinLength) unawaited(_advance());
  }

  void _onBackspace() {
    if (_saving || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _advance() async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    if (!_confirming) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
      return;
    }
    if (_pin != _first) {
      Haptics.error();
      setState(() {
        _first = '';
        _pin = '';
        _confirming = false;
        _mismatch = true;
        _errorTick++;
      });
      return;
    }
    setState(() => _saving = true);
    await AppLock.instance.setPin(_pin);
    if (!mounted) return;
    Haptics.success();
    Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final title = _confirming ? l10n.passcodeRepeat : l10n.passcodeCreate;
    final hint = _mismatch ? l10n.passcodeMismatch : l10n.passcodeDigitsHint;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.passcodeTitle,
        backgroundColor: cs.surface,
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: _confirming ? 1 : 0),
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        builder: (context, closed, _) => LockGlyph(
                          closed: closed,
                          size: 72,
                          color: cs.primary,
                          holeColor: cs.surface,
                        ),
                      ),
                      const SizedBox(height: 30),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          title,
                          key: ValueKey(title),
                          style: TextStyle(
                            fontFamily: displayFontOf(context),
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: _mismatch ? cs.error : cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 30),
                      PasscodeDots(
                        length: AppLock.pinLength,
                        filled: _pin.length,
                        errorTick: _errorTick,
                        color: cs.primary,
                      ),
                      const Spacer(flex: 4),
                      PasscodeKeypad(
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                        enabled: !_saving,
                        canErase: _pin.isNotEmpty,
                        keySize: PasscodeKeypad.keySizeFor(
                          constraints.maxHeight - 300,
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
    );
  }
}
