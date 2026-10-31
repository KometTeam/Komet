import '../links/max_link.dart';
import 'spotlight_ids.dart';

enum WhatsNewTab { chats, calls, contacts, settings }

enum WhatsNewCommand {
  close,
  tab,
  open,
  back,
  scroll,
  highlight,
  tap,
  hint,
  notify,
  wait,
  run,
}

class WhatsNewTarget {
  const WhatsNewTarget.scenario(String this.scenario) : link = null;
  const WhatsNewTarget.link(String this.link) : scenario = null;

  final String? scenario;
  final String? link;

  static final RegExp _name = RegExp(r'^[\w.-]+$');

  static WhatsNewTarget? parse(String raw) {
    final value = raw.trim();
    if (value.startsWith('#')) {
      final name = value.substring(1);
      return _name.hasMatch(name) ? WhatsNewTarget.scenario(name) : null;
    }
    final link = value.startsWith(':') ? 'https://max.ru/$value' : value;
    if (MaxLink.parse(link) != null) return WhatsNewTarget.link(link);
    final uri = Uri.tryParse(link);
    if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
      return WhatsNewTarget.link(link);
    }
    return null;
  }
}

sealed class WhatsNewSpan {
  const WhatsNewSpan(this.text);

  final String text;
}

final class WhatsNewPlainSpan extends WhatsNewSpan {
  const WhatsNewPlainSpan(super.text);
}

final class WhatsNewLinkSpan extends WhatsNewSpan {
  const WhatsNewLinkSpan(super.text, this.target);

  final WhatsNewTarget target;
}

class WhatsNewNote {
  const WhatsNewNote(this.spans, {this.target});

  final List<WhatsNewSpan> spans;
  final WhatsNewTarget? target;

  String get text => spans.map((span) => span.text).join();
}

class WhatsNewStep {
  const WhatsNewStep(this.command, this.args);

  final WhatsNewCommand command;
  final List<String> args;
}

class WhatsNewDocument {
  const WhatsNewDocument._(this.notes, this.scenarios, this.problems);

  static const WhatsNewDocument empty = WhatsNewDocument._([], {}, []);

  final List<WhatsNewNote> notes;
  final Map<String, List<WhatsNewStep>> scenarios;
  final List<String> problems;

  String get plainText => notes.map((note) => note.text).join('\n');

  factory WhatsNewDocument.parse(String source) => _Parser(source).parse();
}

class _Parser {
  _Parser(this.source);

  static final RegExp _header = RegExp(r'^#([\w.-]+)\s*$');
  static final RegExp _wholeLine = RegExp(r'^(.*\S)\s+→\s+(\S+)$');
  static final RegExp _inline = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');

  final String source;
  final List<WhatsNewNote> _notes = [];
  final Map<String, List<WhatsNewStep>> _scenarios = {};
  final List<String> _problems = [];
  final List<(String, int)> _scenarioRefs = [];
  final Map<String, List<String>> _runs = {};

  WhatsNewDocument parse() {
    String? scenario;
    final lines = source.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final number = i + 1;
      final line = lines[i].replaceAll('\r', '').trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('//')) continue;

      final header = _header.firstMatch(line);
      if (header != null) {
        final name = header.group(1)!;
        if (_scenarios.containsKey(name)) {
          _problem(number, 'сценарий #$name объявлен второй раз');
        }
        _scenarios[name] = [];
        scenario = name;
        continue;
      }

      if (line.length != trimmed.length) {
        if (scenario == null) {
          _problem(number, 'шаг с отступом стоит вне сценария');
          continue;
        }
        final step = _step(trimmed, number, scenario);
        if (step != null) _scenarios[scenario]!.add(step);
        continue;
      }

