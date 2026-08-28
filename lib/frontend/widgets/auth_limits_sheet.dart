import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import 'info_action_sheet.dart';

enum AuthEntry { login, registration }

const String _pendingKey = 'pending_auth_limits';
const String _pendingAtKey = 'pending_auth_limits_at';
const Duration _loginLimitsDuration = Duration(hours: 24);

Future<void> markAuthLimitsPending(AuthEntry entry) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingKey, entry.name);
  await prefs.setInt(_pendingAtKey, DateTime.now().millisecondsSinceEpoch);
}

Future<void> showPendingAuthLimits(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getString(_pendingKey);
  final pendingAt = prefs.getInt(_pendingAtKey);
  if (pending == null) return;
  await prefs.remove(_pendingKey);
  await prefs.remove(_pendingAtKey);

  final entry = switch (pending) {
    'login' => AuthEntry.login,
    'registration' => AuthEntry.registration,
    _ => null,
  };
  if (entry == null || !context.mounted) return;

  await showAuthLimitsSheet(
    context,
    entry,
    grantedAt: pendingAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(pendingAt),
  );
}

Future<void> showAuthLimitsSheet(
  BuildContext context,
  AuthEntry entry, {
  DateTime? grantedAt,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final liftsAt = (grantedAt ?? DateTime.now()).add(_loginLimitsDuration);
  switch (entry) {
    case AuthEntry.login:
      await showInfoActionSheet(
        context,
        headerIcon: Symbols.lock_clock,
        headerGlow: true,
        title: l10n.authLimitsLoginTitle,
        subtitle: l10n.authLimitsLoginSubtitle(liftsAt),
        items: [
          InfoActionSheetItem(
            icon: Symbols.password,
            title: l10n.authLimitsLogin2faTitle,
            body: l10n.authLimitsLogin2faBody,
          ),
          InfoActionSheetItem(
            icon: Symbols.devices,
            title: l10n.authLimitsLoginSessionsTitle,
            body: l10n.authLimitsLoginSessionsBody,
          ),
        ],
        confirmLabel: l10n.authLimitsConfirm,
      );
    case AuthEntry.registration:
      await showInfoActionSheet(
        context,
        headerIcon: Symbols.hourglass_top,
        headerGlow: true,
        title: l10n.authLimitsSignupTitle,
        subtitle: l10n.authLimitsSignupSubtitle,
        items: [
          InfoActionSheetItem(
            icon: Symbols.chat_bubble,
            title: l10n.authLimitsSignupMessagesTitle,
            body: l10n.authLimitsSignupMessagesBody,
          ),
          InfoActionSheetItem(
            icon: Symbols.group,
            title: l10n.authLimitsSignupGroupsTitle,
            body: l10n.authLimitsSignupGroupsBody,
          ),
          InfoActionSheetItem(
            icon: Symbols.schedule,
            title: l10n.authLimitsSignupMoreTitle,
            body: l10n.authLimitsSignupMoreBody,
          ),
        ],
        confirmLabel: l10n.authLimitsConfirm,
      );
  }
}
