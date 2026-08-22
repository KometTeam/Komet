import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/api.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/webpush/max_web_socket.dart';
import '../../../core/webpush/web_push_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show accountModule, api;
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';

const String kWebPushSiteUrl = 'https://push.komet.pw';

enum _Stage { loading, intro, waiting, password, ready }

class WebPushScreen extends StatefulWidget {
  const WebPushScreen({super.key});

  @override
  State<WebPushScreen> createState() => _WebPushScreenState();
}

class _WebPushScreenState extends State<WebPushScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  Animation<double>? _routeAnimation;
  void Function(AnimationStatus)? _routeAnimationListener;

  _Stage _stage = _Stage.loading;
  bool _busy = false;
  bool _linked = false;
  WebPushLinkInfo? _link;
  String? _trackId;
  String? _passwordHint;

  @override
  void initState() {
    super.initState();
    WebPushService.instance.changes.addListener(_onServiceChanged);
    _reload();
  }

  void _onServiceChanged() {
    if (mounted) _reload();
  }

  @override
  void dispose() {
    final listener = _routeAnimationListener;
    if (listener != null) _routeAnimation?.removeStatusListener(listener);
    WebPushService.instance.changes.removeListener(_onServiceChanged);
    _passwordController.dispose();
    _passwordFocus.dispose();
    WebPushService.instance.cancelAuth();
    super.dispose();
  }

  Future<void> _reload() async {
    final service = WebPushService.instance;
    final authorized = await service.isAuthorized();
    final link = await service.linkInfo();
    if (!mounted) return;
    setState(() {
      _link = link;
      _linked = link != null;
      _stage = authorized ? _Stage.ready : _Stage.intro;
    });
  }

  void _scheduleKeyboard() {
    final animation = ModalRoute.of(context)?.animation;

    if (animation == null || animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openKeyboard();
      });
      return;
    }

    final previous = _routeAnimationListener;
    if (previous != null) _routeAnimation?.removeStatusListener(previous);

    _routeAnimation = animation;
    _routeAnimationListener = (status) {
      if (status != AnimationStatus.completed) return;
      final listener = _routeAnimationListener;
      if (listener != null) animation.removeStatusListener(listener);
      _routeAnimationListener = null;
      if (mounted) _openKeyboard();
    };
    animation.addStatusListener(_routeAnimationListener!);
  }

  void _openKeyboard() {
    if (!_passwordFocus.hasFocus) _passwordFocus.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on MaxWebException catch (e) {
      if (mounted) showCustomNotification(context, e.message);
    } catch (e) {
      if (mounted) showCustomNotification(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _run(() async {
    final l10n = AppLocalizations.of(context)!;
    if (api.state != SessionState.online) {
      showCustomNotification(context, l10n.webPushNeedsOnline);
      return;
    }

    final service = WebPushService.instance;
    final track = await service.startQrAuth();
    if (!mounted) return;
    setState(() => _stage = _Stage.waiting);

    await accountModule.authorizeWebQrLogin(track.qrLink);
    final step = await service.awaitApproval(track);
    await _applyStep(step);
  });

  Future<void> _submitPassword() => _run(() async {
    final trackId = _trackId;
    if (trackId == null) return;
    final step = await WebPushService.instance.submitPassword(
      trackId,
      _passwordController.text,
    );
    await _applyStep(step);
  });

  Future<void> _applyStep(WebPushAuthStep step) async {
    if (step.needsPassword) {
      if (!mounted) return;
      _trackId = step.passwordChallenge!.trackId;
      _passwordHint = step.passwordChallenge!.hint;
      setState(() => _stage = _Stage.password);
      _scheduleKeyboard();
      return;
    }

    await WebPushService.instance.finishAuth(step.loginToken!);
    if (!mounted) return;
    _passwordController.clear();
    setState(() => _stage = _Stage.ready);
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.webPushSignOut,
      message: l10n.webPushSignOutConfirm,
      confirmLabel: l10n.webPushSignOutAction,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await _run(() async {
      await WebPushService.instance.signOut();
      if (!mounted) return;
      setState(() {
        _linked = false;
        _link = null;
        _trackId = null;
        _stage = _Stage.intro;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.webPushTitle,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: _stage == _Stage.loading
            ? const Center(child: SmallSpinner(size: 36))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: _sections(context, cs, l10n),
              ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) => switch (_stage) {
    _Stage.loading => const [],
    _Stage.intro => [
      _explainer(cs, l10n.webPushIntro),
      const SizedBox(height: 20),
      _primary(l10n.webPushConnect, _connect),
    ],
    _Stage.waiting => [
      _explainer(cs, l10n.webPushWaitingBody),
      const SizedBox(height: 24),
      const Center(child: SmallSpinner(size: 32)),
    ],
    _Stage.password => [
      _explainer(cs, l10n.webPushPasswordExplainer),
      if (_passwordHint != null) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l10n.webPushPasswordHintLabel(_passwordHint!),
            style: TextStyle(color: cs.tertiary, fontSize: 14),
          ),
        ),
      ],
      const SizedBox(height: 20),
      TextField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        enabled: !_busy,
        autofocus: true,
        obscureText: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitPassword(),
        decoration: InputDecoration(
          hintText: l10n.webPushPasswordHint,
          filled: true,
          fillColor: cs.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _primary(l10n.webPushConfirm, _submitPassword),
    ],
    _Stage.ready => [
      SectionHeader(
        _linked ? l10n.webPushLinkedTitle : l10n.webPushInstallTitle,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        fontSize: 14,
      ),
      _explainer(cs, _linked ? l10n.webPushLinkedBody : l10n.webPushInstallBody),
      if (_link != null) ...[
        const SizedBox(height: 12),
        _linkDetails(cs, l10n, _link!),
      ],
      const SizedBox(height: 20),
      _primary(l10n.webPushOpenSite, () {
        Haptics.tap();
        openExternalUrl(context, kWebPushSiteUrl);
      }),
      const SizedBox(height: 24),
      SettingsCard(
        children: [
          SettingsNavTile(
            icon: Symbols.logout,
            label: l10n.webPushSignOut,
            tintColor: cs.error,
            onTap: _busy ? null : _signOut,
            isLast: true,
          ),
        ],
      ),
    ],
  };

  Widget _detailRow(ColorScheme cs, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _linkDetails(
    ColorScheme cs,
    AppLocalizations l10n,
    WebPushLinkInfo link,
  ) => SettingsPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow(cs, l10n.webPushStatusService, link.host),
        _detailRow(cs, l10n.webPushStatusToken, link.shortEndpoint),
        if (link.linkedAt != null)
          _detailRow(
            cs,
            l10n.webPushStatusLinkedAt,
            formatDateTimeWords(link.linkedAt!),
          ),
        _detailRow(cs, l10n.webPushStatusDevice, link.deviceId),
      ],
    ),
  );

  Widget _explainer(ColorScheme cs, String text) => SettingsPanel(
    child: Text(
      text,
      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.5),
    ),
  );

  Widget _primary(String label, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _busy ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _busy
          ? const SmallSpinner(size: 20)
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}
