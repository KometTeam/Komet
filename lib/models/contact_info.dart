class ContactName {
  final String? type;
  final String? name;
  final String? firstName;
  final String? lastName;

  const ContactName({this.type, this.name, this.firstName, this.lastName});

  factory ContactName.fromMap(Map map) => ContactName(
    type: map['type']?.toString(),
    name: map['name']?.toString(),
    firstName: map['firstName']?.toString(),
    lastName: map['lastName']?.toString(),
  );

  String? get label {
    final n = name;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return fullName;
  }

  String? get fullName {
    final combined = [firstName, lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join(' ');
    if (combined.isNotEmpty) return combined;
    final n = name;
    return (n != null && n.trim().isNotEmpty) ? n.trim() : null;
  }
}

class ContactInfo {
  final Map<String, dynamic> raw;
  final List<ContactName> names;

  const ContactInfo({required this.raw, required this.names});

  factory ContactInfo.fromMap(Map<String, dynamic> map) {
    final rawNames = map['names'];
    final names = <ContactName>[];
    if (rawNames is List) {
      for (final n in rawNames) {
        if (n is Map) names.add(ContactName.fromMap(n));
      }
    }
    return ContactInfo(raw: map, names: names);
  }

  String? get displayName {
    String? firstLabel;
    for (final n in names) {
      final label = n.label;
      if (label == null) continue;
      firstLabel ??= label;
      if (n.type == 'ONEME') return label;
    }
    return firstLabel;
  }

  String? get customFullName => _fullNameOfType('CUSTOM');

  String? get onemeFullName => _fullNameOfType('ONEME');

  String? get fullName => customFullName ?? onemeFullName ?? displayName;

  bool get isSavedContact => customFullName != null;

  String? _fullNameOfType(String type) {
    for (final n in names) {
      if (n.type != type) continue;
      final full = n.fullName;
      if (full != null) return full;
    }
    return null;
  }

  String? get firstName {
    for (final n in names) {
      final f = n.firstName;
      if (f != null && f.trim().isNotEmpty) return f.trim();
    }
    return null;
  }

  String? get avatarUrl => raw['baseUrl'] as String?;

  List<String> get options {
    final o = raw['options'];
    return o is List ? o.whereType<String>().toList() : const [];
  }

  bool get isBot => options.contains('BOT');

  bool get isDeleted {
    final status = raw['accountStatus'];
    return status is int && status != 0;
  }

  int? get id => raw['id'] as int?;
}
