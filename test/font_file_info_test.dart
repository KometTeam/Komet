import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/font_file_info.dart';

typedef _Name = ({int platform, int language, int nameId, List<int> bytes});

List<int> _utf16be(String s) => [
  for (final unit in s.codeUnits) ...[unit >> 8, unit & 0xff],
];

Uint8List _nameTable(List<_Name> names) {
  final storage = <int>[];
  final records = _Bytes();
  for (final name in names) {
    records
      ..u16(name.platform)
      ..u16(name.platform == 3 ? 1 : 0)
      ..u16(name.language)
      ..u16(name.nameId)
      ..u16(name.bytes.length)
      ..u16(storage.length);
    storage.addAll(name.bytes);
  }
  return (_Bytes()
        ..u16(0)
        ..u16(names.length)
        ..u16(6 + names.length * 12)
        ..addAll(records.bytes)
        ..addAll(storage))
      .toBytes();
}

Uint8List _font(List<_Name> names, {bool collection = false}) {
  final table = _nameTable(names);
  final headerSize = collection ? 16 : 0;
  final fontOffset = headerSize;
  final tableOffset = fontOffset + 12 + 16;
  final out = _Bytes();
  if (collection) {
    out
      ..u32(0x74746366)
      ..u32(0x00010000)
      ..u32(1)
      ..u32(fontOffset);
  }
  out
    ..u32(0x00010000)
    ..u16(1)
    ..u16(16)
    ..u16(0)
    ..u16(0)
    ..addAll('name'.codeUnits)
    ..u32(0)
    ..u32(tableOffset)
    ..u32(table.length)
    ..addAll(table);
  return out.toBytes();
}

class _Bytes {
  final List<int> bytes = [];

  void u16(int v) => bytes.addAll([(v >> 8) & 0xff, v & 0xff]);

  void u32(int v) => bytes.addAll([
    (v >> 24) & 0xff,
    (v >> 16) & 0xff,
    (v >> 8) & 0xff,
    v & 0xff,
  ]);

  void addAll(Iterable<int> values) => bytes.addAll(values);

  Uint8List toBytes() => Uint8List.fromList(bytes);
}

void main() {
  test('the typographic family wins over the legacy one', () {
    final font = _font([
      (platform: 3, language: 0x0409, nameId: 1, bytes: _utf16be('Synth Bold')),
      (platform: 3, language: 0x0409, nameId: 16, bytes: _utf16be('Synth')),
    ]);
    expect(FontFileInfo.familyName(font), 'Synth');
  });

  test('the English Windows name is preferred, others are a fallback', () {
    final font = _font([
      (platform: 1, language: 0, nameId: 1, bytes: 'Mac Synth'.codeUnits),
      (platform: 3, language: 0x0419, nameId: 1, bytes: _utf16be('Синтез')),
      (platform: 3, language: 0x0409, nameId: 1, bytes: _utf16be('Synth')),
    ]);
    expect(FontFileInfo.familyName(font), 'Synth');

    final onlyRussian = _font([
      (platform: 3, language: 0x0419, nameId: 1, bytes: _utf16be('Синтез')),
    ]);
    expect(FontFileInfo.familyName(onlyRussian), 'Синтез');
  });

  test('a collection is read from its first font', () {
    final font = _font([
      (platform: 3, language: 0x0409, nameId: 1, bytes: _utf16be('Synth')),
    ], collection: true);
    expect(FontFileInfo.familyName(font), 'Synth');
  });

  test('garbage has no family name', () {
    expect(FontFileInfo.familyName(Uint8List.fromList([1, 2, 3])), isNull);
    expect(FontFileInfo.familyName(_font(const [])), isNull);
  });

  test('the file name loses its style suffix and separators', () {
    expect(FontFileInfo.familyFromFileName('/tmp/Synth-Regular.ttf'), 'Synth');
    expect(
      FontFileInfo.familyFromFileName('Synth_Sans-VariableFont_wght.ttf'),
      'Synth Sans',
    );
    expect(FontFileInfo.familyFromFileName('Mono.otf'), 'Mono');
  });
}
