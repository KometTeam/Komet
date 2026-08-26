import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_icon.dart';

Set<String> _iosAlternateIcons() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final anchor = plist.indexOf('<key>CFBundleAlternateIcons</key>');
  expect(
    anchor,
    isNonNegative,
    reason: 'в Info.plist нет альтернативных иконок',
  );
  final tokens = RegExp(
    r'<dict>|</dict>|<key>([^<]*)</key>',
  ).allMatches(plist.substring(anchor));

  final names = <String>{};
  var depth = 0;
  var entered = false;
  for (final token in tokens) {
    final text = token.group(0)!;
    if (text == '<dict>') {
      depth++;
      entered = true;
    } else if (text == '</dict>') {
      depth--;
      if (entered && depth == 0) break;
    } else if (entered && depth == 1) {
      names.add(token.group(1)!);
    }
  }
  return names;
}

Set<String> _androidComponents() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  return RegExp(
    r'android:name="ru\.komet\.app\.(\w+)"',
  ).allMatches(manifest).map((m) => m.group(1)!).toSet();
}

Set<String> _androidIconKeys() {
  final source = File(
    'android/app/src/main/kotlin/ru/komet/app/MainActivity.kt',
  ).readAsStringSync();
  final start = source.indexOf('iconComponents = mapOf(');
  expect(start, isNonNegative, reason: 'в MainActivity нет карты иконок');
  final body = source.substring(start, source.indexOf(')', start));
  return RegExp(r'"(\w+)" to').allMatches(body).map((m) => m.group(1)!).toSet();
}

void main() {
  test('дефолтная иконка на iOS — это primary, а не альтернативная', () {
    expect(
      AppIcon.defaultIcon.iosAlternateName,
      isNull,
      reason: 'setAlternateIconName ждёт nil, любое имя тут — APPLY_FAILED',
    );
  });

  test('каждая альтернативная иконка объявлена в Info.plist', () {
    final declared = _iosAlternateIcons();
    for (final icon in AppIcon.values) {
      final name = icon.iosAlternateName;
      if (name == null) continue;
      expect(
        declared,
        contains(name),
        reason: 'иконка ${icon.id} шлёт в iOS имя $name',
      );
    }
  });

  test('каждый android alias объявлен в манифесте и в MainActivity', () {
    final components = _androidComponents();
    final keys = _androidIconKeys();
    for (final icon in AppIcon.values) {
      expect(
        components,
        contains(icon.androidAlias),
        reason: 'иконка ${icon.id} шлёт в Android имя ${icon.androidAlias}',
      );
      expect(keys, contains(icon.androidAlias));
    }
  });

  test('имена иконок не пересекаются между платформами по смыслу', () {
    final ids = AppIcon.values.map((i) => i.id).toSet();
    expect(ids.length, AppIcon.values.length);
    final aliases = AppIcon.values.map((i) => i.androidAlias).toSet();
    expect(aliases.length, AppIcon.values.length);
  });
}
