import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/plugins/plugin_manifest.dart';
import 'package:komet/frontend/screens/profile/plugins_screen.dart';

void main() {
  testWidgets('URL dialog closes without disposed controller errors', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) => const PluginUrlDialog(),
                );
              },
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.org/synthetic.kinet',
    );
    await tester.tap(find.text('Загрузить'));
    await tester.pumpAndSettle();

    expect(result, 'https://example.org/synthetic.kinet');
    expect(tester.takeException(), isNull);
  });

  testWidgets('URL dialog can be cancelled after input without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => const PluginUrlDialog(),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://example.org/synthetic.kinet',
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(PluginUrlDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('weather plugin declares network access and city argument', () {
    final raw = jsonDecode(
      File('assets/plugins/weather/manifest.json').readAsStringSync(),
    );
    final manifest = PluginManifest.fromJson(Map<String, dynamic>.from(raw));

    expect(manifest.permissions, contains(PluginPermission.network));
    expect(manifest.permissions, contains(PluginPermission.chatWrite));
    expect(manifest.commands.single.name, '/weather');
    expect(manifest.commands.single.arguments.single.name, 'city');
  });

  test('fox plugin declares network and photo permissions', () {
    final raw = jsonDecode(
      File('assets/plugins/fox/manifest.json').readAsStringSync(),
    );
    final manifest = PluginManifest.fromJson(Map<String, dynamic>.from(raw));

    expect(manifest.permissions, contains(PluginPermission.network));
    expect(manifest.permissions, contains(PluginPermission.photoWrite));
    expect(manifest.commands.single.name, '/fox');
    expect(manifest.commands.single.arguments, isEmpty);
  });
}
