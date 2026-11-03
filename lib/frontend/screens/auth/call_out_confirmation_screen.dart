import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../backend/modules/account.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/utils/logger.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/hint_bubble.dart';
import '../../widgets/small_spinner.dart';
import 'call_out_controller.dart';
import 'code_confirmation_screen.dart';
import 'login_needs_2fa_screen.dart';
import 'session_stale_recovery.dart';
import 'verified_login_flow.dart';

class CallOutConfirmationScreen extends StatefulWidget {
  final String phoneNumber;
  final String rawPhone;
  final String countryCode;
  final CallOutParams callOut;

  const CallOutConfirmationScreen({
    super.key,
    required this.phoneNumber,
    required this.rawPhone,
    required this.countryCode,
    required this.callOut,
  });

  @override
  State<CallOutConfirmationScreen> createState() =>
      _CallOutConfirmationScreenState();
}

class _CallOutConfirmationScreenState extends State<CallOutConfirmationScreen>
    with SessionStaleRecovery, VerifiedLoginFlow {
  late final CallOutController _controller;
  late final AppLifecycleListener _lifecycle;
  CallOutPhase? _handledPhase;
  bool _signingIn = false;
  bool _refreshing = false;
  String? _errorMessage;

  @override
  String get connectionDroppedMessage =>
      AppLocalizations.of(context)!.codeConfirmationConnectionDropped;

  @override
  String get verifiedRawPhone => widget.rawPhone;

  @override
  String get verifiedPhoneNumber => widget.phoneNumber;

  @override
  void showVerificationError(String message) =>
      setState(() => _errorMessage = message);

  bool get _busy => _signingIn || _refreshing || recovering;

  @override
  void initState() {
    super.initState();
    _controller = CallOutController(
      params: widget.callOut,
      check: accountModule.checkCallOut,
    )..addListener(_onControllerChanged);
    _lifecycle = AppLifecycleListener(onResume: _controller.pollNow);
    startSessionRecovery();
    _controller.start();
  }

  @override
  void dispose() {
    stopSessionRecovery();
    _lifecycle.dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final phase = _controller.phase;
    if (phase == _handledPhase) return;
    _handledPhase = phase;
    switch (phase) {
      case CallOutPhase.verified:
        unawaited(_signIn());
      case CallOutPhase.failed:
        final error = _controller.error;
        if (error != null && isAuthSessionLostError(error)) {
          unawaited(
            _refresh(notice: AppLocalizations.of(context)!.callOutNewNumber),
          );
        }
      case CallOutPhase.waitingForNumber ||
          CallOutPhase.awaitingCall ||
          CallOutPhase.expired:
        break;
    }
  }

  @override
  Future<void> recoverStaleSession() async {
    if (recovering) return;
    setState(() => recovering = true);
    try {
      if (!await waitForOnline()) {
        if (mounted) {
          showCustomNotification(
            context,
            AppLocalizations.of(context)!.codeConfirmationNoConnection,
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        sessionEpoch = api.sessionEpoch;
        dropNotified = false;
      });
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.codeConfirmationConnectionRestored,
      );
      _controller.pollNow();
    } catch (e) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.codeConfirmationReconnectFailed('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => recovering = false);
    }
  }

  Future<void> _refresh({String? notice}) async {
    if (_signingIn || _refreshing) return;
    setState(() {
      _refreshing = true;
      _errorMessage = null;
    });
    try {
      if (!await waitForOnline()) {
        if (mounted) {
          setState(
            () => _errorMessage = AppLocalizations.of(
              context,
            )!.codeConfirmationNoConnection,
          );
        }
        return;
      }
      final fresh = await accountModule.requestCode(widget.rawPhone);
      if (!mounted) return;
      sessionEpoch = api.sessionEpoch;
      dropNotified = false;
      final callOut = fresh.callOut;
      if (callOut == null) {
        _openCodeScreen(fresh.token);
        return;
      }
      _handledPhase = null;
      _controller.restart(callOut);
      if (notice != null) showCustomNotification(context, notice);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(
            context,
          )!.callOutRefreshFailed('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openCodeScreen(String token) {
    stopSessionRecovery();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CodeConfirmationScreen(
          phoneNumber: widget.phoneNumber,
          rawPhone: widget.rawPhone,
          countryCode: widget.countryCode,
          token: token,
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });
    final VerifyCodeResult result;
    try {
      result = await accountModule.loginByTrack(_controller.trackId);
    } catch (e, st) {
      logger.d('[${api.debugTag}] вход после звонка не принят: $e\n$st');
      if (!mounted) return;
      setState(() => _signingIn = false);
      await _onTrackRejected(e);
      return;
    }
    stopSessionRecovery();
    try {
      await finishVerifiedLogin(result);
    } finally {
      if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) {
        setState(() => _signingIn = false);
      }
    }
  }

  Future<void> _onTrackRejected(Object error) async {
    if (error is PacketError && error.errorKey == loginNeeds2faErrorKey) {
      final retry = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const LoginNeeds2faScreen()),
      );
      if (retry == true && mounted) await _refresh();
      return;
    }
    if (!mounted) return;
    setState(
      () => _errorMessage = isSessionStateError(error)
          ? AppLocalizations.of(context)!.callOutCommonError
          : error.toString(),
    );
  }

  Future<void> _dial(BuildContext anchor, String number) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (launched || !anchor.mounted) return;
    showHintBubble(anchor, AppLocalizations.of(anchor)!.textEntityDialFailed);
  }

  Future<void> _copyNumber(BuildContext anchor, String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!anchor.mounted) return;
    showHintBubble(anchor, AppLocalizations.of(anchor)!.msgActionsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_signingIn,
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Symbols.arrow_back, color: cs.onSurfaceVariant),
            onPressed: _signingIn ? null : () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final phase = _controller.phase;
                final number = _controller.callNumber;
                final error =
                    _errorMessage ??
                    (phase == CallOutPhase.failed
                        ? _controller.error?.toString() ??
                              l10n.callOutCommonError
                        : null);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      widget.phoneNumber,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.callOutDescription,
                      style: TextStyle(
                        color: cs.outline,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _CallNumberCard(
                      number: number,
                      onCopy: number == null
                          ? null
                          : (anchor) => _copyNumber(anchor, number),
                    ),
                    const SizedBox(height: 16),
                    _CallOutStatusLine(
                      phase: phase,
                      remaining: _controller.remaining,
                      signingIn: _signingIn,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topLeft,
                      child: error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                error,
                                style: TextStyle(
                                  color: cs.error,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ),
                    ),
                    const Spacer(),
                    _CallOutAction(
                      phase: phase,
                      number: number,
                      busy: _busy,
                      onDial: _dial,
                      onRefresh: () => unawaited(_refresh()),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CallNumberCard extends StatelessWidget {
  final String? number;
  final void Function(BuildContext anchor)? onCopy;

  const _CallNumberCard({required this.number, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final value = number;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Builder(
        builder: (anchor) => InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onCopy == null ? null : () => onCopy!(anchor),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: SizedBox(
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: value == null
                    ? Row(
                        key: const ValueKey('waiting'),
                        children: [
                          SmallSpinner(size: 20, color: cs.primary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              l10n.callOutWaitingNumber,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: ValueKey(value),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.callOutTapToCopy,
                            style: TextStyle(color: cs.outline, fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallOutStatusLine extends StatelessWidget {
  final CallOutPhase phase;
  final ValueListenable<Duration> remaining;
  final bool signingIn;

  const _CallOutStatusLine({
    required this.phase,
    required this.remaining,
    required this.signingIn,
  });

  static String _format(Duration left) {
    final seconds = (left.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final style = TextStyle(color: cs.outline, fontSize: 14, height: 1.35);

    if (signingIn) return Text(l10n.callOutVerified, style: style);
    if (phase == CallOutPhase.expired) {
      return Text(l10n.callOutExpired, style: style);
    }
    if (phase == CallOutPhase.failed || phase == CallOutPhase.verified) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Duration>(
      valueListenable: remaining,
      builder: (context, left, _) =>
          Text(l10n.callOutTimer(_format(left)), style: style),
    );
  }
}

class _CallOutAction extends StatelessWidget {
  final CallOutPhase phase;
  final String? number;
  final bool busy;
  final Future<void> Function(BuildContext anchor, String number) onDial;
  final VoidCallback onRefresh;

  const _CallOutAction({
    required this.phase,
    required this.number,
    required this.busy,
    required this.onDial,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final value = number;
    final canRefresh =
        phase == CallOutPhase.expired ||
        phase == CallOutPhase.failed ||
        phase == CallOutPhase.verified;

    final Widget label;
    final VoidCallback? onPressed;
    if (busy) {
      label = SmallSpinner(size: 22, color: cs.onPrimary);
      onPressed = null;
    } else if (canRefresh) {
      label = _label(Symbols.refresh, l10n.callOutRefresh);
      onPressed = onRefresh;
    } else if (value != null) {
      label = _label(Symbols.call, l10n.callOutDial(value));
      onPressed = () => unawaited(onDial(context, value));
    } else {
      label = _label(Symbols.call, l10n.callOutDialPending);
      onPressed = null;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: label,
      ),
    );
  }

  static Widget _label(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 22),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
