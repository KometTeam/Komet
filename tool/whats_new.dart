import 'dart:io';

import 'package:komet/core/whats_new/whats_new_document.dart';

const int _playLimit = 500;
const String _dir = 'assets/whats_new';

void main(List<String> args) {
  if (args.length == 2 && args.first == 'play') {
    exit(_play(args[1]));
  }
  if (args.isNotEmpty) {
    stderr.writeln(
      'dart run tool/whats_new.dart            проверить все языки',
    );
    stderr.writeln(
      'dart run tool/whats_new.dart play <ru>  текст для Google Play',
    );
    exit(64);
  }
  exit(_checkAll());
}

WhatsNewDocument? _load(String language) {
  final file = File('$_dir/$language.txt');
  if (!file.existsSync()) {
    stderr.writeln('нет файла ${file.path}');
    return null;
  }
  return WhatsNewDocument.parse(file.readAsStringSync());
}

int _play(String language) {
  final document = _load(language);
  if (document == null) return 1;
  final text = document.plainText;
  stdout.writeln(text);
  final length = text.runes.length;
  if (length > _playLimit) {
    stderr.writeln(
      '\n$length символов — Google Play примет не больше $_playLimit',
    );
    return 1;
  }
  return 0;
}

int _checkAll() {
  final files =
      Directory(_dir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.txt'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  var failed = false;
  for (final file in files) {
    final language = file.uri.pathSegments.last.replaceAll('.txt', '');
    final document = WhatsNewDocument.parse(file.readAsStringSync());
    final length = document.plainText.runes.length;
    final links = document.notes
        .where(
          (note) =>
              note.target != null ||
              note.spans.any((s) => s is WhatsNewLinkSpan),
        )
        .length;
    stdout.writeln(
      '$language: ${document.notes.length} пунктов, $links с переходом, '
      '${document.scenarios.length} сценариев, $length/$_playLimit символов для Play',
    );
    for (final problem in document.problems) {
      stdout.writeln('  ✗ $problem');
      failed = true;
    }
  }
  return failed ? 1 : 0;
}
