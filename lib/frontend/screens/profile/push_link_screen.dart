import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/api.dart';
import '../../../backend/modules/account.dart';
import '../../../backend/modules/account/sessions_module.dart';
import '../../../core/push/push_link_service.dart';
import '../../../core/push/push_proxy_client.dart';
import '../../../core/protocol/opcode_map.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/storage/device_identity.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show accountModule;
import '../../widgets/confirm_dialog.dart';
import '../../widgets/connection_status.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/section_header.dart';
import '../../widgets/settings_card.dart';
import '../../widgets/small_spinner.dart';

class _AccountRow {
  final int accountId;
  final String name;
  final bool isActive;
  bool bound;
  bool active;

  _AccountRow({
    required this.accountId,
    required this.name,
    required this.isActive,
    required this.bound,
    required this.active,
  });
}

enum _FlowStage { idle, waiting, password }

class PushLinkScreen extends StatefulWidget {
  const PushLinkScreen({super.key});

  @override
  State<PushLinkScreen> createState() => _PushLinkScreenState();
}

class _PushLinkScreenState extends State<PushLinkScreen> {
  final _passwordController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  final List<_AccountRow> _rows = [];
  _AccountRow? _pending;
  _FlowStage _flow = _FlowStage.idle;
  PushLinkSession? _linkSession;
  Timer? _pollTimer;
  String? _passwordHint;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _passwordController.dispose();
    final linkId = _linkSession?.linkId;
    if (linkId != null) {
      unawaited(PushLinkService.instance.cancel(linkId));
    }
    PushLinkService.instance.clear();
    super.dispose();
  }

  Future<void> _reload() async {
    final profiles = await AppDatabase.loadAllProfiles();
    final activeId = await TokenStorage.getActiveAccountId();
    if (!mounted) return;
    setState(() => _loading = true);
    final rows = <_AccountRow>[];
    for (final profile in profiles) {
      final state = await PushProxyClient.instance.prepareAccount(profile.id);
      if (!mounted) return;
      final name = [
        profile.firstName,
        profile.lastName,
      ].whereType<String>().join(' ').trim();
      rows.add(
        _AccountRow(
          accountId: profile.id,
          name: name.isEmpty ? 'ID ${profile.id}' : name,
          isActive: profile.id == activeId,
          bound: state?.bound ?? false,
          active: state?.active ?? false,
        ),
      );
    }
    setState(() {
      _rows
        ..clear()
        ..addAll(rows);
      _loading = false;
    });
  }

  Future<void> _onToggle(_AccountRow row, bool value) async {
    if (_busy || _flow != _FlowStage.idle) return;
    if (row.bound == value) return;
    if (value) {
      await _enableAccount(row);
    } else {
      await _disableAccount(row);
    }
  }

  Future<void> _enableAccount(_AccountRow row) async {
    final l10n = AppLocalizations.of(context)!;
    final apnsToken = PushProxyClient.instance.apnsToken;
    if (apnsToken == null || apnsToken.isEmpty) {
      showCustomNotification(context, l10n.pushLinkApnsMissing);
      return;
    }
    final state = await PushProxyClient.instance.prepareAccount(row.accountId);
    if (state != null && state.bound) {
      // #***! устройство уже привязано — QR-перерегистрация не нужна,
      // сокет будится активацией
      await _reload();
      return;
    }
    if (state != null && !state.bound) {
      setState(() => _busy = true);
      try {
        final ok = await PushProxyClient.instance.attachAccount(row.accountId);
        if (!mounted) return;
        if (!ok) {
          showCustomNotification(context, l10n.pushLinkAttachFailed);
          return;
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      await _reload();
      return;
    }
    await _startRegistration(row);
  }

  Future<void> _disableAccount(_AccountRow row) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.pushLinkUnlink,
      message: l10n.pushLinkUnlinkConfirm,
      confirmLabel: l10n.pushLinkUnlink,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await PushProxyClient.instance.unregisterAccount(row.accountId);
      if (!mounted) return;
      showCustomNotification(context, l10n.pushLinkUnlinkedDone);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  Future<void> _startRegistration(_AccountRow row) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      unawaited(PushProxyClient.instance.requestVoipRegistration());
      final voipToken = await PushProxyClient.instance.waitForVoipToken(
        const Duration(seconds: 10),
      );
      final session = await PushLinkService.instance.start(
        apnsToken: PushProxyClient.instance.apnsToken!,
        voipToken: voipToken ?? '',
        deviceId: await DeviceIdentity.deviceId(),
        accountId: row.accountId,
        isDev: kDebugMode,
      );
      _linkSession = session;
      _pending = row;
      setState(() => _flow = _FlowStage.waiting);
      final approved = await _approveQr(row.accountId, session.qrLink);
      if (!approved) {
        await _abortRegistration();
        if (mounted) {
          showCustomNotification(context, l10n.pushLinkApproveFailed);
        }
        return;
      }
      _schedulePolling(session.pollEvery);
    } catch (e) {
      await _abortRegistration();
      if (mounted) showCustomNotification(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abortRegistration() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    final linkId = _linkSession?.linkId;
    _linkSession = null;
    _pending = null;
    if (linkId != null) {
      unawaited(PushLinkService.instance.cancel(linkId));
    }
    if (mounted) {
      setState(() {
        _flow = _FlowStage.idle;
        _busy = false;
      });
    }
  }

  Future<bool> _approveQr(int accountId, String qrLink) async {
    final activeId = await TokenStorage.getActiveAccountId();
    try {
      if (accountId == activeId) {
        await accountModule.authorizeWebQrLogin(qrLink);
        return true;
      }
      return await _approveViaTempSession(accountId, qrLink);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _approveViaTempSession(int accountId, String qrLink) async {
    final token = await TokenStorage.readToken(accountId);
    if (token == null || token.isEmpty) return false;
    final tempApi = Api()..spoofScope = '$accountId';
    try {
      await tempApi.connect();
      if (tempApi.state != SessionState.online) {
        await tempApi.stateStream
            .firstWhere((s) => s == SessionState.online)
            .timeout(const Duration(seconds: 20));
      }
      final login = await tempApi.sendRequest(
        Opcode.login,
        AccountModule(tempApi).buildLoginPayload(token, interactive: false),
      );
      if (!login.isOk) return false;
      await SessionsModule(tempApi).authorizeWebQrLogin(qrLink);
      return true;
    } catch (_) {
      return false;
    } finally {
      unawaited(tempApi.disconnect());
    }
  }

  void _schedulePolling(Duration interval) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => _poll());
  }

  bool _polling = false;

  Future<void> _poll() async {
    final session = _linkSession;
    final row = _pending;
    if (session == null || row == null || _polling) return;
    if (_flow != _FlowStage.waiting) return;
    _polling = true;
    try {
      final status = await PushLinkService.instance.status(session.linkId);
      if (!mounted) return;
      if (status.isPassword) {
        _pollTimer?.cancel();
        setState(() {
          _flow = _FlowStage.password;
          _passwordHint = status.hint;
          _busy = false;
        });
        return;
      }
      if (status.isDone) {
        _pollTimer?.cancel();
        await _finishRegistration(row, status.loginToken);
      } else if (status.isExpired) {
        await _abortRegistration();
        if (mounted) {
          showCustomNotification(
            context,
            AppLocalizations.of(context)!.pushLinkBindFailed,
          );
        }
      }
    } catch (e) {
      await _abortRegistration();
      if (mounted) showCustomNotification(context, e.toString());
    } finally {
      _polling = false;
    }
  }

  Future<void> _submitPassword() async {
    final session = _linkSession;
    final row = _pending;
    if (session == null || row == null || _busy) return;
    if (_flow != _FlowStage.password) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.pushLinkPasswordInvalid,
        );
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final status = await PushLinkService.instance.password(
        session.linkId,
        password,
      );
      if (status.isDone) {
        _pollTimer?.cancel();
        await _finishRegistration(row, status.loginToken);
      } else if (status.isExpired) {
        await _abortRegistration();
        if (mounted) {
          showCustomNotification(
            context,
            AppLocalizations.of(context)!.pushLinkBindFailed,
          );
        }
      } else if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.pushLinkPasswordWrong,
        );
      }
    } catch (e) {
      if (mounted) showCustomNotification(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishRegistration(_AccountRow row, String? loginToken) async {
    final l10n = AppLocalizations.of(context)!;
    if (loginToken == null || loginToken.isEmpty) {
      await _abortRegistration();
      if (mounted) showCustomNotification(context, l10n.pushLinkBindFailed);
      return;
    }
    final ok = await PushProxyClient.instance.registerAccountToken(
      row.accountId,
      loginToken,
    );
    await _abortRegistration();
    if (!mounted) return;
    if (!ok) {
      showCustomNotification(context, l10n.pushLinkBindFailed);
      return;
    }
    Haptics.success();
    showCustomNotification(context, l10n.pushLinkLinkedDone);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ConnectionTitleBar(
        titleText: l10n.pushProxyTile,
        backgroundColor: cs.surface,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: SmallSpinner(size: 36))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.pushLinkIntro,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (_rows.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SectionHeader(
                      l10n.pushLinkAccountsTitle,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      fontSize: 14,
                    ),
                    SettingsCard(
                      children: [
                        for (final row in _rows) _accountTile(cs, l10n, row),
                      ],
                    ),
                  ],
                  if (_flow == _FlowStage.waiting) ...[
                    const SizedBox(height: 20),
                    SettingsCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: SmallSpinner(size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.pushLinkWaiting,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_flow == _FlowStage.password) ...[
                    const SizedBox(height: 20),
                    SettingsCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.pushLinkPasswordBody,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (_passwordHint != null &&
                                  _passwordHint!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _passwordHint!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                autofocus: true,
                                onSubmitted: (_) =>
                                    unawaited(_submitPassword()),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => unawaited(_submitPassword()),
                                icon: const Icon(Symbols.lock),
                                label: Text(l10n.pushLinkConfirm),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _accountTile(ColorScheme cs, AppLocalizations l10n, _AccountRow row) {
    String subtitle;
    if (!row.bound) {
      subtitle = l10n.pushLinkUnlinkedSubtitle;
    } else if (row.active) {
      subtitle = l10n.pushLinkAccountActive;
    } else {
      subtitle = l10n.pushLinkAccountInactive;
    }
    return SettingsToggleTile(
      icon: Symbols.person,
      label: row.isActive
          ? '${row.name} · ${l10n.pushLinkActiveAccountBadge}'
          : row.name,
      subtitle: subtitle,
      value: row.bound,
      enabled: !_busy && _flow == _FlowStage.idle,
      onChanged: (v) => unawaited(_onToggle(row, v)),
    );
  }
}
