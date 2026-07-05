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
    final combined = [firstName, lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .join(' ');
    return combined.isEmpty ? null : combined;
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

  int? get id => raw['id'] as int?;
}
