// #***! итог проверки удостоверения, unknown это что то новое
enum DigitalIdVerification {
  valid,
  invalid,
  photoCreated,
  notFound,
  deviceMismatch,
  liteValid,
  unknown;

  static DigitalIdVerification fromValue(String? value) {
    switch (value) {
      case 'valid':
        return DigitalIdVerification.valid;
      case 'invalid':
        return DigitalIdVerification.invalid;
      case 'photo_created':
        return DigitalIdVerification.photoCreated;
      case 'not_found':
        return DigitalIdVerification.notFound;
      case 'device_mismatch':
        return DigitalIdVerification.deviceMismatch;
      case 'lite_valid':
        return DigitalIdVerification.liteValid;
      default:
        return DigitalIdVerification.unknown;
    }
  }
}

// #***! типы QR госуслуг
enum DigitalIdQrType {
  m1('M1', 'max_confirm_age'),
  m2('M2', 'max_cert_large_family'),
  m3('M3', 'max_student_ticket'),
  m4('M4', 'max_sor'),
  m5('M5', 'max_single_benefits'),
  m7('M7', 'max_invalid_certificate'),
  m8('M8', 'max_pension_certificate'),
  m11('M11', 'max_identify_verification');

  const DigitalIdQrType(this.code, this.alias);

  final String code;
  final String alias;
}

// #***! адрес регистрации по кусочкам, сервер шлёт snake_case
class DigitalIdAddress {
  final String? address;
  final String? flat;
  final String? frame;
  final String? house;
  final String? zipCode;

  const DigitalIdAddress({
    this.address,
    this.flat,
    this.frame,
    this.house,
    this.zipCode,
  });

  factory DigitalIdAddress.fromMap(Map map) {
    return DigitalIdAddress(
      address: map['address'] as String?,
      flat: map['flat'] as String?,
      frame: map['frame'] as String?,
      house: map['house'] as String?,
      zipCode: map['zip_code'] as String?,
    );
  }

  // #***! склейка адреса в строку
  String get formatted {
    final parts = <String>[
      if (address != null && address!.isNotEmpty) address!,
      if (house != null && house!.isNotEmpty) 'д. $house',
      if (frame != null && frame!.isNotEmpty) 'к. $frame',
      if (flat != null && flat!.isNotEmpty) 'кв. $flat',
    ];
    return parts.join(', ');
  }
}

// #***! биометрия, привязан ли токен и к тому ли устройству
class DigitalIdBiometryStatus {
  final bool hasBiometryToken;
  final String? deviceId;
  final bool hasPhotoHash;

  const DigitalIdBiometryStatus({
    required this.hasBiometryToken,
    required this.deviceId,
    required this.hasPhotoHash,
  });

  factory DigitalIdBiometryStatus.fromMap(Map map) {
    return DigitalIdBiometryStatus(
      hasBiometryToken: map['has_biometry_token'] == true,
      deviceId: map['device_id'] as String?,
      hasPhotoHash: map['has_photo_hash'] == true,
    );
  }
}

// #***! документ как есть, набор полей зависит от типа
class DigitalIdDocument {
  final String type;
  final Map<String, dynamic> fields;

  const DigitalIdDocument({required this.type, required this.fields});

  factory DigitalIdDocument.fromMap(Map map) {
    final fields = <String, dynamic>{};
    for (final entry in map.entries) {
      fields[entry.key.toString()] = entry.value;
    }
    return DigitalIdDocument(
      type: (map['type'] as String?) ?? 'unknown',
      fields: fields,
    );
  }

  // #***! ходовые поля геттерами, остальное из fields
  String? get firstName => fields['first_name'] as String?;
  String? get lastName => fields['last_name'] as String?;
  String? get middleName => fields['middle_name'] as String?;
  String? get number => fields['number'] as String?;
  String? get series => fields['series'] as String?;
}

// #***! профиль владельца плюс документы
class DigitalIdProfile {
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? birthDate;
  final String? birthPlace;
  final String? gender;
  final String? snils;
  final String? inn;
  final DigitalIdAddress? registrationAddress;
  final List<DigitalIdDocument> documents;

