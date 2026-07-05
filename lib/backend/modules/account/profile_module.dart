import 'dart:async';

import '../../../core/protocol/opcode_map.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/app_database.dart';
import 'account_base.dart';

class ProfileModule extends AccountApiBase {
  ProfileModule(super.api);

  Future<ProfileData> _applyProfileResponse(Packet packet) async {
    if (packet.isError) {
      throw Exception(packet.payload?.toString() ?? 'Server error');
    }
    final data = packet.payload as Map?;
    if (data == null) throw Exception('Empty response');
    final profile = data['profile'] as Map?;
    if (profile == null) throw Exception('No profile in response');
    final contact = profile['contact'] as Map?;
    if (contact == null) throw Exception('No contact in response');
    final newProfile = ProfileData.fromServerProfile(
      profile.cast<dynamic, dynamic>(),
    );
    await AppDatabase.saveProfile(newProfile, isActive: true);
    return newProfile;
  }

  Future<ProfileData> updateProfileName(
    String firstName,
    String? lastName,
  ) async {
    ensureOnline();
    final payload = <dynamic, dynamic>{'firstName': firstName};
    if (lastName != null) payload['lastName'] = lastName;
    final packet = await api.sendRequest(Opcode.profile, payload);
    return _applyProfileResponse(packet);
  }

  Future<ProfileData> updateProfileAvatar(
    String photoToken, {
    String avatarType = 'USER_AVATAR',
  }) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.profile, {
      'photoToken': photoToken,
      'avatarType': avatarType,
    });
    return _applyProfileResponse(packet);
  }

  Future<String> getAvatarUploadUrl() async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.photoUpload, {
      'count': 1,
      'profile': true,
    });
    if (packet.isError) {
      throw Exception(packet.payload?.toString() ?? 'Server error');
    }
    final data = packet.payload as Map?;
    if (data == null) throw Exception('Empty response');
    final url = data['url'] as String?;
    if (url == null) throw Exception('No url in response');
    return url;
  }

  Future<ProfileData> removeProfilePhoto(int photoId) async {
    ensureOnline();
    final packet = await api.sendRequest(Opcode.removeContactPhoto, {
      'photoId': photoId,
    });
    return _applyProfileResponse(packet);
  }

  Future<ProfileData> processProfileUpdate(
    Future<Packet> requestFuture,
    String tag,
  ) async {
    final completer = Completer<ProfileData>();
    final sub = api.pushStream
        .where((p) => p.opcode == Opcode.notifProfile)
        .listen((push) {
          if (completer.isCompleted) return;
          final payload = push.payload;
          if (payload is! Map) return;
          final profile = payload['profile'];
          if (profile is! Map) return;
          final contact = profile['contact'];
          if (contact is! Map) return;
          completer.complete(
            ProfileData.fromServerProfile(profile.cast<dynamic, dynamic>()),
          );
        });
    final timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Таймаут ожидания обновления профиля'),
        );
      }
    });
    try {
      final packet = await requestFuture;
      checkPacketError(packet, tag);
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }
}
