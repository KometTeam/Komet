// #***! номер из телефонной книги в том виде как уходит в SYNC
class PhonebookEntry {
  final String phone;
  final String firstName;
  final String? lastName;

  const PhonebookEntry({
    required this.phone,
    required this.firstName,
    this.lastName,
  });

  Map<String, String> toWire() => {
    'firstName': firstName,
    'lastName': ?lastName,
  };

  @override
  bool operator ==(Object other) =>
      other is PhonebookEntry &&
      other.phone == phone &&
      other.firstName == firstName &&
      other.lastName == lastName;

  @override
  int get hashCode => Object.hash(phone, firstName, lastName);
}
