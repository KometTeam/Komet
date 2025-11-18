import 'package:gwid/models/profile.dart';

class Account {
  final String id;
  final String token;
  final String? userId;
  final Profile? profile;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  Account({
    required this.id,
    required this.token,
    this.userId,
    this.profile,
    required this.createdAt,
    this.lastUsedAt,
  });

  String get displayName {
    if (profile != null) {
      return profile!.displayName;
    }
    if (userId != null) {
      return 'Аккаунт $userId';
    }
    return 'Аккаунт ${id.substring(0, 8)}';
  }

  String get displayPhone {
    if (profile != null) {
      return profile!.formattedPhone;
    }
    return '';
  }

  String? get avatarUrl => profile?.photoBaseUrl;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'token': token,
      'userId': userId,
      'profile': profile != null
          ? {
              'id': profile!.id,
              'phone': profile!.phone,
              'firstName': profile!.firstName,
              'lastName': profile!.lastName,
              'photoBaseUrl': profile!.photoBaseUrl,
            }
          : null,
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    Profile? profile;
    if (json['profile'] != null) {
      final profileData = json['profile'] as Map<String, dynamic>;
      profile = Profile(
        id: profileData['id'] as int,
        phone: profileData['phone'] as String,
        firstName: profileData['firstName'] as String? ?? '',
        lastName: profileData['lastName'] as String? ?? '',
        photoBaseUrl: profileData['photoBaseUrl'] as String?,
        photoId: 0,
        updateTime: 0,
        options: [],
        accountStatus: 0,
        profileOptions: [],
      );
    }

    return Account(
      id: json['id'] as String,
      token: json['token'] as String,
      userId: json['userId'] as String?,
      profile: profile,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
    );
  }

  Account copyWith({
    String? id,
    String? token,
    String? userId,
    Profile? profile,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return Account(
      id: id ?? this.id,
      token: token ?? this.token,
      userId: userId ?? this.userId,
      profile: profile ?? this.profile,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
}
