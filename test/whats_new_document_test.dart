import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/whats_new/spotlight_ids.dart';
import 'package:komet/core/whats_new/whats_new_document.dart';
import 'package:komet/frontend/widgets/spotlight.dart';

void main() {
  group('notes', () {
    test('inline links, whole-line targets and plain lines', () {
      final document = WhatsNewDocument.parse('''
// comment for writers
• Plain line.
• Open [the storage](#storage) to see it.
• Whole line goes to devices. → :settings/devices

#storage
    open :settings/storage
''');

      expect(document.problems, isEmpty);
      expect(document.notes, hasLength(3));
      expect(document.notes[0].target, isNull);
      expect(document.notes[0].spans.single, isA<WhatsNewPlainSpan>());

      final linked = document.notes[1].spans;
      expect(linked.map((s) => s.text), [
        '• Open ',
        'the storage',
        ' to see it.',
      ]);
      expect((linked[1] as WhatsNewLinkSpan).target.scenario, 'storage');

      final whole = document.notes[2];
      expect(whole.text, '• Whole line goes to devices.');
      expect(whole.target?.link, 'https://max.ru/:settings/devices');

      expect(
        document.plainText,
        '• Plain line.\n'
        '• Open the storage to see it.\n'
        '• Whole line goes to devices.',
      );
    });

    test('external links are kept as they are', () {
      final document = WhatsNewDocument.parse(
        '• Read [the post](https://example.test/post).',
      );
      final span = document.notes.single.spans[1] as WhatsNewLinkSpan;
      expect(span.target.link, 'https://example.test/post');
    });
  });

  group('scenarios', () {
    test('steps keep quoted text and escaped quotes', () {
      final document = WhatsNewDocument.parse('''
#tour
    tab settings
    hint ${SpotlightIds.settingsStorage} "Say \\"hi\\" here"
    notify "Done" "Again" #tour2
    wait 300
#tour2
    close
''');
      expect(document.problems, isEmpty);
      final steps = document.scenarios['tour']!;
      expect(steps.map((s) => s.command), [
        WhatsNewCommand.tab,
        WhatsNewCommand.hint,
        WhatsNewCommand.notify,
        WhatsNewCommand.wait,
      ]);
      expect(steps[1].args, [SpotlightIds.settingsStorage, 'Say "hi" here']);
      expect(steps[2].args, ['Done', 'Again', '#tour2']);
    });

    test('mistakes are reported with their line and dropped', () {
      final document = WhatsNewDocument.parse('''
• Broken [link](#missing).
#tour
    tab gallery
    highlight nowhere.button
    jump
    wait forever
    notify "unclosed
''');
      expect(document.problems, [
        'строка 3: tab chats | calls | contacts | settings',
        'строка 4: нет элемента «nowhere.button» (см. SpotlightIds)',
        'строка 5: неизвестная команда «jump»',
        'строка 6: wait <мс от 0 до 10000>',
        'строка 7: не закрыта кавычка',
        'строка 1: нет сценария #missing',
      ]);
      expect(document.scenarios['tour'], isEmpty);
    });

    test('only elements with an action can be tapped', () {
      final document = WhatsNewDocument.parse('''
#tour
    tap ${SpotlightIds.settingsStorage}
    tap ${SpotlightIds.storageLimit}
''');
      expect(document.problems, [
        'строка 3: «${SpotlightIds.storageLimit}» нельзя нажать '
            '(см. SpotlightIds.tappable)',
      ]);
      expect(document.scenarios['tour'], hasLength(1));
    });

    test('scenarios that run each other in a loop are reported', () {
      final document = WhatsNewDocument.parse('''
#a
    run #b
#b
    run #a
''');
      expect(document.problems.single, contains('зациклены'));
    });
  });

  test('shipped notes parse cleanly and languages stay in step', () {
    final files = Directory('assets/whats_new')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.txt'))
        .toList();
    expect(files, isNotEmpty);

    final documents = {
      for (final file in files)
        file.path: WhatsNewDocument.parse(file.readAsStringSync()),
    };
    for (final MapEntry(key: path, value: document) in documents.entries) {
      expect(document.problems, isEmpty, reason: path);
    }
    final reference = documents.values.first;
    for (final MapEntry(key: path, value: document) in documents.entries) {
      expect(
        document.scenarios.keys.toSet(),
        reference.scenarios.keys.toSet(),
        reason: '$path has a different set of scenarios',
      );
      expect(
        document.notes.length,
        reference.notes.length,
        reason: '$path has a different number of notes',
      );
    }
  });

  testWidgets('a target far down a lazy list is scrolled to and found', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 120,
            itemBuilder: (context, index) => index == 90
                ? const SpotlightTarget(
                    id: SpotlightIds.storageLimit,
                    child: SizedBox(height: 60, child: Text('target')),
                  )
                : SizedBox(height: 60, child: Text('row $index')),
          ),
        ),
      ),
    );
    expect(find.text('target'), findsNothing);

    var done = false;
    var found = false;
    Spotlight.highlight(SpotlightIds.storageLimit).then((value) {
      found = value;
      done = true;
    });
    for (var i = 0; i < 400 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(found, isTrue);
    final rect = tester.getRect(find.text('target'));
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.contains(rect.center), isTrue);
  });
}