      scenario = null;
      _notes.add(_note(line, number));
    }

    for (final (name, number) in _scenarioRefs) {
      if (!_scenarios.containsKey(name)) {
        _problem(number, 'нет сценария #$name');
      }
    }
    _checkCycles();
    return WhatsNewDocument._(_notes, _scenarios, _problems);
  }

  WhatsNewNote _note(String line, int number) {
    var body = line;
    WhatsNewTarget? whole;
    final arrow = _wholeLine.firstMatch(line);
    if (arrow != null) {
      whole = _target(arrow.group(2)!, number);
      if (whole != null) body = arrow.group(1)!;
    }

    final spans = <WhatsNewSpan>[];
    var cursor = 0;
    for (final match in _inline.allMatches(body)) {
      if (match.start > cursor) {
        spans.add(WhatsNewPlainSpan(body.substring(cursor, match.start)));
      }
      final words = match.group(1)!;
      final target = _target(match.group(2)!, number);
      spans.add(
        target == null
            ? WhatsNewPlainSpan(words)
            : WhatsNewLinkSpan(words, target),
      );
      cursor = match.end;
    }
    if (cursor < body.length) {
      spans.add(WhatsNewPlainSpan(body.substring(cursor)));
    }
    return WhatsNewNote(spans, target: whole);
  }

  WhatsNewTarget? _target(String raw, int number) {
    final target = WhatsNewTarget.parse(raw);
    if (target == null) {
      _problem(number, 'не понимаю ссылку «$raw»');
      return null;
    }
    _refer(target, number);
    return target;
  }

  void _refer(WhatsNewTarget target, int number) {
    final scenario = target.scenario;
    if (scenario != null) _scenarioRefs.add((scenario, number));
  }

  WhatsNewStep? _step(String text, int number, String scenario) {
    final tokens = _tokens(text);
    if (tokens == null) {
      _problem(number, 'не закрыта кавычка');
      return null;
    }
    final command = WhatsNewCommand.values.asNameMap()[tokens.first];
    if (command == null) {
      _problem(number, 'неизвестная команда «${tokens.first}»');
      return null;
    }
    final args = tokens.sublist(1);
    final error = _check(command, args, number, scenario);
    if (error != null) {
      _problem(number, error);
      return null;
    }
    return WhatsNewStep(command, args);
  }

  String? _check(
    WhatsNewCommand command,
    List<String> args,
    int number,
    String scenario,
  ) {
    switch (command) {
      case WhatsNewCommand.close:
      case WhatsNewCommand.back:
        return args.isEmpty ? null : '«${command.name}» без аргументов';
      case WhatsNewCommand.tab:
        final known = WhatsNewTab.values.asNameMap();
        return args.length == 1 && known.containsKey(args.first)
            ? null
            : 'tab chats | calls | contacts | settings';
      case WhatsNewCommand.open:
        if (args.length != 1) return 'open <ссылка>';
        final target = WhatsNewTarget.parse(args.first);
        return target?.link == null
            ? 'open ждёт ссылку, а не «${args.first}»'
            : null;
      case WhatsNewCommand.scroll:
        if (args.length != 1) return 'scroll top | bottom | <элемент>';
        final where = args.first;
        if (where == 'top' || where == 'bottom') return null;
        return _spotlight(where);
      case WhatsNewCommand.tap:
        if (args.length != 1) return 'tap <элемент>';
        return SpotlightIds.tappable.contains(args.first)
            ? null
            : '«${args.first}» нельзя нажать (см. SpotlightIds.tappable)';
      case WhatsNewCommand.highlight:
        return args.length == 1
            ? _spotlight(args.first)
            : 'highlight <элемент>';
      case WhatsNewCommand.hint:
        return args.length == 2
            ? _spotlight(args.first)
            : 'hint <элемент> "текст"';
      case WhatsNewCommand.notify:
        if (args.length == 1) return null;
        if (args.length != 3) return 'notify "текст" ["кнопка" #сценарий]';
        final target = WhatsNewTarget.parse(args[2]);
        if (target == null) return 'не понимаю ссылку «${args[2]}»';
        _refer(target, number);
        return null;
      case WhatsNewCommand.wait:
        final ms = args.length == 1 ? int.tryParse(args.first) : null;
        return ms != null && ms >= 0 && ms <= 10000
            ? null
            : 'wait <мс от 0 до 10000>';
      case WhatsNewCommand.run:
        final target = args.length == 1
            ? WhatsNewTarget.parse(args.first)
            : null;
        final name = target?.scenario;
        if (target == null || name == null) return 'run #сценарий';
        _refer(target, number);
        _runs.putIfAbsent(scenario, () => []).add(name);
        return null;
    }
  }

  String? _spotlight(String id) => SpotlightIds.all.contains(id)
      ? null
      : 'нет элемента «$id» (см. SpotlightIds)';

  void _checkCycles() {
    final done = <String>{};
    final path = <String>[];
    void visit(String name) {
      if (done.contains(name)) return;
      if (path.contains(name)) {
        _problems.add('сценарии зациклены: ${[...path, name].join(' → ')}');
        return;
      }
      path.add(name);
      for (final next in _runs[name] ?? const <String>[]) {
        visit(next);
      }
      path.removeLast();
      done.add(name);
    }

    _runs.keys.forEach(visit);
  }

  void _problem(int number, String message) =>
      _problems.add('строка $number: $message');

  static List<String>? _tokens(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    var inToken = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (quoted) {
        if (char == r'\' && i + 1 < text.length) {
          buffer.write(text[++i]);
        } else if (char == '"') {
          quoted = false;
        } else {
          buffer.write(char);
        }
        continue;
      }
      if (char == '"') {
        quoted = true;
        inToken = true;
      } else if (char == ' ' || char == '\t') {
        if (inToken) {
          tokens.add(buffer.toString());
          buffer.clear();
          inToken = false;
        }
      } else {
        buffer.write(char);
        inToken = true;
      }
    }
    if (quoted) return null;
    if (inToken) tokens.add(buffer.toString());
    return tokens;
  }
}
