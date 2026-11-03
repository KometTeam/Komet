import 'package:flutter/material.dart';
import 'package:komet/l10n/app_localizations.dart';

import '../../../backend/modules/account.dart';
import '../../../core/utils/logger.dart';
import '../../../main.dart';
import '../../widgets/auth_limits_sheet.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/login_success_screen.dart';
import '../../widgets/temporary_password_recovery_dialog.dart';
import 'password_2fa_screen.dart';
import 'registration_screen.dart';

mixin VerifiedLoginFlow<T extends StatefulWidget> on State<T> {
  String get verifiedRawPhone;

  String get verifiedPhoneNumber;

  void showVerificationError(String message);

  Future<void> finishVerifiedLogin(VerifyCodeResult result) async {
    try {
      await _continueAfterVerification(result);
    } catch (e, st) {
      logger.d('[${api.debugTag}] вход после подтверждения упал: $e\n$st');
      if (!mounted) return;
      final accountId = result.accountId;
      if (accountId != null) {
        await showTemporaryPasswordRecovery(
          context,
          accountId,
          verifiedAccountId: accountId,
        );
        if (!mounted) return;
      }
      showVerificationError(e.toString());
    }
  }

  Future<void> completeLogin(String? avatarUrl) async {
    if (!mounted) return;

    final avatar = await precacheLoginAvatar(context, avatarUrl);

    if (!mounted) return;

    await markAuthLimitsPending(AuthEntry.login);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => LoginSuccessScreen(avatar: avatar),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  Future<void> _continueAfterVerification(VerifyCodeResult result) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    if (result.requiresPassword) {
      final trackId = result.challengeTrackId;
      if (trackId == null) {
        showCustomNotification(context, l10n.codeError2faMissing);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Password2FAScreen(
            trackId: trackId,
            hint: result.challengeHint,
            rawPhone: verifiedRawPhone,
          ),
        ),
      );
      return;
    }

    if (result.isRegistration) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegistrationScreen(
            phoneNumber: verifiedPhoneNumber,
            registerToken: result.registerToken!,
            presetAvatars: result.presetAvatars,
          ),
        ),
      );
      return;
    }

    logger.d(
      '[${api.debugTag}] вход подтверждён: '
      '${api.webHandshake ? 'SMS-вход через веб' : 'обычный вход'}',
    );
    // #***! эксперим. SMS-вход через веб: получаем сокетовый токен хитрой схемой
    if (api.webHandshake) {
      final token = result.loginToken;
      final accountId = result.accountId;
      if (token == null || accountId == null) {
        showVerificationError(l10n.codeConfirmationSmsNoToken);
        return;
      }
      await accountModule.completeWebSmsSocketLogin(
        phone: verifiedRawPhone,
        accountId: accountId,
        webToken: token,
        existingPassword: null,
      );
      if (!mounted) return;
      await showTemporaryPasswordRecovery(
        context,
        accountId,
        verifiedAccountId: accountId,
      );
      if (!mounted) return;
      await completeLogin(null);
      return;
    }

    final loginResult = await accountModule.login();

    await completeLogin(loginResult.profile.baseUrl);
  }
}
