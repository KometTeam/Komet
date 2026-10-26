import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/parse.dart';
import 'package:komet/models/attachment.dart';

String _garble(String name) => latin1.decode(utf8.encode(name));

void main() {
  test('кириллица, прочитанная сервером как Latin-1, возвращается', () {
    expect(
      repairLatin1Mojibake(_garble('отпуск ляубах.docx')),
      'отпуск ляубах.docx',
    );
  });

  test('нормальные имена не трогаем', () {
    expect(
      repairLatin1Mojibake('отпуск тюменцев.docx'),
      'отпуск тюменцев.docx',
    );
    expect(repairLatin1Mojibake('report-2026.pdf'), 'report-2026.pdf');
    expect(repairLatin1Mojibake('café.docx'), 'café.docx');
    expect(repairLatin1Mojibake(''), '');
    expect(repairLatin1Mojibake(null), isNull);
  });

  test('имя файла во вложении приходит уже починенным', () {
    final file = FileAttachment.fromMap({
      '_type': 'FILE',
      'fileId': 1,
      'name': _garble('синтетический отчёт.docx'),
    });
    expect(file.name, 'синтетический отчёт.docx');
  });

  test(
    'имя для загрузки кодируется процентами, как у официальных клиентов',
    () {
      expect(Uri.encodeComponent('отпуск.docx'), startsWith('%D0%BE%D1%82'));
      expect(
        Uri.decodeComponent(Uri.encodeComponent('отпуск ляубах.docx')),
        'отпуск ляубах.docx',
      );
    },
  );
}
