import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/app_lock.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/confirm_dialog.dart';

// #***! биометрия для мини-приложений: что есть на устройстве, согласие
// #***! пользователя и сама системная проверка
abstract class WebAppBiometry {
  Future<List<String>> types();

  Future<bool?> confirmAccess(String? reason);

  Future<bool> authenticate(String? reason);
}

class DeviceWebAppBiometry implements WebAppBiometry {
  const DeviceWebAppBiometry(this.contextResolver);

  final BuildContext? Function() contextResolver;

  @override
  Future<List<String>> types() async {
    final available = await AppLock.instance.biometricTypes();
    if (available.isEmpty) return const [];
    final types = {
      for (final type in available)
        if (type == BiometricType.face)
          'face'
        else if (type == BiometricType.fingerprint)
          'finger',
    };
    return types.isEmpty ? const ['unknown'] : types.toList();
  }

  @override
  Future<bool?> confirmAccess(String? reason) async {
    final context = contextResolver();
    if (context == null) return null;
    final l10n = AppLocalizations.of(context)!;
    final notice = l10n.webAppBiometryAccessNotice;
    return showConfirmDialog(
      context,
      title: l10n.webAppBiometryAccessTitle,
      message: reason == null ? notice : '$notice\n\n$reason',
      confirmLabel: l10n.attachSheetAllow,
      cancelLabel: l10n.joinRequestsDecline,
    );
  }

  @override
  Future<bool> authenticate(String? reason) {
    final context = contextResolver();
    final prompt =
        reason ??
        (context == null
            ? null
            : AppLocalizations.of(context)!.webAppBiometryAuthReason);
    if (prompt == null) return Future.value(false);
    return AppLock.instance.external(
      () => AppLock.instance.authenticateBiometric(prompt),
    );
  }
}
