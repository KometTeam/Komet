class Profile {
  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final String? description;
  final String? photoBaseUrl;
  final int photoId;
  final int updateTime;
  final List<String> options;
  final int accountStatus;
  final List<ProfileOption> profileOptions;

  Profile({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.description,
    this.photoBaseUrl,
    required this.photoId,
    required this.updateTime,
    required this.options,
    required this.accountStatus,
    required this.profileOptions,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> profileData;
    if (json.containsKey('contact')) {
      profileData = json['contact'] as Map<String, dynamic>;
    } else {
      profileData = json;
    }

    final names = profileData['names'] as List<dynamic>? ?? [];
    final nameData = names.isNotEmpty ? names[0] as Map<String, dynamic> : {};

    return Profile(
      id: profileData['id'],
      phone: profileData['phone'].toString(),
      firstName: nameData['firstName'] ?? '',
      lastName: nameData['lastName'] ?? '',
      description: profileData['description'],
      photoBaseUrl: profileData['baseUrl'],
      photoId: profileData['photoId'] ?? 0,
      updateTime: profileData['updateTime'] ?? 0,
      options: List<String>.from(profileData['options'] ?? []),
      accountStatus: profileData['accountStatus'] ?? 0,
      profileOptions:
          (json['profileOptions'] as List<dynamic>?)
              ?.map((option) => ProfileOption.fromJson(option))
              .toList() ??
          [],
    );
  }

  String get displayName {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isNotEmpty ? fullName : 'Пользователь';
  }

  String get formattedPhone {
    if (phone.length == 11 && phone.startsWith('7')) {
      return '+7 (${phone.substring(1, 4)}) ${phone.substring(4, 7)}-${phone.substring(7, 9)}-${phone.substring(9)}';
    }
    return phone;
  }
}

class ProfileOption {
  final String key;
  final dynamic value;

  ProfileOption({required this.key, required this.value});

  factory ProfileOption.fromJson(Map<String, dynamic> json) {
    return ProfileOption(key: json['key'], value: json['value']);
  }
}
