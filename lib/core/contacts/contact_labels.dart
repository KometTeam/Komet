import '../utils/format.dart';
import '../utils/names.dart';
import 'device_contacts_service.dart';

// #***! заголовок и подпись строки контакта
class ContactLabels {
  final String title;
  final String? subtitle;

  const ContactLabels({required this.title, this.subtitle});
}

// #***! имя из телефонной книги важнее серверного
String? contactName({Object? firstName, Object? lastName, Object? phone}) {
  final book = phone is int ? DeviceContactsService.nameForPhone(phone) : null;
  if (book != null && book.isNotEmpty) return book;
  final full = displayName(firstName, lastName);
  return full.isEmpty ? null : full;
}

// #***! сортируем по имени, нет так по телефону
String contactSortKey({Object? firstName, Object? lastName, Object? phone}) =>
    contactName(firstName: firstName, lastName: lastName, phone: phone) ??
    formatPhone(phone) ??
    '';

// #***! подпись не дублируем
ContactLabels contactLabels({
  required String idLabel,
  Object? firstName,
  Object? lastName,
  Object? phone,
}) {
  final phoneLabel = formatPhone(phone);
  final title =
      contactName(firstName: firstName, lastName: lastName, phone: phone) ??
      phoneLabel ??
      idLabel;
  final subtitle = phoneLabel ?? idLabel;
  return ContactLabels(
    title: title,
    subtitle: subtitle == title ? null : subtitle,
  );
}
