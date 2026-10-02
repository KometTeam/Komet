import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/security/app_lock.dart';
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

  static const String _accessNotice =
      'Мини-приложение сможет запрашивать подтверждение отпечатком или лицом.';
  static const String _authReason = 'Подтвердите действие в мини-приложении';

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
    return showConfirmDialog(
      context,
      title: 'Разрешить биометрию?',
      message: reason == null ? _accessNotice : '$_accessNotice\n\n$reason',
      confirmLabel: 'Разрешить',
      cancelLabel: 'Отклонить',
    );
  }

  @override
  Future<bool> authenticate(String? reason) => AppLock.instance.external(
    () => AppLock.instance.authenticateBiometric(reason ?? _authReason),
  );
}
