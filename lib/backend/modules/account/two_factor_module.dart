import '../../../core/protocol/opcode_map.dart';
import '../../../core/storage/app_database.dart';
import 'account_base.dart';
import 'account_models.dart';
import 'profile_module.dart';

// #***! двухфакторка, пароль подсказка и почта
class TwoFactorModule extends AccountApiBase {
  final ProfileModule _profile;
  TwoFactorModule(super.api, this._profile);

  // #***! весь сценарий по trackId, им сервер связывает шаги
  Future<String> create2faTrack() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authCreateTrack, {'type': 0});
    final data = requireMapPayload(packet, 'create2faTrack');
    final trackId = data['trackId'] as String?;
    if (trackId == null) {
      throw Exception('create2faTrack: отсутствует trackId');
    }
    return trackId;
  }

  // #***! пароль и подсказку сервер сначала валидирует
  Future<void> set2faPassword(String trackId, String password) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authValidatePassword, {
      'trackId': trackId,
      'password': password,
    });
    checkPacketError(packet, 'set2faPassword');
    if (packet.payload != null && packet.payload is! Map) {
      throw Exception('set2faPassword: неожиданный ответ');
    }
  }

  Future<void> set2faHint(String trackId, String hint) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authValidateHint, {
      'trackId': trackId,
      'hint': hint,
    });
    checkPacketError(packet, 'set2faHint');
    if (packet.payload != null && packet.payload is! Map) {
      throw Exception('set2faHint: неожиданный ответ');
    }
  }

  // #***! код на почту, вернёт через сколько можно повторить
  Future<int> verify2faEmail(String trackId, String email) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authVerifyEmail, {
      'trackId': trackId,
      'email': email,
    });
    final data = requireMapPayload(packet, 'verify2faEmail');
    final blockingDuration = data['blockingDuration'] as int? ?? 60;
    return blockingDuration;
  }

  Future<String> verify2faCode(String trackId, String code) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authCheckEmail, {
      'trackId': trackId,
      'verifyCode': code,
    });
    final data = requireMapPayload(packet, 'verify2faCode');
    final email = data['email'] as String? ?? '';
    return email;
  }

  // #***! финал, expectedCapabilities говорит что поменяли
  Future<ProfileData> confirm2fa({
    required String trackId,
    required String password,
    String? hint,
    bool withEmail = true,
  }) async {
    ensureOnline();
    final capabilities = <int>[0, if (hint != null) 3, if (withEmail) 4];
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': capabilities,
      'trackId': trackId,
      'password': password,
    };
    if (hint != null) payload['hint'] = hint;
    return _profile.processProfileUpdate(
      api.sendRequest(Opcode.authSet2fa, payload),
      'confirm2fa',
    );
  }

  // #***! вход в панель 2FA, запрос тот же но смысл другой
  Future<String> enter2faPanel() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authCreateTrack, {'type': 0});
    final data = requireMapPayload(packet, 'enter2faPanel');
    final trackId = data['trackId'] as String?;
    if (trackId == null) {
      throw Exception('enter2faPanel: отсутствует trackId');
    }
    return trackId;
  }

  // #***! включена ли 2FA, почта и подсказка
  Future<TwoFactorDetails> get2faDetails(String trackId) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.auth2faDetails, {
      'trackId': trackId,
    });
    final data = requireMapPayload(packet, 'get2faDetails');
    final password = data['password'] as Map?;
    return TwoFactorDetails(
      enabled: password?['enabled'] ?? false,
      email: password?['email'] as String?,
      hint: password?['hint'] as String?,
    );
  }

  Future<TwoFactorDetails> get2faStatus() async {
    final trackId = await enter2faPanel();
    return get2faDetails(trackId);
  }

  // #***! проверка текущего пароля
  Future<void> check2faPassword(String trackId, String password) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.authCheckPassword, {
      'trackId': trackId,
      'password': password,
    });
    checkPacketError(packet, 'check2faPassword');
    final data = packet.payload;
    if (data is Map && data['error'] != null) {
      throw const WrongPasswordException();
    }
  }

  // #***! смена пароля, валидация подсказка применение
  Future<ProfileData> update2faPassword({
    required String trackId,
    required String newPassword,
    String? hint,
  }) async {
    ensureOnline();
    final validatePacket = await api.sendRequest(Opcode.authValidatePassword, {
      'trackId': trackId,
      'password': newPassword,
    });
    checkPacketError(validatePacket, 'update2faPassword: validate');
    if (validatePacket.payload != null && validatePacket.payload is! Map) {
      throw Exception('update2faPassword: неожиданный ответ при валидации');
    }

    if (hint != null) {
      final hintPacket = await api.sendRequest(Opcode.authValidateHint, {
        'trackId': trackId,
        'hint': hint,
      });
      checkPacketError(hintPacket, 'update2faPassword: hint');
    }

    final payload = <dynamic, dynamic>{
      'expectedCapabilities': <int>[1, if (hint != null) 3],
      'trackId': trackId,
      'password': newPassword,
    };
    if (hint != null) payload['hint'] = hint;

    return _profile.processProfileUpdate(
      api.sendRequest(Opcode.authSet2fa, payload),
      'update2faPassword',
    );
  }

  Future<ProfileData> commit2faEmailChange(String trackId) async {
    ensureOnline();
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [4],
      'trackId': trackId,
    };
    return _profile.processProfileUpdate(
      api.sendRequest(Opcode.authSet2fa, payload),
      'commit2faEmailChange',
    );
  }

  // #***! снятие 2FA, capability 5
  Future<ProfileData> remove2fa(String trackId) async {
    ensureOnline();
    final payload = <dynamic, dynamic>{
      'expectedCapabilities': [5],
      'trackId': trackId,
      'remove2fa': true,
    };
    return _profile.processProfileUpdate(
      api.sendRequest(Opcode.authSet2fa, payload),
      'remove2fa',
    );
  }
}