  const DigitalIdProfile({
    this.firstName,
    this.lastName,
    this.middleName,
    this.birthDate,
    this.birthPlace,
    this.gender,
    this.snils,
    this.inn,
    this.registrationAddress,
    this.documents = const [],
  });

  // #***! битые документы пропускаем, профиль покажем
  factory DigitalIdProfile.fromMap(Map map) {
    final rawDocs = map['documents'];
    final documents = <DigitalIdDocument>[];
    if (rawDocs is List) {
      for (final doc in rawDocs) {
        if (doc is Map) documents.add(DigitalIdDocument.fromMap(doc));
      }
    }
    final address = map['registration_address'];
    return DigitalIdProfile(
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      middleName: map['middle_name'] as String?,
      birthDate: map['birth_date'] as String?,
      birthPlace: map['birth_place'] as String?,
      gender: map['gender'] as String?,
      snils: map['snils'] as String?,
      inn: map['inn'] as String?,
      registrationAddress:
          address is Map ? DigitalIdAddress.fromMap(address) : null,
      documents: documents,
    );
  }

  // #***! фамилия имя отчество
  String get fullName {
    final parts = <String>[
      if (lastName != null && lastName!.isNotEmpty) lastName!,
      if (firstName != null && firstName!.isNotEmpty) firstName!,
      if (middleName != null && middleName!.isNotEmpty) middleName!,
    ];
    return parts.join(' ');
  }
}

// #***! документы конкретного юзера
class DigitalIdUserDocs {
  final int userId;
  final DigitalIdProfile profile;

  const DigitalIdUserDocs({required this.userId, required this.profile});

  factory DigitalIdUserDocs.fromMap(Map map) {
    final profile = map['digital_profile'];
    return DigitalIdUserDocs(
      userId: (map['user_id'] as num?)?.toInt() ?? 0,
      profile: profile is Map
          ? DigitalIdProfile.fromMap(profile)
          : const DigitalIdProfile(),
    );
  }
}

// #***! ссылка на госуслуги плюс state для сверки
class DigitalIdEsiaLink {
  final String? state;
  final String url;

  const DigitalIdEsiaLink({this.state, required this.url});

  factory DigitalIdEsiaLink.fromMap(Map map) {
    return DigitalIdEsiaLink(
      state: map['state'] as String?,
      url: map['url'] as String? ?? '',
    );
  }
}

// #***! QR документа, обычный и по госту
class DigitalIdQr {
  final String qr;
  final String? qrGost;

  const DigitalIdQr({required this.qr, this.qrGost});

  factory DigitalIdQr.fromMap(Map map) {
    return DigitalIdQr(
      qr: map['qr'] as String? ?? '',
      qrGost: map['qr_gost'] as String?,
    );
  }
}

// #***! универсальный QR профиля
class DigitalIdUniversalQr {
  final String uidHash;
  final String? phone;
  final String? sessionId;

  const DigitalIdUniversalQr({
    required this.uidHash,
    this.phone,
    this.sessionId,
  });

  factory DigitalIdUniversalQr.fromMap(Map map) {
    return DigitalIdUniversalQr(
      uidHash: map['uid_hash'] as String? ?? '',
      phone: map['phone'] as String?,
      sessionId: map['session_id'] as String?,
    );
  }
}

// #***! карточка организации в ACMS
class DigitalIdAcmsCard {
  final String id;
  final String inn;
  final String companyName;
  final String logoImg;

  const DigitalIdAcmsCard({
    required this.id,
    required this.inn,
    required this.companyName,
    required this.logoImg,
  });

  factory DigitalIdAcmsCard.fromMap(Map map) {
    return DigitalIdAcmsCard(
      id: map['id'] as String? ?? '',
      inn: map['inn'] as String? ?? '',
      companyName: map['company_name'] as String? ?? '',
      logoImg: map['logo_img'] as String? ?? '',
    );
  }
}
